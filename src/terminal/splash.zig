const Terminal = @import("terminal.zig").Terminal;

pub fn show(terminal: *Terminal) void {
    terminal.setColor(.yellow, .black);

    terminal.writeLine("     _    ____  _   _");
    terminal.writeLine("    / \\  / ___|| | | |");
    terminal.writeLine("   / _ \\ \\___ \\| |_| |");
    terminal.writeLine("  / ___ \\ ___) |  _  |");
    terminal.writeLine(" /_/   \\_\\____/|_| |_|");

    terminal.writeLine("");

    terminal.setColor(.white, .black);
    terminal.writeLine("Ash Operating System");
    terminal.writeLine("Developer Preview | IA-32");
}
