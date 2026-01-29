// build.zig - Builds the osOS kernel for various architectures
// Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const builtin = @import("builtin");

const BuildOptions = struct {
    default_run_target: SupportedTarget,
    boot_specification: BootSpecification,
    boot_loader: BootLoader,
    test_panic: bool,
    build_bochs: bool,

    pub fn init(b: *std.Build) BuildOptions {
        return .{
            .default_run_target = b.option(
                SupportedTarget,
                "arch",
                "Target Architecture",
            ) orelse .x86,
            .boot_specification = b.option(
                BootSpecification,
                "boot_specification",
                "Boot specification to boot the kernel with",
            ) orelse .MultibootOne,
            .test_panic = b.option(
                bool,
                "test_panic",
                "Test the panic handler in kmain",
            ) orelse false,
            .boot_loader = b.option(
                BootLoader,
                "bootloader",
                "Boot loader to build into image (only on x86)",
            ) orelse .grub_legacy,
            .build_bochs = b.option(
                bool,
                "build_bochs",
                "Build bochs from source",
            ) orelse false,
        };
    }
};

const SupportedTarget = enum {
    x86,
    riscv32,
};

const BootSpecification = enum {
    MultibootOne,
    MultibootTwo,
    Limine,
};

const BootLoader = enum {
    grub_legacy,
    limine,
};

