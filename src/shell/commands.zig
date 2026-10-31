const std = @import("std");
const Terminal = @import("../terminal/terminal.zig").Terminal;
const parser = @import("parser.zig");
const resolver = @import("resolver.zig");
const time = @import("../kernel/time.zig");
const irq = @import("../kernel/irq.zig");

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
            terminal.writeLine("  waitsec  Wait specified seconds");
            terminal.writeLine("  waitms   Wait specified milliseconds");
            terminal.writeLine("  ticks    Display current ticks value");
        },

        .version => {
            terminal.writeLine("Ash Operating System");
            terminal.writeLine("ASH-M0.5.0a | IA-32");
        },

        .echo => {
            terminal.writeLine(parsed.args);
        },

        .unknown => {
            terminal.setColor(.light_red, .black);
            terminal.writeLine("Unknown command.");
            terminal.setColor(.white, .black);
        },

        .waitsec => {
            const seconds = std.fmt.parseInt(u64, parsed.args, 10) catch {
                terminal.writeLine("Usage: waitsec <seconds>");
                return;
            };

            if (seconds > 60) {
                terminal.writeLine("Maximum wait: 60 seconds.");
                return;
            }

            const before = irq.ticks();

            terminal.writeLine("Waiting...");
            time.waitSec(seconds);

            const after = irq.ticks();
            const elapsed = after -% before;

            var buffer: [64]u8 = undefined;

            const message = std.fmt.bufPrint(
                &buffer,
                "Elapsed ticks: 0x{x:0>8}{x:0>8}",
                .{
                    @as(u32, @truncate(elapsed >> 32)),
                    @as(u32, @truncate(elapsed)),
                },
            ) catch unreachable;

            terminal.writeLine(message);
            terminal.writeLine("Wait completed.");
        },

        .waitms => {
            const milliseconds = std.fmt.parseInt(u64, parsed.args, 10) catch {
                terminal.writeLine("Usage: waitms <milliseconds>");
                return;
            };

            if (milliseconds > 60000) {
                terminal.writeLine("Maximum wait: 60000 ms.");
                return;
            }

            terminal.writeLine("Waiting...");
            time.waitMs(milliseconds);
            terminal.writeLine("Wait completed.");
        },

        .ticks => {
            const current = irq.ticks();

            const high: u32 = @truncate(current >> 32);
            const low: u32 = @truncate(current);

            var buffer: [64]u8 = undefined;

            const message = std.fmt.bufPrint(
                &buffer,
                "Ticks: 0x{x:0>8}{x:0>8}",
                .{ high, low },
            ) catch unreachable;

            terminal.writeLine(message);
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
