pub fn readCR0() u32 {
    return asm volatile ("mov %%cr0, %[result]"
        : [result] "=r" (-> u32),
    );
}

pub fn readCR4() u32 {
    return asm volatile ("mov %%cr4, %[result]"
        : [result] "=r" (-> u32),
    );
}

pub const SSEState = struct {
    em: bool,
    ts: bool,
    osfxsr: bool,
    osxmmexcpt: bool,
};

pub fn getSSEState() SSEState {
    const cr0 = readCR0();
    const cr4 = readCR4();

    return .{
        .em = (cr0 & (1 << 2)) != 0,
        .ts = (cr0 & (1 << 3)) != 0,
        .osfxsr = (cr4 & (1 << 9)) != 0,
        .osxmmexcpt = (cr4 & (1 << 10)) != 0,
    };
}

pub const CPUFeatures = struct {
    fxsr: bool,
    sse: bool,
    sse2: bool,
};

pub fn getCPUFeatures() CPUFeatures {
    var eax: u32 = 1;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;

    asm volatile ("cpuid"
        : [eax] "+{eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx),
    );

    return .{
        .fxsr = (edx & (1 << 24)) != 0,
        .sse = (edx & (1 << 25)) != 0,
        .sse2 = (edx & (1 << 26)) != 0,
    };
}

pub const SSEInitError = error{
    UnsupportedCPU,
};

pub fn enableSSE() SSEInitError!void {
    const features = getCPUFeatures();

    if (!features.fxsr or !features.sse or !features.sse2) {
        return error.UnsupportedCPU;
    }

    var cr0 = readCR0();

    cr0 |= (@as(u32, 1) << 1);
    cr0 &= ~(@as(u32, 1) << 2);
    cr0 &= ~(@as(u32, 1) << 3);

    asm volatile ("mov %[value], %%cr0"
        :
        : [value] "r" (cr0),
        : .{ .memory = true });

    var cr4 = readCR4();

    cr4 |= (@as(u32, 1) << 9);
    cr4 |= (@as(u32, 1) << 10);

    asm volatile ("mov %[value], %%cr4"
        :
        : [value] "r" (cr4),
        : .{ .memory = true });

    asm volatile ("fninit");
}
