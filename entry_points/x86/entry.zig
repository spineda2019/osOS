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

const kmain = @import("kmain.zig").kmain;

/// Multiboot header to be placed at the beginning of our kernel binary. Must be
/// marked extern to make it exportable. Will follow the C ABI of the target
/// architecture.
const MultiBootHeader = extern struct {
    const magic_number_value: u32 = 0x1BADB002;
    magic_number: u32,
    flags: u32,
    checksum: u32,

    /// if flags[16] is set
    header_addr: u32,

    /// if flags[16] is set
    load_addr: u32,

    /// if flags[16] is set
    load_end_addr: u32,

    /// if flags[16] is set
    bss_end_addr: u32,

    /// if flags[16] is set
    entry_addr: u32,

    /// if flags[2] is set. 0 for linear graphics and 1 for EGA text mode.
    mode_type: u32,

    /// if flags[2] is set. Framebuffer width. Measured in pixels in graphics
    /// mode, or characters in text mode.
    width: u32,

    /// if flags[2] is set. Framebuffer height. Measured in pixels in graphics
    /// mode, or characters in text mode.
    height: u32,

    /// if flags[2] is set. Contains the number of bits per pixel in a graphics
    /// mode, and zero in a text mode. The value zero indicates that the OS
    /// image has no preference.
    depth: u32,

    pub fn init() MultiBootHeader {
        return .{
            .magic_number = MultiBootHeader.magic_number_value,
            .flags = 0,
            .checksum = 0 -% MultiBootHeader.magic_number_value -% @as(u32, 0),
            .header_addr = undefined,
            .load_addr = undefined,
            .load_end_addr = undefined,
            .bss_end_addr = undefined,
            .entry_addr = undefined,
            .mode_type = undefined,
            .width = undefined,
            .height = undefined,
            .depth = undefined,
        };
    }
};

/// Header to mark our kernel as bootable
export const multiboot_header linksection(".text.multiboot") = MultiBootHeader.init();

/// Offset    Type    Field Name    Note
/// 0         u32     magic         required
/// 4         u32     flags         required
/// 8         u32     checksum      required
/// 12        u32     header_addr   if flags[16] is set
/// 16        u32     load_addr     if flags[16] is set
/// 20        u32     load_end_addr if flags[16] is set
/// 24        u32     bss_end_addr  if flags[16] is set
/// 28        u32     entry_addr    if flags[16] is set
/// 32        u32     mode_type     if flags[2] is set
/// 36        u32     width         if flags[2] is set
/// 40        u32     height        if flags[2] is set
/// 44        u32     depth         if flags[2] is set
export fn boot() align(4) linksection(".text") callconv(.naked) noreturn {
    asm volatile (
        \\    # movl __stack_end, %ESP  # setup stack pointer to end of our stack
        \\                            # __stack_end symbol defined in linker
        \\                            # script
    );
    asm volatile (
        \\    jmp *%[kmain_address]
        :
        : [kmain_address] "r" (&kmain),
    );
}
