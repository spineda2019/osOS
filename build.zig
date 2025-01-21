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

    const copy_kernel = b.addSystemCommand(&.{
        "cp",
    });
    copy_kernel.addArtifactArg(x86_exe);
    copy_kernel.addArg("zig-out/x86/iso/boot");
    copy_kernel.step.dependOn(&copy_grub_menu.step);

    const x86_run = b.addSystemCommand(&.{
        "echo",
        "TODO: x86 run step",
    });

    x86_run.step.dependOn(&copy_kernel.step);

    const x86_run_step = b.step("run_x86", "Boot kernel with qemu on x86");
    x86_run_step.dependOn(&x86_run.step);

    // const x86_create_iso = b.step("iso_x86", "Create the x86 ISO");
}
