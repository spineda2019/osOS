/// Entry point for the x86 kernel. Stack must be set up
export fn boot() align(4) linksection(".text") callconv(.Naked) noreturn {
    asm volatile (
        \\.intel_syntax noprefix
        \\mov EAX, 0x4242
    );
    while (true) {
        asm volatile ("");
    }
}
