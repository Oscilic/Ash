const terminal_module = @import("../terminal/terminal.zig");
const MULTIBOOT2_MAGIC: u32 = 0x36D76289;

fn halt() noreturn {
    while (true) {
        asm volatile ("cli;hlt");
    }
}

pub export fn kernel_main(magic: u32, multiboot_info: u32) callconv(.c) noreturn {
    _ = multiboot_info;
    var terminal = terminal_module.Terminal{};
    terminal.init();
    if (magic != MULTIBOOT2_MAGIC) {
        terminal.setColor(.light_red, .black);
        terminal.writeLine("ASH: Invalid Multiboot2 magic!");
        halt();
    }
    terminal.setColor(.yellow, .black);
    terminal.writeLine("ASH Operating System");
    terminal.writeLine("");
    terminal.setColor(.white, .black);
    terminal.writeLine("Kernel initialized successfully.");
    terminal.writeLine("");
    terminal.writeLine("Architecture: IA-32");
    terminal.writeLine("Boot protocol: Multiboot2");
    terminal.writeLine("");
    terminal.setColor(.yellow, .black);
    terminal.writeLine("ASH-M0.1.2 | Terminal Manager");

    terminal.setColor(.white, .black);

    for (0..30) |_| {
        terminal.writeLine("ASH Terminal scrolling test.");
    }

    halt();
}
