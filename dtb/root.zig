const builtin = @import("builtin");
const std = @import("std");

fn toSlice(ptr: [*:0]const u8) []const u8 {
    var full_name_len: usize = 0;
    while (ptr[full_name_len] != 0) {
        full_name_len += 1;
    }
    return ptr[0..full_name_len];
}

pub fn BEU(comptime T: type) type {
    return packed struct(T) {
        val: T,

        const Self = @This();
        pub fn toNative(self: Self) T {
            return switch (builtin.cpu.arch.endian()) {
                .big => self.val,
                .little => @byteSwap(self.val),
            };
        }
    };
}

pub const BEU32 = BEU(u32);
pub const BEU64 = BEU(u64);
pub const BEU8 = BEU(u8);

/// All fields are big endian for some reason
pub const FdtHeader = extern struct {
    magic: BEU32,
    totalsize: BEU32,
    off_dt_struct: BEU32,
    off_dt_strings: BEU32,
    off_mem_rsvmap: BEU32,
    version: BEU32,
    last_comp_version: BEU32,
    boot_cpuid_phys: BEU32,
    size_dt_strings: BEU32,
    size_dt_struct: BEU32,

    pub fn stringBlockIter(fdt: *const FdtHeader) StringBlockIterator {
        return .{
            .begin = @ptrFromInt(@intFromPtr(fdt) + fdt.off_dt_strings.toNative()),
        };
    }

    pub fn getMemEntries(self: *const FdtHeader) []const MemoryReservationBlock {
        const slice_start: [*]const MemoryReservationBlock = @ptrFromInt(
            @intFromPtr(self) + self.off_mem_rsvmap.toNative(),
        );

        var len: usize = 0;
        while (!(slice_start[len].address.val == 0 and slice_start[len].size.val == 0)) {
            len += 1;
        }
        return slice_start[0..len];
    }

    pub fn getStructureIter(self: *const FdtHeader) StructureBlock.Node.Iterator {
        const offset: u32 = self.off_dt_struct.toNative();
        const head_token: [*]const BEU32 = @ptrFromInt(@intFromPtr(self) + offset);

        return .{ .head = head_token };
    }
};

