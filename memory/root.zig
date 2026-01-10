// memory.zig - root module of the osOS kernel's architecture agnostic mem API
// Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pub const SpinLock = @import("SpinLock.zig");

pub fn runtimeMemset(ptr: [*]u8, value: u8, length: usize) void {
    var bytes_left: usize = length;
    var mutable_ptr: [*]u8 = ptr;

    while (bytes_left > 0) : ({
        bytes_left -= 1;
        mutable_ptr += 1;
    }) {
        mutable_ptr[bytes_left] = value;
    }
}
