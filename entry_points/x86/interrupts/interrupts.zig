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

const CpuState = struct {
    eax: u32,
    ebx: u32,
    ecx: u32,
    edx: u32,
    esi: u32,
    edi: u32,
    esp: u32,
    ebp: u32,
};

/// Interrupt 0 has no associated error code
pub fn interrupt_0_handler() callconv(.Naked) void {
    // save CPU registers
    const prior_state: CpuState = undefined;
    asm volatile (
        \\ movl %eax, [%[old_eax]]
        \\ movl %ebx, [%[old_ebx]]
        \\ movl %ecx, [%[old_ecx]]
        \\ movl %edx, [%[old_edx]]
        \\ movl %esi, [%[old_esi]]
        \\ movl %edi, [%[old_edi]]
        \\ movl %esp, [%[old_esp]]
        \\ movl %ebp, [%[old_ebp]]
        :
        : [old_eax] "{eax}" (&prior_state.eax),
          [old_ebx] "{ebx}" (&prior_state.ebx),
          [old_ecx] "{ecx}" (&prior_state.ecx),
          [old_edx] "{edx}" (&prior_state.edx),
          [old_esi] "{esi}" (&prior_state.esi),
          [old_edi] "{edi}" (&prior_state.edi),
          [old_esp] "{esp}" (&prior_state.esp),
          [old_ebp] "{ebp}" (&prior_state.ebp),
        : "memory"
    );
}
