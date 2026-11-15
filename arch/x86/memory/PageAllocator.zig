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

//! PageAllocator.zig - The kernel page allocator for x86

const PageAllocator = @This();
const BootInfo = @import("x86BootInfo");
const MemoryInfo = BootInfo.MemoryInfo;
const std = @import("std");
const builtin = @import("builtin");
const memoptions = @import("memoptions");

const PAGE_SIZE = memoptions.PAGE_SIZE;

/// The tipitty top of free physical memory. When initialized, should point to
/// the first address after the kernel image's end that can hold _at least_ one
/// frame.
head: std.SinglyLinkedList,

pub const Error = error{
    no_system_memory_after_kernel,
    oom,
};

pub const Chunk = struct {
    node: std.SinglyLinkedList.Node,
    free_bytes: u32,

    pub const Iterator = struct {
        node: ?*std.SinglyLinkedList.Node,

        pub fn peek(self: *const Iterator) ?*Chunk {
            if (self.node) |n| {
                const chunk: *Chunk = @fieldParentPtr("node", n);
                return chunk;
            } else {
                return null;
            }
        }

        pub fn next(self: *Iterator) ?*Chunk {
            var result: ?*Chunk = null;
            if (self.node) |n| {
                const chunk: *Chunk = @fieldParentPtr("node", n);
                result = chunk;
                self.node = n.next;
            }
            return result;
        }
    };
};

comptime {
    if (@sizeOf(Chunk) > PAGE_SIZE) {
        @compileError("Chunk type must fit in a single page");
    }
}

pub fn iterator(self: *const PageAllocator) Chunk.Iterator {
    return .{ .node = self.head.first };
}

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
        ptr: usize,
        comptime alignment: comptime_int,
    ) *align(alignment) anyopaque {
        var first_aligned_address: usize = ptr;
        var diff = @mod(first_aligned_address, alignment);

        while (diff > 0) {
            first_aligned_address += alignment - diff;
            diff = @mod(first_aligned_address, alignment);
        }

        return @ptrFromInt(first_aligned_address);
    }

    fn pageAligned(ptr: usize) *align(PAGE_SIZE) anyopaque {
        return withAlignment(ptr, PAGE_SIZE);
    }
};

/// Initialize a PageAllocator
pub fn init(
    iter: *MemoryInfo.Iterator,
    kernel_end: [*]const u8,
) Error!PageAllocator {
    const physical_end: usize = @intFromPtr(kernel_end);

    while (iter.next()) |raw_chunk| {
        const ptr: usize = @intFromPtr(raw_chunk.ptr);
        const chunk_end: usize = ptr + raw_chunk.len;

        const first_past_kernel: usize = blk: {
            if (ptr > physical_end) {
                break :blk ptr;
            } else if (chunk_end > physical_end) {
                break :blk physical_end;
            } else {
                continue;
            }
        };
        const head_candidate: *align(PAGE_SIZE) anyopaque = find_first_valid_address.pageAligned(
            first_past_kernel,
        );
        const freespace: usize = chunk_end - @intFromPtr(head_candidate);
        if (freespace >= PAGE_SIZE) {
            const chunk: *align(PAGE_SIZE) Chunk = @ptrCast(head_candidate);
            chunk.node = .{};
            chunk.free_bytes = freespace;

            return .{
                .head = .{ .first = &chunk.node },
            };
        }
    }

    return Error.no_system_memory_after_kernel;
}

/// Returns a **_physical_** address. It is up to the caller to properly map this
/// to a virtual address if needed.
pub fn allocFrame(self: *PageAllocator) Error!*align(PAGE_SIZE) [PAGE_SIZE]u8 {
    var maybe_node: ?*std.SinglyLinkedList.Node = self.head.first;

    while (maybe_node) |node| {
        // if a chunk isn't page aligned we hella messed up and should panic
        // anyway
        const chunk: *align(PAGE_SIZE) Chunk = @alignCast(@fieldParentPtr("node", node));

        if (chunk.free_bytes >= PAGE_SIZE) {
            self.head.remove(node);

            // We need at least 2 frames worth of free memory to easily
            // guarantee we can intrusively store the new head. A smarter
            // algorithm doesn't need this, but this stays for now because I
            // want to focus on cooler things.
            if (chunk.free_bytes >= 8192) {
                @branchHint(.likely);

                const next_chunk: *Chunk = @ptrFromInt(@intFromPtr(chunk) + PAGE_SIZE);
                next_chunk.free_bytes = chunk.free_bytes - PAGE_SIZE;
                next_chunk.node = .{};

                self.head.prepend(&next_chunk.node);
            }

            return @ptrCast(chunk);
        }

        maybe_node = node.next;
    }

    return Error.oom;
}

