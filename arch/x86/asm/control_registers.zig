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
//! constrol_registers.zig - Types expressing x86 control registers and their
//! state (e.g. CR0 and if paging is enabled)

pub const CR0 = packed struct(u32) {
    /// Bit 0. Commonly labeled 'PE'
    ///
    /// True if in protected mode, false if in real mode.
    protected_mode_enable: bool,

    /// Bit 1. Commonly labeled 'MP'
    ///
    /// TODO(SEP): Find documentation for this bit and add here
    monitor_coprocessor: bool,

    /// Bit 2. Commonly labeled 'EM'
    ///
    /// True there is no x87 FPU, false if present
    no_x87_fpu_emulation: bool,

    /// Bit 3. Commonly labeled 'TS'
    ///
    /// TODO(SEP): Find documentation for this bit and add here
    task_switched: bool,

    /// Bit 4. Commonly labeled 'ET'
    ///
    /// Seems specific to the 386. Specifies if external math coprocessor was
    /// an 80287 or 80387
    extension_type: bool,

    /// Bit 5. Commonly labeled 'NE'
    ///
    /// Only on the 486 and later. Enables internal x87 floating point error
    /// reporting when set to true. Otherwise, enables "PC-style error
    /// reporting from the internal floating-point unit using external logic"
    /// (from wikipedia) style when set to false
    numeric_error: bool,

    _reserved: u10,

    /// Bit 16. Commonly labeled 'WP'
    ///
    /// When set, the CPU cannot write to read-only pages when privilege level
    /// is 0 (kernel mode).
    write_protect: bool,

    __reserved: u1,

    /// Bit 18. Commonly labeled 'AM'
    ///
    /// One of many flags to specify alignment checking. Alignment checking is
    /// enabled if this, AC in EFLAGS, and AND privilege level is set to 3
    /// (user mode)
    alignment_mask: bool,

    ___reserved: u10,

    /// Bit 29. Commonly labeled 'NW'
    not_write_through: bool,

    /// Bit 30. Commonly labeled 'CD'
    cache_disable: bool,

    /// Bit 31. Commonly labeled 'PG'
    paging_enabled: bool,
};
