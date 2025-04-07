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
//! print.zig - module of the osOS kernel's architecture agnostic print API

/// Kernal wide interface for storing the arch dependent implementation details
/// of writing to the screen.
pub const Writer = struct {
    instance: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Write a string
        write: *const fn (self: *anyopaque, raw_string: []const u8) void,
    };

    /// Format print
    ///
    /// Arguments:
    ///
    ///     format_string: string containing format specifiers (ex: %d) to print
    ///
    ///     args: array of values corresponding to format_string
    ///
    ///     Note: writer is probably best passed by value (or at least left up
    ///     to the zig optimizer) since mking it a const ptr would introduce
    ///     and extra level of indirection.
    pub fn kprintf(
        writer: Writer,
        comptime format_string: []const u8,
        args: anytype,
    ) void {
        var buffer: [32]u8 = .{0} ** 32;
        var internal_sentinel: u8 = 0;
        var arg_sentinel: u8 = 0;

        defer {
            // flush
            writer.vtable.write(writer.instance, buffer[0..internal_sentinel]);
        }

        var flag: bool = false;
        for (format_string) |letter| {
            if (internal_sentinel == buffer.len) {
                // flush and reset ptr
                writer.vtable.write(writer.instance, &buffer);
                internal_sentinel = 0;
            }

            switch (letter) {
                '%' => {
                    if (flag) {
                        // write only the single % literal for '%%'
                        buffer[internal_sentinel] = '%';
                        internal_sentinel += 1;
                    }

                    flag = !flag;
                },
                else => {
                    if (flag) {
                        buffer[internal_sentinel] = 'X';
                        internal_sentinel += 1;

                        // TODO: take this arg and fmt print it
                        inline for (args, 0..) |arg, i| {
                            if (i == arg_sentinel) {
                                arg_sentinel += 1;
                                break arg;
                            }
                            break null;
                        }

                        flag = false;
                    } else {
                        buffer[internal_sentinel] = letter;
                        internal_sentinel += 1;
                    }
                },
            }
        }
    }
};
