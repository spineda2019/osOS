name: [*:0]const u8,
cmdline: ?[*:0]const u8,

/// Whether or not the boot environment passed verification, such as
/// checking a multiboot 1 bootloader's magic number against 0xbadb002
valid: bool,

diagnostic: [80]u8,
