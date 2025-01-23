//! This module contains logic for the setup and entry of the x86 kernel

/// Entry point for the x86 kernel. Stack must be set up
/// This MUST be first func in this file for proper adressing.
/// Honestly, may be best to have this as the only function here
export fn boot() align(4096) linksection(".text") callconv(.Naked) noreturn {
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

    const kmain = @import("kernel_jump.zig").kmain;
    const kmain_address: u32 = @intFromPtr(&kmain);

    // jump away to kmain, this should preserve this routine as the lowest
    // address in the binary
    asm volatile (
        \\.intel_syntax noprefix
        \\jmp EDX
        // no outputs
        :
        // pass in adress of kmain
        : [kmain] "{EDX}" (kmain_address),
    );
}
