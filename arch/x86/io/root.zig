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

pub fn log(sp: *SerialPort, fp: *FrameBuffer, buf: []const u8) void {
    fp.write(buf);
    sp.write(buf);
}

pub fn logCStr(sp: *SerialPort, fp: *FrameBuffer, c_buf: [*:0]const u8) void {
    fp.writeCStr(c_buf);
    sp.writeCStr(c_buf);
}

pub fn logLine(sp: *SerialPort, fp: *FrameBuffer, buf: []const u8) void {
    fp.writeLine(buf);
    sp.write(buf);
    sp.write("\r\n");
}
pub fn logLineCStr(sp: *SerialPort, fp: *FrameBuffer, c_buf: [*:0]const u8) void {
    fp.writeLineCStr(c_buf);
    sp.writeCStr(c_buf);
    sp.write("\r\n");
}
