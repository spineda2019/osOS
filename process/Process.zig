//! Universal construct representing an osOS process

const Process = @This();

const ProcessState = enum {
    runnable,
    waiting,
};

pub const ProcessError = error{
    OutOfSlots,
};

/// this is generic code, don't assume arch size
pid: usize,
/// Self explanatory
state: ProcessState,
entry_address: [*]const u8,
