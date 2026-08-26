const std = @import("std");

pub const Emulator = enum {
    qemu,
    bochs,
};

pub const SupportedTarget = enum {
    x86,
    riscv32,
};

pub const BootLoadInfo = union(enum) {
    grub_legacy: enum {
        multiboot_one,
    },
    limine: enum {
        multiboot_one,
        multiboot_two,
        limine,
    },
};
