const tty = @import("riscv32tty");
const riscv32asm = @import("riscv32asm");

/// HAL object to be fed to kmain
pub const Hal = struct {
    terminal: *tty.Terminal,
    comptime assembly_wrappers: type = riscv32asm.assembly_wrappers,
};
