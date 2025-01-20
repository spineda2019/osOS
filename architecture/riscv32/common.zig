//! Common funcs for the kernek. In the future, may be architecture agnostic
//! Note: Be VERY careful when using zig std funcs/types. Many are ok when
//! targetting the freestanding target. For ease of use, I am using only types
//! consisting of simple types and comptime functions.

const sbi = @import("sbi.zig");
const FreeStandingSourceInfo: type = @import("std").builtin.SourceLocation;

/// Kernel Panic
/// Ought to be inline, since adding stackframes to call this may not be
/// desirable. Open to alternate methods
pub inline fn panic(comptime source_info: FreeStandingSourceInfo) noreturn {
    sbi.rawSbiPrint("Kernel Panic! Info:\n");

    sbi.rawSbiPrint("File: ");
    sbi.rawSbiPrint(source_info.file);
    sbi.rawSbiPrint("\n");

    sbi.rawSbiPrint("Function: ");
    sbi.rawSbiPrint(source_info.fn_name);
    sbi.rawSbiPrint("\n");

    sbi.rawSbiPrint("Line: ");
    sbi.rawSbiPrint("TODO");
    sbi.rawSbiPrint("\n");

    sbi.rawSbiPrint("Column: ");
    sbi.rawSbiPrint("TODO");
    sbi.rawSbiPrint("\n");

    while (true) {
        asm volatile ("");
    }
}
