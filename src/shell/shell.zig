const terminal_module = @import("../terminal/terminal.zig");
const ps2 = @import("../drivers/ps2.zig");
const commands = @import("commands.zig");
const layout = @import("../input/layout.zig");
const Terminal = terminal_module.Terminal;

const INPUT_CAPACITY: usize = 64;

pub const Shell = struct {
    terminal: *Terminal,

    input: [INPUT_CAPACITY]u8 = undefined,
    input_len: usize = 0,

    pub fn init(self: *Shell) void {
        self.input_len = 0;

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
    }

    pub fn run(self: *Shell) noreturn {
        while (true) {
            const event = ps2.pollEvent() orelse continue;

            if (!event.pressed) continue;

            switch (event.code) {
                .enter => self.enter(),
                .backspace => self.backspace(),

                .arrow_left,
                .arrow_right,
                .arrow_up,
                .arrow_down,
                .home,
                .end,
                .delete,
                => {
                    // Reservado para la edición de línea.
                },

                else => {
                    const char = layout.toChar(event) orelse continue;
                    self.insert(char);
                },
            }
        }
    }

    fn insert(self: *Shell, char: u8) void {
        if (char < 32 or char > 126) return;

        if (self.input_len >= INPUT_CAPACITY) {
            return;
        }

        self.input[self.input_len] = char;
        self.input_len += 1;

        self.terminal.putChar(char);
    }

    fn backspace(self: *Shell) void {
        if (self.input_len == 0) return;

        self.input_len -= 1;
        self.terminal.backspace();
    }

    fn enter(self: *Shell) void {
        self.terminal.newLine();

        if (self.input_len > 0) {
            const command = self.input[0..self.input_len];

            commands.execute(self.terminal, command);
        }

        self.input_len = 0;
        self.prompt();
    }
};
