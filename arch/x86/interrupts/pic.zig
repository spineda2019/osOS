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
//!
//! The pic was classicly an external chip to the CPU, but in modern systems is
//! on board the chip (if I underatand correctly)

const as = @import("x86asm");
const io = @import("x86io");
const osformat = @import("osformat");
const oscontainers = @import("oscontainers");

const Self: type = @This();

pub var scan_code_buffer: oscontainers.RingBuffer(u8, 64) = .init();

const irq_offset: u8 = 0x20;
var clock_tics: usize = 0;

const master_command_port: u16 = 0x0020;
const master_data_port: u16 = 0x0021;
const slave_command_port: u16 = 0x00A0;
const slave_data_port: u16 = 0x00A1;

pub const irq = enum(u8) {
    timer = 0x20,
    keyboard = 0x21,
};

/// simple namespace to avoid magic number use
const common_messages = struct {
    const pic_acknowledge: u8 = 0x20;

    /// A "raw" initialization byte is technically 0x10, but ORing this with 0x1
    /// indicates we ae using "Cascading Mode", which gives us access to
    /// multiple chained PICs, so we'll just use 0x11 by default.
    const pic_initialize: u8 = 0x11;

    const initialize_8086_mode: u8 = 0x01;

    const masks = struct {
        const keyboard: u8 = 0b0000_0010;
        const timer: u8 = 0b0000_0001;
        const unmask_all: u8 = 0;
        const mask_all: u8 = 0b1111_1111;

        /// informs the master PIC which IRQ
        /// will be used to cascade IRQs from the slave. This wires the
        /// slave to the master via IRQ 2 (the 2nd 0-based bit is set).
        const slave_wire_on_master: u8 = 0b0000_0100;

        /// informs the slave PIC which IRQ
        /// will be used to cascade IRQs to the master. This wires the
        /// slave to the master via IRQ 2 (the number 2 in binary).
        const slave_cascade_irq: u8 = 0b0000_0010;
    };
};

/// Initialize the PIC master and slave with a predefined offset into the
/// IDT (or else the default IRQ nums will be 0-7 which conflict wity x86
/// CPU exceptions)
pub fn init() void {
    // TODO: log warn if no pic found. Right ow we assume it exists.

    // sending the initialization byte to a PIC makes it prepare for 3 more
    // (I)nitialization (C)ommand (W)ords (ICW).

    // ************************** ICW 1: Init *************************** //
    as.assembly_wrappers.x86_out(
        master_command_port,
        common_messages.pic_initialize,
    );
    io.SerialPort.ioWait();

    as.assembly_wrappers.x86_out(
        slave_command_port,
        common_messages.pic_initialize,
    );
    io.SerialPort.ioWait();

    // ************************* ICW 2: Offset ************************** //
    as.assembly_wrappers.x86_out(master_data_port, irq_offset);
    io.SerialPort.ioWait();

    as.assembly_wrappers.x86_out(slave_data_port, irq_offset + 8);
    io.SerialPort.ioWait();

    // ************** ICW 3: Cascade (Master<-Slave) Setup ************** //
    as.assembly_wrappers.x86_out(
        master_data_port,
        common_messages.masks.slave_wire_on_master,
    );
    io.SerialPort.ioWait();

    as.assembly_wrappers.x86_out(
        slave_data_port,
        common_messages.masks.slave_cascade_irq,
    );
    io.SerialPort.ioWait();

    // ************************ ICW 4: 8086 mode ************************ //
    as.assembly_wrappers.x86_out(
        master_data_port,
        common_messages.initialize_8086_mode,
    );
    io.SerialPort.ioWait();

    as.assembly_wrappers.x86_out(
        slave_data_port,
        common_messages.initialize_8086_mode,
    );
    io.SerialPort.ioWait();

    as.assembly_wrappers.x86_out(
        master_data_port,
        comptime ~(common_messages.masks.keyboard | common_messages.masks.timer),
    );
    io.SerialPort.ioWait();
    // as.assembly_wrappers.x86_out(slave_data_port, common_messages.unmask);
    as.assembly_wrappers.x86_out(slave_data_port, common_messages.masks.mask_all);
    io.SerialPort.ioWait();
}

/// Send acknowledgement to the PIC chip that sent an interrupt request. If
/// The slave sends a request, both the slave and master need to be
/// acknowledged.
fn sendAcknowledgement(interrupt_request: u8) void {
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

fn handleKeyboardIRQ() void {
    const scan_code: u8 = as.assembly_wrappers.x86_inb(0x60);
    scan_code_buffer.push(scan_code) catch {};
}

fn handleTimerIRQ() void {
    clock_tics += 1;
}

pub fn IrqHandler(comptime request_type: irq) type {
    return struct {
        pub fn handler() callconv(.naked) void {
            asm volatile (
                \\pushal
                \\pushl %[interrupt_number]
                \\call handleGenericPicIrq
                \\addl $0x4, %esp            // clean pushed interrupt number
                \\popal
                \\iret
                : // no outputs
                : [interrupt_number] "i" (@intFromEnum(request_type)),
            );
        }
    };
}

/// Jumped to from a handler stub
export fn handleGenericPicIrq(irq_with_offset: irq) callconv(.c) void {
    switch (irq_with_offset) {
        .keyboard => handleKeyboardIRQ(),
        .timer => handleTimerIRQ(),
    }
    sendAcknowledgement(@intFromEnum(irq_with_offset) - irq_offset);
}
