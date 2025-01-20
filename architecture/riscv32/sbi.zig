const SbiReturn: type = struct {
    err: u32,
    value: u32,
};

/// Make a call to the SBI API
/// From the SBI Spec:
/// All SBI functions share a single binary encoding, which facilitates the
/// mixing of SBI extensions. The SBI specification follows the below calling
/// convention.
///    An ECALL is used as the control transfer instruction between the
///    supervisor and the SEE.
///    a7 encodes the SBI extension ID (EID),
///    a6 encodes the SBI function ID (FID) for a given extension ID encoded in
///    a7 for any SBI extension defined in or after SBI v0.2.
///    All registers except a0 & a1 must be preserved across an SBI call by the
///    callee.
///    SBI functions must return a pair of values in a0 and a1, with a0
///    returning an error code.
fn generalSBICall(
    arg0: u32,
    arg1: u32,
    arg2: u32,
    arg3: u32,
    arg4: u32,
    arg5: u32,
    fid: u32,
    eid: u32,
) SbiReturn {
    var sbi_error: u32 = 0;
    var sbi_return_value: u32 = 0;

    asm volatile (
    // ecall handles the SBI func request
        "ecall"
        :
        // place what ecall puts in a0 into sbi_error
          [sbi_error] "={a0}" (sbi_error),
          // ditto, but for sbi_return_value
          [sbi_return_value] "={a1}" (sbi_return_value),
        :
        // fill passed in zig args into assembly for the SBI bios
          [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [arg6] "{a6}" (fid),
          [arg7] "{a7}" (eid),
        :
        // special clobber value. Indicates assembly writes to
        // arbitrary mem locations we may not have declared. Makes
        // sense, as the bios will write to wherever it wants
    "memory"
    );

    return .{
        .err = sbi_error,
        .value = sbi_return_value,
    };
}

pub fn putchar(character: u8) SbiReturn {
    // eid of 1 specifies putchar to SBI
    return generalSBICall(character, 0, 0, 0, 0, 0, 0, 1);
}
