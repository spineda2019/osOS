pub const KTerminal = struct {
    /// Pointer to the instance implementing the KTerminal interface
    this: *anyopaque,

    /// Table to runtime determined implementation of this instance
    vtable: *const VTable,

    pub const VTable = struct {
        putChar: *const fn (self: *anyopaque, char: u8) void,

        write: *const fn (self: *anyopaque, contents: []const u8) void,

        writeLine: *const fn (self: *anyopaque, contents: []const u8) void,
    };

    pub fn writeLine(self: KTerminal, buffer: []const u8) void {
        self.vtable.writeLine(self.this, buffer);
    }

    pub fn write(self: KTerminal, buffer: []const u8) void {
        self.vtable.write(self.this, buffer);
    }
};
