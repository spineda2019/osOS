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

/// Universal construct representing an osOS process
pub const Process = struct {
    const ProcessState = enum {
        unused,
        runnable,
        waiting,
    };

    pub const ProcessError = error{
        OutOfSlots,
    };

    /// this is generic code, don't assume arch size
    pid: usize,

    /// Self explanatory
    state: ProcessState,

    entry_address: *const fn () noreturn,

    /// Calling this essentially just jumps to the entry routine address. All
    /// we have to do then is save calle process registers.
    pub inline fn jump(self: *Process) noreturn {
        asm volatile (
            \\ jmp *%[proc]
            :
            : [proc] "r" (self.entry_address),
        );
        unreachable;
    }

    /// Represents an empty process that doesn't exist. Inidicates that this
    /// process can be used to make a real running one.
    pub const emptyProcess: Process = .{
        .pid = 0,
        .state = .unused,
        .entry_address = undefined,
    };
};

pub fn ProcessTable(comptime MAX_PROCESS_COUNT: comptime_int) type {
    return struct {
        const Self = @This();

        pool: [MAX_PROCESS_COUNT]Process,

        pub fn init() Self {
            return .{
                .pool = .{Process.emptyProcess} ** MAX_PROCESS_COUNT,
            };
        }
        /// Create a process at a specific address in RAM. Creates the process entry
        /// in the table and returns the address to the process entry.
        pub fn createProcess(
            self: *Self,
            process_start_address: *const fn () noreturn,
        ) Process.ProcessError!*Process {
            for (&self.pool, 0..) |*process, p| {
                if (process.*.state == .unused) {
                    process.*.state = .runnable;
                    process.*.entry_address = process_start_address;
                    process.pid = p;
                    return process;
                }
            }

            return Process.ProcessError.OutOfSlots;
        }
    };
}
