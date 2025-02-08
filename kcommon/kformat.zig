// kformat.zig - Common formatting code for internal kernel use
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

pub fn format(comptime format_string: []const u8, data: anytype) []const u8 {
    comptime {
        // ensure that the data arg is a struct with less than 32 args
        const ArgsType = @TypeOf(data);
        const args_type_info = @typeInfo(ArgsType);
        if (args_type_info != .@"struct") {
            @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
        }
        const field_info = args_type_info.@"struct".fields;
        if (field_info.len > 32) {
            @compileError("32 arguments max are supported per format call");
        }

        // now ensure that the number of data fields is equal to the amount
        // of format specifers

        var ignore_next: bool = false;
        var format_count: comptime_int = 0;

        for (format_string) |letter| {
            switch (letter) {
                '%' => {
                    if (!ignore_next) {
                        format_count += 1;
                    }
                    ignore_next = false;
                },
                '\\' => {
                    ignore_next = true;
                },
                else => {
                    ignore_next = false;
                },
            }
        }

        if (format_count != field_info.len) {
            const msg = blk: {
                if (format_count > field_info.len) {
                    break :blk "More format specifiers than passed args";
                } else {
                    break :blk "More passed args than format specifiers";
                }
            };
            @compileError("Amount of format specifiers and passed data do not match: " ++ msg);
        }
    }

    return "TODO\n";
}
