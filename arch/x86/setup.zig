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

const framebuffer_api = @import("x86framebuffer");
const serial = @import("x86serial");
const memory = @import("x86memory");
const as = @import("x86asm");
const interrupts = @import("x86interrupts");
const kmain = @import("kmain");
const osformat = @import("osformat");
const oshal = @import("oshal");

/// Hardware setup; jumped to from the boot routine
pub fn setup() noreturn {
    as.assembly_wrappers.disable_x86_interrupts();
    as.assembly_wrappers.enableSSE();

    const gdt: [5]memory.gdt.SegmentDescriptor = memory.gdt.createDefaultGDT();
    const gdt_descriptor: memory.gdt.GDTDescriptor = .defaultInit(&gdt);
    gdt_descriptor.loadGDT(memory.gdt.SegmentRegisterConfiguration.default);

    const idt = interrupts.idt.createDefaultIDT();
    const idt_descriptor: interrupts.idt.IDTDescriptor = .init(&idt);
    idt_descriptor.loadIDT();

    var framebuffer: framebuffer_api.FrameBuffer = .init(.LightBrown, .DarkGray);
    framebuffer.printWelcomeScreen();
    for (0..16384) |_| {
        for (0..32768) |_| {
            asm volatile (
                \\nop
            );
        }
    }
    framebuffer.clear();

    var serial_port = serial.SerialPort.defaultInit();

    const message = "Trying to write out of COM port 1...!";
    serial_port.write(message);
    framebuffer.write(message);

    framebuffer.writeLine("COM1 succesfully written to! Testing cursor movement...");
    framebuffer.writeLine("x86: Activating PIC...");
    interrupts.pic.init(&framebuffer);

    var page_table_directory: memory.paging.Page.Table.Directory = .init();
    _ = &page_table_directory;

    as.assembly_wrappers.enable_x86_interrupts();

    const hal_layout: oshal.HalLayout = comptime .{
        .assembly_wrappers = as,
        .Terminal = framebuffer_api.FrameBuffer,
    };
    kmain.kmain(
        hal_layout,
        oshal.HAL(hal_layout){ .terminal = &framebuffer },
    );
}
