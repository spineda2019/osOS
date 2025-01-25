export fn boot() align(4) linksection(".text") callconv(.Naked) noreturn {
    asm volatile (
        \\.equ MAGIC_NUMBER,      0x1BADB002
        \\.equ FLAGS,             0x0
        \\.equ CHECKSUM,          -MAGIC_NUMBER
        \\.equ KERNEL_STACK_SIZE, 4096
        \\
        \\.section .bss
        \\.align 4
        \\kernel_stack:
        \\    .comm stack_space, KERNEL_STACK_SIZE          # Initialize stack for external code
        \\
        \\.section .text
        \\.align 4
        \\    .long MAGIC_NUMBER
        \\    .long FLAGS
        \\    .long CHECKSUM
        \\    movl $kernel_stack + KERNEL_STACK_SIZE, %ESP  # setup stack pointer to end of kernel_stack
        \\
    );
    const kmain_address: u32 = @intFromPtr(&@import("kmain.zig").kmain);
    asm volatile (
        \\    jmp *%ECX
        :
        : [kmain_address] "{ECX}" (kmain_address),
    );
}
