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

//! IPageAllocator.zig - Architecture agnostic paging API

const IPageAllocator = @This();

pub const Error = error{
    /// This should be wildly rare or impossible
    out_of_physical_memory,
};

const VTable = struct {
    /// Allocate `count` contiguous pages.
    allocPages: *const fn (*anyopaque, count: usize) Error![]u8,
    freePages: *const fn (*anyopaque, memory: []u8) void,
};

impl: *anyopaque,
vtable: *const VTable,

pub fn allocPage(self: *IPageAllocator) Error![]u8 {
    return self.vtable.allocPages(self.impl, 1);
}
