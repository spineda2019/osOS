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
        \\outb %[data], %[port_address]
        : // no outputs
        : [port_address] "{dx}" (port_address),
          [data] "{al}" (data),
        : .{ .memory = true });
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
        : [table_address] "r" (table_address),
    );
}

/// Wrapper for the x86 LIDT instruction, which is used to (L)oad the
/// (I)nterrupt (D)escriptor (T)able. This has the following syntax:
///
/// lidt [REGISTER]
///
/// Where the REGISTER has the address of the table (the brackets in x86) will
/// cause a lookup in RAM to this address, and feed that to the lgdt instruction
pub inline fn x86_lidt(table_address: u32) void {
    asm volatile (
        \\lidtl (%[table_address])
        :
        : [table_address] "r" (table_address),
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

/// Enable SSE instructions on the CPU, including use of the xmm# registers
/// and their various SIMD capabilities.
///
/// To do this, the CR0 and CR4 registers need to be altered:
///
/// CR0: The EM (x87 FPU Emulation) bit (bit 2) must be cleared and the MP
/// (Monitor Processor) bit (bit 1) must be set.
///
/// CR4: The OSFXR (Operating system support for FXSAVE and FXRSTOR
/// instructions) bit (bit 9) and OSXMMEXCPT (Operating System Support for
/// Unmasked SIMD Floating-Point Exceptions) bit (10) must both be set.
///
/// Note: CR0 register is 32 bits wide, CR4 is 25 bits wide.
pub noinline fn enableSSE() void {
    asm volatile (
        \\mov %cr0, %eax
        \\and 0xFFFB, %ax # clear coprocessor emulation CR0.EM
        \\                # 0x FFFB is all 1s except bit 2
        \\or 0b10, %ax    # set coprocessor monitoring  CR0.MP
        \\mov %eax, %cr0  # Store back CR0
        \\mov %cr4, %eax
        \\or $0b0000000000000001000000000, %ax      # set CR4.OSFXSR (bit 9)
        \\or $0b0000000000000010000000000, %ax      # set CR4.OSXMMEXCPT (bit 10)
        \\mov %eax, %cr4  # Store back CR4
    );
}

pub inline fn illegal_instruction() void {}

pub inline fn enablePaging(pd: *anyopaque) void {
    asm volatile (
        \\mov %[pd_address], %cr3
        \\mov %cr0, %eax
        \\or 0x80000001, %eax
        \\mov %eax, %cr0
        : // no outputs
        : [pd_address] "r" (pd),
    );
}
