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

/// Calculates the maximum needed buffer size to represent a number of a given
/// bit width for a given base.
pub fn numberBufSize(comptime bit_width: u8, base: usize) comptime_int {
    const math = @import("std").math;
    @setEvalBranchQuota(2000);

    const log_arg: comptime_int = comptime pow: {
        // pow is not implemented for comptime_int for some reason
        // so I don't have an elegant way to get 2^bits
        if (base == 0) {
            @branchHint(.cold);
            break :pow 1;
        }

        var accumulate: comptime_int = 2;
        var idx: comptime_int = 1;
        while (idx < bit_width) : (idx += 1) {
            accumulate *= 2;
        }

        break :pow accumulate;
    } - 1;
    const log: comptime_float = math.log(comptime_float, base, log_arg);
    return @floor(log) + 1;
}

/// Special type describing a string specifically serialized from an integer of
/// an arbitrary size.
pub fn StringFromInt(comptime T: type, comptime base: comptime_int) type {
    comptime {
        if (@typeInfo(T) != .int and type != comptime_int) {
            const err = "Expected an integer type, found: " ++ @typeName(T);
            @compileError(err);
        }
    }

    const array_size: comptime_int = comptime numberBufSize(switch (T) {
        comptime_int => 64, // TODO: allow bigger comptime nums
        else => @bitSizeOf(T),
    }, base);

    comptime if (base > 16) {
        @compileError("TODO: Properly support bases > 16");
    };

    return struct {
        array: [array_size]u8,
        sentinel: usize,

        const Self: type = @This();

        pub fn init(number: T) Self {
            // 48 is '0' in ascii
            var buffer: [array_size]u8 = .{48} ** array_size;
            var ptr: usize = array_size;
            var remainder: T = number;

            while (remainder > 0 and ptr > 0) {
                ptr -= 1;

                // int cast to u8 should be safe. Modulo will be 9 max.
                const digit: u8 = @intCast(remainder % base);
                const ascii = digit + 48;
                buffer[ptr] = switch (base > 10) {
                    false => ascii,
                    else => switch (ascii) {
                        58 => 'a',
                        59 => 'b',
                        60 => 'c',
                        61 => 'd',
                        62 => 'e',
                        63 => 'f',
                        else => ascii,
                    },
                };
                remainder /= base;
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

test numberBufSize {
    const expect = @import("std").testing.expect;
    const print = @import("std").debug.print;

    const Test = struct {
        T: type,
        base: usize,
        expected_buffer_size: usize,
    };

    const tests = comptime [6]Test{
        .{ .T = u8, .base = 10, .expected_buffer_size = 3 },
        .{ .T = u8, .base = 16, .expected_buffer_size = 2 },
        .{ .T = u8, .base = 2, .expected_buffer_size = 8 },
        .{ .T = u16, .base = 10, .expected_buffer_size = 5 },
        .{ .T = u32, .base = 10, .expected_buffer_size = 10 },
        .{ .T = u64, .base = 10, .expected_buffer_size = 20 },
    };

    inline for (tests) |test_instance| {
        const bit_width = @bitSizeOf(test_instance.T);
        const calculated_bufsize = numberBufSize(bit_width, test_instance.base);
        expect(calculated_bufsize == test_instance.expected_buffer_size) catch |err| {
            //
            const type_name = @typeName(test_instance.T);
            print(
                "Expected max bufsize of {} for type {s} of base {}, got {}\n",
                .{
                    test_instance.expected_buffer_size,
                    type_name,
                    test_instance.base,
                    calculated_bufsize,
                },
            );
            return err;
        };
    }
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
            [_]Test.Config(u8){
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
                .{
                    .number = 16,
                    .base = 16,
                    .expected_string = "10",
                },
                .{
                    .number = 15,
                    .base = 16,
                    .expected_string = "f",
                },
                .{
                    .number = 255,
                    .base = 16,
                    .expected_string = "ff",
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
                const toTest: StringFromInt(T, test_instance.base) = .init(
                    test_instance.number, // type upcast occurs
                );
                std.testing.expect(std.mem.eql(
                    u8,
                    test_instance.expected_string,
                    toTest.getStr(),
                )) catch |err| {
                    std.debug.print(
                        "Number {} of type {s} in base {} did not match expected string {s}. Was {s}\n",
                        .{
                            test_instance.number,
                            @typeName(T),
                            test_instance.base,
                            test_instance.expected_string,
                            toTest.getStr(),
                        },
                    );
                    return err;
                };
            }
        }
    }
}
