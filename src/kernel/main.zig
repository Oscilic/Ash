const idt = @import("../arch/x86/idt.zig");
const terminal_module = @import("../terminal/terminal.zig");
const shell_module = @import("../shell/shell.zig");
const splash = @import("../terminal/splash.zig");
const cpu = @import("../arch/x86/cpu.zig");
const irq = @import("irq.zig");
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
    terminal.writeLine("Kernel initialized successfully.");
    terminal.writeLine("");

    var shell = shell_module.Shell{
        .terminal = &terminal,
    };
    gdt.init();

    const cs: u16 = asm volatile ("mov %%cs, %[value]"
        : [value] "=r" (-> u16),
    );

    const ds: u16 = asm volatile ("mov %%ds, %[value]"
        : [value] "=r" (-> u16),
    );

    const ss: u16 = asm volatile ("mov %%ss, %[value]"
        : [value] "=r" (-> u16),
    );

    if (cs == 0x08 and ds == 0x10 and ss == 0x10) {
        terminal.writeLine("[GDT] Selectors: PASS");
    } else {
        terminal.writeLine("[GDT] Selectors: FAIL");
    }

    gdt.init();
    idt.init();
    pic.init();
    pit.init();
    terminal.writeLine("[PIT] Timer configured");
    pic.unmask(0);
    const io = @import("../arch/x86/io.zig");

    const master_mask = io.inb(0x21);
    const slave_mask = io.inb(0xA1);

    if (master_mask == 0xFE and slave_mask == 0xFF) {
        terminal.writeLine("[PIC] Initialization: PASS");
    } else {
        terminal.writeLine("[PIC] Initialization: FAIL");
    }
    shell.init();

    asm volatile ("sti" ::: .{ .memory = true });

    shell.run();
}
