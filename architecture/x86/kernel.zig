//! This module contains logic for the setup and entry of the x86 kernel

const framebuffer_api = @import("framebuffer.zig");

export fn kmain() align(4) linksection(".text") callconv(.Naked) noreturn {
    asm volatile (
        \\movl 0x4242, %EAX
    );

    asm volatile (
        \\.intel_syntax noprefix
        \\mov WORD PTR [0x000B8000], 0x2841
    );

    //framebuffer_api.FrameBuffer.clear();

    while (true) {
        asm volatile ("");
    }
}
