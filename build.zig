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

const ModuleDocObject = struct {
    name: []const u8,
    root_file: std.Build.LazyPath,
    output_folder: []const u8,
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const kernel_name = "osOS.elf";

    //**************************************************************************
    //                               Module Setup                              *
    //**************************************************************************

    //* ******************************* Shared ******************************* *
    const osformat_module = b.createModule(.{
        .root_source_file = b.path("format/osformat.zig"),
    });

    const osmemory_module = b.createModule(.{
        .root_source_file = b.path("memory/memory.zig"),
    });

    const osprocess_module = b.createModule(.{
        .root_source_file = b.path("process/process.zig"),
    });

    //* *************************** RISC Specific **************************** *
    const riscv32_module = b.createModule(.{
        .root_source_file = b.path("entry_points/riscv32/kernel.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .riscv32,
            .os_tag = .freestanding,
            .abi = .none,
        }),
        .optimize = .ReleaseSmall,
        .strip = false,
    });
    riscv32_module.addImport("osformat", osformat_module);
    riscv32_module.addImport("osmemory", osmemory_module);
    riscv32_module.addImport("osprocess", osprocess_module);

    //* *************************** x86 Specific ***************************** *
    const x86_memory_module = b.createModule(.{
        .root_source_file = b.path("entry_points/x86/memory/memory.zig"),
    });
    const x86_asm_module = b.createModule(.{
        .root_source_file = b.path("entry_points/x86/asm/asm.zig"),
    });
    const x86_module = b.createModule(.{
        .root_source_file = b.path("entry_points/x86/entry.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
            .abi = .none,
        }),
        .optimize = .ReleaseSmall,
        .strip = false,
    });
    x86_module.addImport("osformat", osformat_module);
    x86_module.addImport("x86asm", x86_asm_module);
    x86_module.addImport("x86memory", x86_memory_module);

    //**************************************************************************
    //                           Compile Step Setup                            *
    //**************************************************************************

    //* *************************** RISC Specific **************************** *
    const riscv32_exe = b.addExecutable(.{
        .name = kernel_name,
        .root_module = riscv32_module,
    });
    riscv32_exe.entry = .disabled;
    riscv32_exe.setLinkerScript(b.path("entry_points/riscv32/link.ld"));

    //* *************************** x86 Specific ***************************** *
    const x86_exe = b.addExecutable(.{
        .name = kernel_name,
        .root_module = x86_module,
    });
    x86_exe.entry = .disabled;
    x86_exe.setLinkerScript(b.path("entry_points/x86/link.ld"));

    //**************************************************************************
    //                          Install Artifact Setup                         *
    //**************************************************************************

    //* *************************** RISC Specific **************************** *
    const riscv32_step = b.step("riscv32", "Build the RISC-V32 Kernel");
    const riscv32_out = b.addInstallArtifact(riscv32_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = "RISC-v32",
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
                .custom = "x86",
            },
        },
    });
    x86_step.dependOn(&x86_out.step);
    b.getInstallStep().dependOn(&x86_out.step);

    //* *************************** Doc Specific ***************************** *
    const x86_doc_step = b.step("x86_docs", "Build x86 kernel package documentation");
    const x86_doc_obj = b.addObject(.{ .name = "x86_src", .root_module = x86_module });
    const x86_install_doc = b.addInstallDirectory(.{
        .source_dir = x86_doc_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/x86",
    });
    x86_doc_step.dependOn(&x86_install_doc.step);
    b.getInstallStep().dependOn(x86_doc_step);

    const riscv32_doc_step = b.step(
        "riscv32_docs",
        "Build riscv32 kernel package documentation",
    );
    const riscv32_doc_obj = b.addObject(.{ .name = "riscv32_src", .root_module = riscv32_module });
    const riscv32_install_doc = b.addInstallDirectory(.{
        .source_dir = riscv32_doc_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/RISC-V32",
    });
    riscv32_doc_step.dependOn(&riscv32_install_doc.step);
    b.getInstallStep().dependOn(riscv32_doc_step);
    // make dummy objects for the modules, will be used for doc generation
    const t = b.standardTargetOptions(.{});
    const module_doc_objects: [2]ModuleDocObject = .{
        .{
            .name = "OSProcess",
            .root_file = b.path("process/process.zig"),
            .output_folder = "docs/modules/process",
        },
        .{
            .name = "OSFormat",
            .root_file = b.path("format/osformat.zig"),
            .output_folder = "docs/modules/format",
        },
    };

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
    copy_landing_page.step.dependOn(x86_doc_step);
    copy_landing_page.step.dependOn(riscv32_doc_step);

    // dump in all shared modules
    for (module_doc_objects) |doc_object| {
        const module_doc_object = b.addObject(.{
            .name = doc_object.name,
            .root_module = b.createModule(.{
                .root_source_file = doc_object.root_file,
                .target = t,
                .optimize = .Debug, // just for docs, opt for fast build
            }),
        });
        const install_module_doc = b.addInstallDirectory(.{
            .source_dir = module_doc_object.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = doc_object.output_folder,
        });
        copy_landing_page.step.dependOn(&install_module_doc.step);
    }

    copy_landing_style.step.dependOn(&copy_landing_page.step);
    doc_page_step.dependOn(&copy_landing_page.step);
    doc_page_step.dependOn(&copy_landing_style.step);
    b.getInstallStep().dependOn(doc_page_step);
    //**************************************************************************
    //                             Run Step Setup                              *
    //**************************************************************************

    //* *************************** RISC Specific **************************** *
    const run_step = b.step("run_riscv32", "Boot kernel with qemu on riscv32");
    const run = b.addSystemCommand(&.{
        "qemu-system-riscv32",
        "-machine",
        "virt",
        "-bios",
        "default",
        // "-nographic",
        "-serial",
        "mon:stdio",
        "--no-reboot",
        "-kernel",
    });
    run.addArtifactArg(riscv32_exe);
    run.step.dependOn(riscv32_step);
    run_step.dependOn(&run.step);

    //* *************************** x86 Specific ***************************** *
    // TODO: Make these copy steps system agnostic
    const create_x86_iso_structure = b.addSystemCommand(&.{
        "mkdir",
        "-p",
        "zig-out/x86/iso/boot/grub",
    });
    create_x86_iso_structure.step.dependOn(x86_step);

    const copy_grub_files = b.addSystemCommand(&.{
        "cp",
        "entry_points/x86/stage2_eltorito",
        "zig-out/x86/iso/boot/grub",
    });
    copy_grub_files.step.dependOn(&create_x86_iso_structure.step);

    const copy_grub_menu = b.addSystemCommand(&.{
        "cp",
        "entry_points/x86/menu.lst",
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

    const x86_run_step_qemu = b.step("run_x86_qemu", "Boot kernel with QEMU on x86");
    x86_run_step_qemu.dependOn(&x86_run_qemu.step);

    const x86_copy_bochs = b.addSystemCommand(&.{
        "cp",
        "entry_points/x86/bochs.config",
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

    //**************************************************************************
    //                                 Doc Setup                               *
    //**************************************************************************

}
