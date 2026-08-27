//! This ccontains all build modules specific to the x86 port of the
//! project. This is used as a glorified array where each element is named.
//! The build script uses comptime capabilities to iterate through the fields
//! when/where needed.
const OsModule = @import("../OsModule.zig");

asm_module: OsModule,
io_module: OsModule,
memory_module: OsModule,
interrupts_module: OsModule,
boot_info: OsModule,

kernel_entry: OsModule,
