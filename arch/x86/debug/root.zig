const std = @import("std");

pub const SelfInfo = @import("SelfInfo.zig");

pub const getDebugInfoAllocator: fn () std.mem.Allocator = SelfInfo.getDebugInfoAllocator;
