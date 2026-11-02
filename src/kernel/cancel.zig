var requested: bool = false;

pub fn request() void {
    const ptr: *volatile bool = @volatileCast(&requested);
    ptr.* = true;
}

pub fn isRequested() bool {
    const ptr: *volatile bool = @volatileCast(&requested);
    return ptr.*;
}

pub fn clear() void {
    const ptr: *volatile bool = @volatileCast(&requested);
    ptr.* = false;
}
