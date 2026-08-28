//! This contains all build modules that are target architecture-agnostic and
//! can be used by common USERLAND code (e.g. the init process and kernel stdlib
//! should live here). Should contain NO kernel build modules.
//!
//! This is used as a glorified array where each element is named.
//! The build script uses comptime capabilities to iterate through the fields
//! when/where needed.

const OsModule = @import("../OsModule.zig");

/// The kernel API stdlib like "sys/*.h" on linux
sys: OsModule,
/// The first userland process, just the shell
shell: OsModule,
