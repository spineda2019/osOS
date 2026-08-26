//! Modules used/ran for build time generation of some artifacts, such as
//! creating directories/copying files for creating the iso.

const std = @import("std");
const builtin = @import("builtin");
const BuildTool = @This();

name: []const u8,
exe: *std.Build.Step.Run,
test_exe: ?*std.Build.Step.Run,

pub const InitInfo = struct {
    b: *std.Build,
    root_source_file: std.Build.LazyPath,
    name: []const u8,
    create_tests: bool = true,
};

pub fn init(info: InitInfo) BuildTool {
    const mod = info.b.createModule(.{
        .root_source_file = info.root_source_file,
        .target = .{
            .query = .fromTarget(&builtin.target),
            .result = builtin.target,
        },
        .optimize = .Debug, // no need to optimize for generation (for now?)
    });

    const exe = info.b.addExecutable(.{
        .name = info.name,
        .root_module = mod,
    });

    exe.step.dependOn(info.b.getInstallStep());

    const test_exe: ?*std.Build.Step.Compile = blk: {
        if (info.create_tests) {
            break :blk info.b.addTest(.{ .root_module = mod });
        } else {
            break :blk null;
        }
    };

    const run_test: ?*std.Build.Step.Run = blk: {
        if (test_exe) |x| {
            break :blk info.b.addRunArtifact(x);
        } else {
            break :blk null;
        }
    };

    return .{
        .name = info.name,
        .exe = info.b.addRunArtifact(exe),
        .test_exe = run_test,
    };
}
