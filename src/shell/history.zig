const std = @import("std");

pub const CAPACITY: usize = 16;
pub const LINE_CAPACITY: usize = 64;

pub const History = struct {
    entries: [CAPACITY][LINE_CAPACITY]u8 = undefined,
    lengths: [CAPACITY]usize = [_]usize{0} ** CAPACITY,

    count: usize = 0,
    next: usize = 0,
    position: ?usize = null,

    draft: [LINE_CAPACITY]u8 = undefined,
    draft_length: usize = 0,

    pub fn add(self: *History, text: []const u8) void {
        self.position = null;

        if (text.len == 0 or text.len > LINE_CAPACITY) return;

        // Evitamos duplicados consecutivos.
        if (self.count > 0) {
            const latest = (self.next + CAPACITY - 1) % CAPACITY;
            const last_command = self.entries[latest][0..self.lengths[latest]];

            if (std.mem.eql(u8, last_command, text)) return;
        }

        for (text, 0..) |char, i| {
            self.entries[self.next][i] = char;
        }
        self.lengths[self.next] = text.len;

        self.next = (self.next + 1) % CAPACITY;

        if (self.count < CAPACITY) {
            self.count += 1;
        }
    }

    fn entry(self: *const History, index: usize) []const u8 {
        const oldest = (self.next + CAPACITY - self.count) % CAPACITY;
        const slot = (oldest + index) % CAPACITY;

        return self.entries[slot][0..self.lengths[slot]];
    }

    pub fn previous(
        self: *History,
        current: []const u8,
    ) ?[]const u8 {
        if (self.count == 0) return null;

        if (self.position == null) {
            self.draft_length = @min(current.len, LINE_CAPACITY);
            for (0..self.draft_length) |i| {
                self.draft[i] = current[i];
            }

            self.position = self.count - 1;
        } else if (self.position.? > 0) {
            self.position.? -= 1;
        }

        return self.entry(self.position.?);
    }

    pub fn nextEntry(self: *History) ?[]const u8 {
        const position = self.position orelse return null;

        if (position + 1 < self.count) {
            self.position = position + 1;
            return self.entry(self.position.?);
        }

        self.position = null;
        return self.draft[0..self.draft_length];
    }

    pub fn resetNavigation(self: *History) void {
        self.position = null;
    }
};

test "historial vacio" {
    var history = History{};

    try std.testing.expect(
        history.previous("") == null,
    );
}

test "navegacion hacia atras y adelante" {
    var history = History{};

    history.add("ver");
    history.add("help");
    history.add("echo hello");

    try std.testing.expectEqualStrings(
        "echo hello",
        history.previous("").?,
    );

    try std.testing.expectEqualStrings(
        "help",
        history.previous("").?,
    );

    try std.testing.expectEqualStrings(
        "ver",
        history.previous("").?,
    );

    try std.testing.expectEqualStrings(
        "help",
        history.nextEntry().?,
    );
}

test "restaurar borrador" {
    var history = History{};

    history.add("help");

    try std.testing.expectEqualStrings(
        "help",
        history.previous("echo prueba").?,
    );

    try std.testing.expectEqualStrings(
        "echo prueba",
        history.nextEntry().?,
    );
}

test "evitar duplicados consecutivos" {
    var history = History{};

    history.add("help");
    history.add("help");

    try std.testing.expectEqual(@as(usize, 1), history.count);
}

test "buffer circular conserva los mas recientes" {
    var history = History{};

    for (0..CAPACITY + 4) |i| {
        var buffer: [32]u8 = undefined;
        const command = try std.fmt.bufPrint(
            &buffer,
            "cmd {d}",
            .{i},
        );
        history.add(command);
    }

    try std.testing.expectEqual(CAPACITY, history.count);

    for (0..CAPACITY - 1) |_| {
        _ = history.previous("");
    }

    try std.testing.expectEqualStrings(
        "cmd 4",
        history.previous("").?,
    );
}
