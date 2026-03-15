//! IWriter.zig - Kernel Writer interface
//! Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.

const osformat = @import("root.zig");

instance: *anyopaque,
vtable: *const VTable,
buffer: []u8,
sentinel: usize,

const IWriter = @This();
const Error = error{};

const FormatSpecifier = union(enum) {
    fn init(char: u8) FormatSpecifier {
        return switch (char) {
            's' => .{ .slice = void{} },
            'x', 'd' => |base| switch (base) {
                'x' => .{ .number_with_base = 16 },
                'd' => .{ .number_with_base = 10 },
                else => @compileError("Unrecognized numeric base specifier: " ++ base),
            },
            '*' => .{ .address = void{} },
            else => @compileError("Unrecognized format specifier: " ++ char),
        };
    }

    slice: void,
    address: void,
    number_with_base: comptime_int,
};

pub fn writef(self: *IWriter, comptime format: []const u8, args: anytype) !void {
    const State = enum {
        start,
        open_brace,
        close_brace,
    };
    comptime var start_index: usize = 0;
    comptime var state = State.start;
    comptime var next_arg: usize = 0;
    comptime var format_spec: FormatSpecifier = undefined;

    // TODO(SEP): Does this need to be inline?
    inline for (format, 0..) |c, i| {
        switch (state) {
            State.start => switch (c) {
                '{' => {
                    if (start_index < i) {
                        self.fillBuf(format[start_index..i]);
                    }
                    state = State.open_brace;
                },
                '}' => {
                    if (start_index < i) {
                        self.fillBuf(format[start_index..i]);
                    }
                    state = State.close_brace;
                },
                else => {},
            },
            State.open_brace => switch (c) {
                '{' => {
                    state = State.start;
                    start_index = i;
                },
                '}' => {
                    self.writeValue(args[next_arg], format_spec);
                    next_arg += 1;
                    state = State.start;
                    start_index = i + 1;
                },
                else => |char| {
                    format_spec = .init(char);
                },
            },
            State.close_brace => switch (c) {
                '}' => {
                    state = State.start;
                    start_index = i;
                },
                else => @compileError("Single '}' encountered in format string"),
            },
        }
    }

    comptime {
        if (args.len != next_arg) {
            @compileError("Unused arguments");
        }
        if (state != State.start) {
            @compileError("Incomplete format string: " ++ format);
        }
    }

    if (start_index < format.len) {
        self.fillBuf(format[start_index..format.len]);
    }
}

fn writeValue(
    self: *IWriter,
    comptime arg: anytype,
    comptime spec: FormatSpecifier,
) void {
    const T = comptime @TypeOf(arg);
    const type_info = comptime @typeInfo(T);
    const errors = struct {
        fn badArgHelper() []const u8 {
            var message: []const u8 = "Invalid type \"";
            message = message ++ @typeName(T) ++ "\" with type info \"";
            message = message ++ @tagName(type_info) ++ "\" for specifier: ";
            message = message ++ @tagName(spec);

            return message;
        }

        const bad_arg_type = badArgHelper();
        const slice_ptr = "Expected slice for tag " ++ @tagName(spec) ++ " but received " ++ @typeName(T);
    };

    switch (spec) {
        .slice => {
            switch (type_info) {
                .pointer => |ptr_info| {
                    switch (ptr_info.size) {
                        .slice => {
                            self.fillBuf(arg);
                        },
                        .one => {
                            @compileError(errors.slice_ptr);
                        },
                        else => |ptr_type| {
                            @compileError("TODO for ptr: " ++ @tagName(ptr_type));
                        },
                    }
                },
                else => {
                    @compileError(errors.bad_arg_type);
                },
            }
        },
        .address => {
            if (type_info == .pointer) {
                const addr: osformat.format.AddressString = .init(
                    @intFromPtr(arg),
                );
                self.fillBuf(addr.getStr());
            } else {
                @compileError(errors.bad_arg_type);
            }
        },
        .number_with_base => |tag| {
            if ((type_info != .comptime_int) and (type_info != .int)) {
                @compileError(errors.bad_arg_type);
            } else {
                const num: osformat.format.StringFromInt(T, tag) = .init(arg);
                self.fillBuf(num.getStr());
            }
        },
    }
}

fn addChar(self: *IWriter, char: u8) void {
    self.buffer[self.sentinel] = char;
    self.sentinel += 1;
}

fn fillBuf(self: *IWriter, buf: []const u8) void {
    var buf_sentinel: usize = 0;

    while (buf_sentinel < buf.len) {
        if (self.sentinel >= self.buffer.len) {
            @branchHint(.cold);
            self.flush();
        }

        self.addChar(buf[buf_sentinel]);
        buf_sentinel += 1;
    }
}

pub fn flush(self: *IWriter) void {
    self.vtable.write(self.instance, self.buffer[0..self.sentinel]);
    self.sentinel = 0;
}

