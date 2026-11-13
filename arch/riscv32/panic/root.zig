const tty = @import("riscv32tty");
const osformat = @import("osformat");

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


