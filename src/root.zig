pub const kernel = @import("kernel/main.zig");

comptime {
    _ = kernel.kernel_main;
}
