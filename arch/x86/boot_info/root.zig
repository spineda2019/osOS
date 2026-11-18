const BootInfo = @This();
const BootloaderInfo = @import("BootloaderInfo.zig");
const FramebufferInfo = @import("FramebufferInfo.zig");
const IModuleProber = @import("osprocess").IModuleProber;
pub const MemoryInfo = @import("MemoryInfo.zig");
pub const PagingInfo = @import("x86memory").paging.Info;

bootinfo: BootloaderInfo,
framebuffer: FramebufferInfo,
memory: MemoryInfo,
paging: PagingInfo,
module_info: IModuleProber,
