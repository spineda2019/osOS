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
    framebuffer.write(" COM1 succesfully written to! Setting up GDT");

    // only set up 3 segments for now: null descriptor and descriptor's for
    // kernel's code and data segments
    var gdt: [3]memory.gdt.SegmentDescriptor = undefined;
    gdt[0] = memory.gdt.SegmentDescriptor.createNullDescriptor();
    gdt[1] = memory.gdt.SegmentDescriptor.createDefaultCodeSegmentDescriptor();
    gdt[2] = memory.gdt.SegmentDescriptor.createDefaultDataSegmentDescriptor();

    const gdt_ptr = memory.gdt.GlobalDescriptorTablePointer.init(&gdt);
    _ = &gdt_ptr;

    // as.assembly_wrappers.disable_x86_interrupts();
    // load GDT and the respective segment registers
    // as.assembly_wrappers.x86_lgdt(&gdt_ptr);
    asm volatile (
        \\#jmp $0x08, $.kmain_long_jump
        \\#.kmain_long_jump:
        \\#movw 0x10, %ds  # data segment is third in our GDT table
        \\#movw 0x10, %ss  # 0x10 is 16, which matches the offset to be 3rd 
        \\#movw 0x10, %es
    );
    // as.assembly_wrappers.enable_x86_interrupts();

    _ = &idt;

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
