const vga = @import("../drivers/vga.zig");

pub const Terminal = struct {
    cursor_x: usize = 0,
    cursor_y: usize = 0,
    col: u8 = vga.attribute(.white, .black),
    default_color: u8 = vga.attribute(.white, .black),
    clear_color: u8 = vga.attribute(.white, .black),

    color: u8 = vga.attribute(.white, .black),

    fn syncCursor(self: *Terminal) void {
        vga.setCursor(self.cursor_x, self.cursor_y);
    }

    pub fn init(self: *Terminal) void {
        self.cursor_x = 0;
        self.cursor_y = 0;
        self.color = vga.attribute(.white, .black);

        vga.clear(self.color);
        self.syncCursor();
    }

    pub fn setColor(self: *Terminal, fg: vga.Color, bg: vga.Color) void {
        self.color = vga.attribute(fg, bg);
    }

    pub fn clear(self: *Terminal) void {
        vga.clear(self.color);

        self.cursor_x = 0;
        self.cursor_y = 0;

        self.syncCursor();
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
        self.syncCursor();
    }

    pub fn newLine(self: *Terminal) void {
        self.cursor_x = 0;
        self.cursor_y += 1;

        if (self.cursor_y >= vga.HEIGHT) {
            self.scroll();
            self.cursor_y = vga.HEIGHT - 1;
        }
        self.syncCursor();
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
            self.syncCursor();
        }
    }

    fn scroll(self: *Terminal) void {
        vga.scrollUp(self.color);
    }

    pub fn setCursorPosition(
        self: *Terminal,
        x: usize,
        y: usize,
    ) void {
        if (x >= vga.WIDTH or y >= vga.HEIGHT) return;

        self.cursor_x = x;
        self.cursor_y = y;
        self.syncCursor();
    }

    pub fn drawInputLine(
        self: *Terminal,
        start_x: usize,
        start_y: usize,
        text: []const u8,
        cursor: usize,
        view_offset: usize,
        selection_start: usize,
        selection_end: usize,
    ) void {
        if (start_x >= vga.WIDTH or start_y >= vga.HEIGHT) return;

        const available = vga.WIDTH - start_x;
        const selection_color = vga.attribute(.black, .yellow);

        for (0..available) |i| {
            const index = view_offset + i;

            const char: u8 = if (index < text.len)
                text[index]
            else
                ' ';

            const selected =
                index < text.len and
                index >= selection_start and
                index < selection_end;

            vga.putCell(
                start_x + i,
                start_y,
                char,
                if (selected) selection_color else self.color,
            );
        }

        const relative_cursor =
            if (cursor >= view_offset)
                cursor - view_offset
            else
                0;

        self.setCursorPosition(
            start_x + @min(relative_cursor, available - 1),
            start_y,
        );
    }
};
