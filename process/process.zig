// process.zig - kernel process logic
//! Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.
//!
//! This module provides the entry point of the kernel on RISC-V 32 bit systems
//! Specifically, this is currently designed for the QEMU "virt" machine

/// Universal construct representing an osOS process
const Process = struct {
    const ProcessState = enum {
        unused,
        runnable,
    };
    const KERNEL_STACK_SIZE: comptime_int = 8192;
    const MAX_PROCESS_COUNT: comptime_int = 8;

    pid: usize, // this is generic code, don't assume arch size
    state: ProcessState,
    stack_pointer: usize,

    /// each process gets their own stack
    stack: [KERNEL_STACK_SIZE]u8,
};

/// In the C counterpart, this would be marked Naked to avoid preamble
/// and post-amble asm generation. In zig however, you can't call naked
/// functions, but making this inline should have the same effect.
/// Registers: a0 will hold calle sp to save, a1 shall hold caller sp to store
pub inline fn switch_context(
    previous_stack_ptr: *usize,
    new_stack_ptr: *usize,
) void {
    switch (comptime @import("builtin").target.cpu.arch) {
        .riscv32 => {
            const previous_stack_address = @intFromPtr(previous_stack_ptr);
            const new_stack_address = @intFromPtr(new_stack_ptr);
            // Save callee-saved registers onto the current process's stack.
            // line 1: Allocate stack space for 13 4-byte registers
            // line 2: Save callee-saved registers only
            // line 15: Switch the stack pointer. (*prev_sp = sp;)
            // line 16: Switch stack pointer (sp) here
            // line 17: Restore callee-saved registers (only) from the next process's stack.
            // line 30: We've popped 13 4-byte registers from the stack
            asm volatile (
                \\addi sp, sp, -13 * 4
                \\sw ra,  0  * 4(sp)
                \\sw s0,  1  * 4(sp)
                \\sw s1,  2  * 4(sp)
                \\sw s2,  3  * 4(sp)
                \\sw s3,  4  * 4(sp)
                \\sw s4,  5  * 4(sp)
                \\sw s5,  6  * 4(sp)
                \\sw s6,  7  * 4(sp)
                \\sw s7,  8  * 4(sp)
                \\sw s8,  9  * 4(sp)
                \\sw s9,  10 * 4(sp)
                \\sw s10, 11 * 4(sp)
                \\sw s11, 12 * 4(sp)
                \\sw sp, (a0)
                \\lw sp, (a1)
                \\lw ra,  0  * 4(sp)
                \\lw s0,  1  * 4(sp)
                \\lw s1,  2  * 4(sp)
                \\lw s2,  3  * 4(sp)
                \\lw s3,  4  * 4(sp)
                \\lw s4,  5  * 4(sp)
                \\lw s5,  6  * 4(sp)
                \\lw s6,  7  * 4(sp)
                \\lw s7,  8  * 4(sp)
                \\lw s8,  9  * 4(sp)
                \\lw s9,  10 * 4(sp)
                \\lw s10, 11 * 4(sp)
                \\lw s11, 12 * 4(sp)
                \\addi sp, sp, 13 * 4
                :
                : [previous_stack_address] "{a0}" (previous_stack_address),
                  [new_stack_address] "{a0}" (new_stack_address),
            );
        },
        else => |arch| {
            @compileError("Unsupported architecture detected: " ++ @tagName(arch));
        },
    }
}
