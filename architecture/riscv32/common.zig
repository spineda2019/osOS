//! Common funcs for the kernek. In the future, may be architecture agnostic
//! Note: Be VERY careful when using zig std funcs/types. Many are ok when
//! targetting the freestanding target. For ease of use, I am using only types
//! consisting of simple types and comptime functions.

const sbi = @import("sbi.zig");
const oscommon = @import("oscommon");
const FreeStandingSourceInfo: type = @import("std").builtin.SourceLocation;
/// Struct representing saved state of each register. Packed to guarantee field
/// sizes. Each register shall be 32 bits wide on risv32. Order is guaranteed
/// to be preserved in memory
const TrapFrame: type = packed struct {
    ra: u32,
    gp: u32,
    tp: u32,
    t0: u32,
    t1: u32,
    t2: u32,
    t3: u32,
    t4: u32,
    t5: u32,
    t6: u32,
    a0: u32,
    a1: u32,
    a2: u32,
    a3: u32,
    a4: u32,
    a5: u32,
    a6: u32,
    a7: u32,
    s0: u32,
    s1: u32,
    s2: u32,
    s3: u32,
    s4: u32,
    s5: u32,
    s6: u32,
    s7: u32,
    s8: u32,
    s9: u32,
    s10: u32,
    s11: u32,
    sp: u32,
};

export fn handleTrap(trap_frame: *const TrapFrame) void {
    _ = trap_frame;
    sbi.rawSbiPrint("Hey! I'm in the trap handler!\n");
    panic(@src());
}

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

    const line_type: type = comptime @TypeOf(source_info.line);
    const line_num = comptime oscommon.format.intToString(line_type, source_info.line);
    sbi.rawSbiPrint("Line: ");
    sbi.rawSbiPrint(line_num.innerSlice());
    sbi.rawSbiPrint("\n");

    const column_type: type = comptime @TypeOf(source_info.column);
    const column_num = comptime oscommon.format.intToString(column_type, source_info.column);
    sbi.rawSbiPrint("Column: ");
    sbi.rawSbiPrint(column_num.innerSlice());
    sbi.rawSbiPrint("\n");

    while (true) {
        asm volatile ("");
    }
}

/// Save register state and call trap handler. Aligned to 4 bytes for SBI to
/// set proper bits in expected memory locations
pub fn cpuExceptionHandler() align(4) callconv(.Naked) void {
    // Important notes:
    //     csrw is a priviledged instruction.
    //     Writes StackPointer to sscratch, a temporary register
    //
    //     We don't save any floating point registers here.
    //
    //     Allocate stack space to save registers to memory.
    asm volatile (
        \\csrw sscratch, sp
        \\addi sp, sp, -4 * 31
        \\sw ra,  4 * 0(sp)
        \\sw gp,  4 * 1(sp)
        \\sw tp,  4 * 2(sp)
        \\sw t0,  4 * 3(sp)
        \\sw t1,  4 * 4(sp)
        \\sw t2,  4 * 5(sp)
        \\sw t3,  4 * 6(sp)
        \\sw t4,  4 * 7(sp)
        \\sw t5,  4 * 8(sp)
        \\sw t6,  4 * 9(sp)
        \\sw a0,  4 * 10(sp)
        \\sw a1,  4 * 11(sp)
        \\sw a2,  4 * 12(sp)
        \\sw a3,  4 * 13(sp)
        \\sw a4,  4 * 14(sp)
        \\sw a5,  4 * 15(sp)
        \\sw a6,  4 * 16(sp)
        \\sw a7,  4 * 17(sp)
        \\sw s0,  4 * 18(sp)
        \\sw s1,  4 * 19(sp)
        \\sw s2,  4 * 20(sp)
        \\sw s3,  4 * 21(sp)
        \\sw s4,  4 * 22(sp)
        \\sw s5,  4 * 23(sp)
        \\sw s6,  4 * 24(sp)
        \\sw s7,  4 * 25(sp)
        \\sw s8,  4 * 26(sp)
        \\sw s9,  4 * 27(sp)
        \\sw s10, 4 * 28(sp)
        \\sw s11, 4 * 29(sp)
        \\
        \\csrr a0, sscratch
        \\sw a0, 4 * 30(sp)
        \\
        \\mv a0, sp
        \\call handleTrap
        \\
        \\lw ra,  4 * 0(sp)
        \\lw gp,  4 * 1(sp)
        \\lw tp,  4 * 2(sp)
        \\lw t0,  4 * 3(sp)
        \\lw t1,  4 * 4(sp)
        \\lw t2,  4 * 5(sp)
        \\lw t3,  4 * 6(sp)
        \\lw t4,  4 * 7(sp)
        \\lw t5,  4 * 8(sp)
        \\lw t6,  4 * 9(sp)
        \\lw a0,  4 * 10(sp)
        \\lw a1,  4 * 11(sp)
        \\lw a2,  4 * 12(sp)
        \\lw a3,  4 * 13(sp)
        \\lw a4,  4 * 14(sp)
        \\lw a5,  4 * 15(sp)
        \\lw a6,  4 * 16(sp)
        \\lw a7,  4 * 17(sp)
        \\lw s0,  4 * 18(sp)
        \\lw s1,  4 * 19(sp)
        \\lw s2,  4 * 20(sp)
        \\lw s3,  4 * 21(sp)
        \\lw s4,  4 * 22(sp)
        \\lw s5,  4 * 23(sp)
        \\lw s6,  4 * 24(sp)
        \\lw s7,  4 * 25(sp)
        \\lw s8,  4 * 26(sp)
        \\lw s9,  4 * 27(sp)
        \\lw s10, 4 * 28(sp)
        \\lw s11, 4 * 29(sp)
        \\lw sp,  4 * 30(sp)
        \\sret
    );
}
