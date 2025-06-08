const std = @import("std");
const meta = std.meta;

/// this struct should mirror what validateHalObject is returning. However, this
/// struct will storewhat types the end result HAL will have.
pub const IntermediateHal = struct {
    terminal_type: ?type,

    pub fn terminal(self: IntermediateHal) type {
        if (self.terminal_type) |term_type| {
            return term_type;
        } else {
            @compileError("HAL missing field implementing terminal interaction");
        }
    }

    pub fn populate(self: *IntermediateHal, role: HalFieldRole) void {
        switch (role) {
            .terminal => |term_type| {
                validateTerminalType(term_type);
                self.terminal_type = *term_type;
            },
        }
    }
};

/// Iterates through fields in the given hal type and populates an intermediate
/// HAL containing valid types it has found.
pub fn validateHalFieldTypes(hal_type: type) IntermediateHal {
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
                const role: HalFieldRole = HalFieldRole.init(field.name, pointee_type);
                intermediate.populate(role);
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
const HalFieldRole = union(enum) {
    terminal: type,

    pub fn init(hal_field_name: []const u8, field_type: type) HalFieldRole {
        if (std.mem.eql(u8, hal_field_name, "terminal")) {
            return .{ .terminal = field_type };
        } else {
            var error_message = "Unrecognized HAL Field: ";
            error_message = error_message ++ hal_field_name;
            error_message = error_message ++ "in type: ";
            error_message = error_message ++ @typeName(field_type);
            @compileError(error_message);
        }
    }
};

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
