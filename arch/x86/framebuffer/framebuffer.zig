// framebuffer.zig - API for providing access to a x86 framebuffer
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

//! This module contains logic for writing to the x86 framebuffer
//! (on most machines)

const as = @import("x86asm");
const osformat = @import("osformat");
const kmain = @import("kmain");

pub const FrameBufferCellColor: type = enum {
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGray,
    DarkGray,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    LightBrown,
    White,

    pub fn byteValue(self: FrameBufferCellColor) u8 {
        return switch (self) {
            FrameBufferCellColor.Black => 0,
            FrameBufferCellColor.Blue => 1,
            FrameBufferCellColor.Green => 2,
            FrameBufferCellColor.Cyan => 3,
            FrameBufferCellColor.Red => 4,
            FrameBufferCellColor.Magenta => 5,
            FrameBufferCellColor.Brown => 6,
            FrameBufferCellColor.LightGray => 7,
            FrameBufferCellColor.DarkGray => 8,
            FrameBufferCellColor.LightBlue => 9,
            FrameBufferCellColor.LightGreen => 10,
            FrameBufferCellColor.LightCyan => 11,
            FrameBufferCellColor.LightRed => 12,
            FrameBufferCellColor.LightMagenta => 13,
            FrameBufferCellColor.LightBrown => 14,
            FrameBufferCellColor.White => 15,
        };
    }
};

/// For the sole purpose of adhering to the exernal API for kmain
pub const Terminal = FrameBuffer;

