const std = @import("std");
const isooptions = @import("isooptions"); // TODO(SEP): delete from build.zig

const ArgError = error{
    bad_arg_count,
};

fn createDirectories(args: *const Args, io: std.Io) !void {
    var root_dir: std.Io.Dir = try std.Io.Dir.openDirAbsolute(
        io,
        args.repo_root,
        .{},
    );
    defer root_dir.close(io);

    for (args.dirs_to_create) |dir| {
        var it = std.fs.path.componentIterator(dir);
        while (it.next()) |child| {
            std.debug.print("Trying to create {s} ...\n", .{child.path});
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

fn copyFiles(args: *const Args, allocator: std.mem.Allocator, io: std.Io) !void {
    for (args.files_to_copy) |pair| {
        const source, const should_free = handle_absolute: {
            var result: []const u8 = undefined;
            var free = false;
            if (std.fs.path.isAbsolute(pair.src)) {
                // source files may be absolute if passed from a build system
                // dependency (e.g.: limine)
                result = pair.src;
            } else {
                result = try std.fs.path.join(allocator, &.{
                    args.repo_root,
                    pair.src,
                });
                free = true;
            }

            break :handle_absolute .{ result, free };
        };
        const destination = try std.fs.path.join(
            allocator,
            &.{ args.repo_root, pair.dest },
        );
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
    args: *const Args,
    allocator: std.mem.Allocator,
    io: std.Io,
) !void {
    std.debug.print(
        "Copying kernel {s} to dir {s} ...\n",
        .{ args.kernel.kernel_image_src, args.kernel.kernel_image_dest },
    );

    const destination = try std.fs.path.join(allocator, &.{
        args.repo_root,
        args.kernel.kernel_image_dest,
        std.fs.path.basename(args.kernel.kernel_image_src),
    });
    defer allocator.free(destination);
    try std.Io.Dir.copyFileAbsolute(
        args.kernel.kernel_image_src,
        destination,
        io,
        .{},
    );
}

pub fn main(init: std.process.Init) !void {
    const allocator: std.mem.Allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    const parsed: Args = try .parseArgs(args[1..], allocator);

    try createDirectories(&parsed, init.io);
    try copyFiles(&parsed, allocator, init.io);
    try copyKernel(&parsed, allocator, init.io);
}

const Args = struct {
    repo_root: []const u8,

    files_to_copy: []const CopyFiles,
    dirs_to_create: []const []const u8,

    kernel: KernelInfo,

    const CopyFiles = struct {
        src: []const u8,
        dest: []const u8,
    };

    const KernelInfo = struct {
        kernel_image_src: []const u8,
        kernel_image_dest: []const u8,
    };

    const ParseError = error{
        unexpected_flag,
        missing_flag,
        missing_value,
    };

    const Error = std.mem.Allocator.Error || ParseError;

    const ArgIter = struct {
        idx: usize = 0,
        args: []const []const u8,

        fn next(self: *ArgIter) ?[]const u8 {
            const result = self.peek();
            if (result) |_| {
                self.idx += 1;
            }
            return result;
        }

        fn peek(self: *const ArgIter) ?[]const u8 {
            if (self.idx < self.args.len) {
                return self.args[self.idx];
            } else {
                return null;
            }
        }
    };

    pub fn parseArgs(
        args: []const []const u8,
        allocator: std.mem.Allocator,
    ) Error!Args {
        const State = enum {
            search_root,
            search_kernel_info,
            search_copy,
            search_dirs,
        };
        var state: State = .search_root;

        var iter: ArgIter = .{ .args = args };
        var result: Args = .{
            .repo_root = undefined,
            .files_to_copy = &.{},
            .dirs_to_create = &.{},
            .kernel = undefined,
        };

        var copy_buf: std.ArrayList(CopyFiles) = .empty;
        var minmum_complete: bool = false;

        while (iter.next()) |arg| {
            switch (state) {
                .search_root => {
                    if (std.mem.startsWith(u8, arg, "--")) {
                        std.debug.print(
                            "Expected repo root value, found flag: {s}\n",
                            .{arg},
                        );
                        return ParseError.unexpected_flag;
                    } else {
                        result.repo_root = arg;
                        state = .search_kernel_info;
                    }
                },
                .search_kernel_info => {
                    if (std.mem.eql(u8, arg, "--kernel-src")) {
                        result.kernel = try searchKernelInfo(&iter);
                        state = .search_dirs;
                        minmum_complete = true;
                    } else {
                        std.debug.print(
                            "Expected '--kernel-src', found: {s}\n",
                            .{arg},
                        );
                        return ParseError.missing_flag;
                    }
                },
                .search_dirs => {
                    if (std.mem.eql(u8, arg, "--to-create")) {
                        result.dirs_to_create = try searchDirs(&iter, allocator);
                        state = .search_copy;
                    } else {
                        std.debug.print("Expected '--to-create', found: {s}\n", .{arg});
                        return ParseError.missing_flag;
                    }
                },
                .search_copy => {
                    if (std.mem.eql(u8, arg, "--copy")) {
                        const pair: CopyFiles = try searchCopyPair(&iter);
                        try copy_buf.append(allocator, pair);
                    } else {
                        std.debug.print("Expected '--copy', found: {s}\n", .{arg});
                        return ParseError.missing_flag;
                    }
                },
            }
        }

        result.files_to_copy = copy_buf.items;

        if (minmum_complete) {
            return result;
        } else {
            std.debug.print("Missing required repo root and kernel info\n", .{});
            return ParseError.missing_value;
        }
    }

    fn searchKernelInfo(iter: *ArgIter) ParseError!KernelInfo {
        // --kernel-src has been consumed already
        const State = enum {
            search_src,
            search_dest_flag,
            search_dest,
        };
        var info: KernelInfo = undefined;
        var state: State = .search_src;
        var complete: bool = false;

        while (iter.next()) |arg| {
            switch (state) {
                .search_src => {
                    if (std.mem.startsWith(u8, arg, "--")) {
                        std.debug.print(
                            "Expected value for '--kernel-src', found flag: {s}",
                            .{arg},
                        );
                        return ParseError.unexpected_flag;
                    } else {
                        info.kernel_image_src = arg;
                        state = .search_dest_flag;
                    }
                },
                .search_dest_flag => {
                    if (std.mem.eql(u8, arg, "--kernel-dest")) {
                        state = .search_dest;
                    } else {
                        std.debug.print("Expected '--kernel-dest', got: {s}\n", .{arg});
                        return ParseError.missing_flag;
                    }
                },
                .search_dest => {
                    if (std.mem.startsWith(u8, arg, "--")) {
                        std.debug.print(
                            "Expected value for '--kernel-dest', found flag: {s}",
                            .{arg},
                        );
                        return ParseError.unexpected_flag;
                    } else {
                        info.kernel_image_dest = arg;
                        complete = true;
                        break;
                    }
                },
            }
        }

        if (complete) {
            return info;
        } else {
            std.debug.print("Received incomplete info for kernel.\n", .{});
            return ParseError.missing_value;
        }
    }

    fn searchDirs(
        iter: *ArgIter,
        allocator: std.mem.Allocator,
    ) Error![]const []const u8 {
        // --to-create has been consumed
        var buf: std.ArrayList([]const u8) = .empty;
        errdefer buf.deinit(allocator);

        while (iter.peek()) |next| {
            if (std.mem.startsWith(u8, next, "--")) {
                @branchHint(.unlikely);
                break;
            } else {
                @branchHint(.likely);
                try buf.append(allocator, next);
                _ = iter.next();
            }
        }

        return buf.items;
    }

    fn searchCopyPair(iter: *ArgIter) ParseError!CopyFiles {
        // --copy has been consumed
        const State = enum {
            search_src,
            search_dest,
        };
        var state: State = .search_src;
        var pair: CopyFiles = undefined;
        var complete: bool = false;
        while (iter.next()) |arg| {
            switch (state) {
                .search_src => {
                    if (std.mem.startsWith(u8, arg, "--")) {
                        std.debug.print("Expected copy src, found flag: {s}\n", .{arg});
                        return ParseError.unexpected_flag;
                    } else {
                        pair.src = arg;
                        state = .search_dest;
                    }
                },
                .search_dest => {
                    if (std.mem.startsWith(u8, arg, "--")) {
                        std.debug.print("Expected copy dest, found flag: {s}\n", .{arg});
                        return ParseError.unexpected_flag;
                    } else {
                        pair.dest = arg;
                        complete = true;
                        break;
                    }
                },
            }
        }
        if (complete) {
            return pair;
        } else {
            std.debug.print("Missing values under --copy, expected a pair\n", .{});
            return ParseError.missing_value;
        }
    }
};

test Args {
    const correct_args: []const []const u8 = &.{
        "my_repo",
        "--kernel-src",
        "foo/bar",
        "--kernel-dest",
        "bar/baz",
        "--to-create",
        "a/b/",
        "c/d/",
        "--copy",
        "e/f/g.txt",
        "h/i/j.txt",
        "--copy",
        "k/l/m.txt",
        "n/o/p.txt",
    };

    var dbg_alloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = dbg_alloc.allocator();
    const parsed: Args = try .parseArgs(correct_args, allocator);

    std.debug.print("Expected: 'my_repo'\n", .{});
    std.debug.print("Actual: {s}\n\n", .{parsed.repo_root});
    try std.testing.expect(std.mem.eql(
        u8,
        parsed.repo_root,
        "my_repo",
    ));

    std.debug.print("Expected: 'foo/bar'\n", .{});
    std.debug.print("Actual: {s}\n\n", .{parsed.kernel.kernel_image_src});
    try std.testing.expect(std.mem.eql(
        u8,
        parsed.kernel.kernel_image_src,
        "foo/bar",
    ));
    std.debug.print("Expected: 'bar/baz'\n", .{});
    std.debug.print("Actual: {s}\n\n", .{parsed.kernel.kernel_image_dest});
    try std.testing.expect(std.mem.eql(
        u8,
        parsed.kernel.kernel_image_dest,
        "bar/baz",
    ));

    std.debug.print("Expected len: 2\n", .{});
    std.debug.print("Actual: {d}\n\n", .{parsed.dirs_to_create.len});
    try std.testing.expect(parsed.dirs_to_create.len == 2);
    try std.testing.expect(std.mem.eql(
        u8,
        parsed.dirs_to_create[0],
        "a/b/",
    ));
    try std.testing.expect(std.mem.eql(
        u8,
        parsed.dirs_to_create[1],
        "c/d/",
    ));

    std.debug.print("Expected len: 2\n", .{});
    std.debug.print("Actual: {d}\n\n", .{parsed.files_to_copy.len});
    try std.testing.expect(parsed.files_to_copy.len == 2);
    try std.testing.expect(std.mem.eql(
        u8,
        parsed.files_to_copy[0].src,
        "e/f/g.txt",
    ));
    try std.testing.expect(std.mem.eql(
        u8,
        parsed.files_to_copy[0].dest,
        "h/i/j.txt",
    ));
    try std.testing.expect(std.mem.eql(
        u8,
        parsed.files_to_copy[1].src,
        "k/l/m.txt",
    ));
    try std.testing.expect(std.mem.eql(
        u8,
        parsed.files_to_copy[1].dest,
        "n/o/p.txt",
    ));
}
