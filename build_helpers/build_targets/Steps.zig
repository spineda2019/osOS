const std = @import("std");
const Steps = @This();

build_all: *std.Build.Step,
build_docs: *std.Build.Step,
build_iso: *std.Build.Step,
build_kernel: *std.Build.Step,
build_shell: *std.Build.Step,

run: *std.Build.Step,
test_: *std.Build.Step,

pub fn init(b: *std.Build) Steps {
    return .{
        .build_all = b.step(
            "all",
            "Build the Kernel for all supported architectures",
        ),
        .build_docs = b.step(
            "doc_site",
            "Build all docs and tie them together with the landing page",
        ),
        .build_iso = b.step("iso", "Build the x86 ISO disc image"),
        .build_kernel = b.step(
            "kernel",
            "Build (just) the kernel for just the specified target",
        ),
        .run = b.step(
            "run",
            "Boot kernel for specified target (x86 by default)",
        ),
        .test_ = b.step(
            "test",
            "Run arch-agnostic unit tests (Runnable from any host)",
        ),
        .build_shell = b.step("shell", "Build the userland shell"),
    };
}
