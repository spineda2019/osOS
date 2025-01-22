//! This module contains logic for writing to the x86 framebuffer
//! (on most machines)

pub const FrameBufferCellColor: type = enum {
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGray,
    DaryGray,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    LightBrown,
    White,
};

const FrameBuffer: type = struct {
    // memory mapped I/O for the framebuffer begins ar adress 0x000B8000
    // The framebuffer's memory is split up into 16bit chunks:
    // Bit:     | 15 14 13 12 11 10 9 8 | 7 6 5 4    | 3 2 1 0         |
    // Content: | ASCII                 | foreground | Background      |

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
    frame_buffer_cell: u16,

    const frame_buffer_start: *volatile u8 = @ptrFromInt(0x000B8000);

    pub fn writeCell(
        row: u8,
        column: u8,
        character: u8,
        comptime foreground_color: FrameBufferCellColor,
        comptime background_color: FrameBufferCellColor,
    ) void {
        if (row >= 25 or column >= 80) {
            return; // out of window
        }

        // Bit:     | 15 14 13 12 11 10 9 8 | 7 6 5 4    | 3 2 1 0         |
        // Content: | ASCII                 | foreground | Background      |
        const adr: *volatile u8 = @ptrFromInt(@intFromPtr(frame_buffer_start) + (row * 80) + (column * 25));
        adr.* = (character << 8) & (colorTo4BitNumber(foreground_color) << 4) & (colorTo4BitNumber(background_color));
    }

    fn clear() void {
        for (0..80) |column| {
            for (0..25) |row| {
                writeCell(row, column, 0, FrameBufferCellColor.Black, FrameBufferCellColor.LightGray);
            }
        }
    }

    fn colorTo4BitNumber(comptime color: FrameBufferCellColor) u4 {
        return switch (color) {
            FrameBufferCellColor.Black => 0,
            FrameBufferCellColor.Blue => 1,
            FrameBufferCellColor.Green => 2,
            FrameBufferCellColor.Cyan => 3,
            FrameBufferCellColor.Red => 4,
            FrameBufferCellColor.Magenta => 5,
            FrameBufferCellColor.Brown => 6,
            FrameBufferCellColor.LightGray => 7,
            FrameBufferCellColor.DaryGray => 8,
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
