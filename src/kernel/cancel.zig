var requested: u8 = 0;

pub fn request() void {
    @atomicStore(u8, &requested, 1, .monotonic);
}

pub fn isRequested() bool {
    return @atomicLoad(u8, &requested, .monotonic) != 0;
}

pub fn clear() void {
    @atomicStore(u8, &requested, 0, .monotonic);
}
