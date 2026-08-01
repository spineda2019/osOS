const ModuleInfo = @This();

prober: IModuleProber,

pub fn iterator(self: *const ModuleInfo) Iterator {
    return .{ .prober = self.prober };
}

pub const Iterator = struct {
    prober: IModuleProber,
    idx: usize = 0,

    pub const BootModule = struct {
        physical_address: []const u8,
        name: []const u8,
    };

    pub fn next(self: *Iterator) ?BootModule {
        const peeked = self.peek();
        if (peeked) |_| {
            self.idx += 1;
        }
        return peeked;
    }

    pub fn peek(self: *const Iterator) ?BootModule {
        const maybe_addr: ?[]const u8 = self.prober.vtable.nthModuleAddress(
            self.prober.impl,
            self.idx,
        );
        if (maybe_addr) |addr| {
            const maybe_name: ?[]const u8 = self.prober.vtable.nthModuleName(
                self.prober.impl,
                self.idx,
            );
            if (maybe_name) |name| {
                return .{ .physical_address = addr, .name = name };
            } else {
                return null;
            }
        } else {
            return null;
        }
    }
};

pub const IModuleProber = struct {
    impl: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        nthModuleAddress: *const fn (*const anyopaque, usize) ?[]const u8,
        nthModuleName: *const fn (*const anyopaque, usize) ?[]const u8,
    };
};

test Iterator {}
