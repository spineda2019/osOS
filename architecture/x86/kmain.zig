//! This module contains logic for the setup and entry of the x86 kernel

const framebuffer_api = @import("framebuffer.zig");

pub fn kmain() noreturn {
    framebuffer_api.FrameBuffer.clear();
    framebuffer_api.FrameBuffer.printWelcomScreen();

    while (true) {
        asm volatile ("");
    }
}
