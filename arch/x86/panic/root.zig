const as = @import("x86asm");
const io = @import("x86io");
const std = @import("std");

pub var virt_fb_addr: ?u32 = null;

pub fn handlePanic(msg: []const u8, start_address: ?usize) noreturn {
    @branchHint(.cold);
    as.assembly_wrappers.disable_x86_interrupts();

    if (virt_fb_addr) |fb_start| {
        var framebuffer: io.FrameBuffer = .init(.Black, .White, fb_start);
        framebuffer.clear();

        var writer_buf: [256]u8 = undefined;
        var fb_writer = framebuffer.writer(&writer_buf);

        fb_writer.writef("Kernel Panic! Message: {s}\n", .{msg});

        // subtract to get the previous address, i.e. the caller of panic
        const call_instruction_size = comptime 5;
        const return_addr = @returnAddress() - call_instruction_size;

        fb_writer.writef("Suspected panic-caller address: 0x{x}\n", .{return_addr});

        const start: usize = start_address orelse return_addr;
        _ = start;

        const si = std.debug.getSelfDebugInfo() catch {
            fb_writer.writef("Could not get SelfInfo\n", .{});
        };
        fb_writer.writef("SelfInfo address: 0x{x}\n", .{@intFromPtr(si)});

        fb_writer.flush();
    }

    while (true) {
        asm volatile ("");
    }
}
