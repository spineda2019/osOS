const exception = @import("exception.zig");
const tty = @import("riscv32tty");

/// BSS Start
const bss = @extern([*]u8, .{ .name = "__bss" });

/// BSS End
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });

/// Defined externally by the linker script.
pub const free_ram_start: [*]u8 = @extern([*]u8, .{ .name = "__free_ram" });

/// Also defined externally by the linker script.
pub const free_ram_end: [*]u8 = @extern([*]u8, .{ .name = "__free_ram_end" });

const kmain = @import("kmain");
const riscv32hal = @import("hal/hal.zig");

pub fn setup() noreturn {
    const bssSize = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bssSize], 0);

    const exception_handler_address = &exception.cpuExceptionHandler;

    asm volatile ("csrw stvec, %[exception_handler]"
        :
        : [exception_handler] "{t3}" (exception_handler_address),
    );

    var terminal = tty.Terminal.init();

    terminal.write("Hello RISC-V32 osOS!\n");

    const hal: riscv32hal.Hal = .{
        .terminal = &terminal,
    };

    kmain.kmain(hal);
}
