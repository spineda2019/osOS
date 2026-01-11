//! memory.zig - Root file for x86 memory module
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

/// Module containing logic for setting up the Global Descriptor Table. Contains
/// logic and types for setting up Segment Descriptors, the GDT itself (just an
/// array of Segment Descriptors), and the GDT Descriptor, what is used to load
/// GDT.
pub const gdt = @import("gdt.zig");

pub const paging = @import("paging.zig");
