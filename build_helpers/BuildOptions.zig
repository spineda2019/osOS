const BuildOptions = @This();

const std = @import("std");
const builtin = @import("builtin");
const enums = @import("enums.zig");

default_run_target: enums.SupportedTarget,
boot_info: enums.BootLoadInfo,
emulator: enums.Emulator,
test_panic: bool,
test_illegal_instruction: bool,
build_bochs: bool,
use_debugger: bool,
build_schilytools: bool,

pub fn init(b: *std.Build) BuildOptions {
    return .{
        .default_run_target = b.option(
            enums.SupportedTarget,
            "arch",
            "Target Architecture",
        ) orelse .x86,
        .boot_info = blk: {
            const boot_spec = b.option(
                enum {
                    multiboot_one,
                    multiboot_two,
                    limine,
                },
                "boot_specification",
                "Boot specification to boot the kernel with",
            ) orelse .multiboot_one;

            const boot_loader = b.option(
                enum {
                    grub_legacy,
                    limine,
                },
                "bootloader",
                "Bootloader to boot the kernel with",
            ) orelse .limine;

            break :blk switch (boot_loader) {
                .limine => switch (boot_spec) {
                    .multiboot_one => .{ .limine = .multiboot_one },
                    .multiboot_two => .{ .limine = .multiboot_two },
                    .limine => .{ .limine = .limine },
                },
                .grub_legacy => switch (boot_spec) {
                    .multiboot_one => .{ .grub_legacy = .multiboot_one },
                    else => |other| std.debug.panic(
                        "Invalid multiboot spec for grub_legacy: {s}",
                        .{@tagName(other)},
                    ),
                },
            };
        },
        .test_panic = b.option(
            bool,
            "test_panic",
            "Test the panic handler in kmain",
        ) orelse false,
        .test_illegal_instruction = b.option(
            bool,
            "test_ill",
            "Test the runtime illegal CPU instruction handler",
        ) orelse false,
        .build_bochs = b.option(
            bool,
            "build_bochs",
            "Build bochs from source",
        ) orelse true,
        .emulator = b.option(
            enums.Emulator,
            "emulator",
            "Emulator to use when running the OS",
        ) orelse .qemu,
        .use_debugger = b.option(
            bool,
            "debugger",
            "Enable usage of the debugger associated with the selected emulator",
        ) orelse false,
        .build_schilytools = b.option(
            bool,
            "build_schilytools",
            "Build schilytools for iso creation from source",
        ) orelse (builtin.os.tag == .linux),
    };
}

pub fn bootBinary(self: BuildOptions) []const u8 {
    return switch (self.boot_info) {
        .grub_legacy => "boot/grub/stage2_eltorito",
        .limine => "boot/limine/limine-bios-cd.bin",
    };
}
