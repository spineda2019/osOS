//! shell.zig - main kernel process
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

const osstdlib = @import("osstdlib");

fn eval(input: []const u8) []const u8 {
    // TODO: actual evaluation
    return input;
}

/// The main "init" process of the osOS kernel. Should be run in user space.
/// Will be capable to run other processes (eventuallY) but will need basic
/// IO and will use the syscall interface to do this (exec/CreateProcess).
pub fn shellMain() void {
    while (true) {
        osstdlib.io.console.print("osshell> ");
        const line: []const u8 = osstdlib.io.console.readLine(); // R
        const result: []const u8 = eval(line); // E
        osstdlib.io.console.printLine(result); // P
    } // L
}
