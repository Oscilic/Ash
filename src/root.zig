pub const kernel = @import("kernel/main.zig");
pub const exceptions = @import("kernel/exceptions.zig");
pub const memory = @import("runtime/memory.zig");
pub const irq = @import("kernel/irq.zig");
const arithmetic = @import("runtime/arithmetic.zig");

comptime {
    _ = arithmetic.__udivdi3;
    _ = arithmetic.__umoddi3;
    _ = kernel.kernel_main;
    _ = exceptions.ash_exception_handler;
    _ = memory.memset;
    _ = @import("kernel/irq.zig");
}
