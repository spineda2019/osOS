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
//!
//! kernel.zig - boot entry point for osOS on riscv32
//! This module provides the entry point of the kernel on RISC-V 32 bit systems
//! Specifically, this is currently designed for the QEMU "virt" machine

const setup: *const fn (u32, u32) callconv(.c) noreturn = &@import("setup.zig").setup;

/// Address to the top of the kernel stack
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

const PanicNamespace = @import("std").debug.FullPanic;
pub const panic = PanicNamespace(@import("setup.zig").handlePanic);

/// The entry point of our kernel. This is defined as the entry point of the
/// executable in the linker script. It's only job is to set up the stack
/// and jump to setup, which will do hardware initialization.
export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j %[setup_address]
        :
        : [stack_top] "r" (stack_top),
          [setup_address] "i" (setup),
    );
}
