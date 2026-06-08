/// This type must expose the following declarations:
const SelfInfo = @This();
const Error = std.debug.SelfInfoError;
const std = @import("std");
const builtin = @import("builtin");

pub const init: SelfInfo = .{};

/// Whether a reliable stack unwinding strategy, such as DWARF unwinding, is
/// available.
pub const can_unwind: bool = builtin.mode == .Debug;

pub fn deinit(_: *SelfInfo, _: std.Io) void {
    @compileError("Deinit unsupported");
}

/// Appends the symbols for the instruction at `address` to `symbols`.
pub fn getSymbols(
    si: *SelfInfo,
    io: std.Io,
    symbol_allocator: std.mem.Allocator,
    text_arena: std.mem.Allocator,
    address: usize,
    incsym_lude_inline_callers: bool,
    symbols: *std.ArrayList(std.debug.Symbol),
) std.debug.SelfInfoError!void {
    // TODO(SEP)
    _ = si;
    _ = io;
    _ = symbol_allocator;
    _ = text_arena;
    _ = address;
    _ = incsym_lude_inline_callers;
    _ = symbols;
    @compileError("TODO");
}

/// Returns a name for the "module" (e.g. shared library or executable image) containing `address`.
pub fn getModuleName(
    si: *SelfInfo,
    io: std.Io,
    address: usize,
) std.debug.SelfInfoError![]const u8 {
    // TODO(SEP)
    _ = si;
    _ = io;
    _ = address;
    @compileError("TODO");
}

pub fn getModuleSlide(
    si: *SelfInfo,
    io: std.Io,
    address: usize,
) std.debug.SelfInfoError!usize {
    // TODO(SEP)
    _ = si;
    _ = io;
    _ = address;
    @compileError("TODO");
}

/// Only required if `can_unwind == true`.
pub const UnwindContext = struct {
    /// An address representing the instruction pointer in the last frame.
    pc: usize,

    pub fn init(
        ctx: *const std.debug.cpu_context.Native,
    ) UnwindContext {
        // TODO(SEP)
        return .{ .pc = ctx.getFp() };
    }
    pub fn deinit(_: *UnwindContext) void {}
    /// Returns the frame pointer associated with the last unwound stack frame.
    /// If the frame pointer is unknown, 0 may be returned instead.
    pub fn getFp(_: *UnwindContext) usize {
        // TODO(SEP)
        @compileError("TODO");
    }
};
/// Only required if `can_unwind == true`. Unwinds a single stack frame, returning the frame's
/// return address, or 0 if the end of the stack has been reached.
pub fn unwindFrame(
    si: *SelfInfo,
    io: std.Io,
    context: *UnwindContext,
) std.debug.SelfInfoError!usize {
    // TODO(SEP)
    _ = si;
    _ = io;
    _ = context;
    @compileError("TODO");
}

pub fn getDebugInfoAllocator() std.mem.Allocator {
    const FailingAllocator = struct {
        pub fn allocator(self: *@This()) std.mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = &struct {
                        fn impl(_: *anyopaque, _: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
                            return null;
                        }
                    }.impl,
                    .resize = &struct {
                        fn impl(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
                            return false;
                        }
                    }.impl,
                    .remap = &struct {
                        fn impl(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
                            return null;
                        }
                    }.impl,
                    .free = &struct {
                        fn impl(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {}
                    }.impl,
                },
            };
        }
    };

    const failing: FailingAllocator = .{};
    _ = failing;
    @compileError("TODO");
}
