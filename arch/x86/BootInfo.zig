//! Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.
//!
//! Bootloader (and protocol) agnostic information about the system extracted
//! from the bootloader and whichever protocol it used.

const std = @import("std");
const BootInfo = @This();

bootinfo: BootloaderInfo,

framebuffer: FramebufferInfo,

memory: MemoryInfo,

pd_address: *const anyopaque,

pub const BootloaderInfo = struct {
    name: [*:0]const u8,
    cmdline: ?[*:0]const u8,

    /// Whether or not the boot environment passed verification, such as
    /// checking a multiboot 1 bootloader's magic number against 0xbadb002
    valid: bool,

    diagnostic: [80]u8,
};

pub const FramebufferInfo = struct {
    addr: ?u32,

    height: ?u32,

    width: ?u32,
};

pub const MemoryInfo = struct {
    pub const FreeChunk = struct {
        size: u32,
        address: u32,
        length: u32,
    };

    pub const IMemoryProber = struct {
        instance: *anyopaque,
        vtable: *const VTable,

        pub const VTable = struct {
            availableMemChunkAt: *const fn (*anyopaque, usize) ?FreeChunk,

            /// Simple helper to allow implementors to generate their impl at
            /// compile time. Requires the implementing struct to have a public
            /// function with the same name as the interface members.
            pub fn init(comptime T: type) *const VTable {
                return &.{
                    .availableMemChunkAt = &struct {
                        pub fn impl(opaque_self: *anyopaque, idx: usize) ?FreeChunk {
                            const self: *T = @ptrCast(@alignCast(opaque_self));
                            return self.availableMemChunkAt(idx);
                        }
                    }.impl,
                };
            }
        };
    };

    interface: IMemoryProber,
    len: usize,

    pub fn availableMemChunkAt(self: MemoryInfo, idx: usize) ?FreeChunk {
        return self.interface.vtable.availableMemChunkAt(
            self.interface.instance,
            idx,
        );
    }
};
