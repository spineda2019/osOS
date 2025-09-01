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

pub const HalLayout = struct {
    /// namespace where architecture specific (duh?) functions are defined.
    assembly_wrappers: type,

    /// Provides low level services such as putting characters on the screen
    /// and scrolling
    Terminal: type,
};

pub fn HAL(comptime layout: HalLayout) type {
    return struct {
        comptime assembly_wrappers: type = layout.assembly_wrappers,

        /// Must be implemented. Pointer to an architecture's implemetation
        /// of a terminal for reading and writing
        terminal: *layout.Terminal,
    };
}
