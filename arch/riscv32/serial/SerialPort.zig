const Self = @This();
const MutableSelf = *Self;

pub fn delay(_: MutableSelf, count: usize) void {
    for (0..count) |_| {
        asm volatile ("");
    }
}
