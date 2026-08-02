const ModuleInfo = @This();
const IModuleProber = @import("osprocess").IModuleProber;

pub fn moduleProber() IModuleProber {
    return .{
        .impl = undefined,
        .vtable = &.{
            .nthModuleAddress = &struct {
                fn impl(_: *const anyopaque, _: usize) ?[]const u8 {
                    return null;
                }
            }.impl,
            .nthModuleName = &struct {
                fn impl(_: *const anyopaque, _: usize) ?[]const u8 {
                    return null;
                }
            }.impl,
        },
    };
}
