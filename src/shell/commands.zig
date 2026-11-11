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
const bitmap = @import("../memory/bitmap.zig");

fn integrityStatusText(status: bitmap.IntegrityStatus) []const u8 {
    return switch (status) {
        .pass => "PASS",
        .fail => "FAIL",
        .incomplete => "INCOMPLETE",
        .not_applicable => "N/A",
    };
}

fn overallIntegrityStatus(
    report: *const bitmap.IntegrityReport,
) bitmap.IntegrityStatus {
    const statuses = [_]bitmap.IntegrityStatus{
        report.kernel.status,
        report.multiboot.status,
        report.allocator.status,
        report.low_memory.status,
        report.firmware.status,
    };
    var incomplete = false;

    for (statuses) |status| {
        switch (status) {
            .fail => return .fail,
            .incomplete => incomplete = true,
            .pass => {},
            .not_applicable => {},
        }
    }

    return if (incomplete) .incomplete else .pass;
}

fn writeIntegrityLine(
    terminal: *Terminal,
    label: []const u8,
    status: bitmap.IntegrityStatus,
) void {
    var buffer: [64]u8 = undefined;
    const line = std.fmt.bufPrint(
        &buffer,
        "{s}{s}",
        .{ label, integrityStatusText(status) },
    ) catch unreachable;

    terminal.writeLine(line);
}

pub fn execute(terminal: *Terminal, input: []const u8) void {
    const parsed = parser.parse(input);
    const args = std.mem.trim(u8, parsed.args, " ");

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
            terminal.writeLine("  memstat       Show physical memory statistics");
            terminal.writeLine("  memtest       ");
            terminal.writeLine("    |-* basic     Test physical memory allocation and deallocation");
            terminal.writeLine("    |-  integrity Test physical memory integrity");
        },

        .version => {
            terminal.writeLine("Ash Operating System");
            terminal.writeLine("ASH-M0.7.3-dev | IA-32");
        },

        .echo => {
            terminal.writeLine(args);
        },

        .unknown => {
            const previous_color = terminal.color;

            terminal.setColor(.light_red, .black);
            terminal.writeLine("Unknown command.");

            terminal.color = previous_color;
        },

        .waitsec => {
            const seconds = std.fmt.parseInt(u64, args, 10) catch {
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
            const milliseconds = std.fmt.parseInt(u64, args, 10) catch {
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
            var tokens = std.mem.tokenizeScalar(u8, args, ' ');

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

        .memstat => {
            const stats = bitmap.physicalStats() orelse {
                terminal.writeLine("Physical memory manager not initialized.");
                return;
            };

            terminal.writeLine("ASH Physical Memory Statistics");

            var buffer: [160]u8 = undefined;

            const message = std.fmt.bufPrint(
                &buffer,
                "Pages: {d} total, {d} free, {d} occupied",
                .{
                    stats.total_pages,
                    stats.free_pages,
                    stats.occupied_pages,
                },
            ) catch unreachable;

            terminal.writeLine(message);

            const free_kib = stats.free_pages * 4;
            const occupied_kib = stats.occupied_pages * 4;

            const memory_message = std.fmt.bufPrint(
                &buffer,
                "Free: {d} KiB | Occupied: {d} KiB",
                .{
                    free_kib,
                    occupied_kib,
                },
            ) catch unreachable;

            terminal.writeLine(memory_message);
        },

        .memtest => {
            if (args.len == 0 or std.mem.eql(u8, args, "basic")) {
                terminal.writeLine("ASH Physical Memory Test");

                const before = bitmap.physicalStats() orelse {
                    terminal.writeLine("PMM not initialized.");
                    return;
                };

                const page = (bitmap.allocatePhysicalPage() catch {
                    terminal.writeLine("Allocation error.");
                    return;
                }) orelse {
                    terminal.writeLine("No free pages available.");
                    return;
                };

                const during = bitmap.physicalStats() orelse {
                    terminal.writeLine("Statistics unavailable.");
                    return;
                };
                const allocated = bitmap.isPhysicalPageAllocated(page);

                bitmap.freePhysicalPage(page) catch {
                    terminal.writeLine("Free error.");
                    return;
                };

                const after = bitmap.physicalStats() orelse {
                    terminal.writeLine("Statistics unavailable.");
                    return;
                };

                const passed =
                    allocated and
                    before.free_pages == during.free_pages + 1 and
                    after.free_pages == before.free_pages and
                    after.occupied_pages == before.occupied_pages and
                    !bitmap.isPhysicalPageAllocated(page);

                var buffer: [160]u8 = undefined;

                const message = std.fmt.bufPrint(
                    &buffer,
                    "Page: {d} | Physical address: 0x{X:0>8}",
                    .{ page, page * 4096 },
                ) catch unreachable;

                terminal.writeLine(message);

                const counts = std.fmt.bufPrint(
                    &buffer,
                    "Free pages: {d} -> {d} -> {d}",
                    .{
                        before.free_pages,
                        during.free_pages,
                        after.free_pages,
                    },
                ) catch unreachable;

                terminal.writeLine(counts);

                terminal.writeLine(
                    if (passed) "MEMTEST: PASS" else "MEMTEST: FAIL",
                );
            } else if (std.mem.eql(u8, args, "integrity")) {
                terminal.writeLine("ASH PMM Reservation Integrity");
                if (physical.reservations.len == 0) {
                    terminal.writeLine("INTEGRITY: FAIL - No reservations.");
                    return;
                }
                const report = bitmap.reservationIntegrityReport(
                    &physical.reservations,
                ) orelse {
                    terminal.writeLine("PMM integrity: NOT INITIALIZED");
                    return;
                };
                terminal.writeLine("");
                writeIntegrityLine(terminal, "Kernel:       ", report.kernel.status);
                writeIntegrityLine(terminal, "Multiboot2:   ", report.multiboot.status);
                writeIntegrityLine(terminal, "Allocator:    ", report.allocator.status);
                writeIntegrityLine(terminal, "Low Memory:   ", report.low_memory.status);
                writeIntegrityLine(terminal, "Firmware:     ", report.firmware.status);

                terminal.writeLine("");
                writeIntegrityLine(
                    terminal,
                    "Global:       ",
                    overallIntegrityStatus(&report),
                );
            } else {
                terminal.writeLine("Usage: memtest [*basic|integrity]");
                terminal.writeLine("                *: Default case.");
            }
        },
    }
}
