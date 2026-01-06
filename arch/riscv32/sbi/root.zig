const osformat = @import("osformat");

const SbiRet = extern struct {
    err: SbiErrorCode,
    value: u32,
};

const SbiErrorCode = enum(i32) {
    sbi_success = 0,
    sbi_err_failed = -1,
    sbi_err_not_supported = -2,
    sbi_err_invalid_param = -3,
    sbi_err_denied = -4,
    sbi_err_invalid_address = -5,
    sbi_err_already_available = -6,
    sbi_err_already_started = -7,
    sbi_err_already_stopped = -8,
};

/// SBI Extension ID
const EID = enum(u32) {
    base = 0x10,
};

/// SBI Function ID
const FID = enum(u32) {
    sbi_get_spec_version = 0,
    sbi_get_impl_id = 1,
    sbi_get_impl_version = 2,
    sbi_probe_extension = 3,
    sbi_get_mvendorid = 4,
};

const ImplementationID = enum(u32) {
    berkeley_boot_loader = 0,
    opensbi = 1,
    xvisor = 2,
    kvm = 3,
    rustsbi = 4,
    diosix = 5,
    coffer = 6,

    pub fn toStr(self: ImplementationID) []const u8 {
        return switch (self) {
            .berkeley_boot_loader => "Berkeley Boot Loader",
            .opensbi => "OpenSBI",
            .xvisor => "Xvisor",
            .kvm => "KVM",
            .rustsbi => "RustSBI",
            .diosix => "Diosix",
            .coffer => "Coffer",
        };
    }
};

fn sbi(
    arg0: u32,
    arg1: u32,
    arg2: u32,
    arg3: u32,
    arg4: u32,
    arg5: u32,
    fid: FID,
    eid: EID,
) SbiRet {
    var err: SbiErrorCode = undefined;
    var value: u32 = 0;

    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [value] "={a1}" (value),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [arg6] "{a6}" (@intFromEnum(fid)),
          [arg7] "{a7}" (@intFromEnum(eid)),
        : .{ .memory = true });

    return .{ .err = err, .value = value };
}

pub const SbiVersion = struct {
    major: osformat.format.StringFromInt(u8, 10),
    minor: osformat.format.StringFromInt(u32, 10),
};

/// Per the SBI specification, this must always succeed
pub fn getSpecVersion() SbiVersion {
    const sbi_result = sbi(0, 0, 0, 0, 0, 0, FID.sbi_get_spec_version, EID.base);

    if (sbi_result.err != .sbi_success) {
        // panic
        unreachable;
    } else {
        const high_seven_mask: u32 = 0b0111_1111_0000_0000_0000_0000_0000_0000;
        const high_seven: u8 = @truncate((sbi_result.value & high_seven_mask) >> 24);

        const low_twenty_four_mask: u32 = 0b0000_0000_1111_1111_1111_1111_1111_1111;
        const low_twenty_four: u32 = sbi_result.value & low_twenty_four_mask;
        return .{
            .major = .init(high_seven),
            .minor = .init(low_twenty_four),
        };
    }
}

pub fn getImplId() []const u8 {
    const result = sbi(0, 0, 0, 0, 0, 0, FID.sbi_get_impl_id, EID.base);
    if (result.err != .sbi_success) {
        return "unknown";
    } else {
        const impl: ImplementationID = @enumFromInt(result.value);
        return impl.toStr();
    }
}
