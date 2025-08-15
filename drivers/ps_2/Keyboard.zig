const Self: type = @This();

pub const ScanCode = union(enum) {
    const left_shift_down: u8 = 0x2A;
    const right_shift_down: u8 = 0x36;
    const left_shift_up: u8 = 0xAA;
    const right_shift_up: u8 = 0xB6;

    modifier: enum(u8) {
        shift_down,
        shift_up,
        caps_down,
        caps_up,
    },

    ascii_press: u8,

    /// essentially the same as ignored
    ascii_release,

    ignored,

    pub fn init(raw_scan_code: u8) ScanCode {
        return switch (raw_scan_code) {
            left_shift_down, left_shift_up, right_shift_down, right_shift_up => .{
                .modifier = .shift_down,
            },
            else => .ignored,
        };
    }
};

/// if somehow 1K of characters is pending an enter key stroke, well...
buffer: [4096]u8,

shift_down: bool,

caps_lock_on: bool,

pub fn init() Self {
    return .{
        .buffer = .{0} ** 4096,
        .shift_down = false,
        .caps_lock_on = false,
    };
}

pub fn press(self: *Self, scan_code: ScanCode) void {}
