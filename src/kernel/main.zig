const idt = @import("../arch/x86/idt.zig");
const terminal_module = @import("../terminal/terminal.zig");
const shell_module = @import("../shell/shell.zig");
const splash = @import("../terminal/splash.zig");
const cpu = @import("../arch/x86/cpu.zig");

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
    idt.init();
    const features = cpu.getCPUFeatures();
    const sse = cpu.getSSEState();
    terminal.writeLine(if (sse.em) "CR0.EM = 1" else "CR0.EM = 0");
    terminal.writeLine(if (sse.ts) "CR0.TS = 1" else "CR0.TS = 0");
    terminal.writeLine(if (sse.osfxsr) "CR4.OSFXSR = 1" else "CR4.OSFXSR = 0");
    terminal.writeLine(if (sse.osxmmexcpt) "CR4.OSXMMEXCPT = 1" else "CR4.OSXMMEXCPT = 0");
    terminal.writeLine(if (features.fxsr) "CPU FXSR: YES" else "CPU FXSR: NO");
    terminal.writeLine(if (features.sse) "CPU SSE: YES" else "CPU SSE: NO");
    terminal.writeLine(if (features.sse2) "CPU SSE2: YES" else "CPU SSE2: NO");
    shell.init();
    shell.run();
}
