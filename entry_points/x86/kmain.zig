//! kmain.zig - The central core of osOS on x86; where the boot routine jumps to
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

const framebuffer_api = @import("framebuffer/framebuffer.zig");
const serial = @import("io/serial.zig");
const memory = @import("x86memory");
const as = @import("x86asm");
const interrupts = @import("interrupts/interrupts.zig");

fn delay() void {
    for (0..16384) |_| {
        for (0..32768) |_| {
            asm volatile (
                \\nop
            );
        }
    }
}

/// Actual root "main" function of the x86 kernel. Jumped to from entry point
pub fn kmain() noreturn {
    var framebuffer = framebuffer_api.FrameBuffer.init();
    var serial_port = serial.SerialPort.defaultInit();
    var idt: interrupts.InterruptDescriptionTable = undefined;

    const message = "foo && bar && baz!";

    framebuffer.write(message);
    serial_port.write(message);
    framebuffer.write(" COM1 succesfully written to!");

    var gd_table = memory.gdt.GlobalDescriptorTable{
        .address = undefined,
        .size = 2,
    };
    gd_table.address = @intFromPtr(&gd_table);
    const gdt_entry = memory.gdt.SegmentDescriptor.create(
        1048575,
        @intFromPtr(&kmain),
        0,
        0,
    );
    asm volatile (
        \\ and %[foo], %[foo]
        :
        : [foo] "r" (&gdt_entry),
    );

    _ = &idt;

    // as.assembly_wrappers.x86_lgdt(&gd_table);

    const address = &interrupts.interrupt_0_handler;
    asm volatile (
        \\movl %[addr], %eax
        :
        : [addr] "r" (address),
    );

    while (true) {
        asm volatile ("");
    }
}
