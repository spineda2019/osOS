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
    oom,
};

pub const Chunk = struct {
    node: std.SinglyLinkedList.Node,
    free_bytes: u32,
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

    fn pageAligned(ptr: usize) *align(4096) anyopaque {
        return withAlignment(ptr, 4096);
    }
};

pub fn init(mem_info: MemoryInfo) Error!PageAllocator {
    const kernel_end: usize = @intFromPtr(mem_info.kernel_end);

    for (0..mem_info.len) |idx| {
        if (mem_info.availableMemChunkAt(idx)) |raw_chunk| {
            const region_end = raw_chunk.address + raw_chunk.length;
            if (region_end > kernel_end) {
                const search_start = blk: {
                    if (raw_chunk.address >= kernel_end) {
                        break :blk raw_chunk.address;
                    } else {
                        break :blk kernel_end;
                    }
                };
                const head_candidate: *align(4096) anyopaque = find_first_valid_address.pageAligned(
                    search_start,
                );
                const freespace = region_end - @intFromPtr(head_candidate);
                if (freespace >= 4096) {
                    const chunk: *align(4096) Chunk = @ptrCast(head_candidate);
                    chunk.node = .{};
                    chunk.free_bytes = freespace;

                    return .{
                        .head = .{ .first = &chunk.node },
                    };
                }
            }
        }
    }

    return Error.no_system_memory_after_kernel;
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
        const Self = @This();

        fake_kernel_end: [8][4096 * 2]u8 = undefined,

        pub fn init() @This() {
            var self: Self = .{};
            @memset(&self.fake_kernel_end, .{0} ** (4096 * 2));
            return self;
        }

        pub fn prober(self: *Self) MemoryInfo.IMemoryProber {
            return .{
                .instance = self,
                .vtable = MemoryInfo.IMemoryProber.VTable.init(@This()),
            };
        }

        pub fn availableMemChunkAt(self: *Self, idx: usize) ?MemoryInfo.FreeChunk {
            if (idx > self.fake_kernel_end.len) {
                return null;
            } else {
                return .{
                    .address = @intFromPtr(&(self.fake_kernel_end[idx])),
                    .length = self.fake_kernel_end[idx].len,
                };
            }
        }
    };
};

// test allocator {
// const FakeMemoryProber = struct {
// const Self = @This();
//
// fake_kernel_end: [8][4096 * 2]u8 = undefined,
//
// pub fn init() @This() {
// var self: Self = .{};
// @memset(&self.fake_kernel_end, .{0} ** (4096 * 2));
// return self;
// }
//
// pub fn prober(self: *Self) MemoryInfo.IMemoryProber {
// return .{
// .instance = self,
// .vtable = MemoryInfo.IMemoryProber.VTable.init(@This()),
// };
// }
//
// pub fn availableMemChunkAt(self: *Self, idx: usize) ?MemoryInfo.FreeChunk {
// if (idx > self.fake_kernel_end.len) {
// return null;
// } else {
// return .{
// .address = @intFromPtr(&(self.fake_kernel_end[idx])),
// .length = self.fake_kernel_end[idx].len,
// };
// }
// }
// };
//
// var fake_mem_prober: FakeMemoryProber = .init();
//
// var page_allocator: PageAllocator = try PageAllocator.init(.{
// .interface = fake_mem_prober.prober(),
// .len = 1,
// .kernel_end = &fake_mem_prober.fake_kernel_end,
// });
//
// var zig_allocator: std.mem.Allocator = page_allocator.allocator();
// _ = &zig_allocator;
// }
//
test PageAllocator {
    var fake_mem_prober: test_helpers.FakeMemoryProber = .init();

    var page_allocator: PageAllocator = try PageAllocator.init(.{
        .interface = fake_mem_prober.prober(),
        .len = 1,
        .kernel_end = &fake_mem_prober.fake_kernel_end,
    });
    _ = &page_allocator;

    if (page_allocator.head.first) |head| {
        var maybe_node: ?*std.SinglyLinkedList.Node = head;
        while (maybe_node) |node| {
            defer maybe_node = node.next;
            const chunk: *Chunk = @fieldParentPtr("node", node);
            std.debug.print("Chunk Object Address: {*}\n", .{chunk});
            std.debug.print("Child node Address: {*}\n", .{node});

            const remainder = @mod(@intFromPtr(chunk), 4096);
            try std.testing.expect(remainder == 0);
        }
    } else {
        std.debug.print("Init failed!\n", .{});
    }
}
