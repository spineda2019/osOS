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

pub const hal = @import("oshal");
const hal_validation = @import("hal_validation.zig");
const builtin = @import("builtin");

fn delay() void {
    for (0..8192) |_| {
        for (0..8192) |_| {
            asm volatile (
                \\nop
            );
        }
    }
}

pub fn kmain(arch_agnostic_hal: anytype) noreturn {
    comptime hal_validation.validateHalType(@TypeOf(arch_agnostic_hal));

    for (0..12) |_| {
        delay();
        arch_agnostic_hal.terminal.write("Foo " ** 20);
        delay();
        arch_agnostic_hal.terminal.write("Bar " ** 20);
        delay();
        arch_agnostic_hal.terminal.write("Baz " ** 20);
    }

    arch_agnostic_hal.terminal.write("Hey there! We succesfully passed the HAL to kmain!");
    arch_agnostic_hal.terminal.write(" Testing writeLine...");

    arch_agnostic_hal.terminal.writeLine("Hi there from a new line!");
    arch_agnostic_hal.terminal.writeLine("Hi there from a new line again!");

    if (builtin.target.cpu.arch == .riscv32) {
        arch_agnostic_hal.assembly_wrappers.illegal_instruction();
    }

    while (true) {
        asm volatile ("");
    }
}
