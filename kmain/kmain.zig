//! kmain.zig - The central core of osOS; where the boot routine jumps to
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

// const terminal = @import("hal_terminal");
// const serial = @import("hal_serial");

const hal_validation = @import("hal_validation.zig");
const builtin = @import("builtin");
const process = @import("osprocess");
const osformat = @import("osformat");
const oshal = @import("oshal");
const testoptions = @import("testoptions");

pub fn kmain(
    comptime layout: oshal.HalLayout,
    arch_agnostic_hal: oshal.HAL(layout),
) noreturn {
    comptime hal_validation.validateHalType(@TypeOf(arch_agnostic_hal));

    for (0..12) |_| {
        arch_agnostic_hal.terminal.writef("Foo " ** 20, .{});
        arch_agnostic_hal.terminal.writef("Bar " ** 20, .{});
        arch_agnostic_hal.terminal.writef("Baz " ** 20, .{});
    }

    arch_agnostic_hal.terminal.writef("Hey there! We succesfully passed the HAL to kmain\r\n", .{});
    arch_agnostic_hal.terminal.writef("Testing writeLine...\r\n", .{});
    arch_agnostic_hal.terminal.writef("Hi there from a new line!\r\n", .{});
    arch_agnostic_hal.terminal.writef("Hi there from a new line again!\r\n", .{});

    if (testoptions.test_panic) {
        arch_agnostic_hal.terminal.writef("Testing Panic\r\n", .{});
        @panic("Testing Panic");
    }

    if (builtin.target.cpu.arch == .riscv32) {
        arch_agnostic_hal.terminal.writef(
            "Purposefully performing an illegal instruction...\r\n",
            .{},
        );
        arch_agnostic_hal.assembly_wrappers.illegal_instruction();
    }

    const col_width: u32 = 80;
    arch_agnostic_hal.terminal.writef("Terminal Column Width: {d}\r\n", .{col_width});

    arch_agnostic_hal.terminal.flush();
    arch_agnostic_hal.serial_io.flush();

    const process_pool: process.ProcessTable = .init();
    _ = process_pool;

    while (true) {
        asm volatile ("");
    }
}
