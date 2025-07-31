//! structure representing the plic and associated functions
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

const Self = @This();

/// TODO: do not hardcode; get from parsing DTB
const plic_base_address: *volatile u32 = 0xc000000;

const uart_0_interrupt_request: comptime_int = 10;
const virt_io_0_interrupt_request: comptime_int = 1;

pub fn init() Self {
    const uart_int_address: *volatile u32 = comptime plic_base_address + (uart_0_interrupt_request * 4);
    uart_int_address.* = 1;

    const virt_int_address: *volatile u32 = comptime plic_base_address + (virt_io_0_interrupt_request * 4);
    virt_int_address.* = 1;

    return .{};
}