/// Interface member functions should directly hit the IO device. We distinguish
/// between `write` `writeLine` due to implementation differences of what a
/// "line" means. For example, the kernel's x86 Framebuffer won't interpret a
/// \n as a newline, whereas the x86 SerialPort indeed interprets a \r\n as a
/// newline.
pub const VTable = struct {
    write: *const fn (opaque_self: *anyopaque, buffer: []const u8) void,

    writeLine: *const fn (opaque_self: *anyopaque, buffer: []const u8) void,
};

const test_helpers = struct {
    const std = @import("std");

    const FakeWriter = struct {
        /// NOT a buffer. This should simulate a truly written-to IO device.
        /// As a result, the buffer passed in to `writer` that creates an
        /// `IWriter` may be "ahead" of this object. Meaning, `IWriter` buffers
        /// input itself, and only writes to this underlying `fake_memory` when
        /// it it needs to or when it is explicitly flushed
        fake_memory: std.ArrayList(u8),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) FakeWriter {
            return .{ .fake_memory = .empty, .allocator = allocator };
        }

        pub fn writer(self: *FakeWriter, buffer: []u8) IWriter {
            return .{
                .sentinel = 0,
                .buffer = buffer,
                .instance = self,
                .vtable = &.{
                    .write = &struct {
                        fn impl(opaque_self: *anyopaque, buf: []const u8) void {
                            const concrete_self: *FakeWriter = @ptrCast(@alignCast(opaque_self));
                            concrete_self.write(buf);
                        }
                    }.impl,
                    .writeLine = &struct {
                        fn impl(opaque_self: *anyopaque, buf: []const u8) void {
                            const concrete_self: *FakeWriter = @ptrCast(@alignCast(opaque_self));
                            concrete_self.writeLine(buf);
                        }
                    }.impl,
                },
            };
        }

        pub fn write(self: *FakeWriter, buffer: []const u8) void {
            self.fake_memory.appendSlice(self.allocator, buffer) catch unreachable;
        }

        pub fn writeLine(self: *FakeWriter, buffer: []const u8) void {
            self.write(buffer);
            self.fake_memory.append(self.allocator, '\n') catch unreachable;
        }

        pub fn cleanup(self: *FakeWriter) void {
            self.fake_memory.deinit(self.allocator);
        }

        pub fn reset(self: *FakeWriter) void {
            self.fake_memory.clearAndFree(self.allocator);
        }
    };
};

test IWriter {
    const std = @import("std");
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var fake_writer: test_helpers.FakeWriter = .init(allocator);
    defer fake_writer.cleanup();

    {
        var buffer: [1024]u8 = .{0} ** 1024;
        var fake_interface: IWriter = fake_writer.writer(&buffer);

        const to_write = comptime "I take no args";
        try fake_interface.writef(to_write, .{});

        std.testing.expect(std.mem.eql(
            u8,
            to_write,
            buffer[0..fake_interface.sentinel],
        )) catch |err| {
            std.debug.print(
                "Expected buffer to be \"{s}\", but was \"{s}\"\n",
                .{ to_write, buffer[0..fake_interface.sentinel] },
            );
            return err;
        };

        std.debug.print(
            "Hard memory length before flush: {d}\n",
            .{fake_writer.fake_memory.items.len},
        );

        fake_interface.flush();

        std.debug.print(
            "Hard memory length before flush: {d}\n",
            .{fake_writer.fake_memory.items.len},
        );

        try std.testing.expect(fake_writer.fake_memory.items.len == to_write.len);
    }

    fake_writer.reset();

    {
        var buffer: [1024]u8 = .{0} ** 1024;
        var fake_interface: IWriter = fake_writer.writer(&buffer);

        const foo_slice: []const u8 = "foo";
        try fake_interface.writef("I take one arg: {s}", .{foo_slice});
        const expected_result = comptime "I take one arg: foo";

        std.testing.expect(std.mem.eql(
            u8,
            expected_result,
            buffer[0..fake_interface.sentinel],
        )) catch |err| {
            std.debug.print(
                "Expected buffer to be \"{s}\", but was \"{s}\"\n",
                .{ expected_result, buffer[0..fake_interface.sentinel] },
            );
            return err;
        };
    }

    {
        var buffer: [1024]u8 = .{0} ** 1024;
        var fake_interface: IWriter = fake_writer.writer(&buffer);

        const random_number: usize = 42;
        try fake_interface.writef("I want a number: {d}", .{random_number});
        const expected_result = comptime "I want a number: 42";

        std.testing.expect(std.mem.eql(
            u8,
            expected_result,
            buffer[0..fake_interface.sentinel],
        )) catch |err| {
            std.debug.print(
                "Expected buffer to be \"{s}\", but was \"{s}\"\n",
                .{ expected_result, buffer[0..fake_interface.sentinel] },
            );
            return err;
        };
    }
}
