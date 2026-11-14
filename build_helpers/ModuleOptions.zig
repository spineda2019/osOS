//! Central type for storing compile-time values that are added as imports into
//! zig modules in the project being built. Not to be confused with
//! `BuildOptions`, which is the central type for storing user defined runtime
//! options.

const std = @import("std");
const ModuleOptions = @This();

testing: *std.Build.Step.Options,
boot: *std.Build.Step.Options,
mem: *std.Build.Step.Options,

pub fn init(b: *std.Build) ModuleOptions {
    return .{
        .testing = b.addOptions(),
        .boot = b.addOptions(),
        .mem = b.addOptions(),
    };
}
