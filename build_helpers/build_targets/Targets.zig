const std = @import("std");
const Targets = @This();

x86: std.Target.Query,
riscv32: std.Target.Query,

pub fn init() Targets {
    return .{
        .x86 = .{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
            .abi = .none,
            // remove features not guaranteed to exist on old-ish hardware (qemu defaults)
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
        },
        .riscv32 = .{
            .cpu_arch = .riscv32,
            .os_tag = .freestanding,
            .abi = .none,
        },
    };
}
