//! Page.zig - Root for paging logic on x86
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

pub const PAGE_SIZE: comptime_int = 4096;
pub const ENTRY_COUNT = 1024;

pub const PageDirectory = [ENTRY_COUNT]PageDirectoryEntry;

/// Must be aligned to 4KiB, or 4096 bytes.
pub const PageDirectoryEntry = packed struct(u32) {
    in_physical_memory: bool,
    writable: bool,
    userland_accesible: bool,
    write_through: bool,
    cache_disable: bool,
    /// Set if read during virtual address translation. CPU will not clear this
    /// bit EVER, so OS needs to do so if desired.
    accessed: bool,
    /// The dirty bit. This isn't specified in 4KiB mode, but this bit is
    /// guaranteed to be reserved for the OS, so we'll use this as the dirty
    /// bit.
    written_to: bool,
    enable_4mb_page_size: bool,
    _unused: u4 = 0,
    /// Remaining bits point to the actual page table. The table pointed to
    /// must be aligned to 4KiB, or 4096 bytes, as we are only working with
    /// the top 20 bits here.
    page_table_address: u20,

    pub const default: PageDirectoryEntry = .{
        .in_physical_memory = false,
        .writable = false,
        .userland_accesible = false,
        .write_through = false,
        .cache_disable = false,
        .accessed = false,
        .written_to = false,
        .enable_4mb_page_size = false,
        .page_table_address = 0,
    };

    pub inline fn IndexFromVirtual(address: u32) u32 {
        return (address & 0b1111111111_0000000000000000000000) >> 22;
    }

    pub fn basicInit(
        self: *PageDirectoryEntry,
        pt_to_use: *align(PAGE_SIZE) PageTable,
    ) void {
        self.* = .default;
        self.writable = true;
        self.page_table_address = @intCast(@intFromPtr(pt_to_use) >> 12);
        self.in_physical_memory = true;
    }
};

pub const PageTable = [ENTRY_COUNT]PageTableEntry;

/// Must be aligned to 4KiB, or 4096 bytes.
pub const PageTableEntry = packed struct(u32) {
    const Error = error{
        not_paged,
    };
    in_physical_memory: bool,
    writeable: bool,
    userland_accesible: bool,
    write_through: bool,
    cache_disable: bool,
    accessed: bool,
    /// The dirty bit.
    written_to: bool,
    page_attribute_table: bool,
    global: bool,
    _unused: u3 = 0,
    page_frame_address: u20,

    pub const default: PageTableEntry = .{
        .in_physical_memory = false,
        .writeable = false,
        .userland_accesible = false,
        .write_through = false,
        .cache_disable = false,
        .accessed = false,
        .written_to = false,
        .page_attribute_table = false,
        .global = false,
        .page_frame_address = 0,
    };

    pub inline fn IndexFromVirtual(address: u32) u32 {
        return (address & 0b0000000000_1111111111_000000000000) >> 12;
    }
};

pub inline fn offsetFromVirtual(address: u32) u32 {
    return (address & 0b0000000000_0000000000_111111111111);
}

pub const Info = struct {
    page_directory: *align(PAGE_SIZE) PageDirectory,
    virtual_kernel_base: u32,

    /// Sets up the higher half kernel by enabling paging and mapping
    /// the first 4MB starting at 0xC0_00_00_00 ()
    pub fn initHigherHalfPages(self: Info, pt_to_use: *align(PAGE_SIZE) PageTable) void {
        comptime {
            // gives a clearer error code rather than cryptic u64 vs usize error
            if (@sizeOf(usize) > 4) {
                var err: []const u8 = "Only valid on 32 bit architectures. Here, ";
                err = err ++ "paging makes assumptions around sizeof(usize) being ";
                err = err ++ "equal to sizeof(u32)";
                @compileError(err);
            }
        }

        const pd_index: u32 = PageDirectoryEntry.IndexFromVirtual(
            self.virtual_kernel_base,
        );
        const pde: *PageDirectoryEntry = &self.page_directory[pd_index];
        pde.basicInit(pt_to_use);

        // Will map starting physical addresses 0x0 through
        // 1023*4096=4_194_304=0x3F_F0_00, spanning the actuall physical range of
        // 0x0 <- -> (1023*4096) + 4095 = 0x3F_FF_FF AKA the first 4 MiB.
        for (pt_to_use, 0..) |*entry, idx| {
            const scale: u32 = (idx);
            entry.*.writeable = true;
            entry.*.in_physical_memory = true;
            entry.*.page_frame_address = @truncate((PAGE_SIZE * scale) >> 12);
        }

        // We also have to identity map the first 4mb to make the kernel not crash
        // when paging is turned on.
        const first_pde: *PageDirectoryEntry = &self.page_directory[0];
        first_pde.basicInit(pt_to_use);
    }

    pub fn enablePaging(self: Info) void {
        as.assembly_wrappers.enablePaging(self.page_directory);
    }
};

