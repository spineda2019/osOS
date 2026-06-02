const std = @import("std");
const isooptions = @import("isooptions");
const config = switch (isooptions.bootloader) {
    .grub_legacy => @import("zon/grub_legacy.zon"),
    .limine => @import("zon/limine.zon"),
};

const ArgError = error{
    bad_arg_count,
};

fn createDirectories(root: [:0]const u8, io: std.Io) !void {
    var root_dir: std.Io.Dir = try std.Io.Dir.openDirAbsolute(io, root, .{});
    defer root_dir.close(io);

    inline for (config.to_create) |dir| {
        var it = std.fs.path.componentIterator(dir);
        while (it.next()) |child| {
            std.debug.print("Creating {s} ...\n", .{child.path});
            root_dir.createDirPath(io, child.path) catch |e| {
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

fn copyFiles(root: [:0]const u8, allocator: std.mem.Allocator, io: std.Io) !void {
    inline for (config.to_copy) |pair| {
        const source, const should_free = handle_absolute: {
            var result: []const u8 = undefined;
            var free = false;
            if (std.fs.path.isAbsolute(pair.src)) {
                // source files may be absolute if passed from a build system
                // dependency (e.g.: limine)
                result = pair.src;
            } else {
                result = try std.fs.path.join(allocator, &.{ root, pair.src });
                free = true;
            }

            break :handle_absolute .{ result, free };
        };
        const destination = try std.fs.path.join(allocator, &.{ root, pair.dest });
        defer allocator.free(destination);
        defer {
            if (should_free) {
                allocator.free(source);
            }
        }
        std.debug.print("Copying {s} to {s} ...\n", .{ source, destination });
        try std.Io.Dir.copyFileAbsolute(source, destination, io, .{});
    }
}

fn copyKernel(
    root: [:0]const u8,
    kernel_path: [:0]const u8,
    allocator: std.mem.Allocator,
    io: std.Io,
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
    try std.Io.Dir.copyFileAbsolute(kernel_path, destination, io, .{});
}

pub fn main(init: std.process.Init) !void {
    const allocator: std.mem.Allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 3) {
        std.debug.print("TODO", .{});
        return ArgError.bad_arg_count;
    }

    const root = args[1];

    try createDirectories(root, init.io);
    try copyFiles(root, allocator, init.io);

    const kernel_path = args[2];
    try copyKernel(root, kernel_path, allocator, init.io);
}
