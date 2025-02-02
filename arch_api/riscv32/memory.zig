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

const page_size: u32 = 4096;

pub fn allocate_pages(page_count: u32) u32 {
    const static_wrapper = struct {
        // HACK: I hate this. I don't trust zig to keep this behavior
        // consistent, but for now this is how the book does it in C
        var next_physical_address: u32 = @intFromPtr(
            @import("kernel.zig").free_ram_start,
        );
    };

    const physical_address: u32 = static_wrapper.next_physical_address;
    static_wrapper.next_physical_address += page_count * page_size;

    if (static_wrapper.next_physical_address > @intFromPtr(
        @import("kernel.zig").free_ram_end,
    )) {
        riscv32_common.panic(@src());
    }

    const real_address: *anyopaque = @ptrFromInt(physical_address);
    @memset(real_address, 0);
    return physical_address;
}
