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

/// Represents a single Page Frame
pub const Page align(4096) = packed struct(u4096) {
    pub const Table align(4096) = packed struct(u4096) {
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

        entries: [1024]Table.Entry,

        /// A directory encapsulates everything the system knows about paging
        /// at a given moment. When paging is enabled, the register _cr3_ should
        /// hold the address of a valid Directory (which internally has
        /// knowledge of each table, which itself has knowledge of each mapped
        /// frame).
        pub const Directory align(4096) = packed struct(u4096) {
            /// A Directory entry specifies the configuration and address for
            /// a single page _table_.
            pub const Entry = packed struct(u32) {
                pub const Flags = packed struct(u12) {
                    present: u1,
                    read_write: u1,
                    user_supervisor: u1,
                    write_through: u1,
                    cache_disable: u1,
                    accessed: u1,
                    _reserved: u1 = 0,
                    page_size: u1,
                    __reserved: u4 = 0,
                };

                access_rights: Directory.Entry.Flags,

                table_address: u20,
            };

            entries: [1024]Directory.Entry,

            /// Enables paging using this instance of a Page Directory.
            pub fn enablePaging(self: *Directory) void {
                _ = self;
            }
        };
    };
};
