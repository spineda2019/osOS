/// Interrupts are numbered 0 through 255 inclusive. This table will describe
/// a handler for each one. The information each handler will need will be
/// pushed onto the stack by the CPU when triggered, so this structure need
/// only store mappings from iterrupt numbers to handlers
pub const InterruptDescriptionTable = struct {
    /// An entry in the Interrupt Description Table is represented as a 64 bit
    /// integer. x86 is innately a 32 bit architecture, so we will have to carefully
    /// track the high and low bits ourselves. The high bits have the following
    /// layout:
    ///
    /// Bit:     | 31              16 | 15 | 14 13 | 12 | 11 | 10 9 8 | 7 6 5 | 4 3 2 1 0 |
    /// Content: | offset high        | P  | DPL   | 0  | D  | 1  1 0 | 0 0 0 | reserved  |
    ///
    /// And the low bits have the following layout:
    ///
    /// Bit:     | 31              16 | 15              0 |
    /// Content: | segment selector   | offset low        |
    ///
    /// offset high:      The 16 highest bits of the 32 bit address in the segment.
    /// offset low:       The 16 lowest bits of the 32 bits address in the segment.
    /// p:                If the handler is present in memory or not
    ///                   (1 = present, 0 = not present).
    /// DPL:              Descriptor Privilige Level, the privilege level the
    ///                   handler can be called from (0, 1, 2, 3).
    /// D:                Size of gate, (1 = 32 bits, 0 = 16 bits).
    /// segment selector: The offset in the GDT.
    /// r:                Reserved.
    entry_high_bits: [512]u32,
};

/// Memory layout must be packed, as we will push registers on the stack from
/// assembly, then jump to a function with the cdecl calling convention
/// to utilize this struct as an argument
const CpuState = packed struct {
    eax: u32,
    ebx: u32,
    ecx: u32,
    edx: u32,
    esi: u32,
    edi: u32,
    esp: u32,
    ebp: u32,
};

export fn common_interrupt_handler() void {
    const cpu_state = CpuState{
        .ebp = asm volatile (
            \\ popl %eax
            : [ret] "={eax}" (-> u32),
        ),
        .esp = asm volatile (
            \\ popl %eax
            : [ret] "={eax}" (-> u32),
        ),
        .edi = asm volatile (
            \\ popl %eax
            : [ret] "={eax}" (-> u32),
        ),
        .esi = asm volatile (
            \\ popl %eax
            : [ret] "={eax}" (-> u32),
        ),
        .edx = asm volatile (
            \\ popl %eax
            : [ret] "={eax}" (-> u32),
        ),
        .ecx = asm volatile (
            \\ popl %eax
            : [ret] "={eax}" (-> u32),
        ),
        .ebx = asm volatile (
            \\ popl %eax
            : [ret] "={eax}" (-> u32),
        ),
        .eax = asm volatile (
            \\ popl %eax
            : [ret] "={eax}" (-> u32),
        ),
    };

    asm volatile (
        \\ movl %eax, %eax
        :
        : [foo] "{eax}" (&cpu_state),
    );
}

/// Interrupt 0 has no associated error code
pub fn interrupt_0_handler() callconv(.naked) void {
    // save CPU registers
    asm volatile (
        \\pushl %eax
        \\pushl %ebx
        \\pushl %ecx
        \\pushl %edx
        \\pushl %esi
        \\pushl %edi
        \\pushl %esp
        \\pushl %ebp
        \\
        \\jmp common_interrupt_handler  # label must be globally exported
        \\
        \\popl %eax
        \\popl %ebx
        \\popl %ecx
        \\popl %edx
        \\popl %esi
        \\popl %edi
        \\popl %esp
        \\popl %ebp
        \\
        \\iret
    );
}
