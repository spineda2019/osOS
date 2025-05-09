const osformat = @import("osformat");
const kmain = @import("kmain");

pub const Terminal = struct {
    /// TODO: Don't hardcode this
    const uart_address: *volatile u8 = @ptrFromInt(0x10000000);

    buffer: [32]u8,
    internal_sentinel: u8,
    arg_sentinel: u8,

    pub fn init() Terminal {
        return .{
            .buffer = .{0} ** 32,
            .internal_sentinel = 0,
            .arg_sentinel = 0,
        };
    }

    fn putChar(char: u8) void {
        uart_address.* = char;
    }

    pub fn write(_: Terminal, contents: []const u8) void {
        for (contents) |char| {
            putChar(char);
        }
    }

    pub fn writeLine(_: Terminal, contents: []const u8) void {
        for (contents) |char| {
            putChar(char);
        }
        putChar('\n');
    }

    pub fn printf(
        self: *Terminal,
        comptime format_string: []const u8,
        args: anytype,
    ) void {
        defer self.flush();

        var flag: bool = false;
        for (format_string) |letter| {
            if (self.internal_sentinel == self.buffer.len) {
                // flush and reset ptr
                self.write(&self.buffer);
                self.internal_sentinel = 0;
            }

            switch (letter) {
                '%' => {
                    if (flag) {
                        // write only the single % literal for '%%'
                        self.buffer[self.internal_sentinel] = '%';
                        self.internal_sentinel += 1;
                    }

                    flag = !flag;
                },
                else => {
                    if (flag) {
                        self.writeValue(inline for (args, 0..) |arg, i| {
                            if (i == self.arg_sentinel) {
                                break arg;
                            }

                            break null;
                        });
                        flag = false;
                    } else {
                        self.buffer[self.internal_sentinel] = letter;
                        self.internal_sentinel += 1;
                    }
                },
            }
        }
    }

    fn writeValue(self: *Terminal, value: anytype) void {
        self.flush();
        if (value == null) {
            self.write("NULLVAL");
        }

        const nullable: bool = comptime nullable_check: {
            break :nullable_check @typeInfo(@TypeOf(value)) == .optional;
        };

        if (nullable) {
            if (value) |unwrapped| {
                switch (@typeInfo(@TypeOf(unwrapped))) {
                    .int => {
                        const converted = osformat.format.intToString(@TypeOf(unwrapped), unwrapped);
                        self.write(converted.innerSlice());
                    },
                    else => {
                        self.write("UNEXPECTED " ++ @typeName(@TypeOf(unwrapped)));
                    },
                }
            }
        } else {
            switch (@typeInfo(@TypeOf(value))) {
                .int => {
                    const converted = osformat.format.intToString(@TypeOf(value), value);
                    self.write(converted.innerSlice());
                },
                else => {
                    self.write("UNEXPECTED " ++ @typeName(@TypeOf(value)));
                },
            }
        }
    }

    fn flush(self: *Terminal) void {
        self.write(self.buffer[0..self.internal_sentinel]);
        self.internal_sentinel = 0;
    }
};

pub const SbiWriter = struct {
    buffer: [32]u8,
    internal_sentinel: u8,
    arg_sentinel: u8,

    pub fn init() SbiWriter {
        return .{
            .buffer = .{0} ** 32,
            .internal_sentinel = 0,
            .arg_sentinel = 0,
        };
    }

    pub fn isWritableType(comptime t: type) bool {
        if (t == bool) {
            return true;
        }

        return switch (@typeInfo(t)) {
            .int => true,
            .float => true,
            .pointer => true,
            else => false,
        };
    }
};
