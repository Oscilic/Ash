const pic = @import("../arch/x86/pic.zig");

var tick_count: u64 = 0;

pub export fn ash_irq_handler(irq: u32) callconv(.c) void {
    if (irq == 0) {
        const ptr: *volatile u64 = @volatileCast(&tick_count);
        ptr.* +%= 1;
    }

    if (irq < 16) {
        pic.sendEOI(@intCast(irq));
    }
}

pub fn ticks() u64 {
    // Guardar el estado original de EFLAGS.
    const flags: u32 = asm volatile (
        \\pushfl
        \\popl %[result]
        : [result] "=r" (-> u32),
        :
        : .{ .memory = true });

    // Evitar que IRQ0 interrumpa una lectura de 64 bits.
    asm volatile ("cli" ::: .{ .memory = true });

    const ptr: *volatile u64 = @volatileCast(&tick_count);
    const value = ptr.*;

    // Restaurar EFLAGS, incluido el estado anterior de IF.
    asm volatile (
        \\pushl %[flags]
        \\popfl
        :
        : [flags] "r" (flags),
        : .{ .memory = true });

    return value;
}
