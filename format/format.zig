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

pub fn NumberFormatInfo(comptime T: type) type {
    return struct {
        number: T,
        base: usize,
    };
}

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

        pub fn init(number_info: NumberFormatInfo(T)) Self {
            // 48 is '0' in ascii
            var buffer: [array_size]u8 = .{48} ** array_size;
            var ptr: usize = array_size;
            var remainder: T = number_info.number;

            while (remainder > 0 and ptr > 0) {
                ptr -= 1;

                // int cast to u8 should be safe. Modulo will be 9 max.
                const digit: u8 = @intCast(remainder % 10);
                buffer[ptr] = digit + 48;
                remainder /= 10;
            }

            return .{ .array = buffer, .sentinel = switch (ptr) {
                array_size => array_size - 1,
                else => |other| other,
            } };
        }

        pub fn getStr(self: *const Self) []const u8 {
            return self.array[self.sentinel..];
        }
    };
}

test StringFromInt {
    const std = @import("std");

    // all
    const zero_str = "0";
    const one_str = "1";
    const full_u8_str = "255";
    // >= u16
    const four_digit_str = "1234";
    const five_digit_str = "12345";
    // >= u32
    const six_digit_str = "123456";
    const seven_digit_str = "1234567";
    const eight_digit_str = "12345678";
    const nine_digit_str = "123456789";
    const ten_digit_str = "1234567890";

    inline for ([4]type{ u8, u16, u32, usize }) |ty| {
        const zero: StringFromInt(ty) = .init(.{ .number = 0, .base = 10 });
        const one: StringFromInt(ty) = .init(.{ .number = 1, .base = 10 });
        const full_u8: StringFromInt(ty) = .init(.{ .number = 255, .base = 10 });

        try std.testing.expect(std.mem.eql(u8, zero_str, zero.getStr()));
        try std.testing.expect(std.mem.eql(u8, one_str, one.getStr()));
        try std.testing.expect(std.mem.eql(u8, full_u8_str, full_u8.getStr()));
    }
    inline for ([3]type{ u16, u32, usize }) |ty| {
        const four_digit: StringFromInt(ty) = .init(.{ .number = 1234, .base = 10 });
        const five_digit: StringFromInt(ty) = .init(.{ .number = 12345, .base = 10 });

        try std.testing.expect(std.mem.eql(u8, four_digit_str, four_digit.getStr()));
        try std.testing.expect(std.mem.eql(u8, five_digit_str, five_digit.getStr()));
    }
    inline for ([2]type{ u32, usize }) |ty| {
        const six_digit: StringFromInt(ty) = .init(.{ .number = 123456, .base = 10 });
        const seven_digit: StringFromInt(ty) = .init(.{ .number = 1234567, .base = 10 });
        const eight_digit: StringFromInt(ty) = .init(.{ .number = 12345678, .base = 10 });
        const nine_digit: StringFromInt(ty) = .init(.{ .number = 123456789, .base = 10 });
        const ten_digit: StringFromInt(ty) = .init(.{ .number = 1234567890, .base = 10 });

        try std.testing.expect(std.mem.eql(u8, six_digit_str, six_digit.getStr()));
        try std.testing.expect(std.mem.eql(u8, seven_digit_str, seven_digit.getStr()));
        try std.testing.expect(std.mem.eql(u8, eight_digit_str, eight_digit.getStr()));
        try std.testing.expect(std.mem.eql(u8, nine_digit_str, nine_digit.getStr()));
        try std.testing.expect(std.mem.eql(u8, ten_digit_str, ten_digit.getStr()));
    }
}
