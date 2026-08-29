//! This contains all build modules used for build-time generation of other
//! project components. For example: generating code for the documentation site,
//! creating the ISO image, copying files for an emulator to boot the ISO, etc.
//!
//! This is used as a glorified array where each element is named.
//! The build script uses comptime capabilities to iterate through the fields
//! when/where needed.

const BuildTool = @import("../BuildTool.zig");

/// Set up the build directory with the necessary folder (and file) structure
/// to create an iso image from it.
setup_iso: BuildTool,
setup_bochs: BuildTool,
doccopy: BuildTool,
