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

    const Test = struct {
        pub fn Config(comptime T: type) type {
            return struct {
                number: T,
                base: usize,
                expected_string: []const u8,
            };
        }
    };

    const tests = comptime .{
        // >= u8
        .{
            [4]type{ u8, u16, u32, usize },
            [3]Test.Config(u8){
                .{
                    .number = 0,
                    .base = 10,
                    .expected_string = "0",
                },
                .{
                    .number = 1,
                    .base = 10,
                    .expected_string = "1",
                },
                .{
                    .number = 255,
                    .base = 10,
                    .expected_string = "255",
                },
            },
        },
        // >= u16
        .{
            [3]type{ u16, u32, usize },
            [2]Test.Config(u16){
                .{
                    .number = 1234,
                    .base = 10,
                    .expected_string = "1234",
                },
                .{
                    .number = 12345,
                    .base = 10,
                    .expected_string = "12345",
                },
            },
        },
        // >= u32
        .{
            [2]type{ u32, usize },
            [5]Test.Config(u32){
                .{
                    .number = 123456,
                    .base = 10,
                    .expected_string = "123456",
                },
                .{
                    .number = 1234567,
                    .base = 10,
                    .expected_string = "1234567",
                },
                .{
                    .number = 12345678,
                    .base = 10,
                    .expected_string = "12345678",
                },
                .{
                    .number = 123456789,
                    .base = 10,
                    .expected_string = "123456789",
                },
                .{
                    .number = 1234567890,
                    .base = 10,
                    .expected_string = "1234567890",
                },
            },
        },
    };

    inline for (tests) |test_config| {
        inline for (test_config.@"0") |T| {
            inline for (test_config.@"1") |test_instance| {
                const toTest: StringFromInt(T) = .init(.{
                    .number = test_instance.number, // type upcast occurs
                    .base = test_instance.base,
                });
                try std.testing.expect(std.mem.eql(
                    u8,
                    test_instance.expected_string,
                    toTest.getStr(),
                ));
            }
        }
    }
}