pub const FrameBuffer: type = struct {
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

    pub fn testFourCorners(self: *FrameBuffer) void {
        moveCursor(0, 0);
        for (0..16384) |_| {
            for (0..16384) |_| {
                asm volatile (
                    \\nop
                );
            }
        }

        moveCursor(0, 79);
        for (0..16384) |_| {
            for (0..16384) |_| {
                asm volatile (
                    \\nop
                );
            }
        }
        moveCursor(24, 0);
        for (0..16384) |_| {
            for (0..16384) |_| {
                asm volatile (
                    \\nop
                );
            }
        }
        moveCursor(24, 79);
        for (0..16384) |_| {
            for (0..16384) |_| {
                asm volatile (
                    \\nop
                );
            }
        }
        moveCursor(self.current_row, self.current_column);
    }

    /// calculate the address to write in terms of an x,y coordinate.
    ///
    /// Return type is a bare u32 for sake of math, which will be converted
    /// into a volatile pointer for the actual memory mapped IO
    fn calculatedAddress(row: u8, column: u8) u32 {
        const row_offset: u32 = @intCast(row);
        const column_offset: u32 = @intCast(column);
        return frame_buffer_start + (row_offset * 160) + (column_offset * 2);
    }

    pub fn init() FrameBuffer {
        clear(FrameBufferCellColor.LightBlue);
        printWelcomeScreen();
        for (0..16384) |_| {
            for (0..32768) |_| {
                asm volatile (
                    \\nop
                );
            }
        }

        const cursor_position = printRawPrompt();
        return .{
            .current_row = 0,
            .current_column = cursor_position,
            .buffer = .{.{0} ** 80} ** 25,
        };
    }

    fn incrementCursorRow(self: *FrameBuffer) void {
        self.current_row = position_calculation: {
            if (self.current_row >= 24) {
                // wrap around and stay in the bottom for scrolling
                break :position_calculation 24;
            } else {
                break :position_calculation self.current_row + 1;
            }
        };

        self.current_column = 0;

        moveCursor(self.current_row, self.current_column);
    }

    fn incrementCursor(self: *FrameBuffer) void {
        self.current_row = position_calculation: {
            if (self.current_row >= 24) {
                // wrap around and stay in the bottom for scrolling
                break :position_calculation 24;
            } else if (self.current_column < 79) {
                break :position_calculation self.current_row;
            } else {
                break :position_calculation self.current_row + 1;
            }
        };

        self.current_column = position_calculation: {
            if (self.current_column >= 79) {
                break :position_calculation 0;
            } else {
                break :position_calculation self.current_column + 1;
            }
        };

        moveCursor(self.current_row, self.current_column);
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
    pub fn writeln(self: *FrameBuffer, buffer: []const u8) void {
        if (self.current_column != 0) {
            self.framebufferNewline();
        }

        for ("shell> ") |letter| {
            self.putCharacter(letter);
        }
        for (buffer) |letter| {
            self.putCharacter(letter);
        }

        self.framebufferNewline();
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
                    .DarkGray,
                    .LightBrown,
                );
            }
        }

        for (0..80) |column| {
            writeCell(
                24,
                @truncate(column),
                ' ',
                .DarkGray,
                .LightBrown,
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
            .DarkGray,
            .LightBrown,
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
        comptime cell_color: FrameBufferCellColor,
        comptime letter_color: FrameBufferCellColor,
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
        metadata_address.* = comptime (cell_color.byteValue() << 4) | letter_color.byteValue();
        ascii_address.* = character;
    }

    pub fn clear(comptime background_color: FrameBufferCellColor) void {
        for (0..80) |column| {
            for (0..25) |row| {
                writeCell(
                    @intCast(row),
                    @intCast(column),
                    ' ',
                    background_color,
                    FrameBufferCellColor.LightGray,
                );
            }
        }
    }

    fn printWelcomeScreen() void {
        const message = "Welcome to...";
        // zig doesn't have raw string literal syntax (that I know of) so the
        // logo will look weird in code (for now).
        const logo = .{
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

        for (message, 33..) |letter, column| {
            writeCell(
                9, // row
                @intCast(column),
                letter,
                FrameBufferCellColor.LightBlue,
                FrameBufferCellColor.LightBrown,
            );
        }

        // since we're very carefully aligning stuff manually, just manually do
        // the prining. Rolling in a loop is not worth it if we're making it
        // look pretty
        for (logo[0], 20..) |letter, column| {
            writeCell(
                10,
                @intCast(column),
                letter,
                FrameBufferCellColor.LightBlue,
                FrameBufferCellColor.LightBrown,
            );
        }
        for (logo[1], 20..) |letter, column| {
            writeCell(
                11,
                @intCast(column),
                letter,
                FrameBufferCellColor.LightBlue,
                FrameBufferCellColor.LightBrown,
            );
        }
        for (logo[2], 20..) |letter, column| {
            writeCell(
                12,
                @intCast(column),
                letter,
                FrameBufferCellColor.LightBlue,
                FrameBufferCellColor.LightBrown,
            );
        }
        for (logo[3], 20..) |letter, column| {
            writeCell(
                13,
                @intCast(column),
                letter,
                FrameBufferCellColor.LightBlue,
                FrameBufferCellColor.LightBrown,
            );
        }
        for (logo[4], 20..) |letter, column| {
            writeCell(
                14,
                @intCast(column),
                letter,
                FrameBufferCellColor.LightBlue,
                FrameBufferCellColor.LightBrown,
            );
        }
        for (logo[5], 20..) |letter, column| {
            writeCell(
                15,
                @intCast(column),
                letter,
                FrameBufferCellColor.LightBlue,
                FrameBufferCellColor.LightBrown,
            );
        }
        for (logo[6], 20..) |letter, column| {
            writeCell(
                16,
                @intCast(column),
                letter,
                FrameBufferCellColor.LightBlue,
                FrameBufferCellColor.LightBrown,
            );
        }
        for (logo[7], 20..) |letter, column| {
            writeCell(
                17,
                @intCast(column),
                letter,
                FrameBufferCellColor.LightBlue,
                FrameBufferCellColor.LightBrown,
            );
        }
    }

    /// This doesn't display a "real" prompt, since we haven't escaped real
    /// mode yet.
    fn printRawPrompt() u8 {
        clear(FrameBufferCellColor.DarkGray);
        const message = "shell> ";
        var cursor: u8 = 0;
        for (message, 0..) |letter, column| {
            writeCell(
                0,
                @intCast(column),
                letter,
                FrameBufferCellColor.DarkGray,
                FrameBufferCellColor.LightBrown,
            );
            cursor += 1;
        }

        moveCursor(0, cursor);
        return cursor;
    }

    fn moveCursor(row: u8, column: u8) void {
        const position: u16 = (row * 80) + (column);
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
            self.writeln(buffer);
        }
    };

    pub fn writer(self: *FrameBuffer) osformat.print.Writer {
        return .{
            .instance = self,
            .vtable = &.{
                .write = &interface_impls.opaqueWrite,
            },
        };
    }

    pub fn kterminal(self: *FrameBuffer) kmain.hal.terminal.KTerminal {
        return .{
            .this = self,
            .vtable = &.{
                .putChar = &interface_impls.opaquePutChar,
                .write = &interface_impls.opaqueWrite,
                .writeLine = &interface_impls.opaqueWriteLine,
            },
        };
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
