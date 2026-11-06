const io = @import("io.zig");

const PIC1_COMMAND: u16 = 0x20;
const PIC1_DATA: u16 = 0x21;
const PIC2_COMMAND: u16 = 0xA0;
const PIC2_DATA: u16 = 0xA1;

const ICW1_INIT: u8 = 0x10;
const ICW1_ICW4: u8 = 0x01;
const ICW4_8086: u8 = 0x01;

const EOI: u8 = 0x20;

fn ioWait() void {
    io.outb(0x80, 0);
}

pub fn init() void {
    io.outb(PIC1_DATA, 0xFF);
    io.outb(PIC2_DATA, 0xFF);

    io.outb(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
    ioWait();

    io.outb(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);
    ioWait();

    io.outb(PIC1_DATA, 0x20);
    ioWait();

    io.outb(PIC2_DATA, 0x28);
    ioWait();

    io.outb(PIC1_DATA, 0x04);
    ioWait();

    io.outb(PIC2_DATA, 0x02);
    ioWait();

    io.outb(PIC1_DATA, ICW4_8086);
    ioWait();

    io.outb(PIC2_DATA, ICW4_8086);
    ioWait();

    io.outb(PIC1_DATA, 0xFF);
    io.outb(PIC2_DATA, 0xFF);
}

pub fn sendEOI(irq: u8) void {
    if (irq >= 8) {
        io.outb(0xA0, 0x20);
    }

    io.outb(0x20, 0x20);
}
pub fn unmask(irq: u8) void {
    if (irq >= 16) return;

    const port: u16 = if (irq < 8)
        PIC1_DATA
    else
        PIC2_DATA;

    const bit: u3 = @intCast(irq % 8);

    const mask = io.inb(port);
    io.outb(port, mask & ~(@as(u8, 1) << bit));

    if (irq >= 8) {
        const master_mask = io.inb(PIC1_DATA);
        io.outb(PIC1_DATA, master_mask & ~@as(u8, 0x04));
    }
}
