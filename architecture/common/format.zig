// format.zig - Architecture agnostic API for numeric formatting
// Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pub fn StringFromInt(
    comptime array_size: comptime_int,
) type {
    return struct {
        raw_string: [array_size]u8,
        sentinel: usize,

        pub fn innerSlice(self: @This()) []const u8 {
            return self.raw_string[self.sentinel..];
        }
    };
}

fn calculateStringWidth(comptime numeric_type: type) comptime_int {
    return @floor(@bitSizeOf(numeric_type) * 0.30103) + 1;
}

pub fn intToString(
    comptime int_type: type,
    number: int_type,
) StringFromInt(calculateStringWidth(int_type)) {
    if (comptime @typeInfo(int_type) != .int) {
        @compileError("Error: expected an integer type, found: " ++ @typeName(int_type));
    }

    const digit_count = calculateStringWidth(int_type);
    var remainder: int_type = number;
    var buffer: [digit_count]u8 = .{0} ** digit_count;
    var ptr = buffer.len - 1;
    while (remainder > 0) : ({
        if (ptr > 0) {
            ptr -= 1;
        }
        remainder /= 10;
    }) {
        // int cast to u8 should be safe. Modulo will be 9 max.
        const digit: u8 = remainder % 10;
        buffer[ptr] = digit + 48;
    }

    return StringFromInt(digit_count){
        .raw_string = buffer,
        .sentinel = ptr,
    };
}
