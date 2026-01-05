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

const setup: *const fn () noreturn = &@import("setup.zig").setup;

const stack_top: [*]u8 = @extern([*]u8, .{ .name = "__stack_top" });

const bootutils = @import("x86boot");

/// Defined in the build script
const bootoptions = @import("bootoptions");

/// Header to mark our kernel as bootable. Will be placed at the beginning of
/// our kernel's binary, and will be interpretted by the bootloader as the header
/// of bytes defining how the kernel will be booted.
export const multiboot_header linksection(".text.multiboot") = switch (bootoptions.boot_specification) {
    .MultibootOne => bootutils.headers.MultiBootOneHeader.defaultInit(),
    else => |e| @compileError("(Currently) Unsupported boot specification for x86: " ++ @tagName(e)),
};

const PanicNamespace = @import("std").debug.FullPanic;
pub const panic = PanicNamespace(@import("setup.zig").handlePanic);

/// Entry point of our kernel. Will only setup our stack and jump to setup.
export fn boot() linksection(".text") callconv(.naked) noreturn {
    asm volatile (
        \\    movl %[stack_top], %ESP
        \\    jmpl *%[setup_address]
        :
        : [stack_top] "i" (stack_top),
          [setup_address] "r" (setup),
    );
}
