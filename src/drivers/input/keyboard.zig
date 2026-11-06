pub const KeyCode = enum {
    unknown,

    left_shift,
    right_shift,
    caps_lock,

    left_ctrl,
    right_ctrl,

    left_alt,
    right_alt,

    arrow_up,
    arrow_down,
    arrow_left,
    arrow_right,

    home,
    end,
    insert,
    delete,

    character,
    enter,
    backspace,
    tab,
    escape,
};

pub const Modifiers = struct {
    left_shift: bool = false,
    right_shift: bool = false,
    caps_lock: bool = false,

    left_ctrl: bool = false,
    right_ctrl: bool = false,

    left_alt: bool = false,
    right_alt: bool = false,

    pub fn shift(self: Modifiers) bool {
        return self.left_shift or self.right_shift;
    }

    pub fn ctrl(self: Modifiers) bool {
        return self.left_ctrl or self.right_ctrl;
    }

    pub fn alt(self: Modifiers) bool {
        return self.left_alt or self.right_alt;
    }
};

pub const KeyEvent = struct {
    code: KeyCode,
    scancode: u8,
    extended: bool,
    pressed: bool,
    modifiers: Modifiers,
};

pub const Keyboard = struct {
    modifiers: Modifiers = .{},
    caps_pressed: bool = false,

    pub fn process(
        self: *Keyboard,
        scancode: u8,
        extended: bool,
    ) KeyEvent {
        const pressed = (scancode & 0x80) == 0;
        const key = scancode & 0x7F;

        const code = identify(key, extended);

        switch (code) {
            .left_shift => self.modifiers.left_shift = pressed,
            .right_shift => self.modifiers.right_shift = pressed,

            .left_ctrl => self.modifiers.left_ctrl = pressed,
            .right_ctrl => self.modifiers.right_ctrl = pressed,

            .left_alt => self.modifiers.left_alt = pressed,
            .right_alt => self.modifiers.right_alt = pressed,

            .caps_lock => {
                if (pressed and !self.caps_pressed) {
                    self.modifiers.caps_lock =
                        !self.modifiers.caps_lock;
                }

                self.caps_pressed = pressed;
            },

            else => {},
        }

        return .{
            .code = code,
            .scancode = key,
            .extended = extended,
            .pressed = pressed,
            .modifiers = self.modifiers,
        };
    }
};

fn identify(key: u8, extended: bool) KeyCode {
    if (extended) {
        return switch (key) {
            0x1D => .right_ctrl,
            0x38 => .right_alt,

            0x48 => .arrow_up,
            0x50 => .arrow_down,
            0x4B => .arrow_left,
            0x4D => .arrow_right,

            0x47 => .home,
            0x4F => .end,
            0x52 => .insert,
            0x53 => .delete,

            else => .unknown,
        };
    }

    return switch (key) {
        0x2A => .left_shift,
        0x36 => .right_shift,
        0x3A => .caps_lock,

        0x1D => .left_ctrl,
        0x38 => .left_alt,

        0x1C => .enter,
        0x0E => .backspace,
        0x0F => .tab,
        0x01 => .escape,

        else => .character,
    };
}
