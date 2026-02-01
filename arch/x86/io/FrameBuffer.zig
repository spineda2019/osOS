//! framebuffer.zig - API for providing access to a x86 framebuffer
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
const FrameBuffer = @This();

pub const FrameBufferCellColor: type = enum(u8) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGray = 7,
    DarkGray = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    LightBrown = 14,
    White = 15,
};

// memory mapped I/O for the framebuffer begins ar adress 0x000B8000
// The framebuffer's memory is split up into 16bit chunks:
// Bit:     | 15 14 13 12 11 10 9 8 | 7 6 5 4    | 3 2 1 0         |
// Content: | ASCII                 | foreground | Background      |
// The above describes a single "cell" on a 80x25 framebuffer

// Here is the table for the available colors:
// Color         | Value
// ---------------------
// Black         | 0
// Blue          | 1
// Green         | 2
// Cyan          | 3
// Red           | 4
// Magenta       | 5
// Brown         | 6
// Light Gray    | 7
// Dary Gray     | 8
// Light Blue    | 9
// Light Green   | 10
// Light Cyan    | 11
// Light Red     | 12
// Light Magenta | 13
// Light Brown   | 14
// White         | 15

/// Corresponds to top left. Other important locations:
/// 0x000B80A0: Top-Right
/// 0x000B8F00: Bottom-Left
/// 0x000B8F9E: Bottom-Right
const frame_buffer_start: u32 = 0x000B8000;

const command_port_address: u16 = 0x3D4;
const data_port_address: u16 = 0x3D5;
const high_byte_command: u8 = 14;
const low_byte_command: u8 = 15;

current_row: u8,
current_column: u8,

/// In memory buffer representation of what is on the screen. Used for
/// screen scrolling. Theoretically we could extract what character is in
/// a given cell, but this will likely be faster.
buffer: [25][80]u8,

letter_color: FrameBufferCellColor,
background_color: FrameBufferCellColor,

/// calculate the address to write in terms of an x,y coordinate.
///
/// Return type is a bare u32 for sake of math, which will be converted
/// into a volatile pointer for the actual memory mapped IO
fn calculatedAddress(row: u8, column: u8) u32 {
    const row_offset: u32 = @intCast(row);
    const column_offset: u32 = @intCast(column);
    return frame_buffer_start + (row_offset * 160) + (column_offset * 2);
}

pub fn init(
    comptime letter_color: FrameBufferCellColor,
    comptime background_color: FrameBufferCellColor,
) FrameBuffer {
    return .{
        .current_row = 0,
        .current_column = 0,
        .buffer = .{.{0} ** 80} ** 25,
        .letter_color = letter_color,
        .background_color = background_color,
    };
}

fn incrementCursorRow(self: *FrameBuffer) void {
    const next_row = position_calculation: {
        if (self.current_row >= 24) {
            // wrap around and stay in the bottom for scrolling
            break :position_calculation 24;
        } else {
            break :position_calculation self.current_row + 1;
        }
    };

    self.moveCursor(next_row, 0);
}

fn incrementCursor(self: *FrameBuffer) void {
    const next_row = position_calculation: {
        if (self.current_row >= 24) {
            // wrap around and stay in the bottom for scrolling
            break :position_calculation 24;
        } else if (self.current_column < 79) {
            break :position_calculation self.current_row;
        } else {
            break :position_calculation self.current_row + 1;
        }
    };

    const next_column = position_calculation: {
        if (self.current_column >= 79) {
            break :position_calculation 0;
        } else {
            break :position_calculation self.current_column + 1;
        }
    };

    self.moveCursor(next_row, next_column);
}

fn framebufferNewline(self: *FrameBuffer) void {
    for (self.current_column..80) |column| {
        self.buffer[self.current_row][column] = ' ';
    }
    self.incrementCursorRow();
    if (self.isBufferFull()) {
        self.scrollBuffer();
        self.flushBuffer();
    }
}

/// Exactly like write, but adds a newline and reshows the shell prompt.
pub fn writeLine(self: *FrameBuffer, buffer: []const u8) void {
    self.write(buffer);
    for (self.current_column..80) |_| {
        self.putCharacter(' ');
    }
}

/// Based zig lets us pass a safe slice and use the
/// len field rather than depend on the caller giving us the
/// write thing
pub fn write(self: *FrameBuffer, buffer: []const u8) void {
    for (buffer) |letter| {
        self.putCharacter(letter);
    }
}

fn isBufferFull(self: *FrameBuffer) bool {
    return self.current_row >= 24 and self.current_column >= 79;
}

/// Iterate through all (but the last) line in the buffer and write what
/// its contents to the frambuffer.
fn flushBuffer(self: *FrameBuffer) void {
    // Need to leave the last line empty, .. is non-right-inclusive
    for (0..24) |row| {
        for (self.buffer[row], 0..) |scrolled_letter, column| {
            writeCell(
                @truncate(row),
                @truncate(column),
                scrolled_letter,
                self.background_color,
                self.letter_color,
            );
        }
    }

    for (0..80) |column| {
        writeCell(
            24,
            @truncate(column),
            ' ',
            self.background_color,
            self.letter_color,
        );
    }
}

/// Delete first row in buffer and move all rows up one. Will leave bottom
/// row empty. This method will NOT be in charge of physically
/// moving the cursor, this only mutates our memory buffer in place.
pub fn scrollBuffer(self: *FrameBuffer) void {
    for (1..self.buffer.len) |row_num| {
        self.buffer[row_num - 1] = self.buffer[row_num];
    }
}

