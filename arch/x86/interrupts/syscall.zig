//! syscall.zig - root module for everything related to syscalls
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

fn syscallHandler(
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,
) callconv(.c) void {
    _ = edi;
    _ = esi;
    _ = ebp;
    _ = esp;
    _ = ebx;
    _ = edx;
    _ = ecx;
    _ = eax;
}

/// never forget gang, args are pushed right to left
///
/// `pushal` pushes args in this order
/// * EAX
/// * ECX
/// * EDX
/// * EBX
/// * ESP
/// * EBP
/// * ESI
/// * EDI
pub fn syscallIsr() callconv(.naked) noreturn {
    asm volatile (
        \\pushal
    );

    asm volatile (
        \\call *%[landing_pad]
        \\popal
        \\iret
        : // no outputs
        : [landing_pad] "r" (@intFromPtr(&syscallHandler)),
    );
}
