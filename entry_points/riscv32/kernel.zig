// kernel.zig - boot entry point for osOS on riscv32
// Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

//! This module provides the entry point of the kernel on RISC-V 32 bit systems
//! Specifically, this is currently designed for the QEMU "virt" machine

const riscv32 = @import("riscv32");

// The following pulls in symbols defined in the linker script

/// BSS Start
const bss = @extern([*]u8, .{ .name = "__bss" });
/// BSS End
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
/// Address to the top of the kernel stack
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });
pub const free_ram_start: [*]u8 = @extern([*]u8, .{ .name = "__free_ram" });
pub const free_ram_end: [*]u8 = @extern([*]u8, .{ .name = "__free_ram_end" });

export fn kmain() noreturn {
    const bssSize = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bssSize], 0);

    const exception_handler_address: u32 = @intFromPtr(&riscv32.exception.cpuExceptionHandler);

    asm volatile ("csrw stvec, %[exception_handler]"
        :
        : [exception_handler] "{t3}" (exception_handler_address),
    );

    riscv32.sbi.rawSbiPrint("Hello RISC-V32 osOS!\n");
    // Causing a kernel pacnic will look like this: common.panic(@src());
    // register our cpuExceptionHanlder with the stvec handler

    asm volatile ("unimp");

    while (true) {
        asm volatile ("");
    }
}

export fn boot() linksection(".text.boot") callconv(.Naked) noreturn {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kmain
        :
        : [stack_top] "r" (stack_top),
    );
}
