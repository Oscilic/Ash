const MULTIBOOT2_MAGIC: u32 = 0x36D76289;
const VGA_BUFFER: [*]volatile u16 = @ptrFromInt(0xB8000);

const VGA_WIDTH: usize = 80;
const VGA_HEIGHT: usize = 25;

const COLOR_AMBER: u8 = 0x0E;
const COLOR_WHITE: u8 = 0x0F;
const COLOR_RED: u8 = 0x0C;

fn clearScreen() void 
{
    const attribute: u16 = @as(u16, COLOR_WHITE) << 8;
    for (0..VGA_WIDTH * VGA_HEIGHT) |i| 
    {
        VGA_BUFFER[i] = attribute | @as(u16, ' ');
    }
}

fn printString(text: []const u8, x: usize, y:usize, color: u8) void
{
    if (y >= VGA_HEIGHT or x >= VGA_WIDTH) return;
    const attribute: u16 = @as(u16, color) << 8;
    for (text, 0..) |char, i| 
    {
        if (x + i >= VGA_WIDTH) break;
        const index = y * VGA_WIDTH + x + i;
        VGA_BUFFER[index] = attribute | @as(u16, char);
    }
}

fn halt() noreturn 
{
    while (true) 
    {
        asm volatile ("cli;hlt");
    }
}

export fn kernel_main(magic: u32, multiboot_info: u32) callconv(.c) noreturn
{
    _ = multiboot_info;
    clearScreen();

    if (magic != MULTIBOOT2_MAGIC)
    {
        printString("ASH: Invalid Multiboot2 magic!", 2, 2, COLOR_RED);
        halt();
    }
    printString("ASH Operating System", 2, 2, COLOR_AMBER);
    printString("Kernel initializaed successfully", 2, 4, COLOR_WHITE);
    printString("Architecture: IA-32", 2, 6, COLOR_WHITE);
    printString("Boot Protocol: Multiboot2", 2, 7, COLOR_WHITE);
    printString("ASH-M0.0 | Bootstrap Foundation", 2, 9, COLOR_AMBER);
    halt();
}