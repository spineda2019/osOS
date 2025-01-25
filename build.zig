const std = @import("std");

const Error: type = error{
    UnsupportedTarget,
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const kernel_name = "osOS.elf";
    //**************************************************************************
    //                              RISCV-32 Setup                             *
    //**************************************************************************
    const exe = b.addExecutable(.{
        .name = kernel_name,
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .riscv32,
            .os_tag = .freestanding,
            .abi = .none,
        }),
        .root_source_file = b.path("architecture/riscv32/kernel.zig"),
        .optimize = .ReleaseSmall,
        .strip = false,
    });
    exe.entry = .disabled;
    exe.setLinkerScript(b.path("architecture/riscv32/link.ld"));

    const riscv32_step = b.step("riscv32", "Build the RISC-V32 Kernel");

    const out = b.addInstallArtifact(exe, .{
        .dest_dir = .{
            .override = .{
                .custom = "RISC-v32",
            },
        },
    });

    riscv32_step.dependOn(&out.step);

    // this makes the install target build everything
    b.getInstallStep().dependOn(&out.step);

    const run = b.addSystemCommand(&.{
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

    run.addArtifactArg(exe);

    run.step.dependOn(riscv32_step);

    const run_step = b.step("run_riscv32", "Boot kernel with qemu on riscv32");

    run_step.dependOn(&run.step);
    //**************************************************************************
    //                                 x86 Setup                               *
    //**************************************************************************
    const x86_exe = b.addExecutable(.{
        .name = kernel_name,
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
            .abi = .none,
        }),
        .root_source_file = b.path("architecture/x86/kernel.zig"),
        .optimize = .ReleaseSmall,
        .strip = false,
    });
    x86_exe.entry = .disabled;
    const x86_entry_asm_file = b.addAssembly(.{
        .name = "foo",
        .source_file = b.path("architecture/x86/entry.s"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
            .abi = .none,
        }),
        .optimize = .ReleaseSmall,
    });
    x86_exe.addObject(x86_entry_asm_file);
    x86_exe.setLinkerScript(b.path("architecture/x86/link.ld"));

    const x86_step = b.step("x86", "Build the x86 Kernel");

    const x86_out = b.addInstallArtifact(x86_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = "x86",
            },
        },
    });

    x86_step.dependOn(&x86_out.step);

    // this makes the install target build everything
    b.getInstallStep().dependOn(&x86_out.step);

    // TODO: Make these copy steps system agnostic
    const create_x86_iso_structure = b.addSystemCommand(&.{
        "mkdir",
        "-p",
        "zig-out/x86/iso/boot/grub",
    });
    create_x86_iso_structure.step.dependOn(x86_step);

    const copy_grub_files = b.addSystemCommand(&.{
        "cp",
        "architecture/x86/stage2_eltorito",
        "zig-out/x86/iso/boot/grub",
    });
    copy_grub_files.step.dependOn(&create_x86_iso_structure.step);

    const copy_grub_menu = b.addSystemCommand(&.{
        "cp",
        "architecture/x86/menu.lst",
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
        "architecture/x86/bochs.config",
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

    const x86_run_step_bochs = b.step("run_x86_bochs", "Boot kernel with BOCHS on x86");
    x86_run_step_bochs.dependOn(&x86_run_bochs.step);
}
