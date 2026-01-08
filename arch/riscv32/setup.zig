const exception = @import("exception.zig");
const tty = @import("riscv32tty");
const riscv32asm = @import("riscv32asm");
const sbi = @import("sbi/root.zig");
const osformat = @import("osformat");
const oshal = @import("oshal");

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

pub fn handlePanic(message: []const u8, start_address: ?usize) noreturn {
    // TODO: Disable interrupts (once I have them working)
    var terminal = tty.Terminal.init();

    terminal.writeLine("Kernel Panic!!!");
    terminal.write("Panic Message: ");
    terminal.writeLine(message);

    const return_addr = @returnAddress();
    const return_addr_str: osformat.format.StringFromInt(usize, 16) = .init(
        return_addr,
    );
    terminal.write("@returnAddress: 0x");
    terminal.writeLine(return_addr_str.getStr());

    if (start_address) |start| {
        const start_addr_str: osformat.format.StringFromInt(usize, 16) = .init(
            start,
        );
        terminal.write("Start Address: 0x");
        terminal.writeLine(start_addr_str.getStr());
    } else {
        terminal.writeLine("No Start Address reported");
    }

    while (true) {
        asm volatile ("");
    }
}

pub fn setup(hart_id: u32, dtb_address: u32) callconv(.c) noreturn {
    const bssSize = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bssSize], 0);

    const exception_handler_address = &exception.cpuExceptionHandler;

    asm volatile ("csrw stvec, %[exception_handler]"
        :
        : [exception_handler] "r" (exception_handler_address),
    );

    var terminal = tty.Terminal.init();

    terminal.writeLine("Hello RISC-V32 osOS!");
    terminal.writeSplashLogo();

    terminal.write("Hart ID: ");
    const hart_id_string: osformat.format.StringFromInt(u32, 10) = .init(hart_id);
    terminal.writeLine(hart_id_string.getStr());

    terminal.write("DTB Address: 0x");
    const dtb_address_string: osformat.format.StringFromInt(u32, 16) = .init(dtb_address);
    terminal.writeLine(dtb_address_string.getStr());

    const sbi_spec_version = sbi.getSpecVersion();
    terminal.write("SBI Specification version: ");
    terminal.write(sbi_spec_version.major.getStr());
    terminal.write(".");
    terminal.writeLine(sbi_spec_version.minor.getStr());
    const sbi_impl: []const u8 = sbi.getImplId();
    terminal.write("SBI Implementation: ");
    terminal.writeLine(sbi_impl);

    const hal_layout: oshal.HalLayout = comptime .{
        .assembly_wrappers = riscv32asm.assembly_wrappers,
        .Terminal = tty.Terminal,
    };

    kmain.kmain(hal_layout, oshal.HAL(hal_layout){ .terminal = &terminal });
}
