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

pub fn allocFrame(self: *PageAllocator) Error!*align(4096) anyopaque {
    var previous: ?*std.SinglyLinkedList.Node = self.head.first;
    var maybe_node: ?*std.SinglyLinkedList.Node = self.head.first;

    while (maybe_node) |node| {
        // if a chunk isn't page aligned we hella messed up and should panic
        // anyway
        const chunk: *align(4096) Chunk = @alignCast(@fieldParentPtr("node", node));

        if (chunk.free_bytes >= 4096) {
            self.head.remove(node);

            if (chunk.free_bytes >= 4096 + @sizeOf(Chunk)) {
                @branchHint(.likely);

                const next_chunk: *Chunk = @ptrFromInt(@intFromPtr(chunk) + 4096);
                next_chunk.free_bytes = chunk.free_bytes - 4096;
                next_chunk.node = .{};

                self.head.prepend(&next_chunk.node);
            }

            return @ptrCast(chunk);
        }

        previous = node;
        maybe_node = node.next;
    }

    return Error.oom;
}

pub fn freeFrame(self: *PageAllocator, ptr: *align(4096) anyopaque) void {
    const chunk: *align(4096) Chunk = @ptrCast(ptr);
    // TODO(SEP): Somehow zero the page out
    chunk.node = .{};
    chunk.free_bytes = 4096;

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
    fn FakeMemoryProber(
        comptime chunk_count: comptime_int,
        comptime chunk_width: comptime_int,
    ) type {
        return struct {
            const Self = @This();

            fake_kernel_end: [chunk_count][4096 * chunk_width]u8 = undefined,

            pub fn init() @This() {
                var self: Self = .{};
                @memset(&self.fake_kernel_end, .{0} ** (4096 * chunk_width));
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
    }
};

test allocFrame {
    var fake_mem_prober: test_helpers.FakeMemoryProber(8, 2) = .init();

    var page_allocator: PageAllocator = try PageAllocator.init(.{
        .interface = fake_mem_prober.prober(),
        .len = 1,
        .kernel_end = &fake_mem_prober.fake_kernel_end,
    });

    try std.testing.expect(page_allocator.head.first != null);

    const initial_byte_count, const initial_chunk_address = blk: {
        const head_chunk: *Chunk = @fieldParentPtr(
            "node",
            page_allocator.head.first.?,
        );
        break :blk .{ head_chunk.free_bytes, @intFromPtr(head_chunk) };
    };

    const allocated_page: *align(4096) anyopaque = try page_allocator.allocFrame();
    try std.testing.expect(@intFromPtr(allocated_page) == initial_chunk_address);

    if (page_allocator.head.first) |head| {
        const new_chunk: *Chunk = @fieldParentPtr("node", head);
        const diff = initial_byte_count - 4096;
        std.testing.expect(new_chunk.free_bytes == diff) catch |err| {
            std.debug.print(
                "Initial Free Byte Count: {}\nFinal Free Byte Count: {}\nExpected {}\n",
                .{ initial_byte_count, new_chunk.free_bytes, diff },
            );
            return err;
        };
    }

    try std.testing.expect(page_allocator.head.len() == 1);
    page_allocator.freeFrame(allocated_page);
    try std.testing.expect(page_allocator.head.len() == 2);
}

test PageAllocator {
    var fake_mem_prober: test_helpers.FakeMemoryProber(8, 2) = .init();

    const page_allocator: PageAllocator = try PageAllocator.init(.{
        .interface = fake_mem_prober.prober(),
        .len = 1,
        .kernel_end = &fake_mem_prober.fake_kernel_end,
    });

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
