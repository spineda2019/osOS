//! kmain.zig - The central core of osOS; where the boot routine jumps from setup
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

const builtin = @import("builtin");
const process = @import("osprocess");
const osformat = @import("osformat");
const oshal = @import("oshal");
const testoptions = @import("testoptions");

/// Ideally the beginning of true arch agnostic osOS logic, like where the
/// scheduler will start and where pretty much everything that need not know
/// about CPU architecture (mostly) will be initialized.
///
/// Universally common CPU instructions (like jumping to an address, executing
/// and arbitrary illegal instruction for testing, etc) will be provided via
/// functions in `ct_hal`. Might be an escape hatch, but I like the abstraction.
pub fn kmain(rt_hal: oshal.RtHAL, comptime ct_hal: oshal.CtHal) noreturn {
    var terminal = rt_hal.terminal;
    var serial = rt_hal.serial_io;

    for (0..12) |_| {
        terminal.writef("Foo " ** 20, .{});
        terminal.writef("Bar " ** 20, .{});
        terminal.writef("Baz " ** 20, .{});
    }

    terminal.writef("Hey there! We succesfully passed the HAL to kmain\r\n", .{});
    terminal.writef("Testing writeLine...\r\n", .{});
    terminal.writef("Hi there from a new line!\r\n", .{});
    terminal.writef("Hi there from a new line again!\r\n", .{});

    if (testoptions.test_panic) {
        terminal.writef("Testing Panic\r\n", .{});
        @panic("Testing Panic");
    }

    if (testoptions.test_ill) {
        terminal.writef(
            "Purposefully performing an illegal instruction...\r\n",
            .{},
        );
        ct_hal.assembly_wrappers.illegal_instruction();
    }

    terminal.flush();
    serial.flush();

    var process_pool: process.ProcessTable(8) = .init();
    _ = &process_pool;
    // TODO(SEP) somehow start shell proc in userland
    // Userland semantics will likely need to be passed in via the RtHAL or CtHAL

    while (true) {
        asm volatile ("");
    }
}
