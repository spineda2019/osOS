pub fn intToString(comptime int_type: type, number: int_type) [@floor(@bitSizeOf(int_type) * 0.30103) + 1]u8 {
    if (comptime @typeInfo(int_type) != .int) {
        @compileError("Error: expected an integer type, found: " ++ @typeName(int_type));
    }

    const digit_count = @floor(@bitSizeOf(int_type) * 0.30103) + 1;
    var remainder: int_type = number;
    var buffer: [digit_count]u8 = .{0} ** digit_count;
    var ptr = buffer.len - 1;
    while (remainder > 0) : ({
        if (ptr > 0) {
            ptr -= 1;
        }
        remainder /= 10;
    }) {
        // int cast to u8 should be safe. Modulo will be 9 max.
        const digit: u8 = remainder % 10;
        buffer[ptr] = digit + 48;
    }

    return buffer;
}
