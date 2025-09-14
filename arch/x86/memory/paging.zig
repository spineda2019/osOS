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

const PAGE_SIZE: comptime_int = 4096;

/// Represents a single Page Frame
pub const Page = struct {
    pub const Table = struct {
        /// A Table entry specifies the configuration and address for
        /// a single page _frame_.
        pub const Entry = packed struct(u32) {
            pub const Flags = packed struct(u12) {
                present: u1,
                read_write: u1,
                user_superuser: u1,
                write_through: u1,
                cache_disable: u1,
                accessed: u1,
                dirty: u1,
                pat: u1,
                global: u1,
                _unused: u3 = 0,
            };

            access_rights: Table.Entry.Flags,

            page_address: u20,
        };

        /// The real Page Table. A single entry is 4 bytes, and a single page
        /// table has 1024 entries, thus making each table (the owning type that
        /// has _entries_ as a member) 4096 bytes, explaining its required
        /// alignment.
        entries: [1024]Table.Entry align(PAGE_SIZE),

        /// Maps an entire 4K into memory. See _entries_ for details.
        pub fn init() Table {
            return .{
                .entries = setup: {
                    var entries: [1024]Table.Entry align(PAGE_SIZE) = undefined;

                    // Fill each index in the table with an address to which
                    // the MMU will map that page. Index 0 holds the address
                    // from where the first page will be mapped. index 1 holds
                    // the address for the second page, and so on.

                    for (&entries, 0..) |*entry, index| {
                        entry.* = .{
                            .access_rights = .{
                                .present = 1,
                                .read_write = 1,
                                .user_superuser = 1,
                                .write_through = 0,
                                .cache_disable = 0,
                                .accessed = 0,
                                .dirty = 0,
                                .pat = 0,
                                .global = 0,
                            },
                            .page_address = @intCast(index * 0x00_10_00),
                        };
                    }

                    break :setup entries;
                },
            };
        }

        /// A directory encapsulates everything the system knows about paging
        /// at a given moment. When paging is enabled, the register _cr3_ should
        /// hold the address of a valid Directory (which internally has
        /// knowledge of each table, which itself has knowledge of each mapped
        /// frame).
        pub const Directory = struct {
            /// A Directory entry specifies the configuration and address for
            /// a single page _table_.
            pub const Entry = packed struct(u32) {
                pub const Flags = packed struct(u12) {
                    /// A page fault will occur if this is false and the entry
                    /// is used.
                    in_physical_memory: bool,

                    /// Setting to false will set the entry to read-only.
                    writable: bool,

                    /// When set, all page tables in referenced in this page
                    /// directory entry can be accessed by all. If false, only
                    /// the kernel can access pages referenced in this entry.
                    user_accessible: bool,

                    enable_writethrough_caching: bool,

                    /// If set, page tables referenced by this Directory entry
                    /// will not be cached.
                    disable_caching: bool,

                    /// Indicates if this directory entry was accessed during
                    /// virtual address translation.
                    accessed: bool,

                    _reserved: u1 = 0,

                    /// When enabled, this entry actually points to a 4MB page
                    /// instead of a 4K page _table_. For now, no part of this
                    /// kernel will use this, so just set it to 0 by default.
                    use_4mb_page: bool = false,

                    __reserved: u4 = 0,
                };

                access_rights: Directory.Entry.Flags,

                table_address: u20,
            };

            /// The real Page Directory, the table of Page Tables (yes, a table
            /// of tables) represented as an array of a special type: the Page
            /// Directory Entry. A single entry is 32 bytes, and a single page
            /// directory (the owning type that has _entries_ as a member) has
            /// 1024 entries, thus making each directory (again, the owning type
            /// that has _entries_ as a member) 4096 bytes, explaining its
            /// required alignment.
            entries: [1024]Directory.Entry align(PAGE_SIZE),

            /// Enables paging using this instance of a Page Directory.
            pub fn enablePaging(self: *Directory) void {
                _ = self;
            }

            /// Initialize a completely empty Page Directory with all entries
            /// being marked as unused
            pub fn init() Directory {
                return .{
                    .entries = setup: {
                        var entries: [1024]Directory.Entry align(PAGE_SIZE) = undefined;
                        for (&entries) |*entry| {
                            entry.* = .{
                                .access_rights = .{
                                    .in_physical_memory = false,
                                    .writable = true,
                                    .user_accessible = false,
                                    .enable_writethrough_caching = false,
                                    .disable_caching = false,
                                    .accessed = false,
                                },
                                .table_address = 0,
                            };
                        }

                        break :setup entries;
                    },
                };
            }

            pub fn insertTable(self: *Directory, table: *Table) void {
                for (&self.entries) |*directory_entry| {
                    if (!directory_entry.*.access_rights.in_physical_memory) {
                        directory_entry.*.access_rights.in_physical_memory = true;
                        directory_entry.*.table_address = @intCast(@intFromPtr(table));
                        return;
                    }
                }

                // TODO: need to return an optional or error type
                unreachable;
            }
        };
    };
};
