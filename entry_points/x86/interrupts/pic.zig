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
const serial = @import("x86serial");

pub const PIC = struct {
    const master_command_port: u16 = 0x0020;
    const master_data_port: u16 = 0x0021;
    const slave_command_port: u16 = 0x00A0;
    const slave_data_port: u16 = 0x00A1;

    pub const common_messages = struct {
        const pic_acknowledge: u8 = 0x20;
        /// A "raw" initialization byte is technically 0x10, but ORing this with 0x1
        /// indicates we ae using "Cascading Mode", which gives us access to
        /// multiple chained PICs, so we'll just use 0x11 by default.
        const pic_initialize: u8 = 0x11;

        const initialize_8086_mode: u8 = 0x01;

        const unmask: u8 = 0;
    };

    /// Send acknowledgement to the PIC chip that sent an interrupt request. If
    /// The slave sends a request, both the slave and master need to be
    /// acknowledged.
    pub fn sendAcknowledgement(interrupt_request: u8) void {
        if (interrupt_request >= 8) {
            // must also send ack to the slave chip
            as.assembly_wrappers.x86_out(
                slave_command_port,
                common_messages.pic_acknowledge,
            );
        }

        as.assembly_wrappers.x86_out(
            master_command_port,
            common_messages.pic_acknowledge,
        );
    }

    pub fn remap(master_offset: u8, slave_offset: u8) void {
        // sending the initialization byte to a PIC makes it prepare for 3 more
        // (I)nitialization (C)ommand (W)ords (ICW).
        as.assembly_wrappers.x86_out(
            master_command_port,
            common_messages.pic_initialize,
        );
        serial.SerialPort.ioWait();
        as.assembly_wrappers.x86_out(
            slave_command_port,
            common_messages.pic_initialize,
        );
        serial.SerialPort.ioWait();
        // ICW 2: Offset
        as.assembly_wrappers.x86_out(master_data_port, master_offset);
        serial.SerialPort.ioWait();
        as.assembly_wrappers.x86_out(slave_data_port, slave_offset);
        serial.SerialPort.ioWait();
        // ICW 3: Cascade setup
        as.assembly_wrappers.x86_out(
            master_data_port,
            0b0000_0100, // slave at IRQ 2
        );
        serial.SerialPort.ioWait();
        as.assembly_wrappers.x86_out(
            slave_data_port,
            0b0000_0010, // tell slave its cascade identity
        );
        serial.SerialPort.ioWait();
        // ICW 4: 8086 mode
        as.assembly_wrappers.x86_out(
            master_data_port,
            common_messages.initialize_8086_mode,
        );
        serial.SerialPort.ioWait();
        as.assembly_wrappers.x86_out(
            slave_data_port,
            common_messages.initialize_8086_mode,
        );
        serial.SerialPort.ioWait();

        as.assembly_wrappers.x86_out(master_data_port, common_messages.unmask);
        serial.SerialPort.ioWait();
        as.assembly_wrappers.x86_out(slave_data_port, common_messages.unmask);
        serial.SerialPort.ioWait();
    }
};
