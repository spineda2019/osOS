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

const io = @import("x86io");
const memory = @import("x86memory");
const as = @import("x86asm");
const interrupts = @import("x86interrupts");
const kmain = @import("kmain");
const osformat = @import("osformat");
const oshal = @import("oshal");
const bootutils = @import("osboot");

const physical_kernel_base = @extern(
    *anyopaque,
    .{ .name = "__physical_kernel_base" },
);
const virtual_kernel_base: u32 = 0xC0_00_00_00;

pub fn handlePanic(msg: []const u8, start_address: ?usize) noreturn {
    @branchHint(.cold);
    const StackIterator = @import("std").debug.StackIterator;

    as.assembly_wrappers.disable_x86_interrupts();
    var framebuffer: io.FrameBuffer = .init(.Black, .White);
    framebuffer.clear();
    framebuffer.write("Kernel Panic! Message: ");
    framebuffer.writeLine(msg);
    // subtract to get the previous address, i.e. the caller of panic
    const call_instruction_size = comptime 5;
    const return_addr = @returnAddress() - call_instruction_size;
    const return_addr_str: osformat.format.StringFromInt(usize, 16) = .init(return_addr);
    framebuffer.write("Suspected caller address: 0x");
    framebuffer.writeLine(return_addr_str.getStr());

    if (start_address) |addr| {
        framebuffer.writeLine("Received first_address info:");
        var iterator: StackIterator = .init(addr, @frameAddress());
        while (iterator.next()) |next| {
            const start_addr_str: osformat.format.StringFromInt(usize, 16) = .init(
                next,
            );
            framebuffer.write("    Frame address: 0x");
            framebuffer.writeLine(start_addr_str.getStr());
        }
    } else {
        framebuffer.writeLine("No reported start_address");
    }

    while (true) {
        asm volatile ("");
    }
}

/// Hardware setup; jumped to from the boot routine
pub fn setup(mbInfo: *allowzero const bootutils.MultiBoot.V1.Info) noreturn {
    as.assembly_wrappers.disable_x86_interrupts();
    as.assembly_wrappers.enableSSE();

    const gdt: [5]memory.gdt.SegmentDescriptor = memory.gdt.createDefaultGDT();

    const gdt_descriptor: memory.gdt.GDTDescriptor = .defaultInit(&gdt);
    gdt_descriptor.loadGDT(memory.gdt.SegmentRegisterConfiguration.default);

    const idt = interrupts.idt.createDefaultIDT();
    const idt_descriptor: interrupts.idt.IDTDescriptor = .init(&idt);
    idt_descriptor.loadIDT();

    var framebuffer: io.FrameBuffer = .init(.LightBrown, .DarkGray);
    var serial_port = io.SerialPort.defaultInit();

    framebuffer.printWelcomeScreen();
    for (0..16384) |_| {
        for (0..32768) |_| {
            asm volatile ("");
        }
    }
    framebuffer.clear();

    framebuffer.writeLine("Probing MultibootInfo...");
    framebuffer.write("Info Struct Address: 0x");
    const mbInfoAddrStr: osformat.format.StringFromInt(u32, 16) = .init(
        @intFromPtr(mbInfo),
    );

    framebuffer.writeLine(mbInfoAddrStr.getStr());
    if (mbInfo.flags.framebuffer) {
        framebuffer.writeLine("FB Info found!");
        framebuffer.write("    Lower: 0x");
        const fb_lower_str: osformat.format.StringFromInt(u32, 16) = .init(
            mbInfo.framebuffer_addr_lower,
        );
        framebuffer.writeLine(fb_lower_str.getStr());
    } else {
        framebuffer.writeLine("No FB info...");
    }

    if (mbInfo.flags.mmap) {
        framebuffer.writeLine("MMap info found!");
        framebuffer.write("    Length: ");
        const lenStr: osformat.format.StringFromInt(u32, 10) = .init(
            mbInfo.mmap_length,
        );
        framebuffer.writeLine(lenStr.getStr());

        // Something below is causing an incorrect alignment panbic...
        const EntryType = bootutils.MultiBoot.V1.Info.MemMapEntry;
        const StringFormatType = osformat.format.StringFromInt(u32, 10);
        const AddressFormatType = osformat.format.StringFromInt(u32, 16);

        const entry: [*]const EntryType = @ptrFromInt(mbInfo.mmap_addr);

        var buf: []const u8 = undefined;
        for (0..mbInfo.mmap_length / @sizeOf(EntryType)) |idx| {
            const size_str: StringFormatType = .init(entry[idx].size);
            const addr_str: AddressFormatType = .init(entry[idx].addr_low);
            const len_str: StringFormatType = .init(entry[idx].len_low);

            buf = "    Entry: ";
            framebuffer.writeLine(buf);
            serial_port.write(buf);
            serial_port.write("\r\n");

            buf = "        Size: ";
            framebuffer.write(buf);
            framebuffer.writeLine(size_str.getStr());
            serial_port.write(buf);
            serial_port.write(size_str.getStr());
            serial_port.write("\r\n");

            buf = "        Addr: 0x";
            framebuffer.write(buf);
            framebuffer.writeLine(addr_str.getStr());
            serial_port.write(buf);
            serial_port.write(addr_str.getStr());
            serial_port.write("\r\n");

            buf = "        Len: ";
            framebuffer.write(buf);
            framebuffer.writeLine(len_str.getStr());
            serial_port.write(buf);
            serial_port.write(len_str.getStr());
            serial_port.write("\r\n");

            buf = "        Type: ";
            framebuffer.write(buf);
            framebuffer.writeLine(@tagName(entry[idx].entry_type));
            serial_port.write(buf);
            serial_port.write(@tagName(entry[idx].entry_type));
            serial_port.write("\r\n");
        }
    } else {
        framebuffer.writeLine("MMap info not available");
    }

    const message = "Trying to write out of COM port 1...";
    serial_port.write(message);
    framebuffer.writeLine(message);

    framebuffer.writeLine("COM1 succesfully written to! Testing cursor movement...");
    framebuffer.writeLine("x86: Activating PIC...");
    interrupts.pic.init(&framebuffer);

    as.assembly_wrappers.enable_x86_interrupts();

    const hal_layout: oshal.HalLayout = comptime .{
        .assembly_wrappers = as.assembly_wrappers,
        .Terminal = io.FrameBuffer,
        .SerialPortIo = io.SerialPort,
    };
    kmain.kmain(
        hal_layout,
        oshal.HAL(hal_layout){
            .terminal = &framebuffer,
            .serial_io = &serial_port,
        },
    );
}
