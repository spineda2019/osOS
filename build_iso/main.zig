const std = @import("std");
const isooptions = @import("isooptions");
const config = switch (isooptions.bootloader) {
    .grub_legacy => @import("zon/grub_legacy.zon"),
    .limine => @compileError("TODO: Support Limine"),
};

const ArgError = error{
    bad_arg_count,
};

fn createDirectories(root: [:0]const u8) !void {
    var root_dir: std.fs.Dir = try std.fs.openDirAbsolute(root, .{});
    defer root_dir.close();

    inline for (config.to_create) |dir| {
        var it = try std.fs.path.componentIterator(dir);
        while (it.next()) |child| {
            std.debug.print("Creating {s} ...\n", .{child.path});
            root_dir.makeDir(child.path) catch |e| {
                switch (e) {
                    error.PathAlreadyExists => {
                        std.debug.print("{s} already exists!\n", .{child.path});
                    },
                    else => |other| return other,
                }
            };
        }
    }
}

fn copyFiles(root: [:0]const u8, allocator: std.mem.Allocator) !void {
    inline for (config.to_copy) |pair| {
        const source = try std.fs.path.join(allocator, &.{ root, pair.src });
        const destination = try std.fs.path.join(allocator, &.{ root, pair.dest });
        defer allocator.free(destination);
        defer allocator.free(source);
        std.debug.print("Copying {s} to {s} ...\n", .{ source, destination });
        try std.fs.copyFileAbsolute(source, destination, .{});
    }
}

fn copyKernel(
    root: [:0]const u8,
    kernel_path: [:0]const u8,
    allocator: std.mem.Allocator,
) !void {
    std.debug.print(
        "Copying kernel {s} to dir {s} ...\n",
        .{ kernel_path, config.kernel_destination },
    );

    const destination = try std.fs.path.join(allocator, &.{
        root,
        config.kernel_destination,
        std.fs.path.basename(kernel_path),
    });
    defer allocator.free(destination);
    try std.fs.copyFileAbsolute(kernel_path, destination, .{});
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

    try createDirectories(root);
    try copyFiles(root, allocator);

    const kernel_path = args[2];
    try copyKernel(root, kernel_path, allocator);
}
