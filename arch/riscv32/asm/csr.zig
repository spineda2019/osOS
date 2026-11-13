/// Docs (mostly) ripped from the 1.1 ratified spec
pub const SStatus = packed struct(u32) {
    _reserved_1: u1 = 0,
    /// The SIE bit enables or disables all interrupts in supervisor mode.
    ///
    /// When SIE is clear, interrupts are not taken while in supervisor mode.
    /// When the hart is running in user-mode, the value in SIE is ignored, and
    /// supervisor-level interrupts are enabled. The supervisor can disable
    /// individual interrupt sources using the sie CSR.
    sie: bool,
    _reserved_2: u3 = 0,
    /// The SPIE bit indicates whether supervisor interrupts were enabled prior
    /// to trapping into supervisor mode.
    ///
    /// When a trap is taken into supervisor mode, SPIE is set to SIE, and SIE
    /// is set to 0. When an SRET instruction is executed, SIE is set to SPIE,
    /// then SPIE is set to 1.
    spie: bool,
    ube: bool,
    _reserved_3: u1 = 0,
    /// The SPP bit indicates the privilege level at which a hart was executing
    /// before entering supervisor mode.
    ///
    /// When a trap is taken, SPP is set to 0 if the trap originated from user
    /// mode, or 1 otherwise. When an SRET instruction is executed to return
    /// from the trap handler, the privilege level is set to user mode if the
    /// SPP bit is 0, or supervisor mode if the SPP bit is 1; SPP is then set to
    /// 0
    spp: bool,
    vs: u2,
    _reserved_4: u2 = 0,
    fs: u2,
    xs: u2,
    _reserved_5: u1 = 0,
    sum: bool,
    mxr: bool,
    _reserved_6: u3 = 0,
    spelp: bool,
    sdt: bool,
    _reserved_7: u6 = 0,
    sd: bool,
};
