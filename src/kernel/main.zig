const idt = @import("../arch/x86/idt.zig");
const terminal_module = @import("../terminal/terminal.zig");
const shell_module = @import("../shell/shell.zig");
const splash = @import("../terminal/splash.zig");
const pic = @import("../arch/x86/pic.zig");
const pit = @import("../arch/x86/pit.zig");
const gdt = @import("../arch/x86/gdt.zig");
const cpu = @import("../arch/x86/cpu.zig");
const physical = @import("../memory/physical.zig");
const multiboot2 = @import("../boot/multiboot2.zig");
const bitmap = @import("../memory/bitmap.zig");
const std = @import("std");

const scancode_queue = @import("../drivers/input/scancode_queue.zig");
const ps2 = @import("../drivers/ps2.zig");

const MULTIBOOT2_MAGIC: u32 = 0x36D76289;

pub var boot_info_address: u32 = 0;

fn halt() noreturn {
    while (true) {
        asm volatile ("cli; hlt");
    }
}

pub export fn kernel_main(
    magic: u32,
    multiboot_info: u32,
) callconv(.c) noreturn {
    var terminal = terminal_module.Terminal{};
    terminal.init();

    if (magic != MULTIBOOT2_MAGIC) {
        terminal.setColor(.light_red, .black);
        terminal.writeLine("ASH: Invalid Multiboot2 magic!");
        halt();
    }
    const bool_size = multiboot2.infoSize(
        multiboot_info,
    ) orelse {
        terminal.setColor(.light_red, .black);
        terminal.writeLine("ASH: Invalid Multiboot2 information!");
        halt();
    };
    physical.reserveBootRegions(
        &physical.reservations,
        multiboot_info,
        bool_size,
    ) catch {
        terminal.setColor(.light_red, .black);
        terminal.writeLine("ASH: Failed to reserve boot memory!");
        halt();
    };

    //    var reserve_buffer: [96]u8 = undefined;
    //
    //    const reserve_message = std.fmt.bufPrint(
    //        &reserve_buffer,
    //        "ASH: {d} boot pages reserved.",
    //        .{physical.reservations.countUniquePages()},
    //    ) catch unreachable;
    //
    //    terminal.writeLine(reserve_message);

    bitmap.initPhysicalBitmap();

    //    const memory_map = multiboot2.findMemoryMap(multiboot_info) orelse unreachable;
    //    bitmap.initializeFromMemoryMap(
    //        memory_map,
    //        &physical.reservations,
    //    ) catch unreachable;
    //    if (bitmap.physicalStats()) |stats| {
    //        var stats_buffer: [128]u8 = undefined;
    //
    //        const stats_message = std.fmt.bufPrint(
    //            &stats_buffer,
    //            "ASH Memory: {d} free / {d} occupied pages",
    //            .{
    //                stats.free_pages,
    //                stats.occupied_pages,
    //            },
    //        ) catch unreachable;
    //
    //        terminal.writeLine(stats_message);
    //    }
    //
    //    const test_page = (bitmap.allocatePhysicalPage() catch unreachable) orelse unreachable;
    //
    //    var page_buffer: [128]u8 = undefined;
    //
    //    const page_message = std.fmt.bufPrint(
    //        &page_buffer,
    //        "ASH: Allocated physical page {d} (0x{X:0>8})",
    //        .{
    //            test_page,
    //            test_page * physical.PAGE_SIZE,
    //        },
    //    ) catch unreachable;
    //
    //    terminal.writeLine(page_message);
    //
    //    bitmap.freePhysicalPage(test_page) catch unreachable;
    //    terminal.writeLine("ASH: Physical page released successfully.");
    //
    //    const kernel_first_page = physical.kernelRegion().first_page;
    //
    //    if (bitmap.freePhysicalPage(kernel_first_page)) |_| {
    //        terminal.writeLine(
    //            "ASH ERROR: Kernel page was incorrectly released!",
    //        );
    //    } else |err| {
    //        if (err == error.NotAllocated) {
    //            terminal.writeLine(
    //                "ASH: Kernel page release correctly rejected.",
    //            );
    //        } else {
    //            terminal.writeLine(
    //                "ASH ERROR: Unexpected memory error.",
    //            );
    //        }
    //    }
    //
    //    if (bitmap.freePhysicalPage(1)) |_| {
    //        terminal.writeLine(
    //            "ASH ERROR: Low memory page was released!",
    //        );
    //    } else |err| {
    //        if (err == error.NotAllocated) {
    //            terminal.writeLine(
    //                "ASH: Low memory release correctly rejected.",
    //            );
    //        } else {
    //            terminal.writeLine(
    //                "ASH ERROR: Unexpected memory error.",
    //            );
    //        }
    //    }
    //
    //    var bitmap_buffer: [128]u8 = undefined;
    //
    //    const bitmap_message = std.fmt.bufPrint(
    //        &bitmap_buffer,
    //        "ASH Bitmap: 0x{X:0>8}, {d} bytes",
    //        .{
    //            bitmap.storageAddress(),
    //            bitmap.storageSize(),
    //        },
    //    ) catch unreachable;
    //
    //    terminal.writeLine(bitmap_message);

    boot_info_address = multiboot_info;
    splash.show(&terminal);
    terminal.writeLine("");
    //if (!scancode_queue.selfTest()) {
    //    terminal.writeLine("ASH: ScancodeQueue self-test failed!");
    //    halt();
    //} else {
    //    terminal.writeLine("ASH: ScancodeQueue self-test passed.");
    //}
    //if (ps2.selfTestDroppedScancodes()) {
    //    terminal.writeLine("ASH: PS/2 dropped counter self-test passed.");
    //} else {
    //    terminal.writeLine("ASH: PS/2 dropped counter self-test failed!");
    //}
    var shell = shell_module.Shell{
        .terminal = &terminal,
    };
    cpu.enableSSE() catch {
        terminal.setColor(.light_red, .black);
        terminal.writeLine("ASH: CPU does not support SSE.");
        halt();
    };

    gdt.init();
    idt.init();
    pic.init();
    pit.init();

    pic.unmask(0);
    pic.unmask(1);

    shell.init();

    asm volatile ("sti" ::: .{ .memory = true });

    shell.run();
}
