const irq = @import("irq.zig");

pub const TICKS_PER_SECOND: u64 = 100;

pub fn waitTicks(amount: u64) void {
    const start = irq.ticks();

    while (irq.ticks() -% start < amount) {
        asm volatile ("pause");
    }
}

pub fn waitMs(milliseconds: u64) void {
    if (milliseconds == 0) return;

    const ticks_needed =
        milliseconds / 10 +
        @as(u64, @intFromBool(milliseconds % 10 != 0));

    waitTicks(ticks_needed);
}

pub fn waitSec(seconds: u64) void {
    waitTicks(seconds *| TICKS_PER_SECOND);
}