pub const StructureBlock = struct {
    pub const Token = enum(u32) {
        begin_node = 0x00_00_00_01,
        end_node = 0x00_00_00_02,
        property = 0x00_00_00_03,
        nop = 0x00_00_00_04,
        end_tree = 0x00_00_00_09,

        pub fn toUnderlying(self: Token) u8 {
            return switch (builtin.cpu.arch.endian()) {
                .big => @intFromEnum(self),
                .little => @intFromEnum(@byteSwap(self)),
            };
        }
    };

    pub const Node = struct {
        unit_name: []const u8,
        unit_address: ?[]const u8,
        props: ?Property.Iterator,
        children: ?Node.Iterator,

        pub const Property = struct {
            name_offset: BEU32,
            value: []const u8,
            pub const Iterator = struct {};
        };

        const UnitName = struct {
            name: []const u8,
            address: ?[]const u8,

            fn len(self: *const UnitName) usize {
                var total: usize = self.name.len;
                if (self.address) |addr| {
                    total += addr.len;
                }
                return total;
            }
        };

        pub const Iterator = struct {
            head: [*]const BEU32,
            idx: usize = 0,

            pub const Error = error{
                unexpected_token_type,
                premature_tree_end,
            };

            fn getCurrentToken(self: *const Iterator) Token {
                const raw_big_endian: BEU32 = self.head[self.idx];
                return @enumFromInt(raw_big_endian.toNative());
            }

            fn assertCorrectToken(self: *const Iterator, expected: Token) void {
                const tok: Token = self.getCurrentToken();
                std.debug.assert(tok == expected);
            }

            pub fn next(self: *Iterator) Error!?Node {
                const token: Token = self.getCurrentToken();

                var node: Node = .{
                    .unit_address = null,
                    .unit_name = "",
                    .props = null,
                    .children = null,
                };

                switch (token) {
                    .begin_node => try self.parseBegin(&node),
                    .end_tree, .end_node => return null,
                    else => return Error.unexpected_token_type,
                }

                return node;
            }

            fn consumeUntilNextToken(self: *Iterator, start_offset: usize) void {
                var index_bump: usize = start_offset;
                while (@mod(@intFromPtr(self.head + index_bump), 4) != 0) {
                    index_bump += 1;
                }
                self.idx += index_bump;
            }

            fn getFullName(self: *const Iterator) UnitName {
                self.assertCorrectToken(.begin_node);

                const full_name: []const u8 = toSlice(@ptrCast(self.head + self.idx + 1));

                for (full_name, 0..) |value, idx| {
                    if (value == '@') {
                        return .{
                            .name = full_name[0..idx],
                            .address = full_name[idx..full_name.len],
                        };
                    }
                }

                return .{ .name = full_name, .address = null };
            }

            fn parseBegin(self: *Iterator, node: *Node) Error!void {
                self.assertCorrectToken(.begin_node);

                {
                    const full_name: UnitName = self.getFullName();
                    node.unit_name = full_name.name;
                    node.unit_address = full_name.address;
                    self.consumeUntilNextToken(full_name.len() + 1);
                }

                const token: Token = self.getCurrentToken();
                switch (token) {
                    .end_tree => return Error.unexpected_token_type,
                    .begin_node => {
                        const to_assign: Node.Iterator = .{ .head = self.head, .idx = self.idx };
                        var seeker = to_assign;
                        node.children = to_assign;
                        while (seeker.getCurrentToken() == .begin_node) {
                            try seeker.skipNode();
                        }
                        self.idx = seeker.idx;
                    },
                    .end_node => return,
                    .property => try self.parseProperty(node),
                    .nop => try self.parseNop(node),
                }
            }

            fn parseNop(self: *Iterator, node: *Node) Error!void {
                self.assertCorrectToken(.nop);
                self.consumeUntilNextToken(1);
                const token: Token = self.getCurrentToken();
                switch (token) {
                    .begin_node => try self.parseBegin(node),
                    .property => try self.parseProperty(node),
                    .nop => try self.parseNop(node),
                    .end_tree, .end_node => return,
                }
            }

            fn parseProperty(self: *Iterator, node: *Node) Error!void {
                self.assertCorrectToken(.property);

                _ = node;
            }

            fn skipNode(self: *Iterator) Error!void {
                self.assertCorrectToken(.begin_node);
                var depth: usize = 0;
                while (true) {
                    switch (self.getCurrentToken()) {
                        .begin_node => {
                            const full_name: UnitName = self.getFullName();
                            self.consumeUntilNextToken(full_name.len() + 1);
                            depth += 1;
                        },
                        .end_node => {
                            self.idx += 1;
                            depth -= 1;
                            if (depth == 0) return;
                        },
                        .property => self.skipProperty(),
                        .nop => self.idx += 1,
                        .end_tree => return Error.premature_tree_end, // nested node must end with END_NODE
                    }
                }
            }
        };
    };
};

pub const StringBlockIterator = struct {
    idx: usize = 0,
    begin: [*]const u8,

    pub fn next(self: *StringBlockIterator) ?[]const u8 {
        const maybe_next = self.peek();
        if (maybe_next) |exists| {
            self.idx += exists.len + 1;
            return exists;
        } else {
            return null;
        }
    }

    pub fn peek(self: *const StringBlockIterator) ?[]const u8 {
        const start = self.begin[self.idx];
        if (start == 0) {
            return null;
        } else {
            var idx: usize = self.idx;
            while (self.begin[idx] != 0) {
                idx += 1;
            }
            return self.begin[self.idx..idx];
        }
    }
};

/// Also big endian fields for some reason
pub const MemoryReservationBlock = extern struct {
    address: BEU64,
    size: BEU64,
};
