const idt = @import("../arch/x86/idt.zig");
const terminal_module = @import("../terminal/terminal.zig");
const shell_module = @import("../shell/shell.zig");
const splash = @import("../terminal/splash.zig");
const pic = @import("../arch/x86/pic.zig");
const pit = @import("../arch/x86/pit.zig");
const gdt = @import("../arch/x86/gdt.zig");

const MULTIBOOT2_MAGIC: u32 = 0x36D76289;

fn halt() noreturn {
    while (true) {
        asm volatile ("cli; hlt");
    }
}

pub export fn kernel_main(
    magic: u32,
    multiboot_info: u32,
) callconv(.c) noreturn {
    _ = multiboot_info;

    var terminal = terminal_module.Terminal{};
    terminal.init();

    if (magic != MULTIBOOT2_MAGIC) {
        terminal.setColor(.light_red, .black);
        terminal.writeLine("ASH: Invalid Multiboot2 magic!");
        halt();
    }

    splash.show(&terminal);
    terminal.writeLine("");

    var shell = shell_module.Shell{
        .terminal = &terminal,
    };

    gdt.init();
    idt.init();
    pic.init();
    pit.init();

    pic.unmask(0);

    shell.init();

    asm volatile ("sti" ::: .{ .memory = true });

    shell.run();
}
