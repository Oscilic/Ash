const terminal_module = @import("../terminal/terminal.zig");
const ps2 = @import("../drivers/ps2.zig");
const commands = @import("commands.zig");
const layout = @import("../input/layout.zig");
const editor_module = @import("line_editor.zig");
const vga = @import("../drivers/vga.zig");
const history_module = @import("history.zig");
const History = history_module.History;
const Terminal = terminal_module.Terminal;
const LineEditor = editor_module.LineEditor;

pub const Shell = struct {
    terminal: *Terminal,
    editor: LineEditor = .{},
    history: History = .{},
    input_x: usize = 0,
    input_y: usize = 0,
    view_offset: usize = 0,

    pub fn init(self: *Shell) void {
        self.editor.reset();
        self.view_offset = 0;

        self.terminal.setColor(.yellow, .black);
        self.terminal.writeLine("Ash Interactive Shell");

        self.terminal.setColor(.white, .black);
        self.terminal.writeLine("Type 'help' for commands.");
        self.terminal.writeLine("");

        self.prompt();
    }

    fn prompt(self: *Shell) void {
        self.terminal.setColor(.yellow, .black);
        self.terminal.write("Ash> ");

        self.terminal.setColor(.white, .black);

        self.input_x = self.terminal.cursor_x;
        self.input_y = self.terminal.cursor_y;
        self.view_offset = 0;

        self.redraw();
    }

    fn redraw(self: *Shell) void {
        const width = vga.WIDTH - self.input_x;

        self.view_offset = self.editor.visibleOffset(
            self.view_offset,
            width,
        );
        vga.setCursorShape(
            if (self.editor.mode == .insert)
                .block
            else
                .underline,
        );

        self.terminal.drawInputLine(
            self.input_x,
            self.input_y,
            self.editor.text(),
            self.editor.cursor,
            self.view_offset,
            self.editor.selectionStart(),
            self.editor.selectionEnd(),
        );
    }

    pub fn run(self: *Shell) noreturn {
        while (true) {
            const event = ps2.pollEvent() orelse continue;

            if (!event.pressed) continue;

            switch (event.code) {
                .enter => self.enter(),

                .backspace => {
                    if (self.editor.backspace()) self.redraw();
                },

                .delete => {
                    if (self.editor.delete()) self.redraw();
                },
                .arrow_up => {
                    if (self.history.previous(self.editor.text())) |command| {
                        self.editor.loadText(command);
                        self.redraw();
                    }
                },

                .arrow_down => {
                    if (self.history.nextEntry()) |command| {
                        self.editor.loadText(command);
                        self.redraw();
                    }
                },

                .arrow_left => {
                    if (event.modifiers.shift()) {
                        self.editor.moveLeftSelecting();
                    } else {
                        self.editor.moveLeftNormal();
                    }
                    self.redraw();
                },

                .arrow_right => {
                    if (event.modifiers.shift()) {
                        self.editor.moveRightSelecting();
                    } else {
                        self.editor.moveRightNormal();
                    }
                    self.redraw();
                },

                .home => {
                    if (event.modifiers.shift()) {
                        self.editor.moveHomeSelecting();
                    } else {
                        self.editor.clearSelection();
                        self.editor.moveHome();
                    }
                    self.redraw();
                },

                .end => {
                    if (event.modifiers.shift()) {
                        self.editor.moveEndSelecting();
                    } else {
                        self.editor.clearSelection();
                        self.editor.moveEnd();
                    }
                    self.redraw();
                },

                .insert => {
                    self.editor.toggleMode();
                    self.redraw();
                },

                else => {
                    if (event.modifiers.ctrl() and
                        !event.modifiers.alt() and
                        event.code == .character and
                        event.scancode == 0x1E)
                    {
                        self.editor.selectAll();
                        self.redraw();
                        continue;
                    }
                    if (event.modifiers.ctrl() or
                        event.modifiers.alt())
                    {
                        continue;
                    }

                    const char = layout.toChar(event) orelse continue;

                    if (self.editor.writeChar(char)) {
                        self.redraw();
                    }
                },
            }
        }
    }

    fn enter(self: *Shell) void {
        // Ubicar la salida después del área de entrada.
        self.terminal.setCursorPosition(
            self.input_x,
            self.input_y,
        );
        self.terminal.newLine();

        if (self.editor.length > 0) {
            self.history.add(self.editor.text());
            commands.execute(self.terminal, self.editor.text());
        }

        self.history.resetNavigation();
        self.editor.reset();
        self.prompt();
    }
};
