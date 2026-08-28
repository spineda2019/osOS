//! This contains all build modules that are target architecture-agnostic and
//! can be used by common KERNEL code (e.g. kmain and scheduler should live
//! here). Should contain NO userland build modules.
//!
//! This is used as a glorified array where each element is named.
//! The build script uses comptime capabilities to iterate through the fields
//! when/where needed.

const OsModule = @import("../OsModule.zig");

osformat: OsModule,
osmemory: OsModule,
osprocess: OsModule,
osboot: OsModule,
oshal: OsModule,
oscontainers: OsModule,
osdtb: OsModule,

/// This is special
kmain: OsModule,
