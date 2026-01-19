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

const stack_top: [*]u8 = @extern([*]u8, .{ .name = "__stack_top" });

const bootutils = @import("osboot");

/// Defined in the build script
const bootoptions = @import("bootoptions");

const memory = @import("x86memory");
const as = @import("x86asm");

/// Header to mark our kernel as bootable. Will be placed at the beginning of
/// our kernel's binary, and will be interpretted by the bootloader as the header
/// of bytes defining how the kernel will be booted.
pub export const multiboot_header linksection(".multiboot") = switch (bootoptions.boot_specification) {
    .MultibootOne => bootutils.MultiBoot.V1.defaultInit(),
    else => |e| @compileError("(Currently) Unsupported boot specification for x86: " ++ @tagName(e)),
};

const PanicNamespace = @import("std").debug.FullPanic;
pub const panic = PanicNamespace(@import("setup.zig").handlePanic);

/// Entry point of our kernel. Will only setup our stack and jump to setup.
export fn boot() linksection(".boot") callconv(.naked) noreturn {
    asm volatile (
        \\    movl %[stack_top], %ESP
        \\    jmpl *%[trampoline]
        : // No outputs
        : [stack_top] "i" (stack_top),
          [trampoline] "r" (&trampoline),
    );
}

pub var kernel_page_directory: memory.paging.PageDirectory align(memory.paging.PAGE_SIZE) linksection(".pagedata") = .{
    memory.paging.PageDirectoryEntry.default,
} ** memory.paging.ENTRY_COUNT;

pub var kernel_page_table: memory.paging.PageTable align(memory.paging.PAGE_SIZE) linksection(".pagedata") = .{
    memory.paging.PageTableEntry.default,
} ** memory.paging.ENTRY_COUNT;

fn trampoline() linksection(".trampoline") noreturn {
    const setup = @import("setup.zig");
    // const virtual_kernel_base: u32 = 0xC0_00_00_00;
    //
    // @call(.always_inline, memory.paging.initHigherHalfPages, .{
    // &kernel_page_directory,
    // &kernel_page_table,
    // virtual_kernel_base,
    // });
    // as.assembly_wrappers.enablePaging(&kernel_page_directory);
    setup.setup();
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
