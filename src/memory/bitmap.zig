const physical = @import("physical.zig");
const multiboot2 = @import("../boot/multiboot2.zig");

pub const Bitmap = struct {
    data: []u8,
    page_count: usize,

    pub const Error = error{
        InvalidStorage,
        InvalidPage,
        AlreadyFree,
    };

    pub fn init(
        storage: []u8,
        page_count: usize,
    ) Error!Bitmap {
        const required_bytes =
            page_count / 8 +
            @as(usize, @intFromBool(page_count % 8 != 0));

        if (storage.len < required_bytes) {
            return error.InvalidStorage;
        }

        @memset(storage, 0xFF);

        return .{
            .data = storage,
            .page_count = page_count,
        };
    }

    pub fn isOccupied(self: *const Bitmap, page: usize) bool {
        if (page >= self.page_count) return true;

        const byte_index = page / 8;
        const bit_index: u3 = @intCast(page % 8);
        const mask = @as(u8, 1) << bit_index;

        return (self.data[byte_index] & mask) != 0;
    }

    pub fn markFree(
        self: *Bitmap,
        page: usize,
    ) Error!void {
        if (page >= self.page_count) {
            return error.InvalidPage;
        }

        const byte_index = page / 8;
        const bit_index: u3 = @intCast(page % 8);
        const mask = @as(u8, 1) << bit_index;

        if ((self.data[byte_index] & mask) == 0) {
            return error.AlreadyFree;
        }

        self.data[byte_index] &= ~mask;
    }

    pub fn markOccupied(
        self: *Bitmap,
        page: usize,
    ) Error!void {
        if (page >= self.page_count) {
            return error.InvalidPage;
        }

        const byte_index = page / 8;
        const bit_index: u3 = @intCast(page % 8);
        const mask = @as(u8, 1) << bit_index;

        self.data[byte_index] |= mask;
    }

    pub fn allocate(self: *Bitmap) ?usize {
        for (0..self.page_count) |page| {
            if (!self.isOccupied(page)) {
                self.markOccupied(page) catch unreachable;
                return page;
            }
        }

        return null;
    }
};

pub const MAX_PHYSICAL_PAGES: usize = 1_048_576;

pub const BITMAP_BYTES: usize =
    MAX_PHYSICAL_PAGES / 8;

var physical_bitmap_storage: [BITMAP_BYTES]u8 = undefined;

var physical_bitmap: Bitmap = undefined;
var physical_bitmap_initialized: bool = false;

pub fn initPhysicalBitmap() void {
    physical_bitmap = Bitmap.init(
        physical_bitmap_storage[0..],
        MAX_PHYSICAL_PAGES,
    ) catch unreachable;

    physical_bitmap_initialized = true;
}

pub fn isPhysicalBitmapInitialized() bool {
    return physical_bitmap_initialized;
}

pub fn storageAddress() usize {
    return @intFromPtr(&physical_bitmap_storage);
}

pub fn storageSize() usize {
    return physical_bitmap_storage.len;
}
pub const MemoryMapError = error{
    BitmapNotInitialized,
    InvalidMemoryMap,
};

