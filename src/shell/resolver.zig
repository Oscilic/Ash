const std = @import("std");

pub const Command = enum { clear, help, version, echo, unknown };

pub fn resolve(name: []const u8) Command {
    //Prioridad 1
    if (std.mem.eql(u8, name, "clear")) {
        return .clear;
    }

    if (std.mem.eql(u8, name, "help")) {
        return .help;
    }

    if (std.mem.eql(u8, name, "version")) {
        return .version;
    }
    if (std.mem.eql(u8, name, "echo")) {
        return .echo;
    }
    //Prioridad 2
    if (std.mem.eql(u8, name, "cls")) {
        return .clear;
    }

    if (std.mem.eql(u8, name, "ver")) {
        return .version;
    }
    return .unknown;
}
