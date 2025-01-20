const std = @import("std");

const Error: type = error{
    UnsupportedTarget,
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    //**************************************************************************
    // RISCV-32 Setup
    const exe = b.addExecutable(.{
        .name = "osOS.elf",
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
}
