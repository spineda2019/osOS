pub const console = struct {
    pub fn readLine() []const u8 {
        @panic("TODO");
    }

    pub fn writeLine(buf: []const u8) void {
        write(buf);
        write("\n");
    }

    pub fn write(buf: []const u8) void {
        _ = buf;
    }
};
