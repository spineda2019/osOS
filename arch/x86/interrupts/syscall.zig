//! syscall.zig - root module for everything related to syscalls
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

const syscall_table = @import("syscall.zon");
const syscall_count: comptime_int = blk: {
    var count: comptime_int = 0;
    for (syscall_table) |syscall| {
        if (syscall.number >= count) {
            count = syscall.number + 1;
        }
    }
    break :blk count;
};

const impl = struct {
    fn exit(_: *const Registers) void {}
};

const handler_table: [syscall_count]?*const fn (*const Registers) void = blk: {
    var table: [syscall_count]?*const fn (*const Registers) void = @splat(null);
    for (syscall_table) |syscall| {
        if (@hasDecl(impl, syscall.name)) {
            table[syscall.number] = @field(impl, syscall.name);
        }
    }
    break :blk table;
};

const Registers = struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
};

fn syscallHandler(
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    syscallIndex: u32, // Actually EAX
) callconv(.c) void {
    if (syscallIndex >= handler_table.len) {
        @panic("Invalid syscall index");
    }

    if (handler_table[syscallIndex]) |handler| {
        const regs: Registers = .{
            .edi = edi,
            .esi = esi,
            .ebp = ebp,
            .esp = esp,
            .ebx = ebx,
            .edx = edx,
            .ecx = ecx,
        };
        handler(&regs);
    } else {
        @panic("Syscall TODO");
    }
}

/// never forget gang, args are pushed right to left
///
/// `pushal` pushes args in this order
/// * EAX
/// * ECX
/// * EDX
/// * EBX
/// * ESP
/// * EBP
/// * ESI
/// * EDI
pub fn syscallIsr() callconv(.naked) noreturn {
    asm volatile (
        \\pushal
    );

    asm volatile (
        \\call *%[landing_pad]
        \\popal
        \\iret
        : // no outputs
        : [landing_pad] "r" (@intFromPtr(&syscallHandler)),
    );
}
