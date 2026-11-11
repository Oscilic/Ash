const std = @import("std");

pub const Command = enum {
    clear,
    help,
    version,
    echo,
    waitsec,
    waitms,
    uptime,
    color,
    irqstat,
    memmap,
    memstat,
    memtest,
    unknown,
};

pub fn resolve(name: []const u8) Command {
    // Prioridad 1
    if (std.mem.eql(u8, name, "clear")) return .clear;
    if (std.mem.eql(u8, name, "help")) return .help;
    if (std.mem.eql(u8, name, "version")) return .version;
    if (std.mem.eql(u8, name, "echo")) return .echo;
    if (std.mem.eql(u8, name, "waitsec")) return .waitsec;
    if (std.mem.eql(u8, name, "waitms")) return .waitms;
    if (std.mem.eql(u8, name, "uptime")) return .uptime;
    if (std.mem.eql(u8, name, "color")) return .color;
    if (std.mem.eql(u8, name, "irqstat")) return .irqstat;
    if (std.mem.eql(u8, name, "memmap")) return .memmap;
    if (std.mem.eql(u8, name, "memstat")) return .memstat;
    if (std.mem.eql(u8, name, "memtest")) return .memtest;
    // Prioridad 2: alias
    if (std.mem.eql(u8, name, "cls")) return .clear;
    if (std.mem.eql(u8, name, "ver")) return .version;
    if (std.mem.eql(u8, name, "col")) return .color;

    return .unknown;
}
