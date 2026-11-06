pub const ScancodeQueue = struct {
    buffer: [256]u8 = undefined,
    head: usize = 0,
    tail: usize = 0,

    pub fn enqueue(self: *ScancodeQueue, scancode: u8) bool {
        const next_head = (self.head + 1) & (self.buffer.len - 1);
        if (next_head != self.tail) {
            self.buffer[self.head] = scancode;
            self.head = next_head;
            return true;
        }
        return false;
    }

    pub fn dequeue(self: *ScancodeQueue) ?u8 {
        if (self.head == self.tail) {
            return null;
        }
        const scancode = self.buffer[self.tail];
        self.tail = (self.tail + 1) & (self.buffer.len - 1);
        return scancode;
    }
    pub fn count(self: *const ScancodeQueue) usize {
        return (self.head -% self.tail) & (self.buffer.len - 1);
    }
};
pub fn selfTest() bool {
    var queue: ScancodeQueue = .{};

    if (!queue.enqueue(0x1E)) return false;
    if (!queue.enqueue(0x30)) return false;
    if (!queue.enqueue(0x2E)) return false;

    if (queue.dequeue() != 0x1E) return false;
    if (queue.dequeue() != 0x30) return false;
    if (queue.dequeue() != 0x2E) return false;

    if (queue.dequeue() != null) return false;

    // Llenar la cola.
    for (0..255) |i| {
        if (!queue.enqueue(@intCast(i))) return false;
    }

    // Comprobar saturación.
    if (queue.enqueue(0xFF)) return false;

    // Liberar diez posiciones.
    for (0..10) |i| {
        if (queue.dequeue() != @as(u8, @intCast(i))) return false;
    }

    // Reutilizar las diez posiciones.
    for (0..10) |i| {
        if (!queue.enqueue(@intCast(i))) return false;
    }

    // Verificar los 245 elementos originales restantes.
    for (10..255) |i| {
        if (queue.dequeue() != @as(u8, @intCast(i))) return false;
    }

    // Verificar los diez elementos nuevos.
    for (0..10) |i| {
        if (queue.dequeue() != @as(u8, @intCast(i))) return false;
    }

    // Comprobar que la cola está vacía.
    if (queue.dequeue() != null) return false;
    return true;
}
