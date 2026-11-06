const IDTEntry = packed struct {
    offset_low: u16,
    selector: u16,
    zero: u8,
    type_attr: u8,
    offset_high: u16,
};

const IDTPointer = [6]u8;

comptime {
    if (@sizeOf(IDTEntry) != 8)
        @compileError("Invalid IDT entry size");

    if (@sizeOf(IDTPointer) != 6)
        @compileError("Invalid IDTR size");
}

var entries: [256]IDTEntry align(8) = undefined;

extern const ash_isr_table: [32]u32;
extern const ash_irq_table: [16]u32;

fn currentCodeSegment() u16 {
    return asm volatile ("mov %%cs, %[result]"
        : [result] "=r" (-> u16),
    );
}

pub fn setGate(
    vector: u8,
    handler: u32,
    selector: u16,
) void {
    entries[vector] = .{
        .offset_low = @truncate(handler),
        .selector = selector,
        .zero = 0,
        .type_attr = 0x8E,
        .offset_high = @truncate(handler >> 16),
    };
}

pub fn init() void {
    for (&entries) |*entry| {
        entry.* = .{
            .offset_low = 0,
            .selector = 0,
            .zero = 0,
            .type_attr = 0,
            .offset_high = 0,
        };
    }

    const cs = currentCodeSegment();

    for (0..32) |i| {
        setGate(
            @intCast(i),
            ash_isr_table[i],
            cs,
        );
    }
    for (0..16) |i| {
        setGate(
            @intCast(0x20 + i),
            ash_irq_table[i],
            cs,
        );
    }

    const limit: u16 = @intCast(@sizeOf(@TypeOf(entries)) - 1);
    const base: u32 = @intFromPtr(&entries);

    const pointer: IDTPointer = .{
        @truncate(limit),
        @truncate(limit >> 8),

        @truncate(base),
        @truncate(base >> 8),
        @truncate(base >> 16),
        @truncate(base >> 24),
    };

    asm volatile ("lidt (%[ptr])"
        :
        : [ptr] "r" (&pointer),
        : .{ .memory = true });
}
