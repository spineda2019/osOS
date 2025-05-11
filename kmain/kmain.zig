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

pub const hal = @import("hal/hal.zig");

pub fn kmain(hal_interface: anytype) noreturn {
    _ = comptime hal.validateHalObject(@TypeOf(hal_interface));

    hal_interface.terminal.write("Hey there! We succesfully passed the HAL to kmain!");
    hal_interface.terminal.write(" Testing writeLine...");

    hal_interface.terminal.writeLine("Hi there from a new line!");
    hal_interface.terminal.writeLine("Hi there from a new line again!");

    while (true) {
        asm volatile ("");
    }
}
