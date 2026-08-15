const std = @import("std");

pub const RingBufferReadError = error{
    buffer_empty,
};

pub const RingBufferWriteError = error{
    buffer_full,
};

pub const RingBufferError = RingBufferWriteError || RingBufferReadError;

/// Thread/Interrupt safe ring buffer. NOTE: (Read below)
///
/// This is _largely_ not my own implementation in the slightest. This was
/// taken from rigtorp's blog post about optimizng a ring buffer in C++. His
/// starting implementation bench marks (~5M items per second) mean I could in
/// theory push 5 scan codes within a microsecond, which is what I want for
/// my keyboard handler. See his blog post here:
///
/// https://rigtorp.se/ringbuffer/
pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        buf: [capacity]T,
        /// TODO(SEP): calculate cach-line size of arch at comptime if possible.
        read_ptr: usize align(64),
        /// TODO(SEP): calculate cach-line size of arch at comptime if possible.
        write_ptr: usize align(64),
        dropped: usize,

        pub fn init() Self {
            return .{ .buf = undefined, .read_ptr = 0, .write_ptr = 0, .dropped = 0 };
        }

        pub fn push(self: *Self, item: T) RingBufferWriteError!void {
            const write_idx = @atomicLoad(usize, &self.write_ptr, .unordered);
            var next_write_idx = write_idx + 1;
            if (next_write_idx == capacity) {
                next_write_idx = 0;
            }
            if (next_write_idx == @atomicLoad(usize, &self.read_ptr, .acquire)) {
                return RingBufferWriteError.buffer_full;
            }
            self.buf[write_idx] = item;
            @atomicStore(usize, &self.write_ptr, next_write_idx, .release);
        }

        pub fn pop(self: *Self) ?T {
            const read_idx = @atomicLoad(usize, &self.read_ptr, .unordered);
            if (read_idx == @atomicLoad(usize, &self.write_ptr, .acquire)) {
                return null;
            }
            const item = self.buf[read_idx];
            var next_read_idx = read_idx + 1;
            if (next_read_idx == capacity) {
                next_read_idx = 0;
            }
            @atomicStore(usize, &self.read_ptr, next_read_idx, .release);
            return item;
        }
    };
}

test RingBuffer {
    var ring: RingBuffer(u8, 6) = .init();
    try ring.push(0);
    try ring.push(2);
    try ring.push(4);
    try ring.push(6);
    try ring.push(8);
    try std.testing.expect(failed: {
        ring.push(10) catch {
            break :failed true;
        };
        break :failed false;
    });

    const expected_popped_in_order = comptime [_]u8{ 0, 2, 4, 6, 8 };

    for (expected_popped_in_order) |expected| {
        if (ring.pop()) |popped| {
            std.testing.expect(popped == expected) catch |err| {
                std.debug.print("Expected popped={}, got {}\n", .{ expected, popped });
                return err;
            };
        } else {
            std.debug.print("Expected pop success, but failed.\n", .{});
            try std.testing.expect(false);
        }
    }

    try std.testing.expect(ring.pop() == null);

    const BigRing = RingBuffer(u8, 1001);
    var big_ring: BigRing = .init();
    const Push = struct {
        const src: [1000]u8 = blk: {
            @setEvalBranchQuota(2000);
            var ret: [1000]u8 = undefined;
            for (0..100) |label| {
                const start_idx = label * 10;
                const end_idx = start_idx + 10;
                for (ret[start_idx..end_idx]) |*val| {
                    val.* = label;
                }
            }
            break :blk ret;
        };
        fn work(buf: *BigRing) void {
            var idx: usize = 0;
            while (true) {
                if (idx == src.len) {
                    return;
                } else {
                    const succeeded = blk: {
                        buf.push(src[idx]) catch {
                            break :blk false;
                        };
                        break :blk true;
                    };

                    if (succeeded) {
                        idx += 1;
                    }
                }
            }
        }
    };
    const Pop = struct {
        var to_check: std.ArrayList(u8) = .empty;
        var keep_popping: bool = true;
        fn work(buf: *BigRing) void {
            const allocator = std.heap.smp_allocator;
            while (true) {
                if (buf.pop()) |popped| {
                    to_check.append(allocator, popped) catch {};
                } else if (!keep_popping) {
                    return;
                }
            }
        }
    };
    const popper = try std.Thread.spawn(.{}, Pop.work, .{&big_ring});
    const pusher = try std.Thread.spawn(.{}, Push.work, .{&big_ring});
    pusher.join();
    Pop.keep_popping = false;
    popper.join();

    try std.testing.expect(std.mem.eql(u8, &Push.src, Pop.to_check.items));
}
