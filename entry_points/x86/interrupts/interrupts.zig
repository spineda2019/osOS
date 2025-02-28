pub const InterruptError = error{
    InvalidInterruptNumber,
};

/// Interrupts are numbered 0 through 255 inclusive. This table will describe
/// a handler for each one. The information each handler will need will be
/// pushed onto the stack by the CPU when triggered, so this structure need
/// only store mappings from iterrupt numbers to handlers
pub const InterruptDescriptionTable = struct {
    entries: [256]InterruptDescriptor,

    pub fn addEntry(
        self: *InterruptDescriptionTable,
        interrupt_number: u16,
        entry: u32,
    ) InterruptError!void {
        if (interrupt_number > 255) {
            return InterruptError.InvalidInterruptNumber;
        } else {
            self.entries[interrupt_number] = .{
                .offset_low = entry & 0b0000_0000_1111_1111,
                .offset_high = entry & 0b1111_1111_0000_0000,
                .segment_selector = 0x8, // TODO: needs to point to offest in GDT holding cs
                .unused = 0,
                .gate_type = 0b1,
                .gate_stuffing = 0b11, // must be 0b11
                .gate_size = 0b1, // 32 bit
                .zero = 0,
                .descriptor_privilege_level = 0,
                .present_bit = 0b1,
            };
        }
    }
};

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
pub const InterruptDescriptor = packed struct {
    /// Overall bits [0, 15], bits [0, 15] in lower bits
    ///
    /// Lower 16 bits of the total offset of ths descriptor in the table. The
    /// total offset points to the entry point of the handler
    offset_low: u16,

    /// Overall bits [16, 31], bits [16, 31] in lower bits
    ///
    /// Segment selector pointing to valid entry in our GDT
    segment_selector: u16,

    /// Overall bits [32, 39], bits [0, 7] in higher bits
    ///
    /// Unused
    unused: u8,

    /// Overall bits 40th, overall 8th bit in higher bits
    ///
    /// Bits configuring the type of handler. Task gates are not supported
    ///
    /// 0b0 -> Interrupt Gate
    /// 0b1 -> Trap Gate
    gate_type: u1,

    /// Overall bits [41, 42], bits [9, 10] in higher bits
    ///
    /// Bits configuring the type of handler. Task gates are not supported, so
    /// this MUST be 0b11
    ///
    /// 0b11 -> Interrupt/Trap Gate
    /// 0b10 -> Task Gate (Unsupported)
    gate_stuffing: u2,

    /// Overall 43rd bit, 11th bit in higher bits
    ///
    /// 1 inidicates a 32 bit gate, 0 indicates 16 bit.
    gate_size: u1,

    /// Unused. 44th overall bit, 12th bit in higher bits
    zero: u1,

    /// Overall bits [45, 46], bits [13, 14] in higher bits
    ///
    /// Defines CPU privilege levels which are allow to access this interrupt
    /// with the "int" instruction (hardware interrupts just ignore this).
    descriptor_privilege_level: u2,

    /// 47th overall bit. 15th bit in higher bits
    ///
    /// Must be 1 for this descriptor to be valid
    present_bit: u1,

    /// Overall bits [48, 63], bits [16, 31] in higher bits
    ///
    /// Higher 16 bits of the total offset of ths descriptor in the table. The
    /// total offset points to the entry point of the handler
    offset_high: u16,
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
