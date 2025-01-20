const sbi = @import("sbi.zig");

/// Kernel Panic
/// Ought to be inline, since adding stackframes to call this may not be
/// desirable. Open to alternate methods
pub inline fn panic(comptime file: []const u8) noreturn {
    sbi.rawSbiPrint("Kernel Panic! Ocurred in:");
    sbi.rawSbiPrint(file);
    while (true) {
        asm volatile ("");
    }
}
