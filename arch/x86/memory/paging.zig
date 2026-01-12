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

pub const PAGE_SIZE: comptime_int = 4096;
const ENTRY_COUNT = 1024;

pub const PageDirectory = [ENTRY_COUNT]PageDirectoryEntry;
pub const uninitialized_directory: PageDirectory align(PAGE_SIZE) = .{
    PageDirectoryEntry.default,
} ** ENTRY_COUNT;

/// Must be aligned to 4KiB, or 4096 bytes.
pub const PageDirectoryEntry = packed struct(u32) {
    in_physical_memory: bool,
    writable: bool,
    userland_accesible: bool,
    write_through: u1,
    cache_disable: u1,
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
        .cache_disable = true,
        .accessed = false,
        .written_to = false,
        .enable_4mb_page_size = false,
        .page_table_address = 0,
    };
};

pub const PageTable = [ENTRY_COUNT]PageTableEntry;
pub const uninitialized_table: PageTable align(PAGE_SIZE) = .{
    PageTableEntry.default,
} ** ENTRY_COUNT;

/// Must be aligned to 4KiB, or 4096 bytes.
pub const PageTableEntry = packed struct(u32) {
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
        .cache_disable = true,
        .accessed = false,
        .written_to = false,
        .page_attribute_table = false,
        .global = false,
        .page_frame_address = 0,
    };
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
pub fn virtualToPhysical(virtualAddress: u32, pd: *const PageDirectory) u32 {
    const pd_index: u32 = (virtualAddress & 0b1111111111_0000000000000000000000) >> 22;
    const pt_index: u32 = (virtualAddress & 0b0000000000_1111111111_000000000000) >> 12;
    const offset: u32 = (virtualAddress & 0b0000000000_0000000000_111111111111);

    const pde: *const PageDirectoryEntry = &pd[pd_index];
    const pt: *const PageTable = @ptrFromInt(pde.page_table_address);
    const pte: *const PageTableEntry = &pt[pt_index];

    return @as(u32, pte.page_frame_address) + offset;
}

test virtualToPhysical {}
