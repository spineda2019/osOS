const std = @import("std");

const ProgramError = error{
    invalid_arg_count,
};

pub fn main() !void {
    const dbg_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = dbg_allocator.deinit();
    const allocator: std.mem.Allocator = dbg_allocator.allocator();

    const args: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.debug.print("Unexpected arg count, expected 2, got {}\n", .{args.len});
        return ProgramError.invalid_arg_count;
    }

    std.debug.print("\n", .{args[0]});
    std.debug.print("\n", .{args[1]});
}
