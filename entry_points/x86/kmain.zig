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
const osformat = @import("osformat");

fn panic() noreturn {
    while (true) {
        asm volatile ("");
    }
}

/// Actual root "main" function of the x86 kernel. Jumped to from entry point
pub fn kmain() noreturn {
    as.assembly_wrappers.enableSSE();
    var framebuffer = framebuffer_api.FrameBuffer.init();
    var serial_port = serial.SerialPort.defaultInit();

    const message = "foo && bar && baz!";

    serial_port.write(message);
    framebuffer.write(" COM1 succesfully written to! Setting up GDT...");

    // only set up 3 segments for now: null descriptor and descriptor's for
    // kernel's code and data segments
    var gdt: [3]memory.gdt.SegmentDescriptor = undefined;
    gdt[0] = memory.gdt.SegmentDescriptor.createNullDescriptor();
    gdt[1] = memory.gdt.SegmentDescriptor.createDefaultCodeSegmentDescriptor();
    gdt[2] = memory.gdt.SegmentDescriptor.createDefaultDataSegmentDescriptor();

    const gdt_ptr = memory.gdt.GlobalDescriptorTablePointer.init(&gdt);
    _ = gdt_ptr;
    // gdt_ptr.loadGDT();

    const interrupt_function_table = interrupts.InterruptHandlerTable.init();
    // const idt = interrupts.InterruptDescriptionTable.init(&interrupt_function_table);
    // const idt_ptr = interrupts.InterruptDescriptionTablePtr.init(&idt);

    asm volatile (
        \\#lidtl (%[idt_address])
        : // no outputs
        : [idt_address] "r" (&interrupt_function_table),
    );

    const writer = framebuffer.writer();
    osformat.print.kprintf(" We have printf too!", .{}, writer);

    osformat.print.kprintf(" Time to test scrolling...", .{}, writer);
    for (0..60) |_| {
        osformat.print.kprintf(" ", .{}, writer);
    }

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
