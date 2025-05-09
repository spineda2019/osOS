const tty = @import("riscv32tty");

/// HAL object to be fed to kmain
pub const Hal = struct {
    terminal: *tty.Terminal,
};
