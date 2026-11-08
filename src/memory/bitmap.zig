const physical = @import("physical.zig");
const multiboot2 = @import("../boot/multiboot2.zig");

var allocation_bitmap_storage: [BITMAP_BYTES]u8 = undefined;
var allocation_bitmap: Bitmap = undefined;

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

pub const PhysicalAllocator = struct {
    availability: *Bitmap,
    allocations: *Bitmap,

    pub const Error = error{
        InvalidPage,
        NotAllocated,
        InconsistentState,
    };

    pub fn allocate(self: *PhysicalAllocator) Error!?usize {
        if (self.availability.page_count !=
            self.allocations.page_count)
        {
            return error.InconsistentState;
        }

        for (0..self.availability.page_count) |page| {
            if (self.availability.isOccupied(page)) continue;

            if (self.allocations.isOccupied(page)) {
                return error.InconsistentState;
            }

            self.availability.markOccupied(page) catch unreachable;
            self.allocations.markOccupied(page) catch unreachable;

            return page;
        }

        return null;
    }

    pub fn free(
        self: *PhysicalAllocator,
        page: usize,
    ) Error!void {
        if (self.availability.page_count !=
            self.allocations.page_count)
        {
            return error.InconsistentState;
        }

        if (page >= self.availability.page_count) {
            return error.InvalidPage;
        }

        // Solo liberamos páginas entregadas por esta API.
        if (!self.allocations.isOccupied(page)) {
            return error.NotAllocated;
        }

        if (!self.availability.isOccupied(page)) {
            return error.InconsistentState;
        }

        self.allocations.markFree(page) catch unreachable;
        self.availability.markFree(page) catch unreachable;
    }
};

pub const MAX_PHYSICAL_PAGES: usize = 1_048_576;

pub const BITMAP_BYTES: usize =
    MAX_PHYSICAL_PAGES / 8;

var physical_bitmap_storage: [BITMAP_BYTES]u8 = undefined;

var physical_bitmap: Bitmap = undefined;
var physical_bitmap_initialized: bool = false;

pub fn initPhysicalBitmap() void {
    physical_bitmap_initialized = false;

    physical_bitmap = Bitmap.init(
        physical_bitmap_storage[0..],
        MAX_PHYSICAL_PAGES,
    ) catch unreachable;

    allocation_bitmap = Bitmap.init(
        allocation_bitmap_storage[0..],
        MAX_PHYSICAL_PAGES,
    ) catch unreachable;

    @memset(allocation_bitmap_storage[0..], 0);

    physical_bitmap_initialized = true;
}

pub fn isPhysicalBitmapInitialized() bool {
    return physical_bitmap_initialized;
}
pub fn isPhysicalPageAllocated(page: usize) bool {
    if (!physical_bitmap_initialized) return false;
    if (page >= allocation_bitmap.page_count) return false;

    return allocation_bitmap.isOccupied(page);
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
    reserveLowMemory(&physical_bitmap);
}

pub const PhysicalPageError =
    PhysicalAllocator.Error || error{BitmapNotInitialized};

pub fn allocatePhysicalPage() PhysicalPageError!?usize {
    if (!physical_bitmap_initialized) {
        return error.BitmapNotInitialized;
    }

    var allocator = PhysicalAllocator{
        .availability = &physical_bitmap,
        .allocations = &allocation_bitmap,
    };

    return allocator.allocate();
}