const CommonModule = struct {
    name: []const u8,
    module: *std.Build.Module,

    // Some tests are not yet supported to run on my OS just yet, and need
    // to happen on the native target.
    test_artifact: *std.Build.Step.Compile,
    emitted_doc_directory: std.Build.LazyPath,

    pub fn create(
        b: *std.Build,
        name: []const u8,
        root_source_file: []const u8,
        test_target: std.Build.ResolvedTarget,
    ) CommonModule {
        const root = b.path(root_source_file);
        const actual_module = b.createModule(.{
            .root_source_file = root,
        });
        const doc_directory, const test_artifact = doc: {
            const native_target = builtin.target;
            const native_target_query = std.Target.Query.fromTarget(
                &native_target,
            );
            const resolved_native_target = b.resolveTargetQuery(
                native_target_query,
            );
            // The library object shouldn't be used by anyone, so encapsulate
            // it here
            const doc_mod = b.createModule(.{
                .root_source_file = root,
                .target = resolved_native_target,
            });
            const doc_lib = b.addLibrary(.{
                .name = name,
                .root_module = doc_mod,
            });

            const test_mod = b.createModule(.{
                .root_source_file = root,
                .target = test_target,
            });

            break :doc .{
                doc_lib.getEmittedDocs(),
                b.addTest(.{
                    .root_module = test_mod,
                }),
            };
        };

        return .{
            .name = name,
            .module = actual_module,
            .emitted_doc_directory = doc_directory,
            .test_artifact = test_artifact,
        };
    }
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) std.mem.Allocator.Error!void {
    const zigver = builtin.zig_version;
    std.debug.print(
        "building with zig version: {}.{}.{}\n",
        .{ zigver.major, zigver.minor, zigver.patch },
    );

    std.debug.print("*************** Build time options **************\n", .{});
    const build_options: BuildOptions = .init(b);
    inline for (comptime std.meta.fieldNames(BuildOptions)) |option_name| {
        const option = @field(build_options, option_name);
        std.debug.print("Option: {s}\n", .{option_name});
        std.debug.print("\tValue: {}\n\n", .{option});
    }
    std.debug.print("*************************************************\n", .{});

    //**************************************************************************
    //                               Option Setup                              *
    //**************************************************************************
    const optimize = b.standardOptimizeOption(.{});
    const test_target = b.standardTargetOptions(.{});

    const kernel_name = "osOS.elf";

    const x86_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        // remove features not guaranteed to exist on the original i386
        .cpu_features_sub = std.Target.x86.featureSet(&.{
            .mmx,
            .sse,
            .sse2,
            .sse3,
            .sse4_1,
            .sse4_2,
            .sse4a,
            .sse_unaligned_mem,
            .ssse3,
            .avx,
        }),
    });
    const riscv32_target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const boot_options = b.addOptions();
    boot_options.addOption(
        BootSpecification,
        "boot_specification",
        build_options.boot_specification,
    );

    const test_options = b.addOptions();
    test_options.addOption(bool, "test_panic", build_options.test_panic);

    const depbochs = b.lazyDependency(
        "bochs_zig",
        .{ .@"with-x11" = true, .@"with-sdl" = true },
    );

    //**************************************************************************
    //                               Module Setup                              *
    //**************************************************************************

    //* ******************************* Shared ******************************* *

    const SharedModules = struct {
        osformat: CommonModule,
        osmemory: CommonModule,
        osprocess: CommonModule,
        osboot: CommonModule,
        oshal: CommonModule,
        osshell: CommonModule,
        osstdlib: CommonModule,
    };

    const shared_modules: SharedModules = .{
        .osformat = .create(b, "osformat", "format/root.zig", test_target),
        .osmemory = .create(b, "osmemory", "memory/root.zig", test_target),
        .osprocess = .create(b, "osprocess", "process/root.zig", test_target),
        .osboot = .create(b, "osboot", "boot_utilities/bootutils.zig", test_target),
        .oshal = .create(b, "oshal", "HAL/root.zig", test_target),
        .osshell = .create(b, "osshell", "userland/shell/shell.zig", test_target),
        .osstdlib = .create(b, "osstdlib", "userland/stdlib/root.zig", test_target),
    };

    const modbochs = bochs: {
        if (!build_options.build_bochs) {
            break :bochs null;
        } else if (depbochs) |dep| {
            break :bochs dep.module("bochs");
        } else {
            break :bochs null;
        }
    };

    //* *************************** RISC Specific **************************** *
    const RiscV32Modules = struct {
        asm_module: CommonModule,
        tty_module: CommonModule,
    };
    const riscv32_modules: RiscV32Modules = .{
        .asm_module = .create(b, "riscv32asm", "arch/riscv32/asm/root.zig", test_target),
        .tty_module = .create(b, "riscv32tty", "arch/riscv32/tty/root.zig", test_target),
    };

    riscv32_modules.tty_module.module.addImport(
        shared_modules.osformat.name,
        shared_modules.osformat.module,
    );

    const riscv32_module = b.createModule(.{
        .root_source_file = b.path("arch/riscv32/entry.zig"),
        .target = riscv32_target,
        .optimize = optimize,
        .strip = false,
    });
    riscv32_module.addImport(
        riscv32_modules.tty_module.name,
        riscv32_modules.tty_module.module,
    );
    riscv32_module.addImport(
        riscv32_modules.asm_module.name,
        riscv32_modules.asm_module.module,
    );
    riscv32_module.addImport(
        shared_modules.osformat.name,
        shared_modules.osformat.module,
    );
    riscv32_module.addImport(
        shared_modules.osmemory.name,
        shared_modules.osmemory.module,
    );
    riscv32_module.addImport(
        shared_modules.osprocess.name,
        shared_modules.osprocess.module,
    );
    riscv32_module.addImport(
        shared_modules.oshal.name,
        shared_modules.oshal.module,
    );

    //* *************************** x86 Specific ***************************** *
    const X86Modules = struct {
        asm_module: CommonModule,
        serial_module: CommonModule,
        framebuffer_module: CommonModule,
        memory_module: CommonModule,
        interrupts_module: CommonModule,
    };
    const x86_modules: X86Modules = .{
        .asm_module = .create(b, "x86asm", "arch/x86/asm/root.zig", test_target),
        .serial_module = .create(b, "x86serial", "arch/x86/io/root.zig", test_target),
        .framebuffer_module = .create(b, "x86framebuffer", "arch/x86/framebuffer/root.zig", test_target),
        .memory_module = .create(b, "x86memory", "arch/x86/memory/root.zig", test_target),
        .interrupts_module = .create(b, "x86interrupts", "arch/x86/interrupts/root.zig", test_target),
    };

    x86_modules.serial_module.module.addImport(
        x86_modules.asm_module.name,
        x86_modules.asm_module.module,
    );

    x86_modules.framebuffer_module.module.addImport(
        x86_modules.asm_module.name,
        x86_modules.asm_module.module,
    );
    x86_modules.framebuffer_module.module.addImport(
        shared_modules.osformat.name,
        shared_modules.osformat.module,
    );

    x86_modules.memory_module.module.addImport(
        x86_modules.asm_module.name,
        x86_modules.asm_module.module,
    );

    x86_modules.interrupts_module.module.addImport(
        x86_modules.asm_module.name,
        x86_modules.asm_module.module,
    );
    x86_modules.interrupts_module.module.addImport(
        x86_modules.serial_module.name,
        x86_modules.serial_module.module,
    );
    x86_modules.interrupts_module.module.addImport(
        x86_modules.framebuffer_module.name,
        x86_modules.framebuffer_module.module,
    );
    x86_modules.interrupts_module.module.addImport(
        shared_modules.osformat.name,
        shared_modules.osformat.module,
    );

    const x86_module = b.createModule(.{
        .root_source_file = b.path("arch/x86/entry.zig"),
        .target = x86_target,
        .optimize = optimize,
        .strip = false,
    });
    x86_module.addImport(
        x86_modules.asm_module.name,
        x86_modules.asm_module.module,
    );
    x86_module.addImport(
        x86_modules.memory_module.name,
        x86_modules.memory_module.module,
    );
    x86_module.addImport(
        x86_modules.interrupts_module.name,
        x86_modules.interrupts_module.module,
    );
    x86_module.addImport(
        x86_modules.framebuffer_module.name,
        x86_modules.framebuffer_module.module,
    );
    x86_module.addImport(
        x86_modules.serial_module.name,
        x86_modules.serial_module.module,
    );
    x86_module.addImport(
        shared_modules.osboot.name,
        shared_modules.osboot.module,
    );
    x86_module.addImport(
        shared_modules.osprocess.name,
        shared_modules.osprocess.module,
    );
    x86_module.addImport(
        shared_modules.osformat.name,
        shared_modules.osformat.module,
    );
    x86_module.addImport(
        shared_modules.oshal.name,
        shared_modules.oshal.module,
    );
    x86_module.addOptions("bootoptions", boot_options);

    //* *************************** Doc Specific ***************************** *
    // to properly build with an opt level and root module, we need to make
    // dummy objects for freestanding modules.

    //* ******************************* kmain ******************************** *
    const kmain_module = b.createModule(.{
        .root_source_file = b.path("kmain/kmain.zig"),
    });
    kmain_module.addImport(
        shared_modules.oshal.name,
        shared_modules.oshal.module,
    );
    kmain_module.addImport(
        shared_modules.osshell.name,
        shared_modules.osshell.module,
    );
    kmain_module.addImport(
        shared_modules.osstdlib.name,
        shared_modules.osstdlib.module,
    );
    kmain_module.addImport(
        shared_modules.osprocess.name,
        shared_modules.osprocess.module,
    );
    kmain_module.addImport(
        shared_modules.osformat.name,
        shared_modules.osformat.module,
    );
    kmain_module.addOptions(
        "testoptions",
        test_options,
    );

    x86_module.addImport("kmain", kmain_module);
    riscv32_module.addImport("kmain", kmain_module);

    //**************************************************************************
    //                           Compile Step Setup                            *
    //**************************************************************************

    //* *************************** RISC Specific **************************** *
    const riscv32_exe = b.addExecutable(.{
        .name = kernel_name,
        .root_module = riscv32_module,
    });
    riscv32_exe.entry = .disabled;
    riscv32_exe.setLinkerScript(b.path("arch/riscv32/link.ld"));

    //* *************************** x86 Specific ***************************** *
    const x86_exe = b.addExecutable(.{
        .name = kernel_name,
        .root_module = x86_module,
    });
    x86_exe.entry = .disabled;
    x86_exe.setLinkerScript(b.path("arch/x86/link.ld"));

    //* ******************************* Bochs ******************************** *
    const exebochs = bochs_exe: {
        if (modbochs) |mod| {
            break :bochs_exe b.addExecutable(.{
                .name = "bochs",
                .root_module = mod,
            });
        } else {
            break :bochs_exe null;
        }
    };

    //**************************************************************************
    //                          Install Artifact Setup                         *
    //**************************************************************************

    //* *************************** RISC Specific **************************** *
    const riscv32_step = b.step("riscv32", "Build the RISC-V32 Kernel");
    const riscv32_out = b.addInstallArtifact(riscv32_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = @tagName(std.Target.Cpu.Arch.riscv32),
            },
        },
    });
    riscv32_step.dependOn(&riscv32_out.step);
    b.getInstallStep().dependOn(&riscv32_out.step);

    //* *************************** x86 Specific ***************************** *
    const x86_step = b.step("x86", "Build the x86 Kernel");
    const x86_out = b.addInstallArtifact(x86_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = @tagName(std.Target.Cpu.Arch.x86),
            },
        },
    });
    x86_step.dependOn(&x86_out.step);
    b.getInstallStep().dependOn(&x86_out.step);

    //* *************************** Doc Specific ***************************** *
    const doc_page_step = b.step(
        "doc_site",
        "Build all docs and tie them together with the landing page",
    );

    const copy_landing_page = b.addSystemCommand(&.{
        "cp",
        "docs/index.html",
        "zig-out/docs/",
    });
    const copy_landing_style = b.addSystemCommand(&.{
        "cp",
        "docs/styles.css",
        "zig-out/docs/",
    });

    // build all module docs before copying index.html
    const x86_install_doc = b.addInstallDirectory(.{
        .source_dir = x86_exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/x86",
    });
    inline for (comptime std.meta.fieldNames(X86Modules)) |field| {
        const member = @field(x86_modules, field);
        const install_directory = b.addInstallDirectory(.{
            .source_dir = member.emitted_doc_directory,
            .install_dir = .prefix,
            .install_subdir = buf_calc: {
                var buf: std.ArrayList(u8) = .empty;
                try buf.appendSlice(b.allocator, "docs/x86modules/");
                try buf.appendSlice(b.allocator, member.name);

                break :buf_calc buf.items;
            },
        });
        copy_landing_page.step.dependOn(&install_directory.step);
    }

    const riscv32_install_doc = b.addInstallDirectory(.{
        .source_dir = riscv32_exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/" ++ @tagName(std.Target.Cpu.Arch.riscv32),
    });
    inline for (comptime std.meta.fieldNames(RiscV32Modules)) |field| {
        const member = @field(riscv32_modules, field);
        const install_directory = b.addInstallDirectory(.{
            .source_dir = member.emitted_doc_directory,
            .install_dir = .prefix,
            .install_subdir = buf_calc: {
                var buf: std.ArrayList(u8) = .empty;
                try buf.appendSlice(b.allocator, "docs/riscv32modules/");
                try buf.appendSlice(b.allocator, member.name);

                break :buf_calc buf.items;
            },
        });
        copy_landing_page.step.dependOn(&install_directory.step);
    }

    inline for (comptime std.meta.fieldNames(SharedModules)) |field_name| {
        const member = @field(shared_modules, field_name);
        const install_directory = b.addInstallDirectory(.{
            .source_dir = member.emitted_doc_directory,
            .install_dir = .prefix,
            .install_subdir = "docs/shared_modules/" ++ field_name,
        });
        copy_landing_page.step.dependOn(&install_directory.step);
    }

    copy_landing_page.step.dependOn(&x86_install_doc.step);
    copy_landing_page.step.dependOn(&riscv32_install_doc.step);

    // then copy style.css
    copy_landing_style.step.dependOn(&copy_landing_page.step);

    doc_page_step.dependOn(&copy_landing_style.step);
    b.getInstallStep().dependOn(doc_page_step);

    //* ******************************* Bochs ******************************** *
    const installbochs = install_bochs: {
        if (exebochs) |exe| {
            break :install_bochs b.addInstallArtifact(exe, .{});
        } else {
            break :install_bochs null;
        }
    };
    if (build_options.build_bochs) {
        if (installbochs) |install_bochs| {
            b.getInstallStep().dependOn(&install_bochs.step);
        }
    }

    //**************************************************************************
    //                             Run Step Setup                              *
    //**************************************************************************

    //* *************************** RISC Specific **************************** *
    const riscv32_run_step = b.step("run_riscv32", "Boot kernel with qemu on riscv32");
    const run_riscv32 = b.addSystemCommand(&.{
        "qemu-system-riscv32",
        "-machine",
        "virt",
        "-bios",
        "default",
        "-nographic",
        "-serial",
        "mon:stdio",
        "--no-reboot",
        "-kernel",
    });
    run_riscv32.addArtifactArg(riscv32_exe);
    run_riscv32.step.dependOn(riscv32_step);
    riscv32_run_step.dependOn(&run_riscv32.step);

    //* *************************** x86 Specific ***************************** *
    const isooptions = b.addOptions();
    isooptions.addOption(BootLoader, "bootloader", build_options.boot_loader);
    const modiso = b.createModule(.{
        .root_source_file = b.path("build_iso/main.zig"),
        .optimize = .ReleaseSafe,
        .target = b.resolveTargetQuery(std.Target.Query.fromTarget(&builtin.target)),
    });
    modiso.addOptions("isooptions", isooptions);
    const exeiso = b.addExecutable(.{
        .name = "build_iso",
        .root_module = modiso,
    });
    const runiso = b.addRunArtifact(exeiso);
    runiso.addFileArg(b.path(""));
    runiso.addArtifactArg(x86_exe);

    // TODO: Make these copy steps system agnostic
    const create_x86_iso_structure = b.addSystemCommand(&.{
        "mkdir",
        "-p",
        "zig-out/x86/iso/boot/grub",
    });
    create_x86_iso_structure.step.dependOn(x86_step);

    const copy_grub_files = b.addSystemCommand(&.{
        "cp",
        "arch/x86/stage2_eltorito",
        "zig-out/x86/iso/boot/grub",
    });
    copy_grub_files.step.dependOn(&create_x86_iso_structure.step);

    const copy_grub_menu = b.addSystemCommand(&.{
        "cp",
        "arch/x86/menu.lst",
        "zig-out/x86/iso/boot/grub",
    });
    copy_grub_menu.step.dependOn(&copy_grub_files.step);

    const copy_x86_kernel = b.addSystemCommand(&.{
        "cp",
    });
    copy_x86_kernel.addArtifactArg(x86_exe);
    copy_x86_kernel.addArg("zig-out/x86/iso/boot");
    copy_x86_kernel.step.dependOn(&copy_grub_menu.step);

    const create_x86_iso = b.addSystemCommand(&.{
        "genisoimage",
        "-R",
        "-b",
        "boot/grub/stage2_eltorito",
        "-no-emul-boot",
        "-boot-load-size",
        "4",
        "-A",
        "osOS",
        "-input-charset",
        "utf8",
        "-quiet",
        "-boot-info-table",
        "-o",
        "zig-out/x86/osOS.iso",
        "zig-out/x86/iso/",
    });
    create_x86_iso.step.dependOn(&copy_x86_kernel.step);

    const x86_run_qemu = b.addSystemCommand(&.{
        "qemu-system-i386",
        "-machine",
        "pc",
        "-cdrom",
        "zig-out/x86/osOS.iso",
        "-boot",
        "d",
        "-m",
        "1024",
    });

    x86_run_qemu.step.dependOn(&create_x86_iso.step);

    const x86_iso_step = b.step("iso_x86", "Build the x86 ISO disc image");
    x86_iso_step.dependOn(&create_x86_iso.step);
    x86_iso_step.dependOn(&runiso.step);

    const x86_run_step_qemu = b.step("run_x86_qemu", "Boot kernel with QEMU on x86");
    x86_run_step_qemu.dependOn(&x86_run_qemu.step);

    const x86_copy_bochs = b.addSystemCommand(&.{
        "cp",
        "arch/x86/bochs.config",
        "zig-out/x86/",
    });
    x86_copy_bochs.step.dependOn(&create_x86_iso.step);

    const x86_run_bochs = b.addSystemCommand(&.{
        "bochs",
        "-f",
        "zig-out/x86/bochs.config",
        "-q",
    });
    x86_run_bochs.step.dependOn(&x86_copy_bochs.step);

    const x86_run_step_bochs = b.step(
        "run_x86_bochs",
        "Boot kernel with BOCHS on x86",
    );
    x86_run_step_bochs.dependOn(&x86_run_bochs.step);

    const x86_run_bochs_debugger = b.addSystemCommand(&.{
        "bochs",
        "-f",
        "zig-out/x86/bochs.config",
        "-q",
        "-debugger",
    });
    x86_run_bochs_debugger.step.dependOn(&x86_copy_bochs.step);
    const x86_run_step_bochs_debugger = b.step(
        "run_x86_bochs_debugger",
        "Boot kernel with BOCHS on x86 using the built in debugger",
    );
    x86_run_step_bochs_debugger.dependOn(&x86_run_bochs_debugger.step);

    //* ************************* Generic Run Target ************************* *
    const generic_run_step = b.step(
        "run",
        "Boot kernel for specified target (x86 by default)",
    );
    generic_run_step.dependOn(switch (build_options.default_run_target) {
        .x86 => x86_run_step_qemu,
        .riscv32 => riscv32_run_step,
    });

    const generic_build_step = b.step(
        "kernel",
        "Build the kernel for just the specified target",
    );
    generic_build_step.dependOn(switch (build_options.default_run_target) {
        .x86 => x86_step,
        .riscv32 => riscv32_step,
    });

    //* ***************************** Unit Tests ***************************** *

    const arch_agnostic_test_step = b.step(
        "test",
        "Run arch-agnostic unit tests (Runnable from any host)",
    );

    inline for (comptime std.meta.fieldNames(SharedModules)) |field_name| {
        const run_test = b.addRunArtifact(
            @field(shared_modules, field_name).test_artifact,
        );
        arch_agnostic_test_step.dependOn(&run_test.step);
    }
    inline for (comptime std.meta.fieldNames(X86Modules)) |field_name| {
        const run_test = b.addRunArtifact(
            @field(x86_modules, field_name).test_artifact,
        );
        arch_agnostic_test_step.dependOn(&run_test.step);
    }
    inline for (comptime std.meta.fieldNames(RiscV32Modules)) |field_name| {
        const run_test = b.addRunArtifact(
            @field(riscv32_modules, field_name).test_artifact,
        );
        arch_agnostic_test_step.dependOn(&run_test.step);
    }
}
