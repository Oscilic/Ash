const io = @import("../arch/x86/io.zig");
const keyboard_module = @import("input/keyboard.zig");
const queue_module = @import("input/scancode_queue.zig");
const cpu = @import("../arch/x86/cpu.zig");

const DATA_PORT: u16 = 0x60;
const STATUS_PORT: u16 = 0x64;

const KeyEvent = keyboard_module.KeyEvent;
const Keyboard = keyboard_module.Keyboard;

var keyboard: Keyboard = .{};
var extended_pending: bool = false;
var e1_remaining: u8 = 0;

var scancode_queue: queue_module.ScancodeQueue = .{};

var dropped_scancodes: u32 = 0;

pub fn handleIrq() void {
    const status = io.inb(STATUS_PORT);

    if ((status & 0x01) == 0) return;

    const scancode = io.inb(DATA_PORT);
    if (!scancode_queue.enqueue(scancode)) {
        //dropped_scancodes +%= 1;
        recordDroppedScancode();
    }
}

pub fn pollEvent() ?KeyEvent {
    while (dequeueProtected()) |scancode| {

        if (e1_remaining > 0) {
            e1_remaining -= 1;
            continue;
        }

        if (scancode == 0xE1) {
            extended_pending = false;
            e1_remaining = 5;
            continue;
        }

        if (scancode == 0xE0) {
            extended_pending = true;
            continue;
        }

        const extended = extended_pending;
        extended_pending = false;

        return keyboard.process(scancode, extended);
    }

    return null;
}
fn dequeueProtected() ?u8 {
    const flags = cpu.saveAndDisableInterrupts();
    const result = scancode_queue.dequeue();
    cpu.restoreInterrupts(flags);
    return result;
}
pub fn getDroppedScancodes() u32 {
    return @atomicLoad(
        u32,
        &dropped_scancodes,
        .monotonic,
    );
}
fn recordDroppedScancode() void {
    _ = @atomicRmw(
        u32,
        &dropped_scancodes,
        .Add,
        1,
        .monotonic,
    );
}
pub fn selfTestDroppedScancodes() bool {
    var test_queue = queue_module.ScancodeQueue{};

    // Llenar la capacidad efectiva: 255 elementos.
    for (0..255) |i| {
        if (!test_queue.enqueue(@intCast(i))) {
            return false;
        }
    }

    const before = getDroppedScancodes();

    // La inserción 256 debe ser rechazada.
    if (test_queue.enqueue(0xAA)) {
        return false;
    }

    recordDroppedScancode();

    const after = getDroppedScancodes();

    return after == before +% 1;
}
pub fn getPendingScancodes() usize {
    const flags = cpu.saveAndDisableInterrupts();

    const pending = scancode_queue.count();

    cpu.restoreInterrupts(flags);

    return pending;
}
