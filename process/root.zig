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

pub const BootModule = @import("BootModule.zig");
pub const IModuleProber = @import("IModuleProber.zig");
pub const Process = @import("Process.zig");
pub const ContextTools = @import("ContextTools.zig");
pub const ProcessPoolInfo = @import("ProcessPoolInfo.zig");

pub fn ProcessTable(
    comptime info: ProcessPoolInfo,
) type {
    return struct {
        const Self = @This();

        const ctx: ContextTools = info.context_tools;
        procs: [info.max_process_count]?Process,
        stacks: [info.max_process_count][info.stack_size]u8,

        pub fn init() Self {
            return .{ .procs = @splat(null), .stacks = @splat(@splat(0)) };
        }
        /// Create a process at a specific address in RAM. Creates the process entry
        /// in the table and returns the address to the process entry.
        pub fn createProcess(
            self: *Self,
            process_start_address: [*]const u8,
        ) Process.ProcessError!void {
            for (&self.procs, 0..) |*process, p| {
                if (process.* == null) {
                    process.* = .{
                        .state = .runnable,
                        .entry_address = process_start_address,
                        .pid = p,
                        .stack_info = undefined, // TODO: !!!
                    };
                    return;
                }
            }

            return Process.ProcessError.OutOfSlots;
        }

        pub fn schedule(self: *Self) void {
            for (&self.procs) |*proc| {
                if (proc.*) |p| {
                    _ = p;
                }
            }
        }
    };
}
