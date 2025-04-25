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

const MAX_PROCESS_COUNT: comptime_int = 8;

/// Universal construct representing an osOS process
pub const Process = struct {
    const ProcessState = enum {
        unused,
        runnable,
    };
    const KERNEL_STACK_SIZE: comptime_int = 8192;

    /// this is generic code, don't assume arch size
    pid: usize,

    state: ProcessState,

    /// this is generic code, don't assume arch size
    stack_pointer: usize,

    /// each process gets their own stack
    stack: [KERNEL_STACK_SIZE]u8,

    pub fn initializePool() ProcessTable {
        return ProcessTable{
            .pool = .{null} ** MAX_PROCESS_COUNT,
        };
    }
};

/// Representation of the kernel's pool of total available process slots
pub const ProcessTable = struct {
    pool: [MAX_PROCESS_COUNT]?Process,

    pub fn createProcess(self: *ProcessTable, program_counter: usize) *Process {
        var slot: usize = 0;
        var end_of_process_stack: [*]usize = calc_block: {
            for (self.pool, 0..) |process, i| {
                if (process == null) {
                    self.pool[i] = Process{
                        .pid = i + 1,
                        .state = .runnable,
                        .stack = undefined, // init with garbage data
                        .stack_pointer = undefined, // will be calculated below
                    };
                    slot = i;
                    // .? is now safe as we just initialized that memory
                    const stack_len = self.pool[i].?.stack.len;
                    break :calc_block @alignCast(@ptrCast(
                        &(self.pool[i].?.stack[stack_len - 1]),
                    ));
                }
            }

            // TODO: Panic
            unreachable;
        };

        // don't use a loop for the sake of self documentation
        end_of_process_stack[0] = 0; // s11
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s10
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s9
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s8
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s7
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s6
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s5
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s4
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s3
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s2
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s1
        end_of_process_stack -= 1;
        end_of_process_stack[0] = 0; // s0
        end_of_process_stack -= 1;
        end_of_process_stack[0] = program_counter; // ra
        end_of_process_stack -= 1;
        self.pool[slot].?.stack_pointer = @intFromPtr(end_of_process_stack);
        return &(self.pool[slot].?);
    }
};

/// In the C counterpart, this would be marked Naked to avoid preamble
/// and post-amble asm generation. In zig however, you can't call naked
/// functions, but making this inline should have the same effect.
/// This function saves all callee registers (including stack ptr)
/// and loads in callers.
///
/// This function is intended to be used from a process to voluntarily switch
/// to a different context. Due to its simplicity, this may be reserved for
/// kernel space processes. This function essentially just pushes all
/// general purpose registers to the process's own stack, then switches the
/// stack ptr to the new value.
///
/// Registers: a0 will hold calle sp to save, a1 shall hold caller sp to store
pub inline fn switchContext(
    previous_stack_ptr: *usize,
    new_stack_ptr: *usize,
) void {
    const previous_stack_address: usize = @intFromPtr(previous_stack_ptr);
    const new_stack_address: usize = @intFromPtr(new_stack_ptr);

    switch (comptime @import("builtin").target.cpu.arch) {
        .riscv32 => {
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
                // a0 needs to hold the old stack address, and a1 must hold
                // the new one
                : [previous_stack_address] "{a0}" (previous_stack_address),
                  [new_stack_address] "{a0}" (new_stack_address),
            );
        },
        .x86 => {
            @compileError("TODO: x86 context switching not yet implemented");
        },
        else => |arch| {
            @compileError("Unsupported architecture detected: " ++ @tagName(arch));
        },
    }
}
