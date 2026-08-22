const builtin = @import("builtin");

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
        end = 0x00_00_00_09,

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

        pub fn getPropIter(self: *const Node) Property.Iterator {
            _ = self;
            return .{};
        }

        pub const Property = struct {
            name_offset: BEU32,
            value: []const u8,
            pub const Iterator = struct {};
        };

        pub const Iterator = struct {
            head: [*]const BEU32,

            pub const Error = error{
                unexpected_token_type,
            };
            pub fn next(self: *Iterator) Error!?Node {
                const raw_big_endian: BEU32 = self.head[0];
                const token: Token = @enumFromInt(raw_big_endian.toNative());
                var node: Node = .{ .unit_address = null, .unit_name = "" };
                switch (token) {
                    .begin_node => {
                        //
                        const full_name: [*:0]const u8 = @ptrCast(self.head + 1);
                        var full_name_len: usize = 0;
                        while (full_name[full_name_len] != 0) {
                            full_name_len += 1;
                        }
                        node.unit_name = full_name[0..full_name_len];

                        const first_aligned: [*]const BEU32 = loop: {
                            const raw_head_addr: [*]const u8 = node.unit_name.ptr + node.unit_name.len + 1;
                            var raw_head_idx: usize = 0;
                            while (@mod(@intFromPtr(raw_head_addr + raw_head_idx), 4) != 0) {
                                raw_head_idx += 1;
                            }
                            break :loop @ptrCast(@alignCast(raw_head_addr + raw_head_idx));
                        };
                        self.head = first_aligned;
                    },
                    .end => return null,
                    else => return Error.unexpected_token_type,
                }

                return node;
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
