const builtin = @import("builtin");

pub fn architectureName() []const u8 {
    return switch (builtin.cpu.arch) {
        .x86 => "IA-32",
        .x86_64 => "x86-64",
        else => "Unknown",
    };
}
