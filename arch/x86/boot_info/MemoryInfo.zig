const MemoryInfo = @This();

interface: IMemoryProber,
kernel_end: [*]const u8,

pub const IMemoryProber = struct {
    instance: *anyopaque,
    vtable: *const VTable,

    pub const MemError = error{
        InfoUnavailable,
        NoMoreChunks,
    };

    pub const VTable = struct {
        availableMemChunkAt: *const fn (*const anyopaque, usize) MemError!?[]allowzero u8,
    };
};

pub const Iterator = struct {
    prober: IMemoryProber,
    idx: usize = 0,

    pub fn next(self: *Iterator) ?[]allowzero u8 {
        const result = self.searchNext();
        if (result.payload) |_| {
            self.idx = result.hit_index;
        }
        return result.payload;
    }

    pub fn peek(self: *const Iterator) ?[]allowzero u8 {
        return self.searchNext().payload;
    }

    const Search = struct {
        payload: ?[]allowzero u8,
        hit_index: usize,
    };

    fn searchNext(self: *const Iterator) Search {
        var result: Search = .{ .hit_index = self.idx, .payload = null };

        while (result.payload == null) {
            result.payload = self.prober.vtable.availableMemChunkAt(
                self.prober.instance,
                result.hit_index,
            ) catch {
                // errors only when no more segments exist, accounting for gaps
                return .{ .hit_index = result.hit_index, .payload = null };
            };

            result.hit_index += 1;
        }

        return result;
    }
};

pub fn iterator(self: *const MemoryInfo) Iterator {
    return .{ .prober = self.interface };
}

pub fn findFreeAbove1MB(self: *const MemoryInfo) ?[]allowzero u8 {
    var iter: Iterator = self.iterator();
    while (iter.next()) |chunk| {
        if (chunk.address >= 0x10_00_00) {
            return chunk;
        }
    }

    return null;
}
