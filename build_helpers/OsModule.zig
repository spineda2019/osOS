const std = @import("std");
const builtin = @import("builtin");
const OsModule = @This();

name: ?[]const u8,
/// This module's final build target will be determined by its consumer. For
/// example, if this is an ArchAgnostic module (like osformat), the concrete
/// kernel target (e.g. x76, riscv32, etc) will determine the modules output
/// arch
module: *std.Build.Module,
test_artifact: TestArtifact,
emitted_doc_directory: std.Build.LazyPath,

const TestArtifact = struct {
    compile: *std.Build.Step.Compile,
    run: *std.Build.Step.Run,
};

pub const InitInfo = struct {
    b: *std.Build,
    name: ?[]const u8,
    root_source_file: std.Build.LazyPath,
    /// Overriding the target is useful on targets that can use qemu/wine,
    /// like linux. Rarely, some tests (e.g. paging tests) require running on
    /// a 32 bit target
    test_target: std.Build.ResolvedTarget = .{
        .query = .fromTarget(&builtin.target),
        .result = builtin.target,
    },
    run_target: ?std.Build.ResolvedTarget = null,
    optimize: ?std.builtin.OptimizeMode = null,
};

pub fn init(info: InitInfo) OsModule {
    const actual_module = info.b.createModule(.{
        .root_source_file = info.root_source_file,
        .target = info.run_target,
        .optimize = info.optimize,
    });

    const test_exe = info.b.addTest(.{
        .root_module = info.b.createModule(.{
            .root_source_file = info.root_source_file,
            .target = if (info.run_target) |run| run else info.test_target,
        }),
    });

    if (info.name) |n| {
        const description = std.fmt.allocPrint(
            info.b.allocator,
            "Build {s} module",
            .{n},
        ) catch @panic("OOM");
        const step = info.b.step(n, description);
        step.dependOn(&test_exe.step);
    }

    return .{
        .name = info.name,
        .module = actual_module,
        .emitted_doc_directory = test_exe.getEmittedDocs(),
        .test_artifact = .{
            .compile = test_exe,
            .run = info.b.addRunArtifact(test_exe),
        },
    };
}

pub fn addImportToAll(self: *OsModule, other: *const OsModule) void {
    if (other.name) |name| {
        self.module.addImport(name, other.module);
        self.test_artifact.compile.root_module.addImport(
            name,
            other.test_artifact.compile.root_module,
        );
    }
}

pub fn addOptionsToAll(
    self: *OsModule,
    name: []const u8,
    options: *std.Build.Step.Options,
) void {
    self.module.addOptions(name, options);
    self.test_artifact.compile.root_module.addOptions(name, options);
}

pub fn addAnonymousImportToAll(self: *OsModule, name: []const u8, options: std.Build.Module.CreateOptions) void {
    self.module.addAnonymousImport(name, options);
    self.test_artifact.compile.root_module.addAnonymousImport(name, options);
}
