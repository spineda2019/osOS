const riscv32_common = @import("common.zig");

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
