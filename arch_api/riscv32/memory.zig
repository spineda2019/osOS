// memory.zig - riscv32 memory allocation and APIs
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

const riscv32_common = @import("exception.zig");

pub const PageAllocater: type = struct {
    free_ram_start_address: u32,
    free_ram_end_address: u32,
    next_physical_address: u32,

    const page_size: u32 = 4096;

    pub fn init(ram_start: u32, ram_end: u32) PageAllocater {
        return PageAllocater{
            .free_ram_start_address = ram_start,
            .free_ram_end_address = ram_end,
            .next_physical_address = ram_start,
        };
    }

    pub fn allocate(self: *PageAllocater, requested: u32) u32 {
        // save the end boundary of the previously allocated page
        const physical_address: u32 = self.next_physical_address;

        // allocate requested number of pages
        self.next_physical_address += requested * page_size;

        // allocating past the end of free ram is pretty much unrecoverable
        if (self.next_physical_address > self.free_ram_end_address) {
            riscv32_common.panic(@src());
        }

        const real_address: *anyopaque = @ptrFromInt(physical_address);
        @memset(real_address[0..(requested * page_size)], 0);
        return physical_address;
    }
};
