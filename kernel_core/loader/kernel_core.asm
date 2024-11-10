global kernel_core                                  ; Entry symbol for ELF
extern kmain
extern dummy_buffer_write
extern clear_screen
extern test_corners
extern frame_buffer_write_cell
extern welcome_message
extern reset_cursor
extern move_framebuffer_cursor

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

kernel_core:
    push word 0x8                                   ; background
    push word 0x2                                   ; foreground
    push word 0x57                                  ; should be W in hex
    push dword 0x0
    call frame_buffer_write_cell
    call clear_screen
    call welcome_message
    call test_corners
    call reset_cursor
    call kmain                                 ; No pushing needed

.loop:
    ; blink the cursors around
    call sleep
    push 0
    call move_framebuffer_cursor
    pop eax

    call sleep
    push 79
    call move_framebuffer_cursor
    pop eax

    call sleep
    push 1920
    call move_framebuffer_cursor
    pop eax

    call sleep
    push 1999
    call move_framebuffer_cursor
    pop eax

    jmp .loop

sleep:
    push ebp
    mov ebp, esp
    sub esp, 16

    mov DWORD [ebp - 4], 0
    jmp .L4
.L5:
    add DWORD [ebp - 4], 1
.L4:
    cmp DWORD [ebp - 4], 999999999
    jle .L5
    nop
    nop

    leave
    ret


