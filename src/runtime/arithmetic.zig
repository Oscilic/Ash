const DivisionResult = struct {
    quotient: u64,
    remainder: u64,
};

fn divideUnsigned(numerator: u64, denominator: u64) DivisionResult {
    if (denominator == 0) {
        @trap();
    }

    var quotient: u64 = 0;
    var remainder: u64 = 0;

    var i: u7 = 64;

    while (i > 0) {
        i -= 1;

        const bit: u64 =
            (numerator >> @as(u6, @intCast(i))) & 1;

        const carry = (remainder >> 63) != 0;

        remainder = (remainder << 1) | bit;

        if (carry or remainder >= denominator) {
            remainder -%= denominator;

            quotient |=
                @as(u64, 1) << @as(u6, @intCast(i));
        }
    }

    return .{
        .quotient = quotient,
        .remainder = remainder,
    };
}

pub export fn __udivdi3(
    numerator: u64,
    denominator: u64,
) callconv(.c) u64 {
    return divideUnsigned(numerator, denominator).quotient;
}

pub export fn __umoddi3(
    numerator: u64,
    denominator: u64,
) callconv(.c) u64 {
    return divideUnsigned(numerator, denominator).remainder;
}
