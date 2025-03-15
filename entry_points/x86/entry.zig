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

/// Defined in the linker script. Used to initialize Stack Pointer from memory
/// defined in bss.
const stack_end: [*]u8 = @extern([*]u8, .{ .name = "__stack_end" });

export fn boot() align(4) linksection(".text") callconv(.Naked) noreturn {
    asm volatile (
        \\.equ MAGIC_NUMBER,      0x1BADB002
        \\.equ FLAGS,             0x0
        \\.equ CHECKSUM,          -MAGIC_NUMBER
        \\.equ KERNEL_STACK_SIZE, 4096
        \\
        \\    .long MAGIC_NUMBER
        \\    .long FLAGS
        \\    .long CHECKSUM
        \\    movl __stack_end, %ESP  # setup stack pointer to end of kernel_stack
        \\
    );
    asm volatile (
        \\    jmp *%[kmain_address]
        :
        : [kmain_address] "r" (&kmain),
    );
}
