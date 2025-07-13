const framebuffer = @import("x86framebuffer");
const x86asm = @import("x86asm");

/// HAL object to be fed to kmain
pub const Hal = struct {
    terminal: *framebuffer.FrameBuffer,
    comptime assembly_wrappers: type = x86asm.assembly_wrappers,
};
