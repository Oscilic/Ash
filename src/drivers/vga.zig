const VGA_BUFFER: [*]volatile u16 = @ptrFromInt(0xB8000);
const io = @import("../arch/x86/io.zig");

const VGA_COMMAND_PORT: u16 = 0x3D4;
const VGA_DATA_PORT: u16 = 0x3D5;

pub const WIDTH: usize = 80;
pub const HEIGHT: usize = 25;

pub const Color = enum(u8) { black = 0x00, blue = 0x01, green = 0x02, cyan = 0x03, red = 0x04, magenta = 0x05, brown = 0x06, light_gray = 0x07, dark_gray = 0x08, light_blue = 0x09, light_green = 0x0A, light_cyan = 0x0B, light_red = 0x0C, pink = 0x0D, yellow = 0x0E, white = 0x0F };

pub const CursorShape = enum {
    block,
    underline,
};

fn readRegister(index: u8) u8 {
    io.outb(VGA_COMMAND_PORT, index);
    return io.inb(VGA_DATA_PORT);
}

fn writeRegister(index: u8, value: u8) void {
    io.outb(VGA_COMMAND_PORT, index);
    io.outb(VGA_DATA_PORT, value);
}

pub fn setCursorShape(shape: CursorShape) void {
    const old_start = readRegister(0x0A);
    const old_end = readRegister(0x0B);

    const start_line: u8 = switch (shape) {
        .block => 0,
        .underline => 14,
    };

    const end_line: u8 = 15;

    writeRegister(
        0x0A,
        (old_start & 0xC0) | start_line,
    );

    writeRegister(
        0x0B,
        (old_end & 0xE0) | end_line,
    );
}

pub fn setCursor(x: usize, y: usize) void {
    if (x >= WIDTH or y >= HEIGHT) return;
    const position: u16 = @intCast(y * WIDTH + x);

    io.outb(VGA_COMMAND_PORT, 0x0F);
    io.outb(VGA_DATA_PORT, @truncate(position));
    io.outb(VGA_COMMAND_PORT, 0x0E);
    io.outb(VGA_DATA_PORT, @truncate(position >> 8));
}
pub fn attribute(fg: Color, bg: Color) u8 {
    return @intFromEnum(fg) | (@intFromEnum(bg) << 4);
}

pub fn putCell(x: usize, y: usize, character: u8, attr: u8) void {
    if (x >= WIDTH or y >= HEIGHT) return;

    const index = y * WIDTH + x;
    VGA_BUFFER[index] = (@as(u16, attr) << 8) | @as(u16, character);
}

pub fn clear(attr: u8) void {
    for (0..HEIGHT) |y| {
        for (0..WIDTH) |x| {
            putCell(x, y, ' ', attr);
        }
    }
}

pub fn scrollUp(attr: u8) void {
    for (0..HEIGHT - 1) |y| {
        for (0..WIDTH) |x| {
            const destination = y * WIDTH + x;
            const source = (y + 1) * WIDTH + x;

            VGA_BUFFER[destination] = VGA_BUFFER[source];
        }
    }

    for (0..WIDTH) |x| {
        putCell(x, HEIGHT - 1, ' ', attr);
    }
}
