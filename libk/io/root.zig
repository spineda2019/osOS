pub fn printf(writer: anytype, comptime fmt: []const u8, args: anytype) void {
    comptime {
        const args_t = @TypeOf(args);
        const args_t_info = @typeInfo(args_t);

        if (args_t_info != .@"struct") {
            const args_t_name = @typeName(args_t);
            @compileError("Expected args to be a tuple, got a " ++ args_t_name);
        }
    }

    var buffer: [512]u8 = .{0} ** 512;
    var sentinel: usize = 0;
    defer writer.write(buffer[sentinel..]);

    for (fmt) |letter| {
        switch (sentinel) {
            buffer.len => {
                writer.write(&buffer);
                buffer[0] = letter;
                sentinel = 0;
            },
            else => {
                buffer[sentinel] = letter;
                sentinel += 1;
            },
        }
    }
}

fn printValue(writer: anytype, value: anytype) void {
    const value_t = @TypeOf(value);
}
