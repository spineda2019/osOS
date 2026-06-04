const html_begin = @embedFile("index.html.begin");
const html_end = @embedFile("index.html.end");
const css = @embedFile("styles.css");
const config = @import("zon/config.zon");

const std = @import("std");

const ArgError = error{
    bad_arg_count,
};

pub fn main(init: std.process.Init) !void {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(allocator);

    if (args.len > 2) {
        std.debug.print("{}\n", .{args.len});
        return ArgError.bad_arg_count;
    }
    const root = args[1];
    std.debug.print("Root directory {s}\n", .{root});

    var install_dir = try std.Io.Dir.openDirAbsolute(init.io, root, .{});
    defer install_dir.close(init.io);
    var doc_dir = try install_dir.openDir(init.io, "docs", .{});
    defer doc_dir.close(init.io);

    var index_buf: [4096]u8 = undefined;
    var index_file = try doc_dir.createFile(init.io, "index.html", .{});
    var index_writer = index_file.writer(init.io, &index_buf);
    defer index_writer.end() catch @panic("File Writer End");

    _ = try index_writer.interface.write(html_begin);

    _ = try index_writer.interface.write(
        \\<ul>
        \\
    );

    const arches = config.arch;
    inline for (comptime std.meta.fieldNames(@TypeOf(arches))) |arch| {
        std.debug.print(
            "Processing documentation for arch: {s}\n",
            .{arch},
        );
        // NOTE: Uncomment me for debugging
        //
        // std.debug.print(
        // "\tLabel: {s}\n",
        // .{arch_doc_info.entry_module.label},
        // );
        // std.debug.print(
        // "\tIndex Path: {s}\n",
        // .{arch_doc_info.entry_module.index_path},
        // );

        const arch_doc_info = @field(arches, arch);
        _ = try index_writer.interface.write(
            \\    <li>
            \\        <a href="
        );
        _ = try index_writer.interface.write(arch_doc_info.entry_module.index_path);
        _ = try index_writer.interface.write(
            \\">
        );
        _ = try index_writer.interface.write(arch_doc_info.entry_module.label);
        _ = try index_writer.interface.write(
            \\</a>
            \\        <ul>
            \\
        );

        inline for (arch_doc_info.submodules) |submod| {
            // NOTE: Uncomment me for debugging
            //
            // std.debug.print("\tSubmodule:\n", .{});
            // std.debug.print(
            // "\t\tLabel: {s}\n",
            // .{submod.label},
            // );
            // std.debug.print(
            // "\t\tIndex Path: {s}\n",
            // .{submod.index_path},
            // );

            _ = try index_writer.interface.write(
                \\            <li><a href="
            );
            _ = try index_writer.interface.write(submod.index_path);
            _ = try index_writer.interface.write(
                \\">
            );
            _ = try index_writer.interface.write(submod.label);
            _ = try index_writer.interface.write("</a></li>\n");
        }
        _ = try index_writer.interface.write(
            \\        </ul>
            \\    </li>
            \\
        );
    }

    std.debug.print("Processing documentation for shared modules\n", .{});

    _ = try index_writer.interface.write(
        \\    <li>
        \\        CommonModules
        \\        <ul>
        \\
    );
    inline for (config.common) |common_mod| {
        // NOTE: Uncomment me for debugging
        //
        // std.debug.print("\tLabel: {s}\n", .{common_mod.label});
        // std.debug.print("\tIndex Path: {s}\n", .{common_mod.index_path});
        _ = try index_writer.interface.write(
            \\            <li><a href="
        );
        _ = try index_writer.interface.write(common_mod.index_path);
        _ = try index_writer.interface.write(
            \\">
        );
        _ = try index_writer.interface.write(common_mod.label);
        _ = try index_writer.interface.write("</a></li>\n");
    }
    _ = try index_writer.interface.write(
        \\        </ul>
        \\    </li>
        \\</ul>
        \\
    );

    _ = try index_writer.interface.write(html_end);

    var css_buf: [4096]u8 = undefined;
    var css_file = try doc_dir.createFile(init.io, "styles.css", .{});
    var css_writer = css_file.writer(init.io, &css_buf);
    defer css_writer.end() catch @panic("File Writer End");

    _ = try css_writer.interface.write(css);
}
