//! PageAllocator.zig - The kernel page allocator for x86
//!
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

const PageAllocator = @This();
const MemoryInfo = @import("BootInfo").MemoryInfo;
const std = @import("std");

head: std.SinglyLinkedList,

pub const Error = error{
    no_system_memory_after_kernel,
};

pub const Chunk = struct {
    base_address: *align(4096) anyopaque,
    node: std.SinglyLinkedList.Node,
    /// The amount of free bytes starting at `base_address`
    free_bytes: u32,
    used: bool,
};

const find_first_valid_address = struct {
    /// Given a raw pointer, find the first address after that has the correct
    /// alignment for the given type
    fn ofType(ptr: *anyopaque, comptime T: type) *T {
        const alignment = @alignOf(T);

        var first_aligned_address: usize = @intFromPtr(ptr);
        var diff = @mod(first_aligned_address, alignment);

        while (diff > 0) {
            first_aligned_address += alignment - diff;
            diff = @mod(first_aligned_address, alignment);
        }

        return @ptrFromInt(first_aligned_address);
    }

    fn withAlignment(
        ptr: *anyopaque,
        comptime alignment: comptime_int,
    ) *align(alignment) anyopaque {
        var first_aligned_address: usize = @intFromPtr(ptr);
        var diff = @mod(first_aligned_address, alignment);

        while (diff > 0) {
            first_aligned_address += alignment - diff;
            diff = @mod(first_aligned_address, alignment);
        }

        return @ptrFromInt(first_aligned_address);
    }
};

pub fn init(mem_info: MemoryInfo) Error!PageAllocator {
    const inplace_chunk: *Chunk = find_first_valid_address.ofType(
        mem_info.kernel_end,
        Chunk,
    );

    // ensure in-place chunk is within physical memory
    var mem_idx: usize = 0;
    for (mem_idx..mem_info.len) |idx| {
        if (mem_info.availableMemChunkAt(idx)) |raw_chunk| {
            const raw_chunk_end = raw_chunk.address + raw_chunk.length;
            const head_node_end = @intFromPtr(inplace_chunk) + @sizeOf(Chunk);
            if (raw_chunk_end > head_node_end) {
                mem_idx = idx;
                const first_chunk = find_first_valid_address.withAlignment(
                    @ptrFromInt(@intFromPtr(inplace_chunk) + 1),
                    4096,
                );
                if (@intFromPtr(first_chunk) > raw_chunk_end) {
                    continue;
                }
                inplace_chunk.base_address = first_chunk;
                inplace_chunk.node = .{};
                inplace_chunk.free_bytes = raw_chunk_end - @intFromPtr(inplace_chunk.base_address);
                break;
            }
        }
    } else {
        return Error.no_system_memory_after_kernel;
    }

    const head: std.SinglyLinkedList = .{ .first = &inplace_chunk.node };
    var tail = &inplace_chunk.node;

    // fill in any potential other available mem chunks. In practice (at least
    // on qemu and bochs) this won't find anything
    for (mem_idx + 1..mem_info.len) |idx| {
        if (mem_info.availableMemChunkAt(idx)) |raw_chunk| {
            const chunk: *Chunk = find_first_valid_address.ofType(
                mem_info.kernel_end,
                Chunk,
            );
            const raw_chunk_end = raw_chunk.address + raw_chunk.length;
            const node_end = @intFromPtr(chunk) + @sizeOf(Chunk);
            if (raw_chunk_end > node_end) {
                const chunk_base = find_first_valid_address.withAlignment(
                    @ptrFromInt(@intFromPtr(chunk) + 1),
                    4096,
                );
                if (@intFromPtr(chunk_base) > raw_chunk_end) {
                    continue;
                }
                chunk.base_address = chunk_base;
                chunk.node = .{};
                chunk.free_bytes = raw_chunk_end - @intFromPtr(chunk.base_address);
                chunk.used = false;

                tail.next = &chunk.node;
                tail = &chunk.node;
            }
        }
    }

    return .{
        .head = head,
    };
}

pub fn allocFrame() !void {}

test PageAllocator {
    // in the actual kernel, this buffer is unneeded (and would defeat the
    // point of implementing an allocator). This is for testing in a hosted
    // environment to prevent segfaults.

    var fake_kernel_end: [4096 * 2]u8 = undefined;

    var page_allocator: PageAllocator = .init(&fake_kernel_end);
    _ = &page_allocator;

    if (page_allocator.head.first) |head| {
        const chunk: *const Chunk = @fieldParentPtr("node", head);
        std.debug.print("Chunk Object side: {}\n", .{@sizeOf(Chunk)});
        std.debug.print("Chunk Object Address: {*}\n", .{chunk});
        std.debug.print("chunk.base_address: {}\n", .{chunk.base_address});

        var remainder = @mod(@intFromPtr(chunk), @alignOf(Chunk));
        try std.testing.expect(remainder == 0);

        remainder = @mod(@intFromPtr(chunk.base_address), 4096);
        try std.testing.expect(remainder == 0);
    } else {
        std.debug.print("Init failed!\n", .{});
    }
}
