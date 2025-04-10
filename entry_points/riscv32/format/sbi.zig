// sbi.zig - riscv32 architecture specific API to call into the SBI bios
// Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const exception = @import("../exception.zig");
const osformat = @import("osformat");
const meta = @import("std").meta;

pub const SbiWriter = struct {
    buffer: [32]u8,
    internal_sentinel: u8,
    arg_sentinel: u8,

    pub fn init() SbiWriter {
        return .{
            .buffer = .{0} ** 32,
            .internal_sentinel = 0,
            .arg_sentinel = 0,
        };
    }

    pub fn printf(
        self: *SbiWriter,
        comptime format_string: []const u8,
        args: anytype,
    ) void {
        defer self.flush();

        var flag: bool = false;
        for (format_string) |letter| {
            if (self.internal_sentinel == self.buffer.len) {
                // flush and reset ptr
                self.writeRaw(&self.buffer);
                self.internal_sentinel = 0;
            }

            switch (letter) {
                '%' => {
                    if (flag) {
                        // write only the single % literal for '%%'
                        self.buffer[self.internal_sentinel] = '%';
                        self.internal_sentinel += 1;
                    }

                    flag = !flag;
                },
                else => {
                    if (flag) {
                        self.writeValue(inline for (args, 0..) |arg, i| {
                            if (i == self.arg_sentinel) {
                                break arg;
                            }

                            break null;
                        });
                        flag = false;
                    } else {
                        self.buffer[self.internal_sentinel] = letter;
                        self.internal_sentinel += 1;
                    }
                },
            }
        }
    }

    fn writeRaw(_: *SbiWriter, raw_string: []const u8) void {
        _ = rawSbiPrint(raw_string);
    }

    fn writeValue(self: *SbiWriter, value: anytype) void {
        self.flush();
        if (value == null) {
            self.writeRaw("NULLVAL");
        }

        const nullable: bool = comptime nullable_check: {
            break :nullable_check @typeInfo(@TypeOf(value)) == .optional;
        };

        if (nullable) {
            if (value) |unwrapped| {
                switch (@typeInfo(@TypeOf(unwrapped))) {
                    .int => {
                        const converted = osformat.format.intToString(@TypeOf(unwrapped), unwrapped);
                        self.writeRaw(converted.innerSlice());
                    },
                    else => {
                        self.writeRaw("UNEXPECTED " ++ @typeName(@TypeOf(unwrapped)));
                    },
                }
            }
        } else {
            switch (@typeInfo(@TypeOf(value))) {
                .int => {
                    const converted = osformat.format.intToString(@TypeOf(value), value);
                    self.writeRaw(converted.innerSlice());
                },
                else => {
                    self.writeRaw("UNEXPECTED " ++ @typeName(@TypeOf(value)));
                },
            }
        }
    }

    fn flush(self: *SbiWriter) void {
        _ = rawSbiPrint(self.buffer[0..self.internal_sentinel]);
        self.internal_sentinel = 0;
    }

    pub fn isWritableType(comptime t: type) bool {
        if (t == bool) {
            return true;
        }

        return switch (@typeInfo(t)) {
            .int => true,
            .float => true,
            .pointer => true,
            else => false,
        };
    }
};

