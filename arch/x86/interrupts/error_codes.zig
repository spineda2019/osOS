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
//!
//! error_code.zig - Types expressing pushed error codes during interrupt
//! handling

pub const PageFault = packed struct(u32) {
    present: bool,
    write: bool,
    user: bool,
    reserved_write: bool,
    instruction_fetch: bool,
    protection_key: bool,
    shadow_stack: bool,
    _reserved: u8,
    sgx: bool,
    __reserved: u16,
};
