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

/// Size will be 48 bytes on x86. x64 is 79
pub const GlobalDescriptorTable = packed struct {
    address: u32,
    size: u16,

    /// "Modern" systems don't actually use segmentation for memory protection
    /// and use paging instead. From what forums and docs say, we should set up
    /// the GDT with the bare minimum in a flat model, and use paging.
    pub fn flatInit() GlobalDescriptorTable {}
};
