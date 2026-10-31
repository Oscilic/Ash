const GDTEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,
};

const GDTPointer = packed struct {
    limit: u16,
    base: u32,
};

pub const KERNEL_CODE: u16 = 0x08;
pub const KERNEL_DATA: u16 = 0x10;

var entries: [3]GDTEntry align(8) = .{
    .{
        .limit_low = 0,
        .base_low = 0,
        .base_middle = 0,
        .access = 0,
        .granularity = 0,
        .base_high = 0,
    },

    // Código Ring 0, 32 bits, base 0, límite 4 GiB.
    .{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = 0x9A,
        .granularity = 0xCF,
        .base_high = 0,
    },

    // Datos Ring 0, 32 bits, base 0, límite 4 GiB.
    .{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = 0x92,
        .granularity = 0xCF,
        .base_high = 0,
    },
};

var gdtr: GDTPointer = undefined;

extern fn ash_gdt_flush(pointer: *const GDTPointer) callconv(.c) void;

pub fn init() void {
    gdtr = .{
        .limit = @sizeOf(@TypeOf(entries)) - 1,
        .base = @intFromPtr(&entries),
    };

    ash_gdt_flush(&gdtr);
}
