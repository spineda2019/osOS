const exception = @import("exception.zig");
const tty = @import("riscv32tty");
const riscv32asm = @import("riscv32asm");
const sbi = @import("sbi/root.zig");
const osformat = @import("osformat");
const oshal = @import("oshal");
const kmain = @import("kmain");
const riscv32hal = @import("hal/hal.zig");
const serial = @import("serial/serial.zig");
const BootInfo = @import("BootInfo");

/// BSS Start
const bss = @extern([*]u8, .{ .name = "__bss" });

/// BSS End
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });

/// Defined externally by the linker script.
pub const free_ram_start: [*]u8 = @extern([*]u8, .{ .name = "__free_ram" });

/// Also defined externally by the linker script.
pub const free_ram_end: [*]u8 = @extern([*]u8, .{ .name = "__free_ram_end" });

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

pub fn setup(hart_id: u32, dtb_address: [*]const u8) callconv(.c) noreturn {
    const bssSize = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bssSize], 0);

    const exception_handler_address = &exception.cpuExceptionHandler;

    asm volatile ("csrw stvec, %[exception_handler]"
        :
        : [exception_handler] "r" (exception_handler_address),
    );

    var terminal = tty.Terminal.init();
    terminal.writeSplashLogo();

    var buffer: [1024]u8 = undefined;
    var terminal_writer: osformat.IWriter = terminal.writer(&buffer);

    terminal_writer.writef("Hello RISC-V32 osOS!\n", .{});
    terminal_writer.writef("Hart ID: {d}\n", .{hart_id});
    terminal_writer.writef("DTB Address: {*}\n", .{dtb_address});

    const sbi_spec_version = sbi.getSpecVersion();
    terminal_writer.writef(
        "SBI Specification version: {s}.{s}\n",
        .{
            sbi_spec_version.major.getStr(),
            sbi_spec_version.minor.getStr(),
        },
    );
    const sbi_impl: []const u8 = sbi.getImplId();
    terminal_writer.writef("SBI Implementation: {s}\n", .{sbi_impl});

    var serial_stub: serial.SerialPort = .{};
    var serial_buffer: [1024]u8 = undefined;

    kmain.kmain(
        .{
            .terminal = terminal_writer,
            .serial_io = serial_stub.writer(&serial_buffer),
            .boot_module_info = BootInfo.ModuleInfo.moduleProber(),
            .char_buf = .{
                .impl = null,
                .vtable = &.{
                    .getChar = &struct {
                        fn impl(_: ?*anyopaque) ?u8 {
                            return null;
                        }
                    }.impl,
                },
            },
        },
        .{
            .assembly_wrappers = .{
                .jump = riscv32asm.assembly_wrappers.jump,
                .illegal_instruction = riscv32asm.assembly_wrappers.illegal_instruction,
                .wait_for_interrupt = riscv32asm.assembly_wrappers.waitForInterrupt,
            },
            .ctx_tools = .{
                .enableInterrupts = riscv32asm.assembly_wrappers.enableInterrupts,
                .disableInterrupts = riscv32asm.assembly_wrappers.disableInterrupts,
            },
        },
    );
}
