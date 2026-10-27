const vga = @import("../drivers/vga.zig");
const MULTIBOOT2_MAGIC: u32 = 0x36D76289;

fn halt() noreturn {
    while (true) {
        asm volatile ("cli;hlt");
    }
}

fn printAt(text: []const u8, x: usize, y: usize, attr: u8) void {
    for (text, 0..) |char, i| {
        if (x + i >= vga.WIDTH) break;
        vga.putCell(x + i, y, char, attr);
    }
}

pub export fn kernel_main(magic: u32, multiboot_info: u32) callconv(.c) noreturn {
    _ = multiboot_info;
    const normal = vga.attribute(.white, .black);
    const amber = vga.attribute(.yellow, .black);
    const error_color = vga.attribute(.light_red, .black);

    vga.clear(normal);

    if (magic != MULTIBOOT2_MAGIC) {
        printAt("ASH: Invalid Multiboot2 magic!", 2, 2, error_color);
        halt();
    }
    printAt("ASH Operating System", 2, 2, amber);
    printAt("Kernel initialized successfully", 2, 4, normal);
    printAt("Architecture: IA-32", 2, 6, normal);
    printAt("Boot protocol: Multiboot2", 2, 7, normal);
    printAt("ASH-M0.1 | VGA Driver", 2, 9, amber);
    halt();
}