/// Small wrapper API around internal writeCell. Sets terminal defaults
/// and does internal bookkeeping.
pub fn putCharacter(self: *FrameBuffer, letter: u8) void {
    writeCell(
        self.current_row,
        self.current_column,
        letter,
        self.background_color,
        self.letter_color,
    );
    self.buffer[self.current_row][self.current_column] = letter;
    if (self.isBufferFull()) {
        self.scrollBuffer();
        self.flushBuffer();
    }
    self.incrementCursor();
}

/// API to write directly to the framebuffer.
fn writeCell(
    row: u8,
    column: u8,
    character: u8,
    cell_color: FrameBufferCellColor,
    letter_color: FrameBufferCellColor,
) void {
    if (row >= 25 or column >= 80) {
        return; // out of window
    }

    // Cell layout
    // Bit:     | 15 14 13 12 11 10 9 8 | 7 6 5 4 | 3 2 1 0 |
    // Content: | ASCII                 | Cell    | Letter  |
    const address_int: u32 = calculatedAddress(row, column);
    const ascii_address: *volatile u8 = @ptrFromInt(address_int);
    const metadata_address: *volatile u8 = @ptrFromInt(address_int + 1);
    metadata_address.* = (@intFromEnum(cell_color) << 4) | @intFromEnum(letter_color);
    ascii_address.* = character;

    // MMIO hackery?
    _ = asm volatile (
        \\ mov (%[ascii]), %[ret]
        : [ret] "={eax}" (-> u8),
        : [ascii] "r" (ascii_address),
    );
    _ = asm volatile (
        \\ mov (%[meta]), %[ret]
        : [ret] "={eax}" (-> u8),
        : [meta] "r" (metadata_address),
    );
}

pub fn clear(self: *FrameBuffer) void {
    self.moveCursor(0, 0);

    for (0..80) |column| {
        for (0..25) |row| {
            writeCell(
                @intCast(row),
                @intCast(column),
                ' ',
                self.background_color,
                self.letter_color,
            );
        }
    }
}

pub fn printWelcomeScreen(self: *FrameBuffer) void {
    self.clear();

    const message = comptime "Welcome to...";
    // zig doesn't have raw string literal syntax (that I know of) so the
    // logo will look weird in code.
    const logo: []const []const u8 = comptime &.{
        \\ ________  ________  ________  ________      
        ,
        \\|\   __  \|\   ____\|\   __  \|\   ____\     
        ,
        \\\ \  \|\  \ \  \___|\ \  \|\  \ \  \___|_    
        ,
        \\ \ \  \\\  \ \_____  \ \  \\\  \ \_____  \   
        ,
        \\  \ \  \\\  \|____|\  \ \  \\\  \|____|\  \  
        ,
        \\   \ \_______\____\_\  \ \_______\____\_\  \ 
        ,
        \\    \|_______|\_________\|_______|\_________\
        ,
        \\             \|_________|        \|_________|
    };

    for (0..9) |_| {
        self.writeLine("");
    }
    self.write(" " ** 32);
    self.writeLine(message);

    // needs to be inline since logo is comptime
    for (logo) |line| {
        self.write(" " ** 20);
        self.writeLine(line);
    }
}

fn moveCursor(self: *FrameBuffer, row: u8, column: u8) void {
    self.current_row = row;
    self.current_column = column;

    const position: u16 = (@as(u16, row) * 80) + @as(u16, column);
    const low_byte: u8 = @truncate(position & 0b0000_0000_1111_1111);
    const high_byte: u8 = @truncate((position >> 8) & 0b0000_0000_1111_1111);
    as.assembly_wrappers.x86_out(command_port_address, low_byte_command);
    as.assembly_wrappers.x86_out(data_port_address, low_byte);
    as.assembly_wrappers.x86_out(command_port_address, high_byte_command);
    as.assembly_wrappers.x86_out(data_port_address, high_byte);
}

const interface_impls = struct {
    /// Indirect function for use when creating the kernel Writer interface.
    /// Simply redirects to the proper framebuffer implementation
    fn opaqueWrite(opaque_self: *anyopaque, buffer: []const u8) void {
        const self: *FrameBuffer = @ptrCast(@alignCast(opaque_self));
        self.write(buffer);
    }

    fn opaquePutChar(opaque_self: *anyopaque, char: u8) void {
        const self: *FrameBuffer = @ptrCast(@alignCast(opaque_self));
        self.putCharacter(char);
    }

    fn opaqueWriteLine(opaque_self: *anyopaque, buffer: []const u8) void {
        const self: *FrameBuffer = @ptrCast(@alignCast(opaque_self));
        self.writeLine(buffer);
    }
};

test "FrameBufferAddressTranslation" {
    const std = @import("std");
    try std.testing.expectEqual(
        FrameBuffer.calculatedAddress(0, 0),
        FrameBuffer.frame_buffer_start,
    );
    try std.testing.expectEqual(
        FrameBuffer.calculatedAddress(0, 79),
        0x000B809E,
    );
    try std.testing.expectEqual(
        FrameBuffer.calculatedAddress(24, 0),
        0x000B8F00,
    );
    try std.testing.expectEqual(
        FrameBuffer.calculatedAddress(24, 79),
        0x000B8F9E,
    );
}
