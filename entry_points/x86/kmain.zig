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
const interrupts = @import("x86interrupts");
const osformat = @import("osformat");

/// Actual root "main" function of the x86 kernel. Jumped to from entry point
pub fn kmain() noreturn {
    as.assembly_wrappers.disable_x86_interrupts();
    as.assembly_wrappers.enableSSE();

    var framebuffer = framebuffer_api.FrameBuffer.init();
    var serial_port = serial.SerialPort.defaultInit();

    const message = "Trying to write out of COM port 1...!";
    serial_port.write(message);

    framebuffer.write(" COM1 succesfully written to! Setting up GDT...");

    const gdt: [5]memory.gdt.SegmentDescriptor = memory.gdt.createDefaultGDT();
    const gdt_descriptor: memory.gdt.GDTDescriptor = memory.gdt.GDTDescriptor.defaultInit(&gdt);
    gdt_descriptor.loadGDT(memory.gdt.SegmentRegisterConfiguration.default);

    const interrupt_function_table = comptime interrupts.idt.generateInterruptHandlers();
    const idt = interrupts.idt.createDefaultIDT(&interrupt_function_table);
    const idt_descriptor = interrupts.idt.IDTDescriptor.init(&idt);
    idt_descriptor.loadIDT();

    as.assembly_wrappers.enable_x86_interrupts();
    asm volatile (
        \\int $0x7
        \\int $0x8
    );

    framebuffer.write("Testing cursor movement...");
    framebuffer.testFourCorners();

    const writer = framebuffer.writer();
    osformat.print.kprintf(" We have printf too!", .{}, writer);
    osformat.print.kprintf(" Testing writeln...", .{}, writer);
    framebuffer.writeln("Hi there from a new line!");
    framebuffer.writeln("Hi there from a new line again!");
    framebuffer.writeln("Time to test scrolling...");

    for (0..12) |_| {
        for (0..16384) |_| {
            for (0..16384) |_| {
                asm volatile (
                    \\nop
                );
            }
        }
        framebuffer.write("Foo " ** 20);
        for (0..16384) |_| {
            for (0..16384) |_| {
                asm volatile (
                    \\nop
                );
            }
        }
        framebuffer.write("Bar " ** 20);
        for (0..16384) |_| {
            for (0..16384) |_| {
                asm volatile (
                    \\nop
                );
            }
        }
        framebuffer.write("Baz " ** 20);
    }

    // set EAX just so we know where we are in the log
    asm volatile (
        \\mov $0x4242, %eax
    );

    while (true) {
        asm volatile ("");
    }
}
