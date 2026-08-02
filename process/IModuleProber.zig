impl: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    nthModuleAddress: *const fn (*const anyopaque, usize) ?[]const u8,
    nthModuleName: *const fn (*const anyopaque, usize) ?[]const u8,
};
