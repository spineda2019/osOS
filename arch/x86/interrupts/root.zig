//! interrupts.zig - root module for everything related to interrupts
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

pub const idt = @import("idt.zig");

pub const pic = @import("pic.zig");

const syscall = @import("syscall.zig");

pub const Interrupt = union(enum) {
    intelException: IntelException,
    picInterrupt: *const fn () callconv(.naked) void,
    syscall: *const fn () callconv(.naked) void,
    other: u32,

    pub fn init(comptime number: u32) Interrupt {
        return comptime switch (number) {
            0...31 => |exception| .{ .intelException = .init(exception) },
            @intFromEnum(pic.irq.keyboard) => .{ .picInterrupt = &pic.keyboardISR },
            @intFromEnum(pic.irq.timer) => .{ .picInterrupt = &pic.timerISR },
            0x80 => .{ .syscall = &syscall.syscallISR },
            else => |num| .{ .other = num },
        };
    }

    pub const IntelException = union(enum) {
        withErrorCode: IntelExceptionWithError,
        withoutErrorCode: IntelExceptionWithoutError,

        pub fn init(comptime number: u32) IntelException {
            return comptime switch (number) {
                8, 10, 11, 12, 13, 14, 17, 30 => .{
                    .withErrorCode = @enumFromInt(number),
                },
                0...7, 9, 15, 16, 18...29, 31 => .{
                    .withoutErrorCode = @enumFromInt(number),
                },
                else => {
                    const format = @import("osformat").format;
                    const num: format.StringFromInt(u32) = .init(number);
                    const msg = "Invalid exception interrupt number: ";
                    @compileError(msg ++ num.getStr());
                },
            };
        }

        pub const IntelExceptionWithoutError = enum(u32) {
            divide_error = 0,
            debug = 1,
            nmi_interrupt = 2,
            breakpoint = 3,
            overflow = 4,
            bound_range_exceeded = 5,
            invalid_opcode = 6,
            device_not_available = 7,
            coprocessor_segment_overrun = 9,
            _reserved_15 = 15,
            floating_point_error = 16,
            machine_check = 18,
            simd_fp_exception = 19,
            virtualization_exception = 20,
            control_protection_exception = 21,
            _reserved_22 = 22,
            _reserved_23 = 23,
            _reserved_24 = 24,
            _reserved_25 = 25,
            _reserved_26 = 26,
            _reserved_27 = 27,
            _reserved_28 = 28,
            _reserved_29 = 29,
            _reserved_31 = 31,
        };

        pub const IntelExceptionWithError = enum(u32) {
            double_fault = 8,
            invalid_tss = 10,
            segment_not_present = 11,
            stack_segment_fault = 12,
            general_protection = 13,
            page_fault = 14,
            alignment_check = 17,
            _reserved_30 = 30,
        };
    };
};
