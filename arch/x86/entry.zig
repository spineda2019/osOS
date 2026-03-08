// boot.zig - Entry point for the osOS kernel on 32-bit x86
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

const physical_kernel_end: *anyopaque = @extern(
    *anyopaque,
    .{ .name = "__physical_kernel_end" },
);
const stack_top: [*]u8 = @extern([*]u8, .{ .name = "__stack_top" });

const bootutils = @import("osboot");
/// Defined in the build script
const bootoptions = @import("bootoptions");
const memory = @import("x86memory");
const as = @import("x86asm");
const osformat = @import("osformat");

/// Header to mark our kernel as bootable. Will be placed at the beginning of
/// our kernel's binary, and will be interpretted by the bootloader as the header
/// of bytes defining how the kernel will be booted.
pub export const multiboot_header linksection(".multiboot") = switch (bootoptions.boot_specification) {
    .MultibootOne => bootutils.MultiBoot.V1.init(
        .{
            .flags = .{
                .enforce_all_4kb_alignment = false,
                .include_memory_information = false,
                .include_video_mode_info = true,
                .activate_address_configurations = false,
            },
            .header_addr = undefined,
            .load_addr = undefined,
            .load_end_addr = undefined,
            .bss_end_addr = undefined,
            .entry_addr = undefined,
        },
        .{ .height = 25, .width = 80, .mode_type = .ega_text, .depth = 0 },
    ),
    else => |e| @compileError(
        "(Currently) Unsupported boot specification for x86: " ++ @tagName(e),
    ),
};

pub var kernel_page_directory: memory.paging.PageDirectory align(memory.paging.PAGE_SIZE) linksection(".pagedata") = .{
    memory.paging.PageDirectoryEntry.default,
} ** memory.paging.ENTRY_COUNT;

pub var kernel_page_table: memory.paging.PageTable align(memory.paging.PAGE_SIZE) linksection(".pagedata") = .{
    memory.paging.PageTableEntry.default,
} ** memory.paging.ENTRY_COUNT;

const PanicNamespace = @import("std").debug.FullPanic;
pub const panic = PanicNamespace(@import("setup.zig").handlePanic);

/// Entry point of our kernel. Will only setup our stack and jump to setup.
export fn boot() linksection(".boot") callconv(.naked) noreturn {
    asm volatile (
        \\    movl %[stack_top], %ESP
        \\    movl %esp, %ebp
        \\    pushl %ebx
        \\    pushl %eax
        \\    call *%[trampoline]
        : // No outputs
        : [stack_top] "i" (stack_top),
          [trampoline] "{ecx}" (&trampoline),
    );
}

fn trampoline(
    boot_magic: u32,
    mb_info: *bootutils.MultiBoot.V1.Info,
) linksection(".trampoline") callconv(.c) noreturn {
    const page_info: memory.paging.Info = .{
        .page_directory = &kernel_page_directory,
    };
    page_info.initHigherHalfPages(&kernel_page_table);
    page_info.enablePaging();

    const magic_match: bool = boot_magic == 0x2badb002;

    const setup = @import("setup.zig");
    setup.setup(.{
        .bootinfo = .{
            .name = @ptrFromInt(mb_info.boot_loader_name),
            .cmdline = if (mb_info.flags.cmdline) @ptrFromInt(mb_info.cmdline) else null,
            .valid = magic_match,
            .diagnostic = fill: {
                var buf: [80]u8 = .{0} ** 80;

                var idx: usize = 0;

                if (magic_match) {
                    const msg = "Received expected magic number 0x2badb002";

                    for (msg) |letter| {
                        if (idx < buf.len) {
                            buf[idx] = letter;
                        }

                        idx += 1;
                    }
                } else {
                    const StringFromHex = osformat.format.StringFromInt(u32, 16);
                    const received: StringFromHex = .init(boot_magic);
                    const msg = "expected 0xbadb002. Got 0x";

                    for (msg) |letter| {
                        if (idx < buf.len) {
                            buf[idx] = letter;
                        }

                        idx += 1;
                    }
                    for (received.getStr()) |letter| {
                        if (idx < buf.len) {
                            buf[idx] = letter;
                        }

                        idx += 1;
                    }
                }

                break :fill buf;
            },
        },
        .framebuffer = blk: {
            if (mb_info.flags.framebuffer) {
                break :blk .{
                    .addr = mb_info.framebuffer_addr_lower,
                    .height = mb_info.framebuffer_height,
                    .width = mb_info.framebuffer_width,
                };
            } else {
                break :blk .{
                    .addr = null,
                    .height = null,
                    .width = null,
                };
            }
        },
        .memory = .{
            .interface = mb_info.prober(),
            .len = if (mb_info.flags.mmap) mb_info.mmap_length else 0,
            .kernel_end = @intFromPtr(physical_kernel_end),
        },
        .paging = page_info,
    });
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
