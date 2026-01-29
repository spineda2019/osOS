const std = @import("std");
const isooptions = @import("isooptions");
const config = switch (isooptions.bootloader) {
    .grub_legacy => @import("zon/grub_legacy.zon"),
    .limine => @compileError("TODO: Support Limine"),
};

const ArgError = error{
    bad_arg_count,
};

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const allocator: std.mem.Allocator = debug_allocator.allocator();
    defer _ = debug_allocator.deinit();

    const args: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("TODO", .{});
        return ArgError.bad_arg_count;
    }

    const root = args[1];
    const kernel_path = args[2];

    std.debug.print("Files relative to {s}\n", .{root});

    inline for (config.to_create) |dir| {
        std.debug.print("Must create {s}\n", .{dir});
    }

    inline for (config.to_copy) |pair| {
        std.debug.print("Must copy {s} to {s}\n", .{ pair.src, pair.dest });
    }

    std.debug.print(
        "Must copy {s} to dir {s}\n",
        .{ kernel_path, config.kernel_destination },
    );
}
