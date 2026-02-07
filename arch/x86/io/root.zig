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

pub const SerialPort = @import("SerialPort.zig");

pub const FrameBuffer = @import("FrameBuffer.zig");

pub const Logger = struct {
    sp: *SerialPort,
    fp: *FrameBuffer,

    pub fn log(self: Logger, buf: []const u8) void {
        self.fp.write(buf);
        self.sp.write(buf);
    }

    pub fn logCStr(self: Logger, c_buf: [*:0]const u8) void {
        self.fp.writeCStr(c_buf);
        self.sp.writeCStr(c_buf);
    }

    pub fn logLine(self: Logger, buf: []const u8) void {
        self.fp.writeLine(buf);
        self.sp.write(buf);
        self.sp.write("\r\n");
    }

    pub fn logLineCStr(self: Logger, c_buf: [*:0]const u8) void {
        self.fp.writeLineCStr(c_buf);
        self.sp.writeCStr(c_buf);
        self.sp.write("\r\n");
    }
};
