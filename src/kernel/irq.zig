const pic = @import("../arch/x86/pic.zig");
const queue_module = @import("../drivers/input/scancode_queue.zig");

var scancode_queue: queue_module.ScancodeQueue = .{};

var tick_count: u64 = 0;
var keyboard_irq_count: u32 = 0;

pub export fn ash_irq_handler(irq: u32) callconv(.c) void {
    switch (irq) {
        0 => {
            tick_count += 1;
            pic.sendEOI(0);
        },
        1 => {
            keyboard_irq_count +%= 1;
            const scancode = @import("../drivers/ps2.zig").readIrqScancode() orelse return;
            _ = scancode_queue.enqueue(scancode);
            pic.sendEOI(1);
        },
        else => {},
    }
}

pub fn ticks() u64 {
    const flags: u32 = asm volatile (
        \\pushfl
        \\popl %[result]
        : [result] "=r" (-> u32),
        :
        : .{ .memory = true });

    asm volatile ("cli" ::: .{ .memory = true });

    const ptr: *volatile u64 = @volatileCast(&tick_count);
    const value = ptr.*;

    asm volatile (
        \\pushl %[flags]
        \\popfl
        :
        : [flags] "r" (flags),
        : .{ .memory = true });

    return value;
}
