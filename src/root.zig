pub const kernel = @import("kernel/main.zig");
pub const exceptions = @import("kernel/exceptions.zig");
pub const memory = @import("runtime/memory.zig");

comptime {
    _ = kernel.kernel_main;
    _ = exceptions.ash_exception_handler;
    _ = memory.memset;
}
