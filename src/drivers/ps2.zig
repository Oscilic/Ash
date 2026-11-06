const io = @import("../arch/x86/io.zig");
const keyboard_module = @import("input/keyboard.zig");
const queue_module = @import("input/scancode_queue.zig");

const DATA_PORT: u16 = 0x60;
const STATUS_PORT: u16 = 0x64;

const KeyEvent = keyboard_module.KeyEvent;
const Keyboard = keyboard_module.Keyboard;

var keyboard: Keyboard = .{};
var extended_pending: bool = false;

var scancode_queue: queue_module.ScancodeQueue = .{};

pub fn handleIrq() void {
    const status = io.inb(STATUS_PORT);

    if ((status & 0x01) == 0) return;

    const scancode = io.inb(DATA_PORT);

    _ = scancode_queue.enqueue(scancode);
}

pub fn pollEvent() ?KeyEvent {
    const scancode = dequeueProtected() orelse return null;

    if (scancode == 0xE0) {
        extended_pending = true;
        return null;
    }

    const extended = extended_pending;
    extended_pending = false;

    if (scancode == 0xE1) {
        return null;
    }

    return keyboard.process(scancode, extended);
}
fn dequeueProtected() ?u8 {
    const flags: u32 = asm volatile (
        \\pushfl
        \\popl %[result]
        : [result] "=r" (-> u32),
        :
        : .{ .memory = true });

    asm volatile ("cli" ::: .{ .memory = true });

    const result = scancode_queue.dequeue();

    asm volatile (
        \\pushl %[flags]
        \\popfl
        :
        : [flags] "r" (flags),
        : .{ .memory = true });

    return result;
}
