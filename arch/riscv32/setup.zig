const exception = @import("exception.zig");
const tty = @import("riscv32tty");
const memory = @import("memory/memory.zig");
const osprocess = @import("osprocess");

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

fn delay() void {
    for (0..30000000) |_| {
        asm volatile (
            \\nop
        );
    }
}

pub fn setup() noreturn {
    const bssSize = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bssSize], 0);

    const exception_handler_address: u32 = @intFromPtr(&exception.cpuExceptionHandler);

    asm volatile ("csrw stvec, %[exception_handler]"
        :
        : [exception_handler] "{t3}" (exception_handler_address),
    );

    var terminal = tty.Terminal.init();
    terminal.write("Hello RISC-V32 osOS!\n");
    // Causing a kernel pacnic will look like this: common.panic(@src());
    // register our cpuExceptionHanlder with the stvec handler

    terminal.write("Trying to allocate some memory...\n");
    var page_allocater: memory.PageAllocater = memory.PageAllocater.init(
        @intFromPtr(free_ram_start),
        @intFromPtr(free_ram_end),
    );

    const address_1 = page_allocater.allocate(2);
    const address_2 = page_allocater.allocate(1);

    terminal.write("Mem allocation done!\n");
    terminal.printf("Address 1: %d\nAddress 2: %d\n", .{
        address_1,
        address_2,
    });

    var pool: osprocess.ProcessTable = .init();
    _ = &pool;

    // proc_a_entry();

    asm volatile ("unimp");

    const hal: riscv32hal.Hal = .{
        .terminal = &terminal,
    };

    kmain.kmain(hal);
}
