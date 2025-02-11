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

const meta = @import("std").meta;

fn Specifier(comptime datatype: type) type {
    return struct {
        format_specifier: u8, // a char
        wrapped_data: datatype,

        pub fn init(specifier: u8, data: datatype) @This() {
            comptime {
                switch (specifier) {
                    'c' => {
                        if (datatype != u8) {
                            @compileError(
                                "Expected u8 type for format specifier %c, found: " ++ @typeName(datatype),
                            );
                        }
                    },
                    'd' => {
                        if (@typeInfo(data) != .int) {
                            @compileError(
                                "Expected integer type for format specifier %d, found: " ++ @typeName(datatype),
                            );
                        }
                    },
                    'f' => {
                        if (@typeInfo(data) != .float) {
                            @compileError(
                                "Expected float type for format specifier %f, found: " ++ @typeName(datatype),
                            );
                        }
                    },
                    else => {
                        @compileError("Unrecognized format specifier: " ++ specifier);
                    },
                }
            }

            return .{
                .wrapped_data = data,
                .format_specifier = specifier,
            };
        }
    };
}

fn isPrintableType(t: type) bool {
    // first check if it's a simple formattable type. Numeric types are more
    // tricky since zig supports arbitrary bit width ints, like u32, u12, u3,
    // etc
    const acceptable: [1]type = .{bool};
    for (acceptable) |acceptable_type| {
        if (acceptable_type == t) {
            return true;
        }
    }

    // all is not yet lost, numeric types are also formatable
    const info = @typeInfo(t);

    if (info == .int or info == .float) {
        return true;
    } else {
        return false;
    }
}

pub fn format(comptime format_string: []const u8, data: anytype) []const u8 {
    const bufsize = comptime buf_size_calc: {
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

        var flag: bool = false;
        var format_count: comptime_int = 0;

        for (format_string) |letter| {
            switch (letter) {
                '%' => {
                    // don't count %% as a fmt specifier, %% just gives %
                    flag = !flag;
                },
                else => {
                    if (flag) {
                        format_count += 1;
                        flag = false;
                    }
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

        // now that we verified the format count == the arg count
        // validate the types are actually formattable.
        for (meta.fields(@TypeOf(data))) |field| {
            const field_type: type = field.type;
            if (!isPrintableType(field_type)) {
                // TODO: use @field
                @field(field, field.name);
                @compileError("Unsupported format type: " ++ @typeName(field_type));
            }
        }

        // finally assign the bufsize of our data struct
        break :buf_size_calc field_info.len;
    };

    const specifier_buffer: [bufsize][]const u8 = undefined;
    _ = specifier_buffer;

    // now it's fine to iterate through the runtime data

    return "TODO\n";
}
