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

const std = @import("std");
const io = @import("x86io");
const memory = @import("x86memory");
const as = @import("x86asm");
const interrupts = @import("x86interrupts");
const kmain = @import("kmain");
const osformat = @import("osformat");
const oshal = @import("oshal");
const BootInfo = @import("BootInfo");

pub fn handlePanic(msg: []const u8, start_address: ?usize) noreturn {
    @branchHint(.cold);
    as.assembly_wrappers.disable_x86_interrupts();

    // Assuming we have the higherhalf address. Otherwise, we're boned
    var framebuffer: io.FrameBuffer = .init(.Black, .White, 0xC00B8000);
    framebuffer.clear();

    var writer_buf: [256]u8 = undefined;
    var fb_writer = framebuffer.writer(&writer_buf);

    fb_writer.writef("Kernel Panic! Message: {s}\n", .{msg});

    // subtract to get the previous address, i.e. the caller of panic
    const call_instruction_size = comptime 5;
    const return_addr = @returnAddress() - call_instruction_size;

    fb_writer.writef("Suspected panic-caller address: 0x{x}\n", .{return_addr});

    const start: usize = start_address orelse return_addr;
    _ = start;

    const si = std.debug.getSelfDebugInfo() catch {
        fb_writer.writef("Could not get SelfInfo\n", .{});
    };
    fb_writer.writef("SelfInfo address: 0x{x}\n", .{@intFromPtr(si)});

    fb_writer.flush();
    while (true) {
        asm volatile ("");
    }
}

const gdt: [5]memory.gdt.SegmentDescriptor = memory.gdt.createDefaultGDT();
var gdt_descriptor: memory.gdt.GDTDescriptor = .{ .size = 0, .address = 0 };

var idt: [256]interrupts.idt.InterruptDescriptor = undefined;
var idt_descriptor: interrupts.idt.IDTDescriptor = undefined;

