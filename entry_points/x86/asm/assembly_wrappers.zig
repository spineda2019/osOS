// assembly_wrappers.zig - zig API for calling x86 assembly routines
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

/// Zig wrapper for the x86 "out" instruction
///
/// In x86, the "out" instruction send a byte to an IO port at a specific
/// address. It has the following syntax:
///
/// out REGISTER, REGISTER
///
/// Where the first register is the address of the IO port, and the second is
/// the data byte to send to that port.
///
/// Since this is a wrapper for an inline assembly call, this should be
/// inline
pub inline fn x86_out(port_address: u16, data: u8) void {
    asm volatile (
    // move the data (src) to address. Curse backwards AT&T syntax
        \\outb %[data], %[port_address]
        :
        : [port_address] "{dx}" (port_address),
          [data] "{al}" (data),
    );
}
