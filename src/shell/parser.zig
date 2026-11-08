const std = @import("std");

pub const ParsedCommand = struct {
    name: []const u8,
    args: []const u8,
};

pub fn parse(input: []const u8) ParsedCommand {
    var start: usize = 0;
    while (start < input.len and input[start] == ' ') {
        start += 1;
    }

    if (start == input.len) {
        return .{
            .name = "",
            .args = "",
        };
    }

    const remaining = input[start..];

    const relative_end = std.mem.indexOfScalar(
        u8,
        remaining,
        ' ',
    ) orelse remaining.len;

    const end = start + relative_end;

    var args_start = end;

    while (args_start < input.len and input[args_start] == ' ') {
        args_start += 1;
    }

    return .{
        .name = input[start..end],
        .args = input[args_start..],
    };
}
