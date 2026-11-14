const builtin = @import("builtin");

fn faultTestRead() void {
    const ptr: *volatile u32 = @ptrFromInt(0x01000000);

    _ = ptr.*;
}

fn faultTestWrite() void {
    const ptr: *volatile u32 = @ptrFromInt(0x01000000);

    ptr.* = 0xDEADBEEF;
}
