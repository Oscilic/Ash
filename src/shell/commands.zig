const std = @import("std");
const Terminal = @import("../terminal/terminal.zig").Terminal;
const parser = @import("parser.zig");
const resolver = @import("resolver.zig");
const time = @import("../kernel/time.zig");
const vga = @import("../drivers/vga.zig");
const ps2 = @import("../drivers/ps2.zig");
const multiboot2 = @import("../boot/multiboot2.zig");
const kernel = @import("../kernel/main.zig");
const physical = @import("../memory/physical.zig");

pub fn execute(terminal: *Terminal, input: []const u8) void {
    const parsed = parser.parse(input);

    if (parsed.name.len == 0) return;

    switch (resolver.resolve(parsed.name)) {
        .clear => {
            terminal.clear();
        },

        .help => {
            terminal.writeLine("Available commands:");
            terminal.writeLine("  help          Show available commands");
            terminal.writeLine("  clear (cls)   Clear terminal");
            terminal.writeLine("  version (ver) Show Ash version");
            terminal.writeLine("  echo          Print text");
            terminal.writeLine("  waitsec       Wait specified seconds");
            terminal.writeLine("  waitms        Wait specified milliseconds");
            terminal.writeLine("  uptime        Display system uptime");
            terminal.writeLine("  color (col)   Change terminal color");
            terminal.writeLine("  irqstat       Show IRQ statistics");
            terminal.writeLine("  memmap        Show physical memory map");
        },

        .version => {
            terminal.writeLine("Ash Operating System");
            terminal.writeLine("ASH-M0.7.3-dev | IA-32");
        },

        .echo => {
            terminal.writeLine(parsed.args);
        },

        .unknown => {
            const previous_color = terminal.color;

            terminal.setColor(.light_red, .black);
            terminal.writeLine("Unknown command.");

            terminal.color = previous_color;
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
            if (time.waitSecCancelable(seconds)) {
                terminal.writeLine("Wait completed.");
            } else {
                terminal.writeLine("^C");
                terminal.writeLine("Command canceled.");
            }
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
            if (time.waitMsCancelable(milliseconds)) {
                terminal.writeLine("Wait completed.");
            } else {
                terminal.writeLine("^C");
                terminal.writeLine("Command canceled.");
            }
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
        },
        .irqstat => {
            const dropped = ps2.getDroppedScancodes();
            const pending = ps2.getPendingScancodes();

            var buffer: [128]u8 = undefined;

            const message = std.fmt.bufPrint(
                &buffer,
                "PS/2 dropped scancodes: {d}, pending: {d}",
                .{ dropped, pending },
            ) catch unreachable;

            terminal.writeLine(message);
        },
        .memmap => {
            const mmap = multiboot2.findMemoryMap(
                kernel.boot_info_address,
            ) orelse {
                terminal.writeLine("Memory map unavailable.");
                return;
            };

            terminal.writeLine("ASH Physical Memory Map");

            var i: usize = 0;
            while (i < mmap.entry_count) : (i += 1) {
                const entry = mmap.entry(i) orelse break;

                var buffer: [160]u8 = undefined;

                const message = std.fmt.bufPrint(
                    &buffer,
                    "{d}: Base=0x{X:0>16} Size=0x{X:0>16} Type={d}",
                    .{
                        i,
                        entry.base_addr,
                        entry.length,
                        entry.entry_type,
                    },
                ) catch unreachable;

                terminal.writeLine(message);
            }
            const region = physical.kernelRegion();

            var region_buffer: [160]u8 = undefined;

            const region_message = std.fmt.bufPrint(
                &region_buffer,
                "Kernel: 0x{X:0>8} - 0x{X:0>8} ({d} pages)",
                .{
                    region.start,
                    region.end,
                    region.page_count,
                },
            ) catch unreachable;

            terminal.writeLine(region_message);
            const boot_size = multiboot2.infoSize(
                kernel.boot_info_address,
            ) orelse {
                terminal.writeLine("Invalid Multiboot2 information.");
                return;
            };

            const boot_pages = physical.pageRange(
                @as(usize, kernel.boot_info_address),
                @as(usize, boot_size),
            ) orelse {
                terminal.writeLine("Invalid Multiboot2 page range.");
                return;
            };

            var boot_buffer: [160]u8 = undefined;

            const boot_message = std.fmt.bufPrint(
                &boot_buffer,
                "Multiboot2: 0x{X:0>8}, {d} bytes, {d} pages",
                .{
                    kernel.boot_info_address,
                    boot_size,
                    boot_pages.count(),
                },
            ) catch unreachable;

            terminal.writeLine(boot_message);
        },
    }
}
