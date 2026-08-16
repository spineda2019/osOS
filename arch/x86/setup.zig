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
const panic = @import("panic/root.zig");

/// BSS Start
const bss = @extern([*]u8, .{ .name = "__bss" });

/// BSS End
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });

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
    const bssSize = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bssSize], 0);

    panic.virt_fb_addr = boot_info.framebuffer.virtual_addr;

    gdt_descriptor = .defaultInit(&gdt);
    gdt_descriptor.loadGDT(memory.gdt.SegmentRegisterConfiguration.default);

    idt = interrupts.idt.createDefaultIDT();
    idt_descriptor = .init(&idt);
    idt_descriptor.loadIDT();

    var framebuffer: io.FrameBuffer = .init(
        .LightBrown,
        .DarkGray,
        boot_info.framebuffer.virtual_addr,
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

    logger.log("******* Beginning x86 specific reporting *******\r\n\r\n", .{});

    reportMemoryInfo(&logger, &boot_info);
    reportSpecialRegInfo(&logger);
    reportPagingInfo(&logger, &boot_info);
    reportBootloaderInfo(&logger, &boot_info);
    reportFramebufferInfo(&logger, &boot_info);
    reportBootModuleInfo(&logger, &boot_info);

    var page_iter = blk: {
        var iter = boot_info.memory.iterator();
        const kernel_end: usize = @intFromPtr(boot_info.memory.kernel_end);
        while (iter.peek()) |chunk| {
            const ptr: usize = @intFromPtr(chunk.ptr);
            const region_end = ptr + chunk.len;

            if (region_end > kernel_end) {
                break;
            } else {
                _ = iter.next();
            }
        }

        break :blk iter;
    };

    var page_allocator = memory.PageAllocator.init(
        &page_iter,
        boot_info.memory.kernel_end,
    ) catch |err| {
        @panic(@errorName(err));
    };
    interrupts.idt.free_page_list = page_allocator.head.first;

    logger.log("allocator address: {*}\r\n", .{&page_allocator});

    {
        var iter = page_allocator.iterator();
        while (iter.next()) |chunk| {
            logger.log("Free Chunk at: {*}\r\n", .{chunk});
            logger.log("Free byte count: {d}\r\n", .{chunk.free_bytes});
        }
    }

    logger.log("COM1 succesfully written to! Testing cursor movement...\r\n", .{});
    logger.log("x86: Activating PIC...\r\n", .{});
    interrupts.pic.init();

    // undo first 4MB identity mapping to finish higher half jump.
    boot_info.paging.unmapTable(0);
    as.assembly_wrappers.enable_x86_interrupts();

    kmain.kmain(
        .{
            .terminal = fb_writer,
            .serial_io = sp_writer,
            .boot_module_info = boot_info.module_info,
            .char_buf = .{
                .impl = null,
                .vtable = &.{
                    .getChar = &struct {
                        fn impl(_: ?*anyopaque) ?u8 {
                            return interrupts.pic.scan_code_buffer.pop();
                        }
                    }.impl,
                },
            },
        },
        .{
            .assembly_wrappers = .{
                .jump = as.assembly_wrappers.jump,
                .illegal_instruction = as.assembly_wrappers.illegal_instruction,
                .wait_for_interrupt = as.assembly_wrappers.haltUntilInterrupt,
            },
            .ctx_tools = .{
                .enableInterrupts = as.assembly_wrappers.enable_x86_interrupts,
                .disableInterrupts = as.assembly_wrappers.disable_x86_interrupts,
            },
        },
    );
}

