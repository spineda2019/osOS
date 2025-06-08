const intermediate = @import("intermediate.zig");
const std = @import("std");

/// Compile time function to validate that the HAL object passed to kmain is
/// valid (i.e. it has all expected members with expected methods). Every
/// field in the HAL object should be a pointer to some type implementing some
/// kernel hardware interaction (x86 framebuffer for the terminal, riscv32 uart
/// for the terminal, etc).
///
/// Once the HAL object is determined to be valid, we construct a HAL type to
/// return containing fields of concrete types determined from the hal_type this
/// is examining. This will provide no additional functionality, but provides 2
/// benefits:
///
/// 1: The zig LSP will be able to somewhat better understand what fields in the
/// HAL we're referencing.
///
/// 2: Semantically, this HAL type we create will take ownership of the pointers
/// within the hal_type passed to kmain. This will truly let kmain be isolated
/// from hardware setup, owning only the hardware methods it needs. hal_type
/// will then only be used to handoff information to kmain.
pub fn HAL(comptime hal_type: type) type {
    const intermediate_hal: intermediate.IntermediateHal = comptime hal_blk: {
        const hal_type_info: std.builtin.Type = @typeInfo(hal_type);

        if (hal_type_info != .@"struct") {
            const err_msg = std.fmt.comptimePrint(
                "{s} passed to kmain is not a struct! It is a {s}",
                .{ @typeName(hal_type), @tagName(hal_type_info) },
            );
            @compileError(err_msg);
        }

        break :hal_blk intermediate.validateHalFieldTypes(hal_type);
    };

    return struct {
        const This = @This();

        terminal: intermediate_hal.terminal(),

        pub fn init(handed_off_hal: hal_type) This {
            return .{
                .terminal = handed_off_hal.terminal,
            };
        }
    };
}
