pub export fn memcpy(
    dest: [*]u8,
    src: [*]const u8,
    n: usize,
) callconv(.c) [*]u8 {
    var i: usize = 0;

    while (i < n) : (i += 1) {
        dest[i] = src[i];
    }

    return dest;
}

pub export fn memset(
    dest: [*]u8,
    value: c_int,
    n: usize,
) callconv(.c) [*]u8 {
    const byte: u8 = @truncate(@as(c_uint, @bitCast(value)));

    var i: usize = 0;

    while (i < n) : (i += 1) {
        dest[i] = byte;
    }

    return dest;
}
