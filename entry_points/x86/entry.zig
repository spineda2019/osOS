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

const kmain: *const fn () noreturn = &@import("kmain.zig").kmain;

const stack_top: [*]u8 = @extern([*]u8, .{ .name = "__stack_top" });

const bootutils = @import("x86boot");

/// Header to mark our kernel as bootable. Will be placed at the beginning of
/// our kernel's binary, and will be interpretted by the bootloader as the header
/// of bytes defining how the kernel will be booted.
export const multiboot_header linksection(".text.multiboot") = bootutils.headers.MultiBootOneHeader.init();

/// Entry point of our kernel. Will only setup our stack and jump to main.
export fn boot() linksection(".text") callconv(.naked) noreturn {
    asm volatile (
        \\    movl %[stack_top], %ESP
        \\    jmpl *%[kmain_address]
        :
        : [stack_top] "i" (stack_top),
          [kmain_address] "r" (kmain),
    );
}
