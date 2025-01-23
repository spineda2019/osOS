const framebuffer_api = @import("framebuffer.zig");

pub fn kmain() noreturn {
    framebuffer_api.FrameBuffer.writeCell(
        0,
        0,
        'T',
        framebuffer_api.FrameBufferCellColor.White,
        framebuffer_api.FrameBufferCellColor.Green,
    );
    while (true) {
        asm volatile ("");
    }
}
