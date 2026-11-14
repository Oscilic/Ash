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
const paging = @import("../memory/paging.zig");
const sys_info = @import("../kernel/sys_info.zig");

fn rangeIsIdentityMapped(start: usize, size: usize) bool {
    if (size == 0 or start > paging.INITIAL_MAPPED_BYTES) return false;
    if (size > paging.INITIAL_MAPPED_BYTES - start) return false;

    const first = paging.translateInitial(start) orelse return false;
    const last_address = start + size - 1;
    const last = paging.translateInitial(last_address) orelse return false;
    return first == start and last == last_address;
}

fn currentStackPointer() usize {
    return asm volatile ("mov %%esp, %[result]"
        : [result] "=r" (-> usize),
    );
}

fn writePagingCheck(terminal: *Terminal) void {
    const kernel_region = physical.kernelRegion();
    const stack_pointer = currentStackPointer();
    const cr3 = paging.activeDirectoryAddress();
    const prepared = paging.isPrepared();
    const paging_enabled = paging.isEnabled();

    const checks = [_]struct {
        label: []const u8,
        passed: bool,
    }{
        .{ .label = "CR0.PG:         ", .passed = paging_enabled },
        .{
            .label = "CR3 alignment:  ",
            .passed = cr3 % paging.PAGE_SIZE == 0 and
                cr3 == paging.directoryAddress(),
        },
        .{
            .label = "VGA mapping:    ",
            .passed = prepared and rangeIsIdentityMapped(0x000B8000, 1),
        },
        .{
            .label = "Kernel mapping: ",
            .passed = prepared and
                rangeIsIdentityMapped(
                    kernel_region.start,
                    kernel_region.end - kernel_region.start,
                ),
        },
        .{
            .label = "Bitmap mapping: ",
            .passed = prepared and
                rangeIsIdentityMapped(
                    bitmap.storageAddress(),
                    bitmap.storageSize(),
                ) and
                rangeIsIdentityMapped(
                    bitmap.allocationStorageAddress(),
                    bitmap.allocationStorageSize(),
                ),
        },
        .{
            .label = "Stack mapping:  ",
            .passed = prepared and
                rangeIsIdentityMapped(stack_pointer, 1),
        },
    };

    terminal.writeLine("ASH VMM Diagnostic");

    var all_passed = true;
    for (checks) |check| {
        var buffer: [64]u8 = undefined;
        const line = std.fmt.bufPrint(
            &buffer,
            "{s}{s}",
            .{ check.label, if (check.passed) "PASS" else "FAIL" },
        ) catch unreachable;
        terminal.writeLine(line);
        all_passed = all_passed and check.passed;
    }

    terminal.writeLine("");
    terminal.writeLine(if (all_passed) "RESULT: PASS" else "RESULT: FAIL");
}

fn writePagingStatus(terminal: *Terminal) void {
    var buffer: [128]u8 = undefined;
    terminal.writeLine("ASH Virtual Memory Manager");
    const paging_status = std.fmt.bufPrint(
        &buffer,
        "Paging:        {s}",
        .{if (paging.isEnabled()) "ENABLED" else "DISABLED"},
    ) catch unreachable;
    terminal.writeLine(paging_status);

    const architecture = std.fmt.bufPrint(
        &buffer,
        "Architecture:  {s}",
        .{sys_info.architectureName()},
    ) catch unreachable;
    terminal.writeLine(architecture);

    const page_size = std.fmt.bufPrint(
        &buffer,
        "Page size:     {d} KiB",
        .{paging.PAGE_SIZE / 1024},
    ) catch unreachable;
    terminal.writeLine(page_size);

    const initial_map = std.fmt.bufPrint(
        &buffer,
        "Initial map:   {d} MiB",
        .{paging.INITIAL_MAPPED_BYTES / (1024 * 1024)},
    ) catch unreachable;
    terminal.writeLine(initial_map);

    const page_tables = std.fmt.bufPrint(
        &buffer,
        "Page tables:   {d}",
        .{paging.TABLE_COUNT},
    ) catch unreachable;
    terminal.writeLine(page_tables);

    const directory = std.fmt.bufPrint(
        &buffer,
        "Directory:     0x{X:0>8}",
        .{paging.directoryAddress()},
    ) catch unreachable;
    terminal.writeLine(directory);

    const cr0_pg = std.fmt.bufPrint(
        &buffer,
        "CR0.PG:        {d}",
        .{@intFromBool(paging.isEnabled())},
    ) catch unreachable;
    terminal.writeLine(cr0_pg);

    const cr0_wp = std.fmt.bufPrint(
        &buffer,
        "CR0.WP:        {d}",
        .{@intFromBool(paging.isWriteProtectEnabled())},
    ) catch unreachable;
    terminal.writeLine(cr0_wp);
}

