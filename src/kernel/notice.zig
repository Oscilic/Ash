const std = @import("std");

pub const CAPACITY: usize = 16;
pub const MESSAGE_CAPACITY: usize = 80;

pub const Severity = enum {
    info,
    warning,
    err,
    critical,
};

pub const Notice = struct {
    id: u64 = 0,
    severity: Severity = .info,
    message: [MESSAGE_CAPACITY]u8 = undefined,
    length: usize = 0,

    pub fn text(self: *const Notice) []const u8 {
        return self.message[0..self.length];
    }
};

pub const NoticeQueue = struct {
    entries: [CAPACITY]Notice = undefined,
    head: usize = 0,
    count: usize = 0,
    next_id: u64 = 1,
    dropped: u64 = 0,

    pub fn push(
        self: *NoticeQueue,
        severity: Severity,
        message: []const u8,
    ) void {
        if (self.count == CAPACITY) {
            // Descartar el aviso más antiguo.
            self.head = (self.head + 1) % CAPACITY;
            self.count -= 1;
            self.dropped += 1;
        }

        const index = (self.head + self.count) % CAPACITY;
        const notice = &self.entries[index];

        notice.id = self.next_id;
        notice.severity = severity;
        notice.length = @min(message.len, MESSAGE_CAPACITY);

        for (0..notice.length) |i| {
            notice.message[i] = message[i];
        }

        self.next_id +%= 1;
        self.count += 1;
    }

    pub fn pop(self: *NoticeQueue) ?Notice {
        if (self.count == 0) return null;

        const notice = self.entries[self.head];

        self.head = (self.head + 1) % CAPACITY;
        self.count -= 1;

        return notice;
    }
};

test "cola vacia" {
    var queue = NoticeQueue{};

    try std.testing.expect(queue.pop() == null);
}

test "orden FIFO" {
    var queue = NoticeQueue{};

    queue.push(.info, "Primero");
    queue.push(.warning, "Segundo");

    const first = queue.pop().?;
    const second = queue.pop().?;

    try std.testing.expectEqualStrings(
        "Primero",
        first.text(),
    );

    try std.testing.expectEqualStrings(
        "Segundo",
        second.text(),
    );
}

test "conservar severidad e identificador" {
    var queue = NoticeQueue{};

    queue.push(.critical, "Error critico");

    const notice = queue.pop().?;

    try std.testing.expectEqual(
        Severity.critical,
        notice.severity,
    );

    try std.testing.expectEqual(
        @as(u64, 1),
        notice.id,
    );
}

test "descartar el mas antiguo al llenar la cola" {
    var queue = NoticeQueue{};

    for (0..CAPACITY) |_| {
        queue.push(.info, "Antiguo");
    }

    queue.push(.warning, "Nuevo");

    try std.testing.expectEqual(
        @as(u64, 1),
        queue.dropped,
    );

    const oldest = queue.pop().?;

    try std.testing.expectEqual(
        @as(u64, 2),
        oldest.id,
    );
}

test "copiar mensaje independientemente" {
    var queue = NoticeQueue{};

    var message = [_]u8{ 'A', 's', 'h' };

    queue.push(.info, &message);
    message[0] = 'X';

    const notice = queue.pop().?;

    try std.testing.expectEqualStrings(
        "Ash",
        notice.text(),
    );
}
