pub const PAGE_SIZE: usize = 4096;

extern const __kernel_start: u8;
extern const __kernel_end: u8;

pub const KernelRegion = struct {
    start: usize,
    end: usize,
    first_page: usize,
    end_page: usize,
    page_count: usize,
};

pub fn kernelRegion() KernelRegion {
    const start = @intFromPtr(&__kernel_start);
    const end = @intFromPtr(&__kernel_end);

    const pages = pageRange(start, end - start) orelse unreachable;

    return .{
        .start = start,
        .end = end,
        .first_page = pages.first_page,
        .end_page = pages.end_page,
        .page_count = pages.count(),
    };
}

pub const PageRange = struct {
    first_page: usize,
    end_page: usize,

    pub fn count(self: PageRange) usize {
        return self.end_page - self.first_page;
    }
};

pub fn pageRange(start: usize, size: usize) ?PageRange {
    const end = @addWithOverflow(start, size);
    if (end[1] != 0) return null;

    const first_page = start / PAGE_SIZE;
    const end_page = end[0] / PAGE_SIZE +
        @as(usize, @intFromBool(end[0] % PAGE_SIZE != 0));

    return .{
        .first_page = first_page,
        .end_page = end_page,
    };
}
pub fn usablePageRange(
    base: u64,
    length: u64,
    maxpages: usize,
) ?PageRange {
    const page_size: u64 = PAGE_SIZE;
    const end_result = @addWithOverflow(base, length);
    if (end_result[1] != 0) return null;

    const end = end_result[0];

    const first = base / page_size + @as(u64, @intFromBool(base % page_size != 0));
    const last = end / page_size;
    const limit: u64 = @intCast(maxpages);
    if (first >= limit) return null;
    const bounded_last = @min(last, limit);
    if (bounded_last <= first) return null;
    return .{ .first_page = @intCast(first), .end_page = @intCast(bounded_last) };
}

pub const ReservationKind = enum {
    kernel,
    multiboot,
    allocator,
    firmware,
};

pub const Reservation = struct {
    pages: PageRange,
    kind: ReservationKind,
};

pub const ReservationTable = struct {
    pub const MAX_RESERVATIONS: usize = 32;

    entries: [MAX_RESERVATIONS]Reservation = undefined,
    len: usize = 0,

    pub const Error = error{
        TableFull,
        InvalidRange,
    };

    pub fn reserve(
        self: *ReservationTable,
        pages: PageRange,
        kind: ReservationKind,
    ) Error!void {
        if (pages.end_page <= pages.first_page) {
            return error.InvalidRange;
        }

        if (self.len >= MAX_RESERVATIONS) {
            return error.TableFull;
        }

        self.entries[self.len] = .{
            .pages = pages,
            .kind = kind,
        };

        self.len += 1;
    }

    pub fn isReserved(
        self: *const ReservationTable,
        page: usize,
    ) bool {
        for (self.entries[0..self.len]) |entry| {
            if (page >= entry.pages.first_page and
                page < entry.pages.end_page)
            {
                return true;
            }
        }

        return false;
    }

    pub fn countUniquePages(
        self: *const ReservationTable,
    ) usize {
        var total: usize = 0;

        for (self.entries[0..self.len], 0..) |entry, i| {
            var page = entry.pages.first_page;

            while (page < entry.pages.end_page) : (page += 1) {
                var previously_reserved = false;

                for (self.entries[0..i]) |previous| {
                    if (page >= previous.pages.first_page and
                        page < previous.pages.end_page)
                    {
                        previously_reserved = true;
                        break;
                    }
                }

                if (!previously_reserved) {
                    total += 1;
                }
            }
        }

        return total;
    }
};

pub var reservations: ReservationTable = .{};

