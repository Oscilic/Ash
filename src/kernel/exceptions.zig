const vga = @import("../drivers/vga.zig");

pub const ExceptionFrame = extern struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    esp_saved: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,

    vector: u32,
    error_code: u32,

    eip: u32,
    cs: u32,
    eflags: u32,
};

const names = [_][]const u8{
    "Divide Error",
    "Debug",
    "Non-Maskable Interrupt",
    "Breakpoint",
    "Overflow",
    "BOUND Range Exceeded",
    "Invalid Opcode",
    "Device Not Available",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Invalid TSS",
    "Segment Not Present",
    "Stack-Segment Fault",
    "General Protection Fault",
    "Page Fault",
    "Reserved",
    "x87 Floating-Point Exception",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating-Point Exception",
    "Virtualization Exception",
    "Control Protection Exception",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Hypervisor Injection Exception",
    "VMM Communication Exception",
    "Security Exception",
    "Reserved",
};

pub export fn ash_exception_handler(
    frame: *const ExceptionFrame,
) callconv(.c) noreturn {
    const attr = vga.attribute(.black, .yellow);

    vga.clear(attr);

    writeAt(2, 1, "AMBER SCREEN OF DEATH", attr);
    writeAt(2, 2, "Your system ran into a critical exception and will shut down.", attr);

    writeAt(2, 5, "EXCEPTION:", attr);

    if (frame.vector < names.len) {
        writeAt(13, 5, names[frame.vector], attr);
    } else {
        writeAt(13, 5, "Unknown", attr);
    }

    writeAt(2, 7, "VECTOR:", attr);
    writeHex(13, 7, frame.vector, attr);

    writeAt(2, 8, "ERROR:", attr);
    writeHex(13, 8, frame.error_code, attr);

    if (frame.vector == 14) {
        const fault_address: u32 =
            asm volatile ("mov %%cr2, %[result]"
                : [result] "=r" (-> u32),
            );

        writeAt(2, 9, "CR2:", attr);
        writeHex(13, 9, fault_address, attr);
    }

    writeAt(2, 10, "EIP:", attr);
    writeHex(13, 10, frame.eip, attr);

    writeAt(2, 11, "CS:", attr);
    writeHex(13, 11, frame.cs, attr);

    writeAt(2, 12, "EFLAGS:", attr);
    writeHex(13, 12, frame.eflags, attr);

    writeAt(2, 14, "EAX:", attr);
    writeHex(13, 14, frame.eax, attr);

    writeAt(2, 15, "EBX:", attr);
    writeHex(13, 15, frame.ebx, attr);

    writeAt(2, 16, "ECX:", attr);
    writeHex(13, 16, frame.ecx, attr);

    writeAt(2, 17, "EDX:", attr);
    writeHex(13, 17, frame.edx, attr);

    writeAt(2, 20, "STATUS: SYSTEM HALTED", attr);

    while (true) {
        asm volatile ("cli; hlt");
    }
}

fn writeAt(
    x: usize,
    y: usize,
    message: []const u8,
    attr: u8,
) void {
    for (message, 0..) |character, i| {
        if (x + i >= vga.WIDTH) break;
        vga.putCell(x + i, y, character, attr);
    }
}

fn writeHex(
    x: usize,
    y: usize,
    value: u32,
    attr: u8,
) void {
    const digits = "0123456789ABCDEF";

    vga.putCell(x, y, '0', attr);
    vga.putCell(x + 1, y, 'x', attr);

    for (0..8) |i| {
        const shift: u5 = @intCast((7 - i) * 4);
        const digit: usize = @intCast((value >> shift) & 0xF);

        vga.putCell(x + 2 + i, y, digits[digit], attr);
    }
}

fn writePageFaultDetails(
    error_code: u32,
    attr: u8,
) void {
    const address: u32 = asm volatile ("mov %%cr2, %[result]"
        : [result] "=r" (-> u32),
    );

    const present = (error_code & 0x1) != 0;
    const write = (error_code & 0x2) != 0;
    const user = (error_code & 0x4) != 0;

    writeAt(2, 9, "CR2:", attr);
    writeHex(13, 9, address, attr);

    writeAt(2, 18, "ACCESS:", attr);
    writeAt(
        13,
        18,
        if (write) "WRITE" else "READ",
        attr,
    );

    writeAt(2, 19, "REASON:", attr);
    writeAt(
        13,
        19,
        if (present) "PROTECTION" else "NOT PRESENT",
        attr,
    );

    writeAt(2, 21, "MODE:", attr);
    writeAt(
        13,
        21,
        if (user) "USER" else "SUPERVISOR",
        attr,
    );
}
