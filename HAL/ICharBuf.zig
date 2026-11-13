const ICharBuf = @This();

/// Pointer to implementation.
///
/// Some implementations (like on x86) access a static port or memmapped region,
/// and thus don't have an implementation object that maintains state. That is
/// why this is a maybe pointer. In theory, I could just use `*anyopaque`, in
/// which case the vtable functions just won't use them, but I dislike putting
/// the onus on the implementor to ensure not to use the passed in ptr when I
/// could just encode it as nullable. Niche optimization makes this zero-extra
/// cost in the binary anyway (zig will just use `0` for nullptr)
impl: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    getChar: *const fn (opaque_self: ?*anyopaque) ?u8,
};

pub fn getLine(self: *const ICharBuf) void {
    _ = self;
}
