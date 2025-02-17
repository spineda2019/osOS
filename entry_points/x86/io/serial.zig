// serial.zig - API for providing access to x86 serial ports
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

//! This module contains logic for writing to x86 serial ports

const as = @import("x86asm");

/// The value of COM1
const com1_base: u16 = 0x3F8;

fn calculateFIFOCommandPort(comptime basePort: u16) u16 {
    return basePort + 2;
}

fn calculateLineCommandPort(comptime basePort: u16) u16 {
    return basePort + 3;
}

fn calculateModemCommandPort(comptime basePort: u16) u16 {
    return basePort + 4;
}

fn calculateLineStatusPort(comptime basePort: u16) u16 {
    return basePort + 5;
}

// Tells the serial port to expect first the highest 8 bits on the data port,
// then the lowest 8 bits will follow
const serial_line_enable_dlab: u16 = 0x80;

/// Configure the baud rate of the serial port by sending a divisor.
///
/// Here, the serial port has an internal clock. The divisor (1, 2, 3, etc)
/// indicates how to divide this clock speed, essentially setting up the speed
/// of a singular message we'll send.
pub fn configureBaudRate(port: u16, divisor: u16) void {
    // specify to expect high bits then low bits (can only send 8 bits at a time)
    as.assembly_wrappers.x86_out(port + 3, serial_line_enable_dlab);
    as.assembly_wrappers.x86_out(port, divisor >> 8); // high 8 bits
    as.assembly_wrappers.x86_out(port, divisor & 0b0000_0000_1111_1111); // low
}

/// Configured with a byte:
///
/// Layout of configuration byte by bit:
///
///  ___________________________________________________________________________
/// |      7      |      6       |      5 4 3      |       2      |     1 0    |
/// | Enable DLAB | Enable Break | Parity Bit Num  | Stop Bit Num | datalength |
pub fn configureLine(port: u16) void {
    // Length of 8 bits, disable everything else and use no parity or stop bits
    as.assembly_wrappers.x86_out(port + 3, 0b0_0_000_0_11);
}

/// Check if the FIFO buffer for a serial port is free
///
/// Bit 5 of the read data (using "in") will be set to 1 if the buffer is ready
pub fn isFIFOClear(port: u16) bool {
    return as.assembly_wrappers.x86_inb(port) & 0b0010_0000 > 0;
}

fn init() void {
    const fifo_config: u8 = 0xC7;
    const modem_config: u8 = 0x03;
    as.assembly_wrappers.x86_out(com1_base + 2, fifo_config);
    as.assembly_wrappers.x86_out(com1_base + 4, modem_config);
}

pub fn write(buffer: []const u8) void {
    init();
    while (!isFIFOClear(com1_base)) {
        asm volatile (
            \\nop
        );
    }
    for (buffer) |letter| {
        as.assembly_wrappers.x86_out(com1_base, letter);
    }
}
