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

const terminal = @import("hal_terminal");
const serial = @import("hal_serial");

comptime {
    const meta = @import("std").meta;

    if (meta.hasMethod(terminal.Terminal, "init")) {
        @compileError("TODO");
    }
    if (meta.hasMethod(serial.SerialPort, "defaultInit")) {
        @compileError("TODO");
    }
}

pub fn kmain() noreturn {
    var tty = terminal.Terminal.init();
    var serial_port = serial.SerialPort.defaultInit();

    const message = "Trying to write out of COM port 1...!";
    serial_port.write(message);

    tty.write(" COM1 succesfully written to! Testing cursor movement...");
    tty.testFourCorners();

    const writer = tty.writer();
    writer.kprintf(" We have printf too!", .{});
    writer.kprintf(" Testing writeln...", .{});
    tty.writeln("Hi there from a new line!");
    tty.writeln("Hi there from a new line again!");
    tty.writeln("Time to test scrolling...");
    while (true) {
        asm volatile ("");
    }
}
