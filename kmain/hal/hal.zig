const std = @import("std");
const meta = std.meta;

const HalFieldRole = enum {
    terminal,

    pub fn init(hal_field_name: []const u8) ?HalFieldRole {
        if (std.mem.eql(u8, hal_field_name, "terminal")) {
            return .terminal;
        }
        return null;
    }
};

/// Compile time function to validate that the HAL object passed to kmain is
/// valid (i.e. it has all expected members with expected methods). Every
/// field in the HAL object should be a pointer
pub fn validateHalObject(hal_type: type) void {
    const hal_type_info: std.builtin.Type = @typeInfo(hal_type);

    if (hal_type_info != .@"struct") {
        const err_msg = std.fmt.comptimePrint(
            "{s} passed to kmain is not a struct! It is a {s}",
            .{
                @typeName(hal_type),
                @tagName(hal_type_info),
            },
        );
        @compileError(err_msg);
    }

    const StructFieldArray = []const std.builtin.Type.StructField;
    const hal_fields: StructFieldArray = meta.fields(hal_type);
    inline for (hal_fields) |field| {
        const field_type = field.type;
        const field_type_info = @typeInfo(field_type);
        switch (field_type_info) {
            .pointer => |ptr| {
                const underlying_type = ptr.child;
                const role: ?HalFieldRole = HalFieldRole.init(field.name);
                if (role) |responsibility| {
                    switch (responsibility) {
                        .terminal => validateTerminalType(underlying_type),
                    }
                }
            },
            else => {
                const err_msg = std.fmt.comptimePrint(
                    "{s} has an unexpected non-pointer field: {s} of type {s}",
                    .{
                        @typeName(hal_type),
                        field.name,
                        @typeName(field_type),
                    },
                );
                @compileError(err_msg);
            },
        }
    }
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