/// Hardware setup; jumped to from the boot routine
/// At this point, paging should be enabled, and we should be in the higher
/// half and using a virtual stack.
pub fn setup(boot_info: BootInfo) noreturn {
    as.assembly_wrappers.disable_x86_interrupts();
    // as.assembly_wrappers.enableSSE();

    gdt_descriptor = .defaultInit(&gdt);
    gdt_descriptor.loadGDT(memory.gdt.SegmentRegisterConfiguration.default);

    idt = interrupts.idt.createDefaultIDT();
    idt_descriptor = .init(&idt);
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

    var fb_buffer: [64]u8 = undefined;
    var fb_writer: osformat.IWriter = framebuffer.writer(&fb_buffer);

    var sp_buffer: [64]u8 = undefined;
    var sp_writer: osformat.IWriter = serial_port.writer(&sp_buffer);

    framebuffer.printWelcomeScreen();
    for (0..16384) |_| {
        for (0..32768) |_| {
            asm volatile ("");
        }
    }
    framebuffer.clear();

    var logger: io.Logger = .{
        .framebuffer_writer = &fb_writer,
        .serial_port_writer = &sp_writer,
    };

    const virtual_pd_address = boot_info.paging.virtualPD() catch |err| {
        @panic(@errorName(err));
    };

    logger.log("******************* Memory info *******************\r\n", .{});
    logger.log("Setup fn linear address: {*}\r\n", .{&setup});
    logger.log("GDT (array) linear address: {*}\r\n", .{&gdt});
    logger.log("GDT Descriptor linear address: {*}\r\n", .{&gdt_descriptor});
    logger.log("IDT (array) linear address: {*}\r\n", .{&idt});

    logger.log("******************* Paging info *******************\r\n", .{});
    logger.log("Physical kernel end at {*}\r\n", .{boot_info.memory.kernel_end});
    logger.log("Probing paging information...\r\n", .{});
    logger.log("    PD Address: {*}\r\n", .{boot_info.paging.page_directory});
    logger.log("    Virt Equivalent: {*}\r\n\r\n", .{virtual_pd_address});
    logger.log("    Checking VirtToPhy mappings...\r\n", .{});

    const virt_addresses = comptime [_]u32{
        0xC00B8000,
        0xC0000000,
    };
    inline for (virt_addresses) |addr| {
        const str: []const u8 = comptime osformat.format.AddressString.init(addr).getStr();
        if (boot_info.paging.virtualToPhysical(addr)) |mapped| {
            logger.log(
                "    Virt address (0x" ++ str ++ ") maps to physical address: (0x{x})\r\n",
                .{mapped},
            );
        } else {
            logger.log("    Virt address (0x" ++ str ++ ") is unmapped\r\n", .{});
        }
    }

    logger.log("    Checking PhyToVirt mappings...\r\n", .{});

    const phy_addresses = comptime [_]u32{
        0x000B8000,
        0x00000000,
    };
    inline for (phy_addresses) |addr| {
        const MappingInfo = memory.paging.Info.MappingInfo;
        const mappings: MappingInfo = boot_info.paging.physicalToVirtual(addr) catch .empty;

        if (mappings.map_count == 0) {
            logger.log("    Phy address (0x{d}) maps to nothing...\r\n", .{addr});
        } else {
            const str: []const u8 = comptime osformat.format.AddressString.init(addr).getStr();
            logger.log(
                "    Phy address (0x" ++ str ++ ") maps to virtual address(es):\r\n",
                .{},
            );
            for (mappings.virtual_mappings, 0..) |mapped, idx| {
                if (idx >= mappings.map_count) {
                    break;
                } else {
                    logger.log("        0x{d}\r\n", .{mapped});
                }
            }
        }
    }

    logger.log("Dumping special register info...\r\n", .{});
    const cr0: as.control_registers.CR0 = as.assembly_wrappers.getCR0();
    inline for (comptime std.meta.fieldNames(@TypeOf(cr0))) |name| {
        const field = @field(cr0, name);
        if (@TypeOf(field) == bool) {
            const bit: []const u8 = if (field) "1" else "0";
            logger.log("    " ++ name ++ ": {s}\r\n", .{bit});
        }
    }

    if (!boot_info.bootinfo.valid) {
        @panic(&boot_info.bootinfo.diagnostic);
    } else {
        const slice: []const u8 = &boot_info.bootinfo.diagnostic;
        logger.log("{s}\r\n", .{slice});
    }

    logger.log("Bootloader name: {s}\r\n", .{boot_info.bootinfo.name});

    logger.log("Command Line: ", .{});
    if (boot_info.bootinfo.cmdline) |cmd| {
        logger.log("{s}\r\n", .{cmd});
    } else {
        logger.log("Not found...", .{});
    }

    logger.log("Probing Framebuffer info...\r\n", .{});

    if (boot_info.framebuffer.addr) |address| {
        logger.log("    Address: 0x{d}\r\n", .{address});
    } else {
        logger.log("    Address not found...\r\n", .{});
    }

    if (boot_info.framebuffer.height) |height| {
        logger.log("    Framebuffer Height: {d}\r\n", .{height});
    } else {
        logger.log("    Framebuffer Height not found...\r\n", .{});
    }

    if (boot_info.framebuffer.width) |width| {
        logger.log("    Framebuffer Width: {d}\r\n", .{width});
    } else {
        logger.log("    Framebuffer Width not found...\r\n", .{});
    }

    logger.log("Probing Available Memory...\r\n", .{});
    logger.log("    Total Chunk Count: {d}\r\n", .{boot_info.memory.len});
    logger.log("    Available Chunks: \r\n", .{});
    for (0..boot_info.memory.len) |idx| {
        if (boot_info.memory.availableMemChunkAt(idx)) |chunk| {
            logger.log("        Addr: 0x{d}\r\n", .{chunk.address});
            logger.log("        Len: 0x{d}\r\n\r\n", .{chunk.length});
        }
    }

    var page_allocator = memory.PageAllocator.init(boot_info.memory) catch |err| {
        @panic(@errorName(err));
    };
    interrupts.idt.free_page_list = page_allocator.head.first;

    logger.log("allocator address: {*}\r\n", .{&page_allocator});

    var maybe_node = page_allocator.head.first;
    while (maybe_node) |node| {
        const chunk: *memory.PageAllocator.Chunk = @fieldParentPtr("node", node);

        logger.log("Free Chunk at: {*}\r\n", .{chunk});
        logger.log("Free byte count: {d}\r\n", .{chunk.free_bytes});
        maybe_node = node.next;
    }

    logger.log("COM1 succesfully written to! Testing cursor movement...\r\n", .{});
    logger.log("x86: Activating PIC...\r\n", .{});
    interrupts.pic.init(&framebuffer);

    // undo first 4MB identity mapping to finish higher half jump.
    boot_info.paging.unmap(0);
    as.assembly_wrappers.enable_x86_interrupts();

    kmain.kmain(
        .{
            .terminal = fb_writer,
            .serial_io = sp_writer,
        },
        .{
            .assembly_wrappers = .{
                .jump = as.assembly_wrappers.jump,
                .illegal_instruction = as.assembly_wrappers.illegal_instruction,
            },
        },
    );
}