pub fn freePhysicalPage(
    page: usize,
) PhysicalPageError!void {
    if (!physical_bitmap_initialized) {
        return error.BitmapNotInitialized;
    }

    var allocator = PhysicalAllocator{
        .availability = &physical_bitmap,
        .allocations = &allocation_bitmap,
    };

    try allocator.free(page);
} //Retocar a futuro, encapsular en un struct y no exponer el bitmap de asignaciones, para que no se pueda modificar desde fuera del módulo.

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
pub fn reserveLowMemory(
    target: *Bitmap,
) void {
    const limit = @min(
        physical.LOW_MEMORY_PAGES,
        target.page_count,
    );

    for (0..limit) |page| {
        target.markOccupied(page) catch unreachable;
    }
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
test "physical allocator initializes both bitmaps safely" {
    const std = @import("std");

    initPhysicalBitmap();

    try std.testing.expect(isPhysicalBitmapInitialized());

    const sample_pages = [_]usize{
        0,
        1,
        256,
        65535,
        MAX_PHYSICAL_PAGES - 1,
    };

    for (sample_pages) |page| {
        // Todas las páginas comienzan ocupadas.
        try std.testing.expect(
            physical_bitmap.isOccupied(page),
        );

        // Ninguna página ha sido asignada por la API.
        try std.testing.expect(
            !isPhysicalPageAllocated(page),
        );
    }

    // Los índices fuera del espacio físico no son válidos.
    try std.testing.expect(
        !isPhysicalPageAllocated(MAX_PHYSICAL_PAGES),
    );
}

test "physical allocator allocates and frees pages" {
    const std = @import("std");

    var available_storage: [2]u8 = undefined;
    var allocated_storage: [2]u8 = undefined;

    var availability = try Bitmap.init(&available_storage, 16);
    var allocations = try Bitmap.init(&allocated_storage, 16);

    @memset(allocated_storage[0..], 0);

    try availability.markFree(3);
    try availability.markFree(7);

    var allocator = PhysicalAllocator{
        .availability = &availability,
        .allocations = &allocations,
    };

    const first = (try allocator.allocate()).?;
    try std.testing.expectEqual(@as(usize, 3), first);

    try std.testing.expect(availability.isOccupied(3));
    try std.testing.expect(allocations.isOccupied(3));

    const second = (try allocator.allocate()).?;
    try std.testing.expectEqual(@as(usize, 7), second);

    try allocator.free(first);

    try std.testing.expect(!availability.isOccupied(3));
    try std.testing.expect(!allocations.isOccupied(3));

    const reused = (try allocator.allocate()).?;
    try std.testing.expectEqual(first, reused);
}

test "physical allocator rejects freeing reserved pages" {
    const std = @import("std");

    var available_storage: [1]u8 = undefined;
    var allocated_storage: [1]u8 = undefined;

    var availability = try Bitmap.init(&available_storage, 8);
    var allocations = try Bitmap.init(&allocated_storage, 8);

    @memset(allocated_storage[0..], 0);

    var allocator = PhysicalAllocator{
        .availability = &availability,
        .allocations = &allocations,
    };

    try std.testing.expectError(
        error.NotAllocated,
        allocator.free(0),
    );

    try std.testing.expectError(
        error.NotAllocated,
        allocator.free(3),
    );

    try std.testing.expectError(
        error.InvalidPage,
        allocator.free(8),
    );
}

test "physical allocator rejects double free" {
    const std = @import("std");

    var available_storage: [1]u8 = undefined;
    var allocated_storage: [1]u8 = undefined;

    var availability = try Bitmap.init(&available_storage, 8);
    var allocations = try Bitmap.init(&allocated_storage, 8);

    @memset(allocated_storage[0..], 0);

    try availability.markFree(2);

    var allocator = PhysicalAllocator{
        .availability = &availability,
        .allocations = &allocations,
    };

    const page = (try allocator.allocate()).?;
    try allocator.free(page);

    try std.testing.expectError(
        error.NotAllocated,
        allocator.free(page),
    );
}
test "low memory remains reserved" {
    const std = @import("std");

    var storage: [64]u8 = undefined;
    var target = try Bitmap.init(&storage, 512);

    for (0..512) |page| {
        try target.markFree(page);
    }

    reserveLowMemory(&target);

    for (0..physical.LOW_MEMORY_PAGES) |page| {
        try std.testing.expect(target.isOccupied(page));
    }

    for (physical.LOW_MEMORY_PAGES..512) |page| {
        try std.testing.expect(!target.isOccupied(page));
    }
}
