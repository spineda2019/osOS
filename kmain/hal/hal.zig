pub const terminal = @import("terminal.zig");

/// Architcture agnostic interface for hardware interaction. Populated and
/// supplied by arch specific boot routines.
pub const Hal = struct {
    terminal: terminal.KTerminal,
};
