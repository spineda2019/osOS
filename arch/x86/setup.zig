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

pub fn handlePanic(msg: []const u8, start_address: ?usize) noreturn {
    @branchHint(.cold);
    as.assembly_wrappers.disable_x86_interrupts();

    const StackIterator = @import("std").debug.StackIterator;

    var framebuffer: io.FrameBuffer = .init(.Black, .White, 0xC00B8000);
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
/// At this point, paging should be enabled, and we should be in the higher
/// half.
pub fn setup(boot_info: BootInfo) noreturn {
    // Switch to the virtual stack
    as.assembly_wrappers.disable_x86_interrupts();
    // as.assembly_wrappers.enableSSE();
    const gdt: [5]memory.gdt.SegmentDescriptor = memory.gdt.createDefaultGDT();

    const gdt_descriptor: memory.gdt.GDTDescriptor = .defaultInit(&gdt);
    gdt_descriptor.loadGDT(memory.gdt.SegmentRegisterConfiguration.default);

    const idt = interrupts.idt.createDefaultIDT();
    const idt_descriptor: interrupts.idt.IDTDescriptor = .init(&idt);
    idt_descriptor.loadIDT();

    var framebuffer: io.FrameBuffer = .init(
        .LightBrown,
        .DarkGray,
        fb_start: {
            if (boot_info.framebuffer.addr) |addr| {
                break :fb_start addr + boot_info.paging.virtual_kernel_base;
            } else {
                break :fb_start 0xC00B8000;
            }
        },
    );
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

    const virtual_pd_address = boot_info.paging.virtualPD() catch |err| {
        @panic(@errorName(err));
    };

    {
        const str: osformat.format.AddressString = .init(
            @intFromPtr(boot_info.memory.kernel_end),
        );

        logger.log("Physical kernel end at 0x");
        logger.logLine(str.getStr());
    }

    {
        const pd_address: StringFromHex = .init(@intFromPtr(boot_info.paging.page_directory));
        const virt_address: StringFromHex = .init(@intFromPtr(virtual_pd_address));

        logger.logLine("Probing paging information...");
        logger.log("    PD Address: 0x");
        logger.logLine(pd_address.getStr());
        logger.log("    Virt Equivalent: 0x");
        logger.logLine(virt_address.getStr());

        logger.log("");

        const virt_addresses = comptime [_]u32{
            0xC00B8000,
            0xC0000000,
        };
        logger.logLine("    Checking VirtToPhy mappings...");
        inline for (virt_addresses) |addr| {
            const str: []const u8 = comptime StringFromHex.init(addr).getStr();
            logger.log("    Virt address (0x" ++ str ++ ") maps to physical address: (");
            if (boot_info.paging.virtualToPhysical(addr)) |mapped| {
                logger.log("0x");
                logger.log(StringFromHex.init(mapped).getStr());
            } else {
                logger.log("Unmapped");
            }
            logger.logLine(")");
        }

        const phy_addresses = comptime [_]u32{
            0x000B8000,
            0x00000000,
        };
        logger.logLine("    Checking PhyToVirt mappings...");
        inline for (phy_addresses) |addr| {
            const str: []const u8 = comptime StringFromHex.init(addr).getStr();
            logger.logLine("    Phy address (0x" ++ str ++ ") maps to virtual address(es):");
            const MappingInfo = memory.paging.Info.MappingInfo;
            const mappings: MappingInfo = boot_info.paging.physicalToVirtual(addr) catch .empty;
            if (mappings.map_count == 0) {
                logger.logLine("        None");
            } else {
                for (mappings.virtual_mappings, 0..) |mapped, idx| {
                    if (idx >= mappings.map_count) {
                        break;
                    } else {
                        const mapped_str: StringFromHex = .init(mapped);
                        logger.log("        0x");
                        logger.logLine(mapped_str.getStr());
                    }
                }
            }
        }
    }

    {
        const std = @import("std");
        logger.logLine("Dumping special register info...");
        const cr0: as.control_registers.CR0 = as.assembly_wrappers.getCR0();
        inline for (comptime std.meta.fieldNames(@TypeOf(cr0))) |name| {
            const field = @field(cr0, name);
            if (@TypeOf(field) == bool) {
                logger.logLine("    " ++ name ++ ": " ++ if (field) "1" else "0");
            }
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
            const addr_str: StringFromHex = .init(chunk.address);
            const len_str: StringFromDecimal = .init(chunk.length);

            logger.log("        Addr: 0x");
            logger.logLine(addr_str.getStr());

            logger.log("        Len: ");
            logger.logLine(len_str.getStr());

            logger.logLine("");
        }
    }

    var page_allocator = memory.PageAllocator.init(boot_info.memory) catch |err| {
        @panic(@errorName(err));
    };
    interrupts.idt.free_page_list = page_allocator.head.first;
    {
        const allocator_address: osformat.format.AddressString = .init(
            @intFromPtr(&page_allocator),
        );

        logger.log("allocator address: 0x");
        logger.logLine(allocator_address.getStr());

        var maybe_node = page_allocator.head.first;
        while (maybe_node) |node| {
            const chunk: *memory.PageAllocator.Chunk = @fieldParentPtr("node", node);
            const page_aligned_node = @intFromPtr(chunk);
            const addr: osformat.format.AddressString = .init(page_aligned_node);
            const free_byte_count: osformat.format.DecimalString = .init(chunk.free_bytes);
            logger.log("Free Chunk at: 0x");
            logger.logLine(addr.getStr());
            logger.log("Free byte count: ");
            logger.logLine(free_byte_count.getStr());
            maybe_node = node.next;
        }
    }

    logger.logLine("COM1 succesfully written to! Testing cursor movement...");
    logger.logLine("x86: Activating PIC...");
    interrupts.pic.init(&framebuffer);

    // undo first 4MB identity mapping to finish higher half jump.
    boot_info.paging.unmap(0);
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
