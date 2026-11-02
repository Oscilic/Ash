const irq = @import("irq.zig");

pub const Duration = struct {
    days: u64,
    hours: u8,
    minutes: u8,
    seconds: u8,
    milliseconds: u16,

    pub fn uptime() Duration {
        const raw_ticks = irq.ticks();
        const total_ms = raw_ticks * 10;

        const ms_per_second = 1000;
        const ms_per_minute = ms_per_second * 60;
        const ms_per_hour = ms_per_minute * 60;
        const ms_per_day = ms_per_hour * 24;

        const days = total_ms / ms_per_day;
        const hours = (total_ms % ms_per_day) / ms_per_hour;
        const minutes = (total_ms % ms_per_hour) / ms_per_minute;
        const seconds = (total_ms % ms_per_minute) / ms_per_second;
        const milliseconds = total_ms % ms_per_second;

        return Duration{ .days = days, .hours = @intCast(hours), .minutes = @intCast(minutes), .seconds = @intCast(seconds), .milliseconds = @intCast(milliseconds) };
    }
};

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
