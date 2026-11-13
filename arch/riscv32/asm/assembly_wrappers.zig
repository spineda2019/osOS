//! assembly_wrappers.zig - zig API for calling RISCV32 assembly routines
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
const csr = @import("csr.zig");

pub inline fn illegal_instruction() noreturn {
    asm volatile (
        \\unimp
    );
    unreachable;
}

pub inline fn jump(address: u32) noreturn {
    asm volatile (
        \\jr %[addr]
        : // no outs
        : [addr] "r" (address),
    );
}

const sie_mask: csr.SStatus = .{
    .sie = true,
    .spie = false,
    .ube = false,
    .spp = false,
    .vs = 0,
    .fs = 0,
    .xs = 0,
    .sum = false,
    .mxr = false,
    .spelp = false,
    .sdt = false,
    .sd = false,
};

pub inline fn disableInterrupts() void {
    asm volatile (
        \\csrc sstatus, %[mask]
        : // no outs
        : [mask] "r" (sie_mask),
    );
}

pub inline fn enableInterrupts() void {
    asm volatile (
        \\csrs sstatus, %[mask]
        : // no outs
        : [mask] "r" (sie_mask),
    );
}

pub inline fn waitForInterrupt() void {
    asm volatile (
        \\wfi
    );
}
