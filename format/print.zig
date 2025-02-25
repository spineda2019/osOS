// print.zig - module of the osOS kernel's architecture agnostic print API
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

/// Kernal wide interface for storing the arch dependent implementation details
/// of writing to the screen.
pub const KernelWriter = struct {
    /// pointer to the ACTUAL struct/implementation doing the writing.
    instance: *anyopaque,

    /// Table storing mandatory methods of the "instance" member a KernelWriter
    /// must have. The pillar of making a KernelWriter a quasi-interface.
    vtable: *const VTable,

    pub const VTable = struct {
        /// Write a raw string
        writeRaw: *const fn (self: *anyopaque, raw_string: []const u8) void,

        /// Write a human readable version of a value
        writeValue: *const fn (self: *anyopaque, value: anytype) void,

        /// Empty and write the interna; buffer. This should reset some internal
        /// buffer sentinel
        flush: *const fn (self: *anyopaque) void,

        isBufferFull: *const fn (self: *anyopaque) bool,

        /// Set the current position in the buffer to a specific char. This
        /// should increment some internal buffer sentinel.
        setCurrentChar: *const fn (self: *anyopaque, char: u8) void,
    };
};

pub fn printf(
    comptime format_string: []const u8,
    args: anytype,
    writer: KernelWriter,
) void {
    defer writer.vtable.flush(writer.instance);

    var flag: bool = false;
    var arg_sentinel: u8 = 0;

    for (format_string) |letter| {
        if (writer.vtable.isBufferFull(writer.instance)) {
            writer.vtable.flush(writer.instance);
        }

        switch (letter) {
            '%' => {
                if (flag) {
                    // write only the single % literal for '%%'
                    writer.vtable.setCurrentChar(writer.instance, '%');
                }
                flag = !flag;
            },
            else => {
                if (flag) {
                    writer.vtable.writeValue(inline for (args, 0..) |arg, i| {
                        if (i == arg_sentinel) {
                            arg_sentinel += 1;
                            break arg;
                        }

                        break null;
                    });
                    flag = false;
                } else {
                    writer.vtable.setCurrentChar(writer.instance, letter);
                }
            },
        }
    }
}