/// Generic C printf
/// format_string:
///     comptime format string
/// data:
///     array containing anytypes
pub fn printf(comptime format_string: []const u8, args: anytype) void {
    var sbi_writer = SbiWriter.init();
    comptime {
        // args needs to be an anon struct type
        const ArgsType = @TypeOf(args);
        const args_type_info = @typeInfo(ArgsType);
        if (args_type_info != .@"struct") {
            @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
        }

        const arg_len: comptime_int = args_type_info.@"struct".fields.len;
        if (arg_len > 32) {
            @compileError("32 arguments max are supported per format call");
        }

        for (args_type_info.@"struct".fields) |field| {
            const field_type: type = field.type;
            if (!SbiWriter.isWritableType(field_type)) {
                @compileError("Invalid type for printf: " ++ @typeName(field_type));
            }
        }

        var flag: bool = false;
        var format_specifiers: comptime_int = 0;
        for (format_string) |letter| {
            switch (letter) {
                '%' => {
                    flag = !flag;
                },
                else => {
                    if (flag and letter != '%') {
                        format_specifiers += 1;
                        flag = false;
                    }
                },
            }
        }

        const arg_len_string = osformat.format.intToString(
            @TypeOf(arg_len),
            arg_len,
        );
        const specifier_length_string = osformat.format.intToString(
            @TypeOf(format_specifiers),
            format_specifiers,
        );
        var message: []const u8 = "Mismatching number of format specifiers and arguments. Args: ";
        message = message ++ arg_len_string.innerSlice();
        message = message ++ ". Specifiers: " ++ specifier_length_string.innerSlice();
        if (format_specifiers != arg_len) {
            @compileError(message);
        }
    }

    sbi_writer.printf(format_string, args);
}

pub const Writer = struct {
    /// Calls print and then flushes the buffer.
    pub fn print(self: *Writer, comptime format: []const u8, args: anytype) void {
        const State = enum {
            start,
            open_brace,
            close_brace,
        };

        comptime var start_index: usize = 0;
        comptime var state = State.start;
        comptime var next_arg: usize = 0;

        inline for (format, 0..) |c, i| {
            switch (state) {
                State.start => switch (c) {
                    '{' => {
                        if (start_index < i) {
                            self.write(format[start_index..i]) catch {
                                exception.panic(@src());
                            };
                        }
                        state = State.open_brace;
                    },
                    '}' => {
                        if (start_index < i) self.write(format[start_index..i]) catch {
                            exception.panic(@src());
                        };
                        state = State.close_brace;
                    },
                    else => {},
                },
                State.open_brace => switch (c) {
                    '{' => {
                        state = State.start;
                        start_index = i;
                    },
                    '}' => {
                        self.printValue(args[next_arg]) catch {
                            exception.panic(@src());
                        };
                        next_arg += 1;
                        state = State.start;
                        start_index = i + 1;
                    },
                    's' => {
                        continue;
                    },
                    else => @compileError("Unknown format character: " ++ [1]u8{c}),
                },
                State.close_brace => switch (c) {
                    '}' => {
                        state = State.start;
                        start_index = i;
                    },
                    else => @compileError("Single '}' encountered in format string"),
                },
            }
        }
        comptime {
            if (args.len != next_arg) {
                @compileError("Unused arguments");
            }
            if (state != State.start) {
                @compileError("Incomplete format string: " ++ format);
            }
        }
        if (start_index < format.len) {
            self.write(format[start_index..format.len]) catch {
                exception.panic(@src());
            };
        }

        self.flush() catch {
            exception.panic(@src());
        };
    }

    fn write(self: *Writer, value: []const u8) !void {
        _ = self;
        rawSbiPrint(value);
    }
    pub fn printValue(self: *Writer, value: anytype) !void {
        _ = self;
        _ = value;
    }
    fn flush(self: *Writer) !void {
        _ = self;
    }
};

const SbiReturn: type = struct {
    err: u32,
    value: u32,
};

const PrintFormatSpecifier: type = enum {};

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

pub fn rawSbiPrint(string: []const u8) void {
    for (string) |character| {
        _ = putchar(character);
    }
}

