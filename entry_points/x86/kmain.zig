// kmain.zig - The central core of osOS on x86; where the boot routine jumps to
// Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

//! This module contains logic for the setup and entry of the x86 kernel

const framebuffer_api = @import("framebuffer.zig");

pub fn kmain() noreturn {
    framebuffer_api.FrameBuffer.clear();
    framebuffer_api.FrameBuffer.printWelcomScreen();

    while (true) {
        asm volatile ("");
    }
}
