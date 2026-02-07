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
pub fn setup(mbInfo: *const bootutils.MultiBoot.V1.Info) noreturn {
    as.assembly_wrappers.disable_x86_interrupts();
    // as.assembly_wrappers.enableSSE();

    const gdt: [5]memory.gdt.SegmentDescriptor = memory.gdt.createDefaultGDT();

    const gdt_descriptor: memory.gdt.GDTDescriptor = .defaultInit(&gdt);
    gdt_descriptor.loadGDT(memory.gdt.SegmentRegisterConfiguration.default);

    const idt = interrupts.idt.createDefaultIDT();
    const idt_descriptor: interrupts.idt.IDTDescriptor = .init(&idt);
    idt_descriptor.loadIDT();

    var framebuffer: io.FrameBuffer = .init(.LightBrown, .DarkGray);
    var serial_port = io.SerialPort.defaultInit();
    const message = "Trying to write out of COM port 1...\r\n";
    serial_port.write(message);

    framebuffer.printWelcomeScreen();
    for (0..16384) |_| {
        for (0..32768) |_| {
            asm volatile ("");
        }
    }
    framebuffer.clear();

    io.log(&serial_port, &framebuffer, "MultibootInfo Struct Address: 0x");
    const mbInfoAddrStr: osformat.format.StringFromInt(u32, 16) = .init(
        @intFromPtr(mbInfo),
    );

    io.logLine(&serial_port, &framebuffer, mbInfoAddrStr.getStr());
    const bootLoaderName: [*:0]const u8 = @ptrFromInt(mbInfo.boot_loader_name);
    io.log(&serial_port, &framebuffer, "Bootloader name: ");
    io.logLineCStr(&serial_port, &framebuffer, bootLoaderName);
    io.logLine(&serial_port, &framebuffer, "Probing MultibootInfo...");

    {
        const std = @import("std");
        inline for (comptime std.meta.fieldNames(bootutils.MultiBoot.V1.Info)) |field| {
            io.log(&serial_port, &framebuffer, "    " ++ field ++ ": ");
            const field_val = @field(mbInfo.*, field);
            const T = @TypeOf(field_val);

            switch (@typeInfo(T)) {
                .int => {
                    const base = comptime if (@bitSizeOf(T) > 16) 16 else 10;
                    if (base > 10) {
                        io.log(&serial_port, &framebuffer, "0x");
                    }
                    var str: osformat.format.StringFromInt(u32, base) = .init(field_val);
                    io.logLine(&serial_port, &framebuffer, str.getStr());
                },
                .@"union" => {
                    io.logLine(&serial_port, &framebuffer, "TODO (Union)");
                },
                inline else => {
                    io.logLine(&serial_port, &framebuffer, "TODO (else)");
                },
            }
        }
    }

    if (mbInfo.flags.framebuffer) {
        io.logLine(&serial_port, &framebuffer, "FB Info found!");
        io.log(&serial_port, &framebuffer, "    Lower: 0x");
        const fb_lower_str: osformat.format.StringFromInt(u32, 16) = .init(
            mbInfo.framebuffer_addr_lower,
        );
        io.logLine(&serial_port, &framebuffer, fb_lower_str.getStr());
    } else {
        io.logLine(&serial_port, &framebuffer, "No FB info...");
    }

    if (mbInfo.flags.mmap) {
        io.logLine(&serial_port, &framebuffer, "MMap info found!");
        io.log(&serial_port, &framebuffer, "    Length: ");
        const lenStr: osformat.format.StringFromInt(u32, 10) = .init(
            mbInfo.mmap_length,
        );
        io.logLine(&serial_port, &framebuffer, lenStr.getStr());

        // Something below is causing an incorrect alignment panic...
        //
        const EntryType = bootutils.MultiBoot.V1.Info.MemMapEntry;
        const StringFormatType = osformat.format.StringFromInt(u32, 10);
        const AddressFormatType = osformat.format.StringFromInt(u32, 16);

        const entry: [*]const EntryType = @ptrFromInt(mbInfo.mmap_addr);

        for (0..mbInfo.mmap_length / @sizeOf(EntryType)) |idx| {
            const size_str: StringFormatType = .init(entry[idx].size);
            const addr_str: AddressFormatType = .init(entry[idx].addr_low);
            const len_str: StringFormatType = .init(entry[idx].len_low);

            io.logLine(&serial_port, &framebuffer, "    Entry: ");

            io.log(&serial_port, &framebuffer, "        Size: ");
            io.logLine(&serial_port, &framebuffer, size_str.getStr());

            io.log(&serial_port, &framebuffer, "        Addr: 0x");
            io.logLine(&serial_port, &framebuffer, addr_str.getStr());

            io.log(&serial_port, &framebuffer, "        Len: ");
            io.logLine(&serial_port, &framebuffer, len_str.getStr());

            io.log(&serial_port, &framebuffer, "        Type: ");
            io.logLine(
                &serial_port,
                &framebuffer,
                @tagName(entry[idx].entry_type),
            );
        }
    } else {
        io.logLine(&serial_port, &framebuffer, "MMap info not available");
    }

    io.logLine(
        &serial_port,
        &framebuffer,
        "COM1 succesfully written to! Testing cursor movement...",
    );
    io.logLine(&serial_port, &framebuffer, "x86: Activating PIC...");
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
