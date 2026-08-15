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

pub const InlineOptions = struct {
    const std = @import("std");
    mode: std.builtin.CallModifier = .auto,
};

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

    pub inline fn indexFromVirtual(address: u32) u32 {
        return (address & 0b1111111111_0000000000000000000000) >> 22;
    }

    pub inline fn bitsFromIndex(index: u32) u32 {
        return (index << 22) & 0b1111111111_0000000000000000000000;
    }

    pub fn init(
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

/// Fill a single page table with coherent default values depending on the
/// desired physical base address
///
/// `table`: The table to fill
///
/// `physical_base`: The page-aligned _physical_ address of the first frame in
/// `table`
pub fn fillTable(
    table: *align(PAGE_SIZE) PageTable,
    physical_base: [*]allowzero align(PAGE_SIZE) const u8,
    map_immediately: bool,
) void {
    const base: usize = @intFromPtr(physical_base);
    for (table, 0..) |*entry, scale| {
        entry.*.writeable = true;
        entry.*.in_physical_memory = map_immediately;
        entry.*.page_frame_address = @truncate((base + (PAGE_SIZE * scale)) >> 12);
    }
}

pub fn mapFrame(
    table: *align(PAGE_SIZE) PageTable,
    index: usize,
    physical_addr: [*]allowzero align(PAGE_SIZE) const u8,
) void {
    if (index < table.len) {
        table[index].page_frame_address = @truncate(@intFromPtr(physical_addr) >> 12);
        table[index].writeable = true;
        table[index].cache_disable = true;
        table[index].in_physical_memory = true;
    }
}

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

    pub inline fn indexFromVirtual(address: u32) u32 {
        return (address & 0b0000000000_1111111111_000000000000) >> 12;
    }

    pub inline fn bitsFromIndex(index: u32) u32 {
        return (index << 12) & 0b0000000000_1111111111_000000000000;
    }
};

pub inline fn offsetFromVirtual(address: u32) u32 {
    return (address & 0b0000000000_0000000000_111111111111);
}