pub fn initializeFromMemoryMap(
    map: multiboot2.MemoryMap,
    table: *const physical.ReservationTable,
) MemoryMapError!void {
    if (!physical_bitmap_initialized) {
        return error.BitmapNotInitialized;
    }

    for (0..map.entry_count) |i| {
        const entry = map.entry(i) orelse
            return error.InvalidMemoryMap;

        if (entry.entry_type != multiboot2.MEMORY_AVAILABLE) {
            continue;
        }

        const pages = physical.usablePageRange(
            entry.base_addr,
            entry.length,
            physical_bitmap.page_count,
        ) orelse continue;

        for (pages.first_page..pages.end_page) |page| {
            physical_bitmap.markFree(page) catch |err| switch (err) {
                error.AlreadyFree => {},
                else => unreachable,
            };
        }
    }

    for (0..map.entry_count) |i| {
        const entry = map.entry(i) orelse
            return error.InvalidMemoryMap;

        if (entry.entry_type == multiboot2.MEMORY_AVAILABLE) {
            continue;
        }

        const limit_bytes: u64 =
            @as(u64, @intCast(physical_bitmap.page_count)) *
            physical.PAGE_SIZE;

        const end_result = @addWithOverflow(
            entry.base_addr,
            entry.length,
        );

        const end: u64 = if (end_result[1] != 0)
            ~@as(u64, 0)
        else
            end_result[0];

        const start = @min(entry.base_addr, limit_bytes);
        const bounded_end = @min(end, limit_bytes);

        if (bounded_end <= start) continue;

        const first: usize =
            @intCast(start / physical.PAGE_SIZE);

        const last: usize = @intCast(
            bounded_end / physical.PAGE_SIZE +
                @as(u64, @intFromBool(
                    bounded_end % physical.PAGE_SIZE != 0,
                )),
        );

        for (first..last) |page| {
            physical_bitmap.markOccupied(page) catch unreachable;
        }
    }

    for (table.entries[0..table.len]) |reservation| {
        const first = @min(
            reservation.pages.first_page,
            physical_bitmap.page_count,
        );

        const last = @min(
            reservation.pages.end_page,
            physical_bitmap.page_count,
        );

        for (first..last) |page| {
            physical_bitmap.markOccupied(page) catch unreachable;
        }
    }

    physical_bitmap.markOccupied(0) catch unreachable;
}
pub const BitmapStats = struct {
    total_pages: usize,
    free_pages: usize,
    occupied_pages: usize,
};

pub fn physicalStats() ?BitmapStats {
    if (!physical_bitmap_initialized) return null;

    var free: usize = 0;

    for (0..physical_bitmap.page_count) |page| {
        if (!physical_bitmap.isOccupied(page)) {
            free += 1;
        }
    }

    return .{
        .total_pages = physical_bitmap.page_count,
        .free_pages = free,
        .occupied_pages = physical_bitmap.page_count - free,
    };
}
//pruebas
test "bitmap starts fully occupied" {
    const std = @import("std");

    var storage: [2]u8 = undefined;
    const bitmap = try Bitmap.init(&storage, 16);

    for (0..16) |page| {
        try std.testing.expect(bitmap.isOccupied(page));
    }
}

test "bitmap allocates only free pages" {
    const std = @import("std");

    var storage: [2]u8 = undefined;
    var bitmap = try Bitmap.init(&storage, 16);

    try bitmap.markFree(3);
    try bitmap.markFree(7);

    try std.testing.expectEqual(
        @as(?usize, 3),
        bitmap.allocate(),
    );

    try std.testing.expectEqual(
        @as(?usize, 7),
        bitmap.allocate(),
    );

    try std.testing.expect(bitmap.allocate() == null);
}

test "bitmap rejects double free" {
    const std = @import("std");

    var storage: [1]u8 = undefined;
    var bitmap = try Bitmap.init(&storage, 8);

    try bitmap.markFree(2);

    try std.testing.expectError(
        error.AlreadyFree,
        bitmap.markFree(2),
    );
}

test "bitmap protects out of range pages" {
    const std = @import("std");

    var storage: [1]u8 = undefined;
    var bitmap = try Bitmap.init(&storage, 5);

    try std.testing.expect(bitmap.isOccupied(5));

    try std.testing.expectError(
        error.InvalidPage,
        bitmap.markFree(5),
    );
}

test "bitmap rejects insufficient storage" {
    const std = @import("std");

    var storage: [1]u8 = undefined;

    try std.testing.expectError(
        error.InvalidStorage,
        Bitmap.init(&storage, 16),
    );
}
test "bitmap statistics count free and occupied pages" {
    const std = @import("std");

    var storage: [2]u8 = undefined;
    var test_bitmap = try Bitmap.init(&storage, 16);

    try test_bitmap.markFree(3);
    try test_bitmap.markFree(7);

    var free: usize = 0;

    for (0..test_bitmap.page_count) |page| {
        if (!test_bitmap.isOccupied(page)) {
            free += 1;
        }
    }

    try std.testing.expectEqual(@as(usize, 2), free);
    try std.testing.expectEqual(
        @as(usize, 14),
        test_bitmap.page_count - free,
    );
}
