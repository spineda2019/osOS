//! idt.zig - structs and utils to setup interrupt handling via the IDT
//! Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.

const as = @import("x86asm");
const pic = @import("pic.zig");
const osformat = @import("osformat");

/// Interrupts are numbered 0 through 255 inclusive. This table will describe
/// a handler for each one. The information each handler will need will be
/// pushed onto the stack by the CPU when triggered, so this structure need
/// only store mappings from iterrupt numbers to handlers
pub const InterruptDescriptorTable = [256]InterruptDescriptor;

/// Alias for the correct type of fn ptr to be registered within the IDT
pub const InterruptHandlerFnPtr = *const fn () callconv(.naked) void;

pub const InterruptHandlerTable = [256]InterruptHandlerFnPtr;

/// Descriptor for the IDT (which is itself another descriptor)
pub const IDTDescriptor = packed struct(u48) {
    size: u16,

    /// Linear address of the IDT
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

const interrupt_handler_table: [256]InterruptHandlerFnPtr = generateInterruptHandlers();

/// Given a table of the 256 interrupt function pointers needed to handle every
/// possible interrupt, initialize the IDT.
pub fn createDefaultIDT() InterruptDescriptorTable {
    var entries: [256]InterruptDescriptor = undefined;
    for (interrupt_handler_table, 0..) |fn_ptr, interrupt_number| {
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
    ///
    /// This is essentially the index into the GDT you want shifted to the
    /// right by 3 bits (since those are guaranteed to be 0). So an index
    /// value of 0x1 in this struct is interpretted by the CPU as 0b1000.
    index: u13,

    const kernel_mode_code_segment: SegmentSelector = .{
        .requested_privilege_level = 0,
        .table_type = 0,
        .index = 0x1,
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
pub const InterruptDescriptor = packed struct(u64) {
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
const CpuState = extern struct {
    eax: u32,
    ebx: u32,
    ecx: u32,
    edx: u32,
    esi: u32,
    edi: u32,
    esp: u32,
    ebp: u32,
    eflags: u32,
};

export fn interruptHandlerWithoutErrorCode(
    cpu_state: CpuState,
    interrupt_number: u32,
) callconv(.c) void {
    asm volatile (
        \\movl %[tmp], %eax
        \\movl %[tmp_two], %ebx
        : // no outs
        : [tmp] "r" (interrupt_number),
          [tmp_two] "r" (&cpu_state),
    );

    //
    // TODO: Actual handling
}

export fn interruptHandlerWithErrorCode(
    cpu_state: CpuState,
    interrupt_number: u32,
    error_code: u32,
) callconv(.c) void {
    asm volatile (
        \\movl %[tmp], %eax
        \\movl %[tmp_two], %ebx
        \\movl %[tmp_three], %ecx
        : // no outs
        : [tmp] "r" (interrupt_number),
          [tmp_two] "r" (error_code),
          [tmp_three] "r" (&cpu_state),
    );

    //
    // TODO: Actual handling
}

/// General interrupt handler that pushes register state to stack and calls
/// the internal zig interrupt handler. This function will only be called
/// by each interrupt number's handler. That handler will have (optionally)
/// pushed an error code on the stack, and pushed it's interrupt number on the
/// stack (so it'll be on the top once registers are popped off).
export fn commonInteruptHandlerWithErrorCode() callconv(.naked) void {
    asm volatile (
        \\pushl %eax
        \\pushl %ebx
        \\pushl %ecx
        \\pushl %edx
        \\pushl %esi
        \\pushl %edi
        \\pushl %esp
        \\pushl %ebp
        \\pushfd
        \\
        \\call interruptHandlerWithErrorCode
        \\
        \\popfd
        \\popl %ebp
        \\popl %esp
        \\popl %edi
        \\popl %esi
        \\popl %edx
        \\popl %ecx
        \\popl %ebx
        \\popl %eax
        \\
        \\addl $0x4, %esp  // cleanup pushed interrupt number
        \\addl $0x4, %esp  // cleanup pushed error code
        \\
        \\iret
    );
}

export fn commonInteruptHandlerWithoutErrorCode() callconv(.naked) void {
    asm volatile (
        \\pushl %eax
        \\pushl %ebx
        \\pushl %ecx
        \\pushl %edx
        \\pushl %esi
        \\pushl %edi
        \\pushl %esp
        \\pushl %ebp
        \\pushfd
        \\
        \\call interruptHandlerWithoutErrorCode
        \\
        \\popfd
        \\popl %ebp
        \\popl %esp
        \\popl %edi
        \\popl %esi
        \\popl %edx
        \\popl %ecx
        \\popl %ebx
        \\popl %eax
        \\
        \\addl $0x4, %esp  // cleanup pushed interrupt number
        \\
        \\iret
    );
}

const InterruptNumber = union(enum) {
    withErrorCode: u32,
    withoutErrorCode: u32,
    picInterrupt: pic.irq_number,

    pub fn init(number: u32) InterruptNumber {
        return switch (number) {
            8, 10, 11, 12, 13, 14, 17 => .{ .withErrorCode = number },
            @intFromEnum(pic.irq_number.keyboard), @intFromEnum(pic.irq_number.timer) => .{
                .picInterrupt = @enumFromInt(number),
            },
            else => .{ .withoutErrorCode = number },
        };
    }

    pub fn get(this: InterruptNumber) u32 {
        return switch (this) {
            .picInterrupt => |enumerator| @intFromEnum(enumerator),
            .withErrorCode => |with| with,
            .withoutErrorCode => |without| without,
        };
    }
};

/// Generate interrupt handler functions at comptime, them take and store
/// their addresses at runtime. This should only be called at comptime,
/// generating functions doesn't make sense at runtime, and should not
/// compile anyway.
pub fn generateInterruptHandlers() InterruptHandlerTable {
    var table: [256]InterruptHandlerFnPtr = undefined;

    comptime {
        @setEvalBranchQuota(4096);
        for (0..table.len) |interrupt_number| {
            // .. range is not inclusive on the right
            const i: InterruptNumber = .init(interrupt_number);
            table[interrupt_number] = generateHandler(i);
        }
    }

    return table;
}

/// Generic function to generate an interrupt handler. This handler will push
/// an error code to the stack. This generic pattern is ued in place of macros,
/// which would be used if were using something like NASM for example.
fn generateHandler(
    comptime interrupt_number: InterruptNumber,
) InterruptHandlerFnPtr {
    const fn_pointer: InterruptHandlerFnPtr = switch (interrupt_number) {
        .withErrorCode => |num| &struct {
            fn handler() callconv(.naked) void {
                asm volatile (
                    \\pushl 0                    # push 0 as error code
                    \\pushl %[interrupt_number]  # push interrupt number
                    \\jmp commonInteruptHandlerWithErrorCode
                    : // no outputs
                    : [interrupt_number] "i" (num),
                );
            }
        }.handler,
        .withoutErrorCode => |num| &struct {
            fn handler() callconv(.naked) void {
                asm volatile (
                    \\pushl %[interrupt_number]  # push interrupt number
                    \\jmp commonInteruptHandlerWithoutErrorCode
                    : // no outputs
                    : [interrupt_number] "i" (num),
                );
            }
        }.handler,
        .picInterrupt => |irq| &struct {
            extern fn handleGenericPicIrq(irq_with_offset: u8) callconv(.c) void;
            fn handler() callconv(.naked) void {
                asm volatile (
                    \\pushl %[interrupt_number]
                    \\call handleGenericPicIrq
                    \\addl $0x4, %esp            # cleanup pushed interrupt
                    \\iret
                    : // no outputs
                    : [interrupt_number] "i" (@intFromEnum(irq)),
                );
            }
        }.handler,
    };

    comptime {
        const handler_number: u32 = interrupt_number.get();
        const handler_number_as_string: osformat.format.StringFromInt(u32) = .init(handler_number);
        const exported_name: []const u8 = "interrupt_handler_" ++ handler_number_as_string.getStr();
        @export(fn_pointer, .{ .name = exported_name });
    }

    return fn_pointer;
}
