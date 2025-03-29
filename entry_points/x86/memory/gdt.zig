//! gdt.zig - Structures && Methods for loading the GlobalDescriptorTable
//!
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

/// TODO: Make init functions return an error if they fail
const SegmentDescriptorError = error{};

/// Essentially a fat pointer to our actual table structure. To properly set up
/// the GDT, a pointer poitning to this structure must be loaded into the GDTR
/// register (using the lgdt instruction). This 48 byte structure is specific
/// to x86. x64 has a 79 bit structure
pub const GDTDescriptor = struct {
    /// Linear address of the actual Global Descriptor Table
    address: u32,

    /// size of the actual table structure in bytes MINUS 1.
    size: u16,

    /// Given a created table structure, setup this structure type to feed to
    /// the GDTR register
    pub fn init(table: GlobalDescriptorTable) GDTDescriptor {
        return .{
            .address = @as(u32, @intFromPtr(&table)),
            .size = @truncate(@sizeOf(GlobalDescriptorTable) - 1),
        };
    }

    pub fn loadGDT(self: *const GDTDescriptor) void {
        as.assembly_wrappers.x86_lgdt(@intFromPtr(self));
    }
};

/// Create a GDT with only the null descriptor, and a data and code segment for
/// both kernel mode and user mode.
pub fn createDefaultGDT() [5]SegmentDescriptor {
    return .{
        SegmentDescriptor.null_descriptor, // offset 0x0
        SegmentDescriptor.kernel_mode_code_segment, // offset 0x8 AKA 64 bytes
        SegmentDescriptor.kernel_mode_data_segment, // offset 0x10 AKA 128 bytes
        SegmentDescriptor.user_mode_code_segment, // offset 0x18 AKA 192 bytes
        SegmentDescriptor.user_mode_data_segment, // offset 0x20 AKA 256 bytes
    };
}

/// The GDT is essentially just an array of 64 bit values. Our default GDT
/// will have a comptime known size, but in theory an arbitrary GDT can have
/// any size.
pub const GlobalDescriptorTable = []const SegmentDescriptor;

