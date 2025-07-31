/// static variable w.r.t this container, used as the spin-lock flag
var lock: u8 = 0;

const Self: type = @This();

/// namespace where assembly instructions are defined. Usefull to make this
/// type arch agnostic, as we only really need fence instructions.
assembly_wrappers: type,

pub fn init(comptime assembly_wrappers: type) Self {
    return .{ .assembly_wrappers = assembly_wrappers };
}

pub fn acquire(this: Self) void {
    this.assembly_wrappers.disableInterrupts();
    while (@cmpxchgWeak(u8, &lock, 0, 1, .acquire, .acquire) == null) {}
    this.assembly_wrappers.fullMemoryFence();
}

pub fn release(this: Self) void {
    this.assembly_wrappers.fullMemoryFence();
    @atomicStore(u8, &lock, 0, .release);
}
