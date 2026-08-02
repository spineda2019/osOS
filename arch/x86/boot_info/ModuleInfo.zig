const ModuleInfo = @This();

const osprocess = @import("osprocess");
const IModuleProber = osprocess.IModuleProber;

prober: IModuleProber,

pub fn iterator(self: *const ModuleInfo) Iterator {
    return .{ .prober = self.prober };
}

pub const Iterator = struct {
    prober: IModuleProber,
    idx: usize = 0,

    pub fn next(self: *Iterator) ?osprocess.BootModule {
        const peeked = self.peek();
        if (peeked) |_| {
            self.idx += 1;
        }
        return peeked;
    }

    pub fn peek(self: *const Iterator) ?osprocess.BootModule {
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

test Iterator {}
