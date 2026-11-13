const std = @import("std");

const ParserError = error{
    unrecognized_flag,
    unexpected_flag,
    missing_required_flag,
};

const IOError = std.Io.Dir.OpenError || std.Io.Dir.CopyFileError || std.Io.Writer.Error;

const Error = std.process.Args.ToSliceError || ParserError || IOError;

pub fn main(init: std.process.Init) Error!void {
    const allocator = init.arena.allocator();
    const all_args: []const [:0]const u8 = try init.minimal.args.toSlice(allocator);
    std.debug.assert(all_args.len >= 1);
    const info: Config = try parseArgs(all_args[1..]);

    switch (info) {
        .default => |def| {
            try copyFile(init.io, &def);
        },
        .custom => |rom_info| {
            try buildFile(init.io, &rom_info);
        },
    }
}

fn copyFile(
    io: std.Io,
    def: *const DefaultConfig,
) std.Io.Dir.CopyFileError!void {
    const cwd: std.Io.Dir = .cwd();

    const dest_dir: std.Io.Dir = try cwd.openDir(io, def.dest_dir, .{});
    defer dest_dir.close(io);
    try cwd.copyFile(def.source, dest_dir, "bochs.config", io, .{});
}

fn buildFile(
    io: std.Io,
    rom_info: *const RomInfo,
) IOError!void {
    const cwd: std.Io.Dir = .cwd();

    const dest_dir: std.Io.Dir = try cwd.openDir(io, rom_info.dest_dir, .{});
    defer dest_dir.close(io);

    const custom_file = try dest_dir.createFile(io, "bochs.config", .{});
    defer custom_file.close(io);

    var write_buf: [512]u8 = undefined;
    var file_writer = custom_file.writer(io, &write_buf);
    var writer = &file_writer.interface;

    try writer.writeAll("megs: 32\n");

    try writer.writeAll("display_library: sdl2\n");

    try writer.writeAll("romimage: file=");
    try writer.writeAll(rom_info.romimage);
    try writer.writeAll("\n");

    try writer.writeAll("vgaromimage: file=");
    try writer.writeAll(rom_info.vgaromimage);
    try writer.writeAll("\n");

    try writer.writeAll("ata0-master: type=cdrom, path=zig-out/x86/osOS.iso, status=inserted\n");
    try writer.writeAll("boot: cdrom\n");
    try writer.writeAll("log: bochslog.txt\n");
    try writer.writeAll("clock: sync=realtime, time0=local\n");
    try writer.writeAll("cpu: count=1, ips=1000000\n");
    try writer.writeAll("com1: enabled=1, mode=file, dev=com1.out\n");

    try writer.flush();
}

fn parseArgs(args: []const []const u8) ParserError!Config {
    const Args = struct {
        default_config: ?[]const u8,
        romimage: ?[]const u8,
        vgaromimage: ?[]const u8,
        dest_dir: []const u8,
    };

    // args must come in pairs
    std.debug.assert(args.len % 2 == 0);

    var final: Args = .{
        .default_config = null,
        .romimage = null,
        .vgaromimage = null,
        .dest_dir = undefined,
    };
    var dest_dir_found: bool = false;

    var iter: Iterator = .{ .view = args };

    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--default_config")) {
            const val: []const u8 = iter.next() orelse unreachable;
            if (std.mem.startsWith(u8, val, "--")) {
                std.debug.print("Expected value, got unexpected flag: '{s}'\n", .{val});
                return ParserError.unexpected_flag;
            } else {
                final.default_config = val;
            }
        } else if (std.mem.eql(u8, arg, "--romimage")) {
            const val: []const u8 = iter.next() orelse unreachable;
            if (std.mem.startsWith(u8, val, "--")) {
                std.debug.print("Expected value, got unexpected flag: '{s}'\n", .{val});
                return ParserError.unexpected_flag;
            } else {
                final.romimage = val;
            }
        } else if (std.mem.eql(u8, arg, "--vgaromimage")) {
            const val: []const u8 = iter.next() orelse unreachable;
            if (std.mem.startsWith(u8, val, "--")) {
                std.debug.print("Expected value, got unexpected flag: '{s}'\n", .{val});
                return ParserError.unexpected_flag;
            } else {
                final.vgaromimage = val;
            }
        } else if (std.mem.eql(u8, arg, "--dest_dir")) {
            const val: []const u8 = iter.next() orelse unreachable;
            if (std.mem.startsWith(u8, val, "--")) {
                std.debug.print("Expected value, got unexpected flag: '{s}'\n", .{val});
                return ParserError.unexpected_flag;
            } else {
                final.dest_dir = val;
                dest_dir_found = true;
            }
        } else {
            std.debug.print("Unrecognized arg: '{s}'\n", .{arg});
            return ParserError.unrecognized_flag;
        }
    }

    if (!dest_dir_found) {
        std.debug.print("Missing required flag: '--dest-dir'\n", .{});
        return ParserError.missing_required_flag;
    } else {
        if (final.romimage) |rom| {
            if (final.vgaromimage) |vga| {
                return .{
                    .custom = .{
                        .romimage = rom,
                        .vgaromimage = vga,
                        .dest_dir = final.dest_dir,
                    },
                };
            } else if (final.default_config) |default| {
                return .{
                    .default = .{ .source = default, .dest_dir = final.dest_dir },
                };
            } else {
                std.debug.print("Need to specify at least a default config, or rom info\n", .{});
                return ParserError.missing_required_flag;
            }
        } else if (final.default_config) |default| {
            return .{
                .default = .{ .source = default, .dest_dir = final.dest_dir },
            };
        } else {
            std.debug.print("Need to specify at least a default config, or rom info\n", .{});
            return ParserError.missing_required_flag;
        }
    }
}

