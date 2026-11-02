const std = @import("std");
const Terminal = @import("../terminal/terminal.zig").Terminal;
const parser = @import("parser.zig");
const resolver = @import("resolver.zig");
const time = @import("../kernel/time.zig");
const irq = @import("../kernel/irq.zig");
const vga = @import("../drivers/vga.zig");

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
            terminal.writeLine("  uptime   Display system uptime");
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

            terminal.writeLine("Waiting...");
            time.waitSec(seconds);

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

        .uptime => {
            const sys_uptime = time.Duration.uptime();

            var buffer: [128]u8 = undefined;

            const message = std.fmt.bufPrint(
                &buffer,
                "System uptime:\n   {d} days, {d} hours, {d} minutes, {d} seconds, {d} milliseconds.",
                .{
                    sys_uptime.days,
                    sys_uptime.hours,
                    sys_uptime.minutes,
                    sys_uptime.seconds,
                    sys_uptime.milliseconds,
                },
            ) catch unreachable;

            terminal.writeLine(message);
        },
        .color => {
            var tokens = std.mem.tokenizeScalar(u8, parsed.args, ' ');

            const fg_text = tokens.next() orelse {
                terminal.writeLine("Usage: color <fg> <bg>");
                return;
            };

            const bg_text = tokens.next() orelse {
                terminal.writeLine("Usage: color <fg> <bg>");
                return;
            };
            const fg_number = std.fmt.parseInt(u8, fg_text, 10) catch {
                terminal.writeLine("Invalid foreground color.");
                return;
            };

            const bg_number = std.fmt.parseInt(u8, bg_text, 10) catch {
                terminal.writeLine("Invalid background color.");
                return;
            };

            if (fg_number > 15 or bg_number > 15) {
                terminal.writeLine("Colors must be between 0 and 15.");
                return;
            }

            const fg: vga.Color = @enumFromInt(fg_number);
            const bg: vga.Color = @enumFromInt(bg_number);

            if (fg == bg) {
                terminal.writeLine("Foreground and background cannot be identical.");
                return;
            }

            terminal.setColor(fg, bg);
            terminal.writeLine("Color test");
        },
    }
}
