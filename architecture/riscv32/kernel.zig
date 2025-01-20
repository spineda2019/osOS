//! This module provides the entry point of the kernel on RISC-V 32 bit systems
//! Specifically, this is currently designed for the QEMU "virt" machine

const sbi = @import("sbi.zig");
const common = @import("common.zig");

const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

export fn kmain() noreturn {
    const bssSize = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bssSize], 0);

    sbi.rawSbiPrint("Hello RISC-V32 osOS!\n");
    common.panic(@src());

    while (true) {
        asm volatile ("");
    }
}

export fn boot() linksection(".text.boot") callconv(.Naked) noreturn {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kmain
        :
        : [stack_top] "r" (stack_top),
    );
}
