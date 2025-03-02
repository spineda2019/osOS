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
pub inline fn x86_out(port_address: u16, data: anytype) void {
    const instruction: *const [4]u8 = comptime bit_width_calc: {
        const data_type: type = @TypeOf(data);
        if (@typeInfo(data_type) != .int) {
            const msg = "Invalid integer type: " ++ @typeName(data_type);
            @compileError(msg);
        }

        break :bit_width_calc switch (@bitSizeOf(data_type)) {
            // switch ranges are inclusive on both end
            1...8 => "outb",
            9...16 => "outw",
            17...32 => "outl",
            else => {
                @compileError(
                    "Invalid integer size: " ++ @typeName(data_type),
                );
            },
        };
    };

    asm volatile (
    // move the data (src) to address. Curse backwards AT&T syntax
        instruction ++
            \\ %[data], %[port_address]
        :
        : [port_address] "{dx}" (port_address),
          [data] "{al}" (data),
        : "memory"
    );
}

/// Zig wrapper for the x86 "in" instruction
///
/// In x86, the "in" instruction reads a byte from an IO port at a specific
/// address. It has the following syntax:
///
/// in REGISTER, REGISTER
///
/// Where the first register is the address of the IO port to read from, and
/// the second register specifies where the read data will be placed
///
/// Since this is a wrapper for an inline assembly call, this should be
/// inline
pub inline fn x86_inb(port_address: u16) u8 {
    return asm volatile (
        \\inb %[port_address], %[ret]
        : [ret] "={al}" (-> u8),
        : [port_address] "{dx}" (port_address),
    );
}

/// Wrapper for the x86 LGDT instruction, which is used to (L)oad the (G)lobal
/// (D)escriptor (T)able. This has the following syntax:
///
/// lgdt [REGISTER]
///
/// Where the REGISTER has the address of the table (the brackets in x86) will
/// cause a lookup in RAM to this address, and feed that to the lgdt instruction
pub inline fn x86_lgdt(table_address: u32) void {
    asm volatile (
        \\lgdtl (%[table_address])
        :
        : [table_address] "{eax}" (table_address),
    );
}

pub inline fn disable_x86_interrupts() void {
    asm volatile (
        \\cli
    );
}

pub inline fn enable_x86_interrupts() void {
    asm volatile (
        \\sti
    );
}
