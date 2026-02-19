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
const BootInfo = @import("BootInfo");
const StringFromHex = osformat.format.StringFromInt(usize, 16);
const StringFromDecimal = osformat.format.StringFromInt(usize, 10);

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
    const return_addr_str: StringFromHex = .init(return_addr);
    framebuffer.write("Suspected caller address: 0x");
    framebuffer.writeLine(return_addr_str.getStr());

    if (start_address) |addr| {
        framebuffer.writeLine("Received first_address info:");
        var iterator: StackIterator = .init(addr, @frameAddress());
        while (iterator.next()) |next| {
            const start_addr_str: StringFromHex = .init(
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
pub fn setup(boot_info: BootInfo) noreturn {
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
    const logger: io.Logger = .{ .fp = &framebuffer, .sp = &serial_port };
    const message = "Trying to write out of COM port 1...\r\n";
    serial_port.write(message);

    framebuffer.printWelcomeScreen();
    for (0..16384) |_| {
        for (0..32768) |_| {
            asm volatile ("");
        }
    }
    framebuffer.clear();

    {
        logger.logLine("Probing paging information...");
        const pd_address: StringFromHex = .init(@intFromPtr(boot_info.pd_address));
        logger.log("    PD Address: 0x");
        logger.logLine(pd_address.getStr());

        const virt_addresses = comptime [_]u32{
            0x000B8000,
        };
        inline for (virt_addresses) |addr| {
            const str: StringFromHex = .init(addr);
            logger.log("    Virt address (0x");
            logger.log(str.getStr());
            logger.log(") maps to: ");
            logger.logLine("TODO");
        }
    }

    if (!boot_info.bootinfo.valid) {
        @panic(&boot_info.bootinfo.diagnostic);
    } else {
        logger.logLine(&boot_info.bootinfo.diagnostic);
    }

    logger.log("Bootloader name: ");
    logger.logLineCStr(boot_info.bootinfo.name);

    logger.log("Command Line: ");
    if (boot_info.bootinfo.cmdline) |cmd| {
        logger.logLineCStr(cmd);
    } else {
        logger.logLineCStr("Not found...");
    }

    logger.logLine("Probing Framebuffer info...");

    logger.log("    Address: ");
    if (boot_info.framebuffer.addr) |address| {
        logger.log("0x");
        const fb_lower_str: StringFromHex = .init(address);
        logger.logLine(fb_lower_str.getStr());
    } else {
        logger.logLine("Not found...");
    }

    logger.log("    Framebuffer Height: ");
    if (boot_info.framebuffer.height) |height| {
        const fb_height: StringFromDecimal = .init(height);
        logger.logLine(fb_height.getStr());
    } else {
        logger.logLine("Not found...");
    }

    logger.log("    Framebuffer Width: ");
    if (boot_info.framebuffer.width) |width| {
        const fb_width: StringFromDecimal = .init(width);
        logger.logLine(fb_width.getStr());
    } else {
        logger.logLine("Not found...");
    }

    logger.logLine("Probing Available Memory...");
    logger.log("    Total Chunk Count: ");
    const chunkStr: StringFromDecimal = .init(boot_info.memory.len);
    logger.logLine(chunkStr.getStr());
    logger.logLine("    Available Chunks: ");
    for (0..boot_info.memory.len) |idx| {
        if (boot_info.memory.availableMemChunkAt(idx)) |chunk| {
            const size_str: StringFromDecimal = .init(chunk.size);
            const addr_str: StringFromHex = .init(chunk.address);
            const len_str: StringFromDecimal = .init(chunk.length);

            logger.log("        Size: ");
            logger.logLine(size_str.getStr());

            logger.log("        Addr: 0x");
            logger.logLine(addr_str.getStr());

            logger.log("        Len: ");
            logger.logLine(len_str.getStr());

            logger.logLine("");
        }
    }

    logger.logLine("COM1 succesfully written to! Testing cursor movement...");
    logger.logLine("x86: Activating PIC...");
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
