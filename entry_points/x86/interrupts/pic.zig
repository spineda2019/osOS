//! pic.zig - structs and utils relavent to the PIC chip
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

const as = @import("x86asm");

pub const PIC = struct {
    const master_command_port: u16 = 0x0020;
    const master_data_port: u16 = 0x0021;
    const slave_command_port: u16 = 0x00A0;
    const slave_data_port: u16 = 0x00A1;

    const pic_acknowledge: u8 = 0x20;
    const pic_initialize: u8 = 0x11;

    /// Send acknowledgement to the PIC chip that sent an interrupt request. If
    /// The slave sends a request, both the slave and master need to be
    /// acknowledged.
    pub fn sendAcknowledgement(interrupt_request: u8) void {
        if (interrupt_request >= 8) {
            // must also send ack to the slave chip
            as.assembly_wrappers.x86_out(slave_command_port, pic_acknowledge);
        }

        as.assembly_wrappers.x86_out(master_command_port, pic_acknowledge);
    }

    pub fn remap(master_offset: u32, slave_offset: u32) void {
        _ = master_offset;
        _ = slave_offset;
    }
};
