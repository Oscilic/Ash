const vga = @import("../drivers/vga.zig");

pub const Terminal = struct {
    cursor_x: usize = 0,
    cursor_y: usize = 0,

    color: u8 = vga.attribute(.white, .black),

    pub fn init(self: *Terminal) void {
        self.cursor_x = 0;
        self.cursor_y = 0;
        self.color = vga.attribute(.white, .black);

        vga.clear(self.color);
    }

    pub fn setColor(self: *Terminal, fg: vga.Color, bg: vga.Color) void {
        self.color = vga.attribute(fg, bg);
    }

    pub fn clear(self: *Terminal) void {
        vga.clear(self.color);

        self.cursor_x = 0;
        self.cursor_y = 0;
    }

    pub fn write(self: *Terminal, text: []const u8) void {
        for (text) |char| {
            self.putChar(char);
        }
    }

    pub fn writeLine(self: *Terminal, text: []const u8) void {
        self.write(text);
        self.newLine();
    }

    pub fn putChar(self: *Terminal, char: u8) void {
        switch (char) {
            '\n' => {
                self.newLine();
                return;
            },
            '\r' => {
                self.cursor_x = 0;
                return;
            },
            '\x08' => {
                self.backspace();
                return;
            },
            else => {},
        }

        vga.putCell(
            self.cursor_x,
            self.cursor_y,
            char,
            self.color,
        );

        self.cursor_x += 1;

        if (self.cursor_x >= vga.WIDTH) {
            self.newLine();
        }
    }

    pub fn newLine(self: *Terminal) void {
        self.cursor_x = 0;
        self.cursor_y += 1;

        if (self.cursor_y >= vga.HEIGHT) {
            self.scroll();
            self.cursor_y = vga.HEIGHT - 1;
        }
    }

    pub fn backspace(self: *Terminal) void {
        if (self.cursor_x > 0) {
            self.cursor_x -= 1;

            vga.putCell(
                self.cursor_x,
                self.cursor_y,
                ' ',
                self.color,
            );
        }
    }

    fn scroll(self: *Terminal) void {
        vga.scrollUp(self.color);
    }
};
