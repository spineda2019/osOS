const builtin = @import("builtin");

/// All fields are big endian for some reason
pub const FdtHeader = extern struct {
    magic: u32,
    totalsize: u32,
    off_dt_struct: u32,
    off_dt_strings: u32,
    off_mem_rsvmap: u32,
    version: u32,
    last_comp_version: u32,
    boot_cpuid_phys: u32,
    size_dt_strings: u32,
    size_dt_struct: u32,
};

pub const StructureBlock = extern struct {};

pub const StringsBlock = struct {
    pub const Iterator = struct {
        idx: usize = 0,
        begin: [*]const u8,

        pub fn init(fdt: *const FdtHeader) Iterator {
            const offset: u32 = switch (builtin.cpu.arch.endian()) {
                .big => fdt.off_dt_strings,
                .little => @byteSwap(fdt.off_dt_strings),
            };
            return .{
                .begin = @ptrFromInt(@intFromPtr(fdt) + offset),
            };
        }

        pub fn next(self: *Iterator) ?[]const u8 {
            const maybe_next = self.peek();
            if (maybe_next) |exists| {
                self.idx += exists.len + 1;
                return exists;
            } else {
                return null;
            }
        }

        pub fn peek(self: *const Iterator) ?[]const u8 {
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
};

pub const MemoryReservationBlock = struct {
    /// Also big endian fields for some reason
    pub const Entry = extern struct {
        address: u64,
        size: u64,
    };

    pub fn getEntries(header: *const FdtHeader) []const Entry {
        const offset: u32 = switch (builtin.cpu.arch.endian()) {
            .big => header.off_mem_rsvmap,
            .little => @byteSwap(header.off_mem_rsvmap),
        };
        const slice_start: [*]const Entry = @ptrFromInt(
            @intFromPtr(header) + offset,
        );

        var len: usize = 0;
        while (!(slice_start[len].address == 0 and slice_start[len].size == 0)) {
            len += 1;
        }
        return slice_start[0..len];
    }
};