pub fn reserveBootRegions(
    table: *ReservationTable,
    multiboot_address: usize,
    multiboot_size: usize,
) ReservationTable.Error!void {
    const kernel = kernelRegion();

    const multiboot_pages = pageRange(
        multiboot_address,
        multiboot_size,
    ) orelse return error.InvalidRange;

    if (multiboot_pages.count() == 0) {
        return error.InvalidRange;
    }

    if (table.len > ReservationTable.MAX_RESERVATIONS - 2) {
        return error.TableFull;
    }

    try table.reserve(.{
        .first_page = kernel.first_page,
        .end_page = kernel.end_page,
    }, .kernel);

    try table.reserve(
        multiboot_pages,
        .multiboot,
    );
}

//pruebas
test "pageRange handles partial pages" {
    const std = @import("std");

    const pages = pageRange(0x00100800, 500).?;

    try std.testing.expectEqual(
        @as(usize, 256),
        pages.first_page,
    );

    try std.testing.expectEqual(
        @as(usize, 257),
        pages.end_page,
    );

    try std.testing.expectEqual(
        @as(usize, 1),
        pages.count(),
    );
}

test "pageRange does not reserve the next page" {
    const std = @import("std");

    const pages = pageRange(0x00100000, 0x2000).?;

    try std.testing.expectEqual(
        @as(usize, 2),
        pages.count(),
    );
}

test "pageRange rejects address overflow" {
    const std = @import("std");

    try std.testing.expect(
        pageRange(
            std.math.maxInt(usize) - 10,
            20,
        ) == null,
    );
}

test "reservation table protects pages" {
    const std = @import("std");

    var table = ReservationTable{};

    try table.reserve(.{
        .first_page = 256,
        .end_page = 273,
    }, .kernel);

    try std.testing.expect(table.isReserved(256));
    try std.testing.expect(table.isReserved(272));
    try std.testing.expect(!table.isReserved(273));
    try std.testing.expect(!table.isReserved(255));
}

test "overlapping reservations count once" {
    const std = @import("std");

    var table = ReservationTable{};

    try table.reserve(.{
        .first_page = 256,
        .end_page = 272,
    }, .kernel);

    try table.reserve(.{
        .first_page = 270,
        .end_page = 273,
    }, .multiboot);

    try std.testing.expectEqual(
        @as(usize, 17),
        table.countUniquePages(),
    );
}

test "reservation table rejects empty ranges" {
    const std = @import("std");

    var table = ReservationTable{};

    try std.testing.expectError(
        error.InvalidRange,
        table.reserve(.{
            .first_page = 100,
            .end_page = 100,
        }, .firmware),
    );

    try std.testing.expectEqual(
        @as(usize, 0),
        table.len,
    );
}

test "reservation table respects capacity" {
    const std = @import("std");

    var table = ReservationTable{};

    for (0..ReservationTable.MAX_RESERVATIONS) |i| {
        try table.reserve(.{
            .first_page = i,
            .end_page = i + 1,
        }, .firmware);
    }

    try std.testing.expectError(
        error.TableFull,
        table.reserve(.{
            .first_page = 100,
            .end_page = 101,
        }, .allocator),
    );
}

test "usable range excludes partial pages" {
    const std = @import("std");

    const pages = usablePageRange(
        0x1003,
        0x3000,
        1024,
    ).?;

    try std.testing.expectEqual(
        @as(usize, 2),
        pages.first_page,
    );

    try std.testing.expectEqual(
        @as(usize, 4),
        pages.end_page,
    );
}

test "usable range excludes incomplete page" {
    const std = @import("std");

    try std.testing.expect(
        usablePageRange(0x1001, 100, 1024) == null,
    );
}

test "usable range respects bitmap capacity" {
    const std = @import("std");

    const pages = usablePageRange(
        0x3000,
        0x100000000,
        8,
    ).?;

    try std.testing.expectEqual(
        @as(usize, 3),
        pages.first_page,
    );

    try std.testing.expectEqual(
        @as(usize, 8),
        pages.end_page,
    );
}
