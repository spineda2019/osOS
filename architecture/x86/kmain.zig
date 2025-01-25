//! This module contains logic for the setup and entry of the x86 kernel

const framebuffer_api = @import("framebuffer.zig");

pub fn kmain() noreturn {
    asm volatile (
        \\movl 0x4242, %EAX
    );

    framebuffer_api.FrameBuffer.writeCell(
        0,
        0,
        84,
        framebuffer_api.FrameBufferCellColor.Green,
        framebuffer_api.FrameBufferCellColor.White,
    );
    framebuffer_api.FrameBuffer.writeCell(
        0,
        79,
        'T',
        framebuffer_api.FrameBufferCellColor.Green,
        framebuffer_api.FrameBufferCellColor.LightGray,
    );
    framebuffer_api.FrameBuffer.writeCell(
        24,
        79,
        'T',
        framebuffer_api.FrameBufferCellColor.Green,
        framebuffer_api.FrameBufferCellColor.LightGray,
    );
    framebuffer_api.FrameBuffer.writeCell(
        24,
        0,
        'T',
        framebuffer_api.FrameBufferCellColor.Green,
        framebuffer_api.FrameBufferCellColor.LightGray,
    );

    asm volatile (
        \\movw $0x2841, 0x000B8F9E
    );

    //framebuffer_api.FrameBuffer.clear();

    while (true) {
        asm volatile ("");
    }
}
