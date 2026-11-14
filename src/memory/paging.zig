const physical = @import("physical.zig");

pub const PAGE_SIZE: usize = physical.PAGE_SIZE;
pub const ENTRIES_PER_TABLE: usize = 1024;
pub const TABLE_COUNT: usize = 4;

pub const INITIAL_MAPPED_BYTES: usize =
    TABLE_COUNT * ENTRIES_PER_TABLE * PAGE_SIZE;

const PRESENT: u32 = 1 << 0;
const WRITABLE: u32 = 1 << 1;
const USER: u32 = 1 << 2;
const FLAGS: u32 = PRESENT | WRITABLE;
const ADDRESS_MASK: u32 = 0xFFFFF000;

var page_directory: [ENTRIES_PER_TABLE]u32 align(4096) =
    [_]u32{0} ** ENTRIES_PER_TABLE;

var page_tables: [TABLE_COUNT][ENTRIES_PER_TABLE]u32 align(4096) =
    [_][ENTRIES_PER_TABLE]u32{
        [_]u32{0} ** ENTRIES_PER_TABLE,
    } ** TABLE_COUNT;

var initialized: bool = false;

pub const Error = error{
    KernelOutsideInitialMapping,
    PagingStructuresOutsideInitialMapping,
};

pub const MappingInfo = struct {
    physical_address: usize,
    present: bool,
    writable: bool,
    user: bool,
};

fn isMappedRange(start: usize, size: usize) bool {
    if (start > INITIAL_MAPPED_BYTES) return false;
    return size <= INITIAL_MAPPED_BYTES - start;
}

pub fn prepare() Error!void {
    initialized = false;

    const kernel = physical.kernelRegion();

    if (kernel.end > INITIAL_MAPPED_BYTES) {
        return error.KernelOutsideInitialMapping;
    }

    if (!isMappedRange(@intFromPtr(&page_directory), @sizeOf(@TypeOf(page_directory))) or
        !isMappedRange(@intFromPtr(&page_tables), @sizeOf(@TypeOf(page_tables))))
    {
        return error.PagingStructuresOutsideInitialMapping;
    }

    @memset(page_directory[0..], 0);

    for (0..TABLE_COUNT) |directory_index| {
        @memset(page_tables[directory_index][0..], 0);

        for (0..ENTRIES_PER_TABLE) |table_index| {
            const page_index =
                directory_index * ENTRIES_PER_TABLE + table_index;

            const address: u32 = @intCast(page_index * PAGE_SIZE);

            page_tables[directory_index][table_index] =
                address | FLAGS;
        }

        const table_address: u32 =
            @intCast(@intFromPtr(&page_tables[directory_index]));

        page_directory[directory_index] =
            table_address | FLAGS;
    }

    initialized = true;
}

pub fn isPrepared() bool {
    return initialized;
}

pub fn directoryAddress() usize {
    return @intFromPtr(&page_directory);
}

pub fn mappingInfo(virtual_address: usize) ?MappingInfo {
    if (!initialized) return null;
    if (virtual_address >= INITIAL_MAPPED_BYTES) return null;

    const directory_index = virtual_address >> 22;
    const table_index = (virtual_address >> 12) & 0x3FF;
    const offset = virtual_address & 0xFFF;

    const directory_entry = page_directory[directory_index];

    if ((directory_entry & PRESENT) == 0) {
        return .{
            .physical_address = 0,
            .present = false,
            .writable = false,
            .user = false,
        };
    }

    const table_address: usize =
        @intFromPtr(&page_tables[directory_index]);

    if ((directory_entry & ADDRESS_MASK) != table_address) {
        return null;
    }

    const entry = page_tables[directory_index][table_index];
    const present = (entry & PRESENT) != 0;

    if (!present) {
        return .{
            .physical_address = 0,
            .present = false,
            .writable = false,
            .user = false,
        };
    }

    return .{
        .physical_address = @as(usize, entry & ADDRESS_MASK) + offset,
        .present = true,
        .writable = (directory_entry & WRITABLE) != 0 and
            (entry & WRITABLE) != 0,
        .user = (directory_entry & USER) != 0 and
            (entry & USER) != 0,
    };
}

pub fn translateInitial(virtual_address: usize) ?usize {
    const mapping = mappingInfo(virtual_address) orelse return null;
    if (!mapping.present) return null;
    return mapping.physical_address;
}

pub fn enable() void {
    const directory: u32 = @intCast(directoryAddress());

    asm volatile (
        \\mov %[directory], %%cr3
        \\mov %%cr0, %%eax
        \\orl $0x80000000, %%eax
        \\mov %%eax, %%cr0
        :
        : [directory] "r" (directory),
        : .{ .eax = true, .memory = true });
}

pub fn isEnabled() bool {
    const cr0: u32 = asm volatile ("mov %%cr0, %[result]"
        : [result] "=r" (-> u32),
    );

    return (cr0 & 0x80000000) != 0;
}

pub fn isWriteProtectEnabled() bool {
    const cr0: u32 = asm volatile ("mov %%cr0, %[result]"
        : [result] "=r" (-> u32),
    );

    return (cr0 & 0x00010000) != 0;
}

pub fn activeDirectoryAddress() usize {
    const cr3: u32 = asm volatile ("mov %%cr3, %[result]"
        : [result] "=r" (-> u32),
    );

    return @as(usize, cr3 & 0xFFFFF000);
}
