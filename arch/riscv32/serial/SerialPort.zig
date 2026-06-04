const osformat = @import("osformat");
const SerialPort = @This();

pub fn writer(self: *SerialPort, buffer: []u8) osformat.IWriter {
    return .{
        .buffer = buffer,
        .instance = self,
        .sentinel = 0,
        .vtable = &.{
            .write = &struct {
                fn impl(opaque_self: *anyopaque, buf: []const u8) void {
                    const concrete_self: *SerialPort = @ptrCast(@alignCast(opaque_self));
                    _ = concrete_self;
                    _ = buf;
                }
            }.impl,
        },
    };
}
