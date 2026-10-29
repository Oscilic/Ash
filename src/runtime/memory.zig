pub export fn memset(
    dest: [*]u8,
    value: c_int,
    count: usize,
) callconv(.c) [*]u8 {
    const bytes: [*]volatile u8 = @ptrCast(dest);
    const byte: u8 = @truncate(@as(c_uint, @bitCast(value)));

    var i: usize = 0;

    while (i < count) : (i += 1) {
        bytes[i] = byte;
    }

    return dest;
}
