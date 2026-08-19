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
};

pub const StructureBlock = struct {
    pub const Token = enum(BEU8) {
        begin_node = 0x00_00_00_01,
        end_node = 0x00_00_00_02,
        property = 0x00_00_00_03,
        nop = 0x00_00_00_04,
        end = 0x00_00_00_09,

        pub fn toUnderlying(self: Token) u8 {
            return (BEU8{ .val = @intFromEnum(self) }).toNative();
        }
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
