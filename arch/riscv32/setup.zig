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
    const hart_id_string: osformat.format.StringFromInt(u32) = .init(.{
        .number = hart_id,
        .base = 10,
    });
    terminal.writeLine(hart_id_string.getStr());

    terminal.write("DTB Address: 0x");
    const dtb_address_string: osformat.format.StringFromInt(u32) = .init(.{
        .number = dtb_address,
        .base = 16,
    });
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
