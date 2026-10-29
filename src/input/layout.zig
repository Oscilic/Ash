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
