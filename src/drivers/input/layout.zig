const keyboard = @import("keyboard.zig");

const KeyEvent = keyboard.KeyEvent;

const MAP = [_]u8{
    0,    27,  '1', '2',  '3', '4', '5', '6',
    '7',  '8', '9', '0',  '-', '=', 8,   9,
    'q',  'w', 'e', 'r',  't', 'y', 'u', 'i',
    'o',  'p', '[', ']',  13,  0,   'a', 's',
    'd',  'f', 'g', 'h',  'j', 'k', 'l', ';',
    '\'', '`', 0,   '\\', 'z', 'x', 'c', 'v',
    'b',  'n', 'm', ',',  '.', '/', 0,   '*',
    0,    ' ',
};

pub fn toChar(event: KeyEvent) ?u8 {
    if (!event.pressed) return null;
    if (event.code == .numpad_digit) {
        if (!event.modifiers.num_lock) return null;

        return switch (event.scancode) {
            0x52 => '0',
            0x4F => '1',
            0x50 => '2',
            0x51 => '3',
            0x4B => '4',
            0x4C => '5',
            0x4D => '6',
            0x47 => '7',
            0x48 => '8',
            0x49 => '9',
            else => null,
        };
    }
    switch (event.code) {
        .numpad_multiply => return '*',
        .numpad_divide => return '/',
        .numpad_subtract => return '-',
        .numpad_add => return '+',

        .numpad_decimal => {
            if (event.modifiers.num_lock) {
                return '.';
            }
            return null;
        },

        else => {},
    }
    if (event.extended) return null;
    if (event.code != .character) return null;

    if (event.scancode >= MAP.len) return null;

    const char = MAP[event.scancode];
    if (char == 0) return null;

    const shift = event.modifiers.shift();
    const caps = event.modifiers.caps_lock;

    if (char >= 'a' and char <= 'z') {
        if (shift != caps) {
            return char - ('a' - 'A');
        }

        return char;
    }

    if (!shift) return char;

    return switch (char) {
        '1' => '!',
        '2' => '@',
        '3' => '#',
        '4' => '$',
        '5' => '%',
        '6' => '^',
        '7' => '&',
        '8' => '*',
        '9' => '(',
        '0' => ')',
        '-' => '_',
        '=' => '+',
        '[' => '{',
        ']' => '}',
        ';' => ':',
        '\'' => '"',
        '`' => '~',
        '\\' => '|',
        ',' => '<',
        '.' => '>',
        '/' => '?',
        else => char,
    };
}
