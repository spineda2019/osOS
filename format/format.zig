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
//! format.zig - Architecture agnostic API for numeric formatting

/// calculate (at comptime) buffer size needed to convert a number to a string
fn calculateStringWidth(comptime numeric_type: type) comptime_int {
    return @floor(@bitSizeOf(numeric_type) * 0.30103) + 1;
}

/// Convert an arbitrary width integer to a string
pub fn intToString(
    number: anytype,
) [calculateStringWidth(@TypeOf(number))]u8 {
    const int_type: type = comptime @TypeOf(number);
    comptime {
        if (@typeInfo(int_type) != .int and int_type != comptime_int) {
            @compileError(
                "Error: expected an integer type, found: " ++ @typeName(int_type),
            );
        }
    }

    const digit_count: comptime_int = comptime calculateStringWidth(int_type);
    var buffer: [digit_count]u8 = .{0} ** digit_count;
    var ptr: usize = digit_count - 1;

    var remainder: int_type = number;
    while (remainder > 0) : ({
        if (ptr > 0) {
            ptr -= 1;
        }
        remainder /= 10;
    }) {
        // int cast to u8 should be safe. Modulo will be 9 max.
        const digit: u8 = @intCast(remainder % 10);
        buffer[ptr] = digit + 48;
    }

    return buffer;
}
