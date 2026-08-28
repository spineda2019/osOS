const std = @import("std");
const OutputDirs = @This();

riscv32: std.Build.Step.InstallArtifact.Options,
x86: std.Build.Step.InstallArtifact.Options,

pub fn init() OutputDirs {
    return .{
        .riscv32 = .{
            .dest_dir = .{
                .override = .{
                    .custom = @tagName(std.Target.Cpu.Arch.riscv32),
                },
            },
        },
        .x86 = .{
            .dest_dir = .{
                .override = .{
                    .custom = @tagName(std.Target.Cpu.Arch.x86),
                },
            },
        },
    };
}
