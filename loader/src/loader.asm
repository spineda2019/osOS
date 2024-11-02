global loader                                  ; Entry symbol for ELF
extern kmain
extern frame_buffer_write_cell

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
    push word 0x8                                   ; background
    push word 0x2                                   ; foreground
    push word 0x57                                  ; should be W in hex
    push dword 0x0
    call frame_buffer_write_cell

.loop:
    jmp .loop
