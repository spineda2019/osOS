const framebuffer = @import("x86framebuffer");

/// HAL object to be fed to kmain
pub const Hal = struct {
    terminal: *framebuffer.FrameBuffer,
};
