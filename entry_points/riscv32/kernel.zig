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

/// Common riscv32 specific API
const osprocess = @import("osprocess");

const sbi = @import("format/sbi.zig");

const exception = @import("exception.zig");

const memory = @import("memory/memory.zig");

// The following pulls in symbols defined in the linker script

/// BSS Start
const bss = @extern([*]u8, .{ .name = "__bss" });
/// BSS End
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
/// Address to the top of the kernel stack
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });
/// Defined externally by the linker script.
pub const free_ram_start: [*]u8 = @extern([*]u8, .{ .name = "__free_ram" });
/// Also defined externally by the linker script.
pub const free_ram_end: [*]u8 = @extern([*]u8, .{ .name = "__free_ram_end" });

fn delay() void {
    for (0..30000000) |_| {
        asm volatile (
            \\nop
        );
    }
}

export fn kmain() noreturn {
    const bssSize = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bssSize], 0);

    const exception_handler_address: u32 = @intFromPtr(&exception.cpuExceptionHandler);

    asm volatile ("csrw stvec, %[exception_handler]"
        :
        : [exception_handler] "{t3}" (exception_handler_address),
    );

    sbi.rawSbiPrint("Hello RISC-V32 osOS!\n");
    // Causing a kernel pacnic will look like this: common.panic(@src());
    // register our cpuExceptionHanlder with the stvec handler

    sbi.rawSbiPrint("Trying to allocate some memory...\n");
    var page_allocater: memory.PageAllocater = memory.PageAllocater.init(
        @intFromPtr(free_ram_start),
        @intFromPtr(free_ram_end),
    );

    const address_1 = page_allocater.allocate(2);
    const address_2 = page_allocater.allocate(1);

    sbi.rawSbiPrint("Mem allocation done!\n");
    sbi.printf("Address 1: %d\nAddress 2: %d\n", .{
        address_1,
        address_2,
    });

    var pool: osprocess.ProcessTable = osprocess.Process.initializePool();
    _ = &pool;

    // proc_a_entry();

    asm volatile ("unimp");

    while (true) {
        asm volatile ("");
    }
}

/// The entry point of our kernel. This is defined as the entry point of the
/// executable in the linker script. It's only job is to set up the stack
/// and jump to kmain.
export fn boot() linksection(".text.boot") callconv(.Naked) noreturn {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kmain
        :
        : [stack_top] "r" (stack_top),
    );
}
