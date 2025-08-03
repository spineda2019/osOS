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

/// Special type describing a string specifically serialized from an integer of
/// an arbitrary size.
pub fn StringFromInt(comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .int and type != comptime_int) {
            const err = "Expected an integer type, found: " ++ @typeName(T);
            @compileError(err);
        }
    }

    const array_size: comptime_int = comptime blk: {
        const bit_width: comptime_int = switch (T) {
            comptime_int => 64, // TODO: allow bigger comptime nums
            else => @bitSizeOf(T),
        };
        break :blk @floor(bit_width * 0.30103) + 1;
    };

    return struct {
        array: [array_size]u8,
        sentinel: usize,

        const Self: type = @This();

        pub fn init(number: T) Self {
            var buffer: [array_size]u8 = .{0} ** array_size;
            var ptr: usize = array_size - 1;

            var remainder: T = number;
            while (remainder > 0) {
                // int cast to u8 should be safe. Modulo will be 9 max.
                const digit: u8 = @intCast(remainder % 10);
                buffer[ptr] = digit + 48;

                ptr = switch (ptr) {
                    0 => 0,
                    else => |num| num - 1,
                };
                remainder /= 10;
            }

            return .{ .array = buffer, .sentinel = ptr };
        }

        pub fn getStr(self: *const Self) []const u8 {
            // TODO: detect a full buffer
            return self.array[self.sentinel + 1 ..];
        }
    };
}