/// Virtual to Physical Transation does the following (largely ripped from
/// the OSDev Wiki). A Virtual Address is 32 bits and is translated by extracting
/// three parts from the virtual address.
///
/// 1) The most significant 10 bits (22-31) specify the index into the page
/// directory. A u10 can represent numbers in the range [0, 1023], meaning it
/// can index the whole array of PageDirectoryEntry's (see PageDirectory and
/// PageDirectoryEntry)
///
/// 2) The next 10 bits (12-21) specify the index into the page table indexed
/// from part 1. For the same reason from part 1, this u10 can index into every
/// PageTableEntry (see PageTable and PageTableEntry).
///
/// 3) The remaining bits, which are the least significant 12 bits (0-11),
/// specify an offset. Remeber, each page frame is aligned to 4096 bytes, so
/// once (1) and (2) get us a page table entry, we use the offset from these
/// 12 bits and add it to the frame address specified in the table entry. A u12
/// can represent numbers in the range [0, 4095], so this offset will NEVER
/// result in an address residing in another frame.
pub fn virtualToPhysical(
    pd: *align(PAGE_SIZE) const PageDirectory,
    virtualAddress: u32,
) ?u32 {
    const pd_index: u32 = PageDirectoryEntry.IndexFromVirtual(virtualAddress);
    const pde: *const PageDirectoryEntry = &pd[pd_index];

    const pt: *align(PAGE_SIZE) const PageTable = @ptrFromInt(@as(u32, pde.page_table_address) << 12);
    const pt_index: u32 = PageTableEntry.IndexFromVirtual(virtualAddress);
    const pte: *const PageTableEntry = &pt[pt_index];

    if (pte.in_physical_memory) {
        const offset: u32 = offsetFromVirtual(virtualAddress);
        return (@as(u32, pte.page_frame_address) << 12) + offset;
    } else {
        return null;
    }
}

/// Extracting a virtualAddress from a physical one is not as straight forward
/// as the other way around. We pretty much have to do the reverse of virtual
/// Address translation:
///
/// 1) Strip off the offset to find which index into the PageTable you are
///
pub fn physicalToVirtual(_: u32, _: *const PageDirectory) u32 {
    return 0;
}

test virtualToPhysical {
    const std = @import("std");

    const virtual_kernel_base: u32 = 0xC0_00_00_00;
    const physical_framebuffer_start = 0x00_0B_80_00;
    const virtual_framebuffer_start = 0xC0_0B_80_00;

    var page_directory: PageDirectory align(PAGE_SIZE) = .{
        PageDirectoryEntry.default,
    } ** ENTRY_COUNT;
    var kernel_page_table: PageTable align(PAGE_SIZE) = .{
        PageTableEntry.default,
    } ** ENTRY_COUNT;

    const page_info: Info = .{
        .page_directory = &page_directory,
        .virtual_kernel_base = virtual_kernel_base,
    };

    page_info.initHigherHalfPages(&kernel_page_table);

    var translated = if (virtualToPhysical(
        &page_directory,
        virtual_kernel_base,
    )) |addr| addr else return PageTableEntry.Error.not_paged;
    std.testing.expect(
        translated == 0,
    ) catch |err| {
        std.debug.print(
            "Expected virt address {x} to be translated to {x} but was instead {x}\n",
            .{ virtual_kernel_base, 0, translated },
        );
        return err;
    };

    translated = if (virtualToPhysical(
        &page_directory,
        virtual_framebuffer_start,
    )) |addr| addr else return PageTableEntry.Error.not_paged;
    std.testing.expect(
        translated == physical_framebuffer_start,
    ) catch |err| {
        std.debug.print(
            "Expected virt address {x} to be translated to {x} but was instead {x}\n",
            .{ virtual_framebuffer_start, physical_framebuffer_start, translated },
        );
        return err;
    };
}

test Info {}