pub fn freeFrame(self: *PageAllocator, ptr: *align(PAGE_SIZE) anyopaque) void {
    const chunk: *align(PAGE_SIZE) Chunk = @ptrCast(ptr);
    // TODO(SEP): Somehow zero the page out
    chunk.node = .{};
    chunk.free_bytes = PAGE_SIZE;

    self.head.prepend(&chunk.node);
}

const interface_impl = struct {
    fn alloc(
        self: *PageAllocator,
        len: usize,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        if (ret_addr == 0) {
            // TODO
            return null;
        }

        // TODO
        _ = self;
        _ = len;
        _ = alignment;
        return null;
    }

    fn resize(
        self: *PageAllocator,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        if (ret_addr == 0) {
            // TODO
            return false;
        }

        // TODO
        _ = self;
        _ = memory;
        _ = alignment;
        _ = new_len;
        return false;
    }

    fn remap(
        self: *PageAllocator,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) ?[*]u8 {
        if (ret_addr == 0) {
            // TODO
            return null;
        }

        // TODO
        _ = self;
        _ = memory;
        _ = alignment;
        _ = new_len;
        return null;
    }

    fn free(
        self: *PageAllocator,
        memory: []u8,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        // TODO
        _ = ret_addr;
        _ = self;
        _ = memory;
        _ = alignment;
    }
};

pub fn allocator(self: *PageAllocator) std.mem.Allocator {
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = &struct {
                fn impl(
                    opaque_self: *anyopaque,
                    len: usize,
                    alignment: std.mem.Alignment,
                    ret_addr: usize,
                ) ?[*]u8 {
                    const this: *PageAllocator = @ptrCast(@alignCast(opaque_self));
                    return interface_impl.alloc(this, len, alignment, ret_addr);
                }
            }.impl,
            .resize = &struct {
                fn impl(
                    opaque_self: *anyopaque,
                    memory: []u8,
                    alignment: std.mem.Alignment,
                    new_len: usize,
                    ret_addr: usize,
                ) bool {
                    const this: *PageAllocator = @ptrCast(@alignCast(opaque_self));
                    return interface_impl.resize(
                        this,
                        memory,
                        alignment,
                        new_len,
                        ret_addr,
                    );
                }
            }.impl,
            .remap = &struct {
                fn impl(
                    opaque_self: *anyopaque,
                    memory: []u8,
                    alignment: std.mem.Alignment,
                    new_len: usize,
                    ret_addr: usize,
                ) ?[*]u8 {
                    const this: *PageAllocator = @ptrCast(@alignCast(opaque_self));
                    return interface_impl.remap(
                        this,
                        memory,
                        alignment,
                        new_len,
                        ret_addr,
                    );
                }
            }.impl,
            .free = &struct {
                fn impl(
                    opaque_self: *anyopaque,
                    memory: []u8,
                    alignment: std.mem.Alignment,
                    ret_addr: usize,
                ) void {
                    const this: *PageAllocator = @ptrCast(@alignCast(opaque_self));
                    interface_impl.free(this, memory, alignment, ret_addr);
                }
            }.impl,
        },
    };
}

const test_helpers = struct {
    const FakeMemoryProber = struct {
        fake_kernel_end: [][]u8,

        pub fn init(buf: [][]u8) FakeMemoryProber {
            for (buf) |chunk| {
                @memset(chunk, 0);
            }
            return .{ .fake_kernel_end = buf };
        }

        pub fn availableMemChunkAt(self: *const FakeMemoryProber, idx: usize) ?[]u8 {
            if (idx < self.fake_kernel_end.len) {
                const chunk: []u8 = self.fake_kernel_end[idx][0..];
                return chunk;
            } else {
                return null;
            }
        }
    };
};

