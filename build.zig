const std = @import("std");

const Error: type = error{
    UnsupportedTarget,
};

fn build_riscv32(
    b: *std.Build,
    optimize: *const std.builtin.OptimizeMode,
) !*std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "osOS.elf",
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .riscv32,
            .os_tag = .freestanding,
            .abi = .none,
        }),
        .root_source_file = b.path("architecture/riscv32/kernel.zig"),
        .optimize = optimize.*,
        .strip = false,
    });

    exe.entry = .disabled;

    exe.setLinkerScript(b.path("architecture/riscv32/link.ld"));

    b.installArtifact(exe);

    return exe;
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    // const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    const exe = try build_riscv32(b, &optimize);
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

    run.step.dependOn(&exe.step);

    const run_step = b.step("run_riscv32", "Boot kernel with qemu on riscv32");

    run_step.dependOn(&run.step);
}
