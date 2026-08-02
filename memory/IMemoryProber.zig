instance: *anyopaque,
vtable: *const VTable,

pub const MemError = error{
    InfoUnavailable,
    NoMoreChunks,
};

pub const VTable = struct {
    availableMemChunkAt: *const fn (*const anyopaque, usize) MemError!?[]allowzero u8,
};
