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
pub const Page align(PAGE_SIZE) = struct {
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

        /// The real Page Table.
        entries: [1024]Table.Entry align(PAGE_SIZE),

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
                    user_accesible: bool,

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

            /// The real Page Directory, the table of Page Tables represented
            /// as an array of a special type: the Page Directory Entry.
            entries: [1024]Directory.Entry align(PAGE_SIZE),

            /// Enables paging using this instance of a Page Directory.
            pub fn enablePaging(self: *Directory) void {
                _ = self;
            }
        };
    };
};
