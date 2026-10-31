const io = @import("io.zig");

pub const BASE_FREQUENCY: u32 = 1_193_182;
pub const TARGET_FREQUENCY: u32 = 100;

const CHANNEL0: u16 = 0x40;
const COMMAND: u16 = 0x43;

pub const DIVISOR: u16 =
    @intCast(BASE_FREQUENCY / TARGET_FREQUENCY);

pub const ACTUAL_FREQUENCY: u32 =
    BASE_FREQUENCY / @as(u32, DIVISOR);

pub fn init() void {
    const divisor: u16 = @intCast(BASE_FREQUENCY / TARGET_FREQUENCY);

    io.outb(0x43, 0x34);

    io.outb(0x40, @truncate(divisor));
    io.outb(0x40, @truncate(divisor >> 8));
}
