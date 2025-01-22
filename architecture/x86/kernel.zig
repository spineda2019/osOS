/// Entry point for the x86 kernel. Stack must be set up
export fn boot() align(4) linksection(".text") callconv(.Naked) noreturn {
    // HACK: I couldn't figure out how to link in a flat asm binary to setup
    // the magic boot numbers and checksum, so I took the instructions from
    // the disassembly of my C kernel (which had an entry point in a flat
    // NASM built binary) and plopped them here...
    asm volatile (
        \\addb    0x1bad(%eax), %dh
        \\addb    %al, (%eax)
        \\decb    0x52(%edi)
        \\inb     $0xbc, %al
        \\addb    %dh, (%eax)
        \\adcb    %al, (%eax)
    );

    asm volatile (
    // start off with the storage of magic numbers, flags, and checksum
        \\.intel_syntax noprefix
        \\mov EAX, 0x4242
    );
    while (true) {
        asm volatile ("");
    }
}