pub const Info = struct {
    page_directory: *align(PAGE_SIZE) PageDirectory,
    /// This default comptime value should be defined in the linker script.
    /// Unit tests can inject their own value here to no rely on any linker
    /// script.
    comptime virtual_kernel_base: u32 = 0xC0_00_00_00,

    /// Helper function to find the virtual address of the "this" pointer. That
    /// way users of this struct can get a virtual handle to an Info object that
    /// exists already in physical memory.
    pub fn virtualPD(self: *const Info) Error!*align(PAGE_SIZE) PageDirectory {
        const as_num: u32 = @intFromPtr(self.page_directory);
        const virt: MappingInfo = try self.physicalToVirtual(as_num);
        if (virt.map_count == 0) {
            return Error.VirtualSelfNotFound;
        } else {
            // get the "deepest" virtual address to avoid picking up the
            // identity mapping.
            // NOTE(SEP): Maybe don't assume?
            return @ptrFromInt(virt.virtual_mappings[virt.map_count - 1]);
        }
    }

    pub fn mapTable(
        self: *const Info,
        pt_to_use: *align(PAGE_SIZE) PageTable,
        virtual_address: usize,
        comptime inline_options: InlineOptions,
    ) void {
        const pd_idx: u32 = @call(
            inline_options.mode,
            PageDirectoryEntry.indexFromVirtual,
            .{virtual_address},
        );
        const pde: *PageDirectoryEntry = &self.page_directory[pd_idx];
        @call(inline_options.mode, PageDirectoryEntry.init, .{ pde, pt_to_use });
    }

    /// Sets up the higher half kernel by enabling paging and mapping
    /// the first 4MB starting at 0xC0_00_00_00 ()
    pub fn initHigherHalfPages(
        self: *const Info,
        pt_to_use: *align(PAGE_SIZE) PageTable,
        comptime inline_options: InlineOptions,
    ) void {
        comptime {
            // gives a clearer error code rather than cryptic u64 vs usize error
            if (@sizeOf(usize) > 4) {
                var err: []const u8 = "Only valid on 32 bit architectures. Here, ";
                err = err ++ "paging makes assumptions around sizeof(usize) being ";
                err = err ++ "equal to sizeof(u32)";
                @compileError(err);
            }
        }

        // Will map starting physical addresses 0x0 through
        // 1023*4096=4_194_304=0x3F_F0_00, spanning the actuall physical range of
        // 0x0 <- -> (1023*4096) + 4095 = 0x3F_FF_FF AKA the first 4 MiB.
        @call(
            inline_options.mode,
            fillTable,
            .{ pt_to_use, @as([*]allowzero align(PAGE_SIZE) const u8, @ptrFromInt(0)), true },
        );

        // identity maps first 4 MiB
        @call(inline_options.mode, mapTable, .{ self, pt_to_use, 0, inline_options });
    }

    /// Unmaps the PDE at index `at`
    pub fn unmapTable(self: *const Info, at: u32) void {
        if (at < self.page_directory.len) {
            self.page_directory[at].in_physical_memory = false;
        }
    }

    pub fn enablePaging(self: *const Info) void {
        as.assembly_wrappers.enablePaging(self.page_directory);
    }

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
        self: *const Info,
        virtualAddress: u32,
    ) ?u32 {
        const pd_index: u32 = PageDirectoryEntry.indexFromVirtual(virtualAddress);
        const pde: *const PageDirectoryEntry = &self.page_directory[pd_index];

        const pt: *align(PAGE_SIZE) const PageTable = @ptrFromInt(@as(u32, pde.page_table_address) << 12);
        const pt_index: u32 = PageTableEntry.indexFromVirtual(virtualAddress);
        const pte: *const PageTableEntry = &pt[pt_index];

        if (pte.in_physical_memory) {
            const offset: u32 = offsetFromVirtual(virtualAddress);
            return (@as(u32, pte.page_frame_address) << 12) + offset;
        } else {
            return null;
        }
    }

    pub const MappingInfo = struct {
        physical_address: u32,
        virtual_mappings: [16]u32,
        map_count: u8,

        pub const empty: MappingInfo = .{
            .physical_address = 0,
            .virtual_mappings = .{0} ** 16,
            .map_count = 0,
        };
    };

    /// Extracting a virtualAddress from a physical one is not as straight forward
    /// as the other way around. We pretty much have to do the reverse of virtual
    /// Address translation:
    pub fn physicalToVirtual(self: *const Info, physical_address: u32) Error!MappingInfo {
        var mapped: [16]u32 = undefined;
        var count: u8 = 0;

        for (self.page_directory, 0..) |*pde, pd_index| {
            if (!pde.in_physical_memory) {
                continue;
            }
            const top_10 = PageDirectoryEntry.bitsFromIndex(pd_index);

            const pt: *align(PAGE_SIZE) const PageTable = @ptrFromInt(@as(u32, pde.page_table_address) << 12);
            for (pt, 0..) |*pte, pt_index| {
                if (!pte.in_physical_memory) {
                    continue;
                }
                const next_10 = PageTableEntry.bitsFromIndex(pt_index);
                const candidate_virt = top_10 | next_10 | (@as(u32, pte.page_frame_address) >> 12);
                if (self.virtualToPhysical(candidate_virt) == physical_address) {
                    if (count < mapped.len) {
                        mapped[count] = candidate_virt;
                        count += 1;
                    } else {
                        return Error.MappedCountExceeded;
                    }
                }
            }
        }

        return .{
            .physical_address = physical_address,
            .virtual_mappings = mapped,
            .map_count = count,
        };
    }

    const Error = error{
        MappedCountExceeded,
        VirtualSelfNotFound,
    };
};

test Info {
    if (@sizeOf(usize) != 4) {
        return;
    }

    const std = @import("std");

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
    };

    page_info.initHigherHalfPages(&kernel_page_table, .{});

    var translated = if (page_info.virtualToPhysical(
        page_info.virtual_kernel_base,
    )) |addr| addr else return PageTableEntry.Error.not_paged;
    std.testing.expect(
        translated == 0,
    ) catch |err| {
        std.debug.print(
            "Expected virt address {x} to be translated to {x} but was instead {x}\n",
            .{ page_info.virtual_kernel_base, 0, translated },
        );
        return err;
    };

    translated = if (page_info.virtualToPhysical(
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

    const phys_map_list = try page_info.physicalToVirtual(0);
    for (phys_map_list.virtual_mappings, 0..) |mapped, idx| {
        if (idx >= phys_map_list.map_count) {
            std.testing.expect(false) catch |err| {
                std.debug.print(
                    "Expected phys address {x} to be mapped to {x} but was instead {}\n",
                    .{ 0, page_info.virtual_kernel_base, phys_map_list },
                );
                return err;
            };
        } else if (mapped == 0) {}
        {
            try std.testing.expect(true);
            break;
        }
    }
}
