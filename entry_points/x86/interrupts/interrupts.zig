const osformat = @import("osformat");
const as = @import("x86asm");

pub const InterruptError = error{
    InvalidInterruptNumber,
};

pub const HandlerType = enum {
    WithErrorCode,
    NoErrorCode,
};

pub const IDTDescriptor = packed struct {
    size: u16,
    offset: u32,

    pub fn init(idt: *const InterruptDescriptorTable) IDTDescriptor {
        return .{
            .size = (@bitSizeOf(InterruptDescriptorTable) / 8) - 1,
            .offset = @intFromPtr(&idt),
        };
    }

    pub fn loadIDT(self: *const IDTDescriptor) void {
        as.assembly_wrappers.x86_lidt(@intFromPtr(self));
    }
};

/// Interrupts are numbered 0 through 255 inclusive. This table will describe
/// a handler for each one. The information each handler will need will be
/// pushed onto the stack by the CPU when triggered, so this structure need
/// only store mappings from iterrupt numbers to handlers
pub const InterruptDescriptorTable = [256]InterruptDescriptor;

/// Given a table of the 256 interrupt function pointers needed to handle every
/// possible interrupt, initialize the IDT.
pub fn createDefaultIDT(
    handler_table: *const InterruptHandlerTable,
) InterruptDescriptorTable {
    var entries: [256]InterruptDescriptor = undefined;
    for (handler_table, 0..) |fn_ptr, interrupt_number| {
        entries[interrupt_number] = .{
            .offset_low = @truncate(@intFromPtr(fn_ptr)),
            .offset_high = @truncate(@intFromPtr(fn_ptr) >> 16),
            .segment_selector = SegmentSelector.kernel_mode_code_segment,
            .unused = 0,
            .gate_type = InterruptDescriptorGateType.ProtectedModeInterruptGate,
            .zero = 0,
            .descriptor_privilege_level = 0, // kernel mode
            .present_bit = 0b1,
        };
    }

    return entries;
}

const SegmentSelector = packed struct(u16) {
    /// The requested Privilege Level of the selector, determines if the
    /// selector is valid during permission checks and may set execution or
    /// memory access privilege.
    requested_privilege_level: u2,

    /// Specifies which descriptor table to use. If clear (0) then the GDT is
    /// used, if set (1) then the current LDT is used.
    table_type: u1,

    /// Bits 3-15 of the Index of the GDT or LDT entry referenced by this
    /// selector. Since Segment Descriptors in the GDT are 8 bytes in length,
    /// the value of Index is never unaligned and contains all zeros in the
    /// lowest 3 bits (since the lowest possible index is 0b1000 AKA 0x8).
    index: u13,

    const kernel_mode_code_segment: SegmentSelector = .{
        .requested_privilege_level = 0,
        .table_type = 0,
        .index = 0x8,
    };
};

/// An Interrupt Descriptor has a section of 4 bits that describe the type of
/// handler it is describing. However, there are only 5 valid gate types, so
/// we enumerate them for clarity.
pub const InterruptDescriptorGateType = enum(u4) {
    TaskGate = 0b0101,

    /// 16 bit interrupt gate
    RealModeInterruptGate = 0b0110,

    /// 16 bit trap gate
    RealModeTrapGate = 0b0111,

    /// 16 bit interrupt gate
    ProtectedModeInterruptGate = 0b1110,

    /// 16 bit trap gate
    ProtectedModeTrapGate = 0b1111,
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
    /// Lower 16 bits of the address of the entry point of the interrupt handler
    /// this descriptor describes.
    offset_low: u16,

    /// Overall bits [16, 31], bits [16, 31] in lower bits
    ///
    /// Segment selector pointing to valid entry in our GDT
    segment_selector: SegmentSelector,

    /// Overall bits [32, 39], bits [0, 7] in higher bits
    ///
    /// Unused
    unused: u8,

    /// Overall bits [40, 43], bits [8, 11] in higher bits
    ///
    /// Bits configuring the type of handler. Task gates are not supported, so
    /// this MUST be 0b11
    gate_type: InterruptDescriptorGateType,

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

/// General interrupt handler that pushes register state to stack and calls
/// the internal zig interrupt handler. This function will only be called
/// by each interrupt number's handler. That handler will have (optionally)
/// pushed an error code on the stack, and pushed it's interrupt number on the
/// stack (so it'll be on the top once registers are popped off).
export fn commonInteruptHandler() callconv(.naked) void {
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
    );

    // TODO: Actual handling

    asm volatile (
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

pub const InterruptHandlerTable = [256]*const fn () callconv(.naked) void;

/// Generate interrupt handler functions at comptime, them take and store
/// their addresses at runtime. This should only be called at comptime,
/// generating functions doesn't make sense at runtime, and should not
/// compile anyway.
pub fn generateInterruptHandlers() InterruptHandlerTable {
    var table: [256]*const fn () callconv(.naked) void = undefined;

    for (0..table.len) |interrupt_number| {
        // .. range is not inclusive on the right
        table[interrupt_number] = generateHandler(interrupt_number);
    }

    return table;
}

/// Generic function to generate an interrupt handler. This handler will push
/// an error code to the stack. This generic pattern is ued in place of macros,
/// which would be used if were using something like NASM for example.
fn generateHandler(
    comptime interrupt_number: comptime_int,
) *const fn () callconv(.naked) void {
    const inner = struct {
        const std = @import("std");
        pub fn withErrorCode() callconv(.naked) void {
            asm volatile (
                \\pushl 0                    # push 0 as error code
                \\pushl %[interrupt_number]  # push interrupt number
                \\jmp commonInteruptHandler
                : // no outputs
                : [interrupt_number] "i" (interrupt_number),
            );
        }

        pub fn withoutErrorCode() callconv(.naked) void {
            asm volatile (
                \\pushl %[interrupt_number]  # push interrupt number
                \\jmp commonInteruptHandler
                : // no outputs
                : [interrupt_number] "i" (interrupt_number),
            );
        }
    };

    const fn_pointer = switch (interrupt_number) {
        8, 10, 11, 12, 13, 14, 17 => &inner.withErrorCode,
        else => &inner.withoutErrorCode,
    };

    @export(
        fn_pointer,
        .{
            .name = "interrupt_handler_" ++ inner.std.fmt.comptimePrint("{}", .{
                interrupt_number,
            }),
        },
    );

    return fn_pointer;
}