test parseArgs {
    const arg_set_1 = [_][]const u8{
        "--dest_dir",
        "my_cool_dest",
        "--default_config",
        "my_cool_config",
    };
    const parsed_1 = try parseArgs(&arg_set_1);
    switch (parsed_1) {
        .custom => {
            std.debug.print("Expected a '{s}', got a '{s}'\n", .{
                @typeName(DefaultConfig),
                @typeName(RomInfo),
            });
            try std.testing.expect(false);
        },
        .default => |def| {
            try std.testing.expect(std.mem.eql(u8, def.dest_dir, "my_cool_dest"));
            try std.testing.expect(std.mem.eql(u8, def.source, "my_cool_config"));
        },
    }

    const arg_set_2 = [_][]const u8{
        "--dest_dir",
        "my_cool_dest",
        "--default_config",
        "my_cool_config",
        "--vgaromimage",
        "my_vga_rom",
    };
    const parsed_2 = try parseArgs(&arg_set_2);
    switch (parsed_2) {
        .custom => {
            std.debug.print("Expected a '{s}', got a '{s}'\n", .{
                @typeName(DefaultConfig),
                @typeName(RomInfo),
            });
            try std.testing.expect(false);
        },
        .default => |def| {
            try std.testing.expect(std.mem.eql(u8, def.dest_dir, "my_cool_dest"));
            try std.testing.expect(std.mem.eql(u8, def.source, "my_cool_config"));
        },
    }

    const arg_set_3 = [_][]const u8{
        "--dest_dir",
        "my_cool_dest",
        "--default_config",
        "my_cool_config",
        "--vgaromimage",
        "my_vga_rom",
        "--romimage",
        "my_rom",
    };
    const parsed_3 = try parseArgs(&arg_set_3);
    switch (parsed_3) {
        .default => {
            std.debug.print("Expected a '{s}', got a '{s}'\n", .{
                @typeName(RomInfo),
                @typeName(DefaultConfig),
            });
            try std.testing.expect(false);
        },
        .custom => |rom_info| {
            try std.testing.expect(std.mem.eql(u8, rom_info.dest_dir, "my_cool_dest"));
            try std.testing.expect(std.mem.eql(u8, rom_info.vgaromimage, "my_vga_rom"));
            try std.testing.expect(std.mem.eql(u8, rom_info.romimage, "my_rom"));
        },
    }
}

// easier to mock up for test
const Iterator = struct {
    idx: u32 = 0,
    view: []const []const u8,

    fn next(self: *Iterator) ?[]const u8 {
        const peeked = self.peek();
        if (peeked) |_| {
            self.idx += 1;
        }
        return peeked;
    }

    fn peek(self: *const Iterator) ?[]const u8 {
        if (self.idx >= self.view.len) {
            @branchHint(.unlikely);
            return null;
        } else {
            @branchHint(.likely);
            return self.view[self.idx];
        }
    }
};

const RomInfo = struct {
    romimage: []const u8,
    vgaromimage: []const u8,
    dest_dir: []const u8,
};

const DefaultConfig = struct {
    source: []const u8,
    dest_dir: []const u8,
};

const Config = union(enum) {
    default: DefaultConfig,
    custom: RomInfo,
};
