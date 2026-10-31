const std = @import("std");
const Terminal = @import("../terminal/terminal.zig").Terminal;
const parser = @import("parser.zig");
const resolver = @import("resolver.zig");

pub fn execute(terminal: *Terminal, input: []const u8) void {
    const parsed = parser.parse(input);

    if (parsed.name.len == 0) return;

    switch (resolver.resolve(parsed.name)) {
        .clear => {
            terminal.clear();
        },

        .help => {
            terminal.writeLine("Available commands:");
            terminal.writeLine("  help     Show available commands");
            terminal.writeLine("  clear    Clear terminal");
            terminal.writeLine("  cls      Alias for clear");
            terminal.writeLine("  version  Show Ash version");
            terminal.writeLine("  ver      Alias for version");
            terminal.writeLine("  echo     Print text");
        },

        .version => {
            terminal.writeLine("Ash Operating System");
            terminal.writeLine("ASH-M0.4.0b | IA-32");
        },

        .echo => {
            terminal.writeLine(parsed.args);
        },

        .unknown => {
            terminal.setColor(.light_red, .black);
            terminal.writeLine("Unknown command.");
            terminal.setColor(.white, .black);
        },
    }
}
pub fn testIndexOfScalar(
    terminal: anytype,
) void {
    const input = "echo hola";

    terminal.writeLine("INDEX TEST: START");

    const result = std.mem.indexOfScalar(
        u8,
        input,
        ' ',
    );

    if (result) |position| {
        if (position == 4) {
            terminal.writeLine("INDEX TEST: PASS");
        } else {
            terminal.writeLine("INDEX TEST: WRONG POSITION");
        }
    } else {
        terminal.writeLine("INDEX TEST: NOT FOUND");
    }
}