fn writePagingTranslation(
    terminal: *Terminal,
    address_text: []const u8,
) void {
    const virtual_address = std.fmt.parseInt(usize, address_text, 0) catch {
        terminal.writeLine("Invalid virtual address.");
        terminal.writeLine("Usage: paging translate <address>");
        return;
    };

    const mapping = paging.mappingInfo(virtual_address);
    const mapped = mapping != null and mapping.?.present;
    var buffer: [128]u8 = undefined;

    const virtual_line = std.fmt.bufPrint(
        &buffer,
        "Virtual:   0x{X:0>8}",
        .{virtual_address},
    ) catch unreachable;
    terminal.writeLine(virtual_line);

    if (mapped) {
        const physical_line = std.fmt.bufPrint(
            &buffer,
            "Physical:  0x{X:0>8}",
            .{mapping.?.physical_address},
        ) catch unreachable;
        terminal.writeLine(physical_line);
    } else {
        terminal.writeLine("Physical:  NOT MAPPED");
    }

    const present_line = std.fmt.bufPrint(
        &buffer,
        "Present:   {s}",
        .{if (mapped) "YES" else "NO"},
    ) catch unreachable;
    terminal.writeLine(present_line);

    const writable_line = std.fmt.bufPrint(
        &buffer,
        "Writable:  {s}",
        .{if (mapped and mapping.?.writable) "YES" else "NO"},
    ) catch unreachable;
    terminal.writeLine(writable_line);

    const user_line = std.fmt.bufPrint(
        &buffer,
        "User:      {s}",
        .{if (mapped and mapping.?.user) "YES" else "NO"},
    ) catch unreachable;
    terminal.writeLine(user_line);

    if (mapped and mapping.?.physical_address == virtual_address) {
        terminal.writeLine("Mapping:   IDENTITY");
    } else if (mapped) {
        terminal.writeLine("Mapping:   REMAPPED");
    } else {
        terminal.writeLine("Mapping:   NOT MAPPED");
    }
}

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
            terminal.writeLine("  paging (pag)");
            terminal.writeLine("    |-* status     Show overall status of VMM");
            terminal.writeLine("    |-  check      Check VMM paging integrity");
            terminal.writeLine("    |-  translate  Translate VMM Address");
        },

        .version => {
            terminal.writeLine("Ash Operating System");
            terminal.writeLine("ASH-M0.8.3-dev | IA-32");
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
        .paging => {
            var tokens = std.mem.tokenizeScalar(u8, args, ' ');
            const subcommand = tokens.next() orelse "status";

            if (std.mem.eql(u8, subcommand, "status") and tokens.next() == null) {
                writePagingStatus(terminal);
            } else if (std.mem.eql(u8, subcommand, "check") and tokens.next() == null) {
                writePagingCheck(terminal);
            } else if (std.mem.eql(u8, subcommand, "translate") or std.mem.startsWith(u8, subcommand, "translate(")) {
                var address: []const u8 = undefined;
                if (std.mem.eql(u8, subcommand, "translate")) {
                    address = tokens.next() orelse {
                        terminal.writeLine("Usage: paging translate <address>");
                        return;
                    };
                    if (tokens.next() != null) {
                        terminal.writeLine("Usage: paging translate <address>");
                        return;
                    }
                } else {
                    if (subcommand.len <= "translate()".len or
                        subcommand[subcommand.len - 1] != ')')
                    {
                        terminal.writeLine("Usage: paging translate <address>");
                        return;
                    }
                    address = subcommand["translate(".len .. subcommand.len - 1];
                    if (tokens.next() != null) {
                        terminal.writeLine("Usage: paging translate <address>");
                        return;
                    }
                }

                if (address.len == 0) {
                    terminal.writeLine("Usage: paging translate <address>");
                    return;
                }
                writePagingTranslation(terminal, address);
            } else {
                terminal.writeLine("Usage: paging [*status|check|translate <address>]");
                terminal.writeLine("               *: Default case.");
            }
        },
    }
}
