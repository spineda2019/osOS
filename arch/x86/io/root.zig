//! API for providing access to a x86 IO, such as the framebuffer and serial
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

pub const FrameBuffer = @import("FrameBuffer.zig");

pub const SerialPort = @import("SerialPort.zig");

const IWriter = @import("osformat").IWriter;

pub const Logger = struct {
    serial_port_writer: *IWriter,
    framebuffer_writer: *IWriter,

    pub fn log(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.framebuffer_writer.writef(format, args);
        self.serial_port_writer.writef(format, args);
    }

    pub fn flush(self: *Logger) void {
        self.framebuffer_writer.flush();
        self.serial_port_writer.flush();
    }
};