fn reportPagingInfo(logger: *io.Logger, boot_info: *const BootInfo) void {
    const virtual_pd_address = boot_info.paging.virtualPD() catch |err| {
        @panic(@errorName(err));
    };
    logger.log("******************* Paging info *******************\r\n", .{});
    defer logger.log("************ Paging info END ************\r\n\r\n", .{});
    logger.log("Probing paging information...\r\n", .{});
    logger.log("    PD Address: {*}\r\n", .{boot_info.paging.page_directory});
    logger.log("    Virt Equivalent: {*}\r\n\r\n", .{virtual_pd_address});
    logger.log("    Checking VirtToPhy mappings...\r\n", .{});

    const virt_addresses = [_]u32{
        boot_info.framebuffer.virtual_addr,
    };
    for (virt_addresses) |addr| {
        if (boot_info.paging.virtualToPhysical(addr)) |mapped| {
            logger.log(
                "    Virt address (0x{x}) maps to physical address: (0x{x})\r\n",
                .{ addr, mapped },
            );
        } else {
            logger.log("    Virt address (0x{x}) is unmapped\r\n", .{addr});
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
}

fn reportMemoryInfo(logger: *io.Logger, boot_info: *const BootInfo) void {
    logger.log("******************* Memory info *******************\r\n", .{});
    defer logger.log("************ Memory info END ************\r\n\r\n", .{});
    logger.log("Setup fn linear address: {*}\r\n", .{&setup});
    logger.log("GDT (array) linear address: {*}\r\n", .{&gdt});
    logger.log("GDT Descriptor linear address: {*}\r\n", .{&gdt_descriptor});
    logger.log("IDT (array) linear address: {*}\r\n", .{&idt});
    {
        var iter = boot_info.memory.iterator();
        logger.log("Probing Available Memory...\r\n", .{});
        logger.log("    Available Chunks: \r\n", .{});

        while (iter.next()) |chunk| {
            logger.log("        Addr: {*}\r\n", .{chunk.ptr});
            logger.log("        Len: 0x{d}\r\n\r\n", .{chunk.len});

            logger.flush();
        }
    }
}

fn reportSpecialRegInfo(logger: *io.Logger) void {
    logger.log("************** Special register info **************\r\n", .{});
    defer logger.log("******* Special register info END *******\r\n\r\n", .{});
    const cr0: as.control_registers.CR0 = as.assembly_wrappers.getCR0();
    inline for (comptime std.meta.fieldNames(@TypeOf(cr0))) |name| {
        const field = @field(cr0, name);
        if (@TypeOf(field) == bool) {
            const bit: []const u8 = if (field) "1" else "0";
            logger.log("    " ++ name ++ ": {s}\r\n", .{bit});
        }
    }
}

fn reportBootloaderInfo(logger: *io.Logger, boot_info: *const BootInfo) void {
    logger.log("***************** Bootloader info *****************\r\n", .{});
    defer logger.log("********** Bootloader info END **********\r\n\r\n", .{});
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
}

fn reportFramebufferInfo(logger: *io.Logger, boot_info: *const BootInfo) void {
    logger.log("***************** Framebuffer info *****************\r\n", .{});
    defer logger.log("********** Framebuffer info END **********\r\n\r\n", .{});

    logger.log("    Address: 0x{d}\r\n", .{boot_info.framebuffer.virtual_addr});
    logger.log("    Framebuffer Height: {d}\r\n", .{boot_info.framebuffer.height});
    logger.log("    Framebuffer Width: {d}\r\n", .{boot_info.framebuffer.width});
}

fn reportBootModuleInfo(logger: *io.Logger, boot_info: *const BootInfo) void {
    logger.log("******************* Mod info *******************\r\n", .{});
    defer logger.log("************** Mod info END **************\r\n\r\n", .{});
    var iter = boot_info.module_info.iterator();
    while (iter.next()) |mod| {
        logger.log(
            "    Module (physical) address: {*}\r\n",
            .{mod.physical_address.ptr},
        );
        logger.log(
            "    Module size: {d}B\r\n",
            .{mod.physical_address.len},
        );
        logger.log("    Module name: '{s}'\r\n", .{mod.name});
        const virt = boot_info.paging.physicalToVirtual(
            @intFromPtr(mod.physical_address.ptr),
        ) catch memory.paging.Info.MappingInfo{
            .physical_address = @intFromPtr(mod.physical_address.ptr),
            .virtual_mappings = @as([16]u32, @splat(0)),
            .map_count = 0,
        };
        for (virt.virtual_mappings[0..virt.map_count]) |mapped| {
            if (boot_info.paging.virtualToPhysical(mapped)) |phy| {
                logger.log(
                    "    Potential Module (virtual) address: 0x{x}\r\n",
                    .{mapped},
                );
                logger.log(
                    "        Proof translating back to phys: 0x{x}\r\n",
                    .{phy},
                );
            }
        }
    }
}
