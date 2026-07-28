const syscall_table = @import("syscall_table");
const std = @import("std");

pub fn syscallNum(comptime name: []const u8) comptime_int {
    for (syscall_table) |syscall| {
        if (std.mem.eql(u8, name, syscall.name)) {
            return syscall.number;
        }
    }

    @compileError("Could not find syscall number for syscall: " ++ name);
}
