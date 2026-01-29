const std = @import("std");
const isooptions = @import("isooptions");
const config = switch (isooptions.bootloader) {
    .grub_legacy => @import("zon/grub_legacy.zon"),
    .limine => @compileError("TODO: Support Limine"),
};

const ArgError = error{
    bad_arg_count,
};

fn createDirectories(root: [:0]const u8, allocator: std.mem.Allocator) !void {
    inline for (config.to_create) |dir| {
        const destination = try std.fs.path.join(allocator, &.{ root, dir });
        defer allocator.free(destination);
        std.debug.print("Creating {s} ...\n", .{destination});
    }
}

fn copyFiles(root: [:0]const u8, allocator: std.mem.Allocator) !void {
    inline for (config.to_copy) |pair| {
        const source = try std.fs.path.join(allocator, &.{ root, pair.src });
        const destination = try std.fs.path.join(allocator, &.{ root, pair.dest });
        defer allocator.free(destination);
        defer allocator.free(source);
        std.debug.print("Copying {s} to {s} ...\n", .{ source, destination });
    }
}

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

    try createDirectories(root, allocator);
    try copyFiles(root, allocator);

    std.debug.print(
        "Must copy {s} to dir {s}\n",
        .{ kernel_path, config.kernel_destination },
    );
}
