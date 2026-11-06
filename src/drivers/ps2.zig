const io = @import("../arch/x86/io.zig");
const keyboard_module = @import("../drivers/input/keyboard.zig");

const DATA_PORT: u16 = 0x60;
const STATUS_PORT: u16 = 0x64;

const KeyEvent = keyboard_module.KeyEvent;
const Keyboard = keyboard_module.Keyboard;

var keyboard: Keyboard = .{};
var extended_pending: bool = false;

//pub fn pollScancode() ?u8 {
//    const status = io.inb(STATUS_PORT);
//
//    if ((status & 0x01) == 0) {
//        return null;
//    }
//
//    return io.inb(DATA_PORT);
//}

pub fn readIrqScancode() ?u8 {
    const status = io.inb(STATUS_PORT);

    if ((status & 0x01) == 0) {
        return null;
    }

    return io.inb(DATA_PORT);
}

pub fn pollEvent() ?KeyEvent {
    const scancode = readIrqScancode() orelse return null;

    if (scancode == 0xE0) {
        extended_pending = true;
        return null;
    }

    const extended = extended_pending;
    extended_pending = false;

    //pendiente
    if (scancode == 0xE1) {
        return null;
    }

    return keyboard.process(scancode, extended);
}