// Shamelessly will admit this code is pretty much taken from the zig std lib
// pub fn sbiPrintF(comptime string: []const u8, args: anytype) void {
//
//     const fields_info = args_type_info.Struct.fields;
//     const max_format_args = @typeInfo(u32).Int.bits;
//
//     comptime {
//         if (fields_info.len > max_format_args) {
//             @compileError("32 arguments max are supported per format call");
//         }
//     }
//
//     comptime var arg_state: @import("std").fmt.ArgState = .{ .args_len = fields_info.len };
//     comptime var i = 0;
//     inline while (i < string.len) {
//         const start_index = i;
//
//         inline while (i < string.len) : (i += 1) {
//             switch (string[i]) {
//                 '{', '}' => break,
//                 else => {},
//             }
//         }
//
//         comptime var end_index = i;
//         comptime var unescape_brace = false;
//
//         // Handle {{ and }}, those are un-escaped as single braces
//         if (i + 1 < string.len and string[i + 1] == string[i]) {
//             unescape_brace = true;
//             // Make the first brace part of the literal...
//             end_index += 1;
//             // ...and skip both
//             i += 2;
//         }
//
//         // Write out the literal
//         if (start_index != end_index) {
//             rawSbiPrint(string);
//         }
//
//         // We've already skipped the other brace, restart the loop
//         if (unescape_brace) continue;
//
//         if (i >= string.len) break;
//
//         if (string[i] == '}') {
//             @compileError("missing opening {");
//         }
//
//         // Get past the {
//         comptime {
//             if (string[i] != '{') {
//                 @compileError("Missing opening {");
//             }
//         }
//         i += 1;
//
//         const fmt_begin = i;
//         // Find the closing brace
//         inline while (i < string.len and string[i] != '}') : (i += 1) {}
//         const fmt_end = i;
//
//         if (i >= string.len) {
//             @compileError("missing closing }");
//         }
//
//         // Get past the }
//         comptime {
//             if (string[i] != '}') {
//                 @compileError("Missing closing {");
//             }
//         }
//         i += 1;
//
//         const placeholder = comptime Placeholder.parse(string[fmt_begin..fmt_end].*);
//         const arg_pos = comptime switch (placeholder.arg) {
//             .none => null,
//             .number => |pos| pos,
//             .named => |arg_name| meta.fieldIndex(ArgsType, arg_name) orelse
//                 @compileError("no argument with name '" ++ arg_name ++ "'"),
//         };
//
//         const width = switch (placeholder.width) {
//             .none => null,
//             .number => |v| v,
//             .named => |arg_name| blk: {
//                 const arg_i = comptime meta.fieldIndex(ArgsType, arg_name) orelse
//                     @compileError("no argument with name '" ++ arg_name ++ "'");
//                 _ = comptime arg_state.nextArg(arg_i) orelse @compileError("too few arguments");
//                 break :blk @field(args, arg_name);
//             },
//         };
//
//         const precision = switch (placeholder.precision) {
//             .none => null,
//             .number => |v| v,
//             .named => |arg_name| blk: {
//                 const arg_i = comptime meta.fieldIndex(ArgsType, arg_name) orelse
//                     @compileError("no argument with name '" ++ arg_name ++ "'");
//                 _ = comptime arg_state.nextArg(arg_i) orelse @compileError("too few arguments");
//                 break :blk @field(args, arg_name);
//             },
//         };
//
//         const arg_to_print = comptime arg_state.nextArg(arg_pos) orelse
//             @compileError("too few arguments");
//
//         try formatType(
//             @field(args, fields_info[arg_to_print].name),
//             placeholder.specifier_arg,
//             FormatOptions{
//                 .fill = placeholder.fill,
//                 .alignment = placeholder.alignment,
//                 .width = width,
//                 .precision = precision,
//             },
//             writer,
//             std.options.fmt_max_depth,
//         );
//     }
//
//     if (comptime arg_state.hasUnusedArgs()) {
//         const missing_count = arg_state.args_len - @popCount(arg_state.used_args);
//         switch (missing_count) {
//             0 => unreachable,
//             1 => @compileError("unused argument in '" ++ fmt ++ "'"),
//             else => @compileError(comptimePrint("{d}", .{missing_count}) ++ " unused arguments in '" ++ fmt ++ "'"),
//         }
//     }
// }