test allocFrame {
    if (@sizeOf(usize) != 4) {
        return;
    }

    const osmemory = @import("osmemory");
    var single_chunk: [4 * PAGE_SIZE]u8 = undefined;
    var arena: [8][]u8 = @splat(&single_chunk);
    const first: [][]u8 = arena[0..arena.len];

    var fake_mem_prober: test_helpers.FakeMemoryProber = .init(first);
    const interface: osmemory.IMemoryProber = .{
        .instance = &fake_mem_prober,
        .vtable = &.{
            .availableMemChunkAt = &struct {
                fn impl(
                    opaque_self: *const anyopaque,
                    idx: usize,
                ) osmemory.IMemoryProber.MemError!?[]allowzero u8 {
                    const T: type = test_helpers.FakeMemoryProber;
                    const self: *const T = @ptrCast(@alignCast(opaque_self));
                    return self.availableMemChunkAt(idx);
                }
            }.impl,
        },
    };
    var iter: MemoryInfo.Iterator = .{ .prober = interface };

    var page_allocator: PageAllocator = try PageAllocator.init(
        &iter,
        fake_mem_prober.fake_kernel_end[0].ptr,
    );

    try std.testing.expect(page_allocator.head.first != null);

    var chunk_iter = page_allocator.iterator();
    const peeked: *Chunk = chunk_iter.peek() orelse @panic("first chunk should exist");
    const initial_byte_count = peeked.free_bytes;

    const allocated_page: *align(PAGE_SIZE) [PAGE_SIZE]u8 = try page_allocator.allocFrame();
    try std.testing.expect(@intFromPtr(allocated_page) == @intFromPtr(peeked));

    chunk_iter = page_allocator.iterator();
    const new_chunk: *Chunk = chunk_iter.peek() orelse @panic("Chunk not found");
    const diff = initial_byte_count - PAGE_SIZE;
    std.testing.expect(new_chunk.free_bytes == diff) catch |err| {
        std.debug.print("Initial Free Byte Count: {}\n", .{initial_byte_count});
        std.debug.print("Final Free Byte Count: {}\n", .{new_chunk.free_bytes});
        std.debug.print("Expected {}\n", .{diff});
        return err;
    };

    try std.testing.expect(page_allocator.head.len() == 1);
    page_allocator.freeFrame(allocated_page);
    try std.testing.expect(page_allocator.head.len() == 2);
}

test PageAllocator {
    if (@sizeOf(usize) != 4) {
        return;
    }

    const osmemory = @import("osmemory");
    var single_chunk: [2 * PAGE_SIZE]u8 = undefined;
    var arena: [8][]u8 = @splat(&single_chunk);
    const first: [][]u8 = arena[0..arena.len];

    var fake_mem_prober: test_helpers.FakeMemoryProber = .init(first);
    const interface: osmemory.IMemoryProber = .{
        .instance = &fake_mem_prober,
        .vtable = &.{
            .availableMemChunkAt = &struct {
                fn impl(
                    opaque_self: *const anyopaque,
                    idx: usize,
                ) osmemory.IMemoryProber.MemError!?[]allowzero u8 {
                    const T: type = test_helpers.FakeMemoryProber;
                    const self: *const T = @ptrCast(@alignCast(opaque_self));
                    return self.availableMemChunkAt(idx);
                }
            }.impl,
        },
    };
    var iter: MemoryInfo.Iterator = .{ .prober = interface };

    const page_allocator: PageAllocator = try PageAllocator.init(
        &iter,
        fake_mem_prober.fake_kernel_end[0].ptr,
    );

    var chunk_iter = page_allocator.iterator();
    while (chunk_iter.next()) |chunk| {
        const remainder = @mod(@intFromPtr(chunk), PAGE_SIZE);
        try std.testing.expect(remainder == 0);
    }
}
