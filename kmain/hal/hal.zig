const std = @import("std");
const meta = std.meta;

const HalFieldRole = union(enum) {
    terminal: type,

    pub fn init(hal_field_name: []const u8, field_type: type) ?HalFieldRole {
        if (std.mem.eql(u8, hal_field_name, "terminal")) {
            return .{ .terminal = field_type };
        }
        return null;
    }

    pub fn validate(self: HalFieldRole, intermediate: *IntermediateHal) void {
        switch (self) {
            .terminal => |term_type| {
                validateTerminalType(term_type);
                intermediate.terminal_type = *term_type;
            },
        }
    }
};

/// this struct should mirror what validateHalObject is returning. However, this
/// struct will storewhat types the end result HAL will have.
const IntermediateHal = struct {
    terminal_type: ?type,

    pub fn terminal(self: IntermediateHal) type {
        if (self.terminal_type) |term_type| {
            return term_type;
        } else {
            @compileError("HAL missing field implementing terminal interaction");
        }
    }
};

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
    const hal_type_info: std.builtin.Type = @typeInfo(hal_type);

    if (hal_type_info != .@"struct") {
        const err_msg = std.fmt.comptimePrint(
            "{s} passed to kmain is not a struct! It is a {s}",
            .{ @typeName(hal_type), @tagName(hal_type_info) },
        );
        @compileError(err_msg);
    }

    const intermediate_hal = validateHalFieldTypes(hal_type);

    return struct {
        terminal: intermediate_hal.terminal(),

        const This = @This();

        pub fn init(handed_off_hal: hal_type) This {
            return .{
                .terminal = handed_off_hal.terminal,
            };
        }
    };
}

/// Iterates through fields in the given hal type and populates an intermediate
/// HAL containing valid types it has found.
fn validateHalFieldTypes(hal_type: type) IntermediateHal {
    var intermediate: IntermediateHal = .{
        .terminal_type = null,
    };

    const StructFieldArray: type = []const std.builtin.Type.StructField;
    const hal_fields: StructFieldArray = meta.fields(hal_type);

    inline for (hal_fields) |field| {
        const field_type = field.type;
        const field_type_info = @typeInfo(field_type);

        switch (field_type_info) {
            .pointer => |ptr| {
                const pointee_type = ptr.child;
                const role: ?HalFieldRole = HalFieldRole.init(field.name, pointee_type);
                if (role) |hal_role| {
                    hal_role.validate(&intermediate);
                }
            },
            else => { // this might be allowed in the future, not sure yet
                const err_msg = std.fmt.comptimePrint(
                    "{s} has an unexpected non-pointer field: {s} of type {s}",
                    .{ @typeName(hal_type), field.name, @typeName(field_type) },
                );
                @compileError(err_msg);
            },
        }
    }

    return intermediate;
}

/// A terminal type suplied through the HAL must be a struct with some required
/// methods.
fn validateTerminalType(hal_terminal_type: type) void {
    const terminal_type_info: std.builtin.Type = @typeInfo(hal_terminal_type);

    if (terminal_type_info != .@"struct") {
        const err_msg = std.fmt.comptimePrint(
            "terminal type {s} in the HAL is not a struct! It is a {s}",
            .{
                @typeName(hal_terminal_type),
                @tagName(terminal_type_info),
            },
        );
        @compileError(err_msg);
    }

    const required_methods = .{
        "write",
        "writeLine",
    };

    const err_msg_base = std.fmt.comptimePrint(
        "terminal type {s} in the HAL is missing the following required method: ",
        .{
            @typeName(hal_terminal_type),
        },
    );
    for (required_methods) |required_method| {
        if (!meta.hasMethod(hal_terminal_type, required_method)) {
            @compileError(err_msg_base ++ required_method);
        }
    }
}
