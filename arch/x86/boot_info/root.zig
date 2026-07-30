const BootInfo = @This();
const BootloaderInfo = @import("BootloaderInfo.zig");
const FramebufferInfo = @import("FramebufferInfo.zig");
pub const MemoryInfo = @import("MemoryInfo.zig");
const PagingInfo = @import("x86memory").paging.Info;

bootinfo: BootloaderInfo,
framebuffer: FramebufferInfo,
memory: MemoryInfo,
paging: PagingInfo,