/// Each entry in the GDT is 64 bytes long. All Base and Limit fields are
/// ignored in 64 bit mode.
pub const SegmentDescriptor = packed struct {
    /// 20 bit value (shared among this field and higher limit). Tells the
    /// maximum addressable unit either in 1 byte units or 4KiB pages.
    /// All 20 bits being set with a granularity of 4KiB will describe a segment
    /// spanning the entire 4GiB address space
    lower_limit: u16,

    /// 32 bit value (shared among this field, higher_base, and
    /// higher_base_final). Contains the linear address where the segment
    /// this is describing begins.
    lower_base: u16,

    /// 32 bit value (shared among this field, lower_base, and
    /// higher_base_final). Contains the linear address where the segment
    /// this is describing begins.
    higher_base: u8,

    /// Sets properties for the segment we are describing. Has the form of:
    ///
    /// Bit:     | 7 | 6 5 | 4 | 3 | 2  | 1  | 0 |
    /// Content: | P | DPL | S | E | DC | RW | A |
    ///
    /// A: Accessed Bit. CPU sets this to 1 when the segment is accessed (unless
    /// initialized to 1). Setting will trigger a page fault if this is in RO
    /// memory.
    ///
    /// RW: Readable/Writable bit. For code segments: Readable bit. If clear
    /// (0), read access for this segment is not allowed. If set (1) read access
    /// is allowed. Write access is never allowed for code segments.
    /// For data segments: Writeable bit. If clear (0), write access for this
    /// segment is not allowed. If set (1) write access is allowed. Read access
    /// is always allowed for data segments.
    ///
    /// DC: Direction Bit/Conforming Bit. For data selectors: Direction bit.
    /// If clear (0) the segment grows up. If set (1) the segment grows down,
    /// ie. the Offset has to be greater than the Limit.
    /// For code selectors: Conforming bit.
    /// If clear (0) code in this segment can only be executed from the ring set
    /// in DPL. If set (1) code in this segment can be executed from an equal or
    /// lower privilege level. For example, code in ring 3 can far-jump to
    /// conforming code in a ring 2 segment. The DPL field represent the highest
    /// privilege level that is allowed to execute the segment. For example,
    /// code in ring 0 cannot far-jump to a conforming code segment where DPL is
    /// 2, while code in ring 2 and 3 can. Note that the privilege level remains
    /// the same, ie. a far-jump from ring 3 to a segment with a DPL of 2
    /// remains in ring 3 after the jump.
    ///
    /// E: Executable bit. If clear (0) the descriptor defines a data segment.
    /// If set (1) it defines a code segment which can be executed from
    ///
    /// S: Descriptor type bit. If clear (0) the descriptor defines a system
    /// segment (eg. a Task State Segment). If set (1) it defines a code or data
    /// segment.
    ///
    /// DPL: Descriptor privilege Level. Descriptor privilege level field.
    /// Contains the CPU Privilege level of the segment. 0 = highest privilege
    /// (kernel), 3 = lowest privilege (user applications).
    ///
    /// P: Present bit. Allows an entry to refer to a valid segment. Must be set
    /// (1) for any valid segment.
    access_byte: u8,

    /// 20 bit value (shared among this field and lower limit). Tells the
    /// maximum addressable unit either in 1 byte units or 4KiB pages.
    /// All 20 bits being set with a granularity of 4KiB will describe a segment
    /// spanning the entire 4GiB address space
    higher_limit: u4,

    /// Sets flags for how this segment encodes information. In the form of:
    ///
    /// Bit:     | 3 | 2  | 1  | 0               |
    /// Content: | G | DB | L  | Reserved/Unused |
    ///
    /// L: Long-mode code flag. If set (1), the descriptor defines a 64-bit code
    /// segment. When set, DB should always be clear. For any other type of
    /// segment (other code types or any data segment), it should be clear (0).
    ///
    /// DB: Size flag. If clear (0), the descriptor defines a 16-bit protected
    /// mode segment. If set (1) it defines a 32-bit protected mode segment. A
    /// GDT can have both 16-bit and 32-bit selectors at once.
    ///
    /// G: Granularity flag. Indicates the size the Limit value is scaled by. If
    /// clear (0), the Limit is in 1 Byte blocks (byte granularity). If set (1),
    /// the Limit is in 4 KiB blocks (page granularity).
    flags: u4,

    /// 32 bit value (shared among this field, lower_base, and
    /// higher_base). Contains the linear address where the segment
    /// this is describing begins.
    higher_base_final: u8,

    /// Helper function to create a Segmenr Descriptor (since an entry is kind
    /// of complex and fields are split up).
    ///
    /// limit: Tells the maximum addressable unit either in 1 byte units or 4KiB
    /// pages.
    ///
    /// base: Contains the linear address where the segment this is describing
    /// begins.
    ///
    /// access_byte:
    ///
    /// flags:
    pub fn create(
        limit: u20,
        base: u32,
        access_byte: u8,
        flags: u4,
    ) SegmentDescriptorError!SegmentDescriptor {
        return SegmentDescriptor{
            .lower_limit = @truncate(limit & 0b0000_1111_1111_1111_1111),
            .higher_limit = @truncate(
                (limit & 0b1111_0000_0000_0000_0000) >> 16,
            ),
            .lower_base = @truncate(
                base & 0b0000_0000_0000_0000_1111_1111_1111_1111,
            ),
            .higher_base = @truncate(
                (base & 0b0000_0000_1111_1111_0000_0000_0000_0000) >> 16,
            ),
            .higher_base_final = @truncate(
                (base & 0b1111_1111_0000_0000_0000_0000_0000_0000) >> 24,
            ),
            .access_byte = access_byte,
            .flags = flags,
        };
    }

    pub const null_descriptor: SegmentDescriptor = .{
        .higher_limit = 0,
        .lower_limit = 0,
        .lower_base = 0,
        .higher_base = 0,
        .higher_base_final = 0,
        .access_byte = 0,
        .flags = 0,
    };

    pub const kernel_mode_code_segment: SegmentDescriptor = .{
        .higher_limit = 0b1111,
        .lower_limit = 0b1111_1111_1111_1111,
        .lower_base = 0,
        .higher_base = 0,
        .higher_base_final = 0,
        .access_byte = 0b10011010,
        .flags = 0b1100,
    };

    pub const kernel_mode_data_segment: SegmentDescriptor = .{
        .higher_limit = 0b1111,
        .lower_limit = 0b1111_1111_1111_1111,
        .lower_base = 0,
        .higher_base = 0,
        .higher_base_final = 0,
        .access_byte = 0b10010010,
        .flags = 0b1100,
    };

    pub const user_mode_code_segment: SegmentDescriptor = .{
        .higher_limit = 0b1111,
        .lower_limit = 0b1111_1111_1111_1111,
        .lower_base = 0,
        .higher_base = 0,
        .higher_base_final = 0,
        .access_byte = 0b11111010,
        .flags = 0b1100,
    };

    pub const user_mode_data_segment: SegmentDescriptor = .{
        .higher_limit = 0b1111,
        .lower_limit = 0b1111_1111_1111_1111,
        .lower_base = 0,
        .higher_base = 0,
        .higher_base_final = 0,
        .access_byte = 0b11110010,
        .flags = 0b1100,
    };
};

test "table" {}
