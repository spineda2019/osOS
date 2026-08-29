//! Universal construct representing an osOS process

const Process = @This();

const ProcessState = enum {
    runnable,
    waiting,
};

pub const ProcessError = error{
    OutOfSlots,
};

pub const Stack = struct {
    span: []const u8,
    current_pointer: [*]const u8,
};

/// this is generic code, don't assume arch size
pid: usize,
/// Self explanatory
state: ProcessState,
entry_address: [*]const u8,

stack_info: Stack,
