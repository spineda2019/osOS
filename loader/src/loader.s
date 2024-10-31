global loader                                  ; Entry symbol for ELF
extern kmain

MAGIC_NUMBER equ 0x1BADB002
FLAGS        equ 0x0
CHECKSUM     equ -MAGIC_NUMBER
KERNEL_STACK_SIZE equ 4096

section .bss
align 4
kernel_stack:
    resb KERNEL_STACK_SIZE                     ; Setup stack for C code

section .text
align 4
    dd MAGIC_NUMBER
    dd FLAGS
    dd CHECKSUM
    mov esp, kernel_stack + KERNEL_STACK_SIZE  ; setup stack pointer to end of kernel_stack

loader:
    call kmain                                 ; No pushing needed

.loop:
    jmp .loop
