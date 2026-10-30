pub const CAPACITY: usize = 64;

pub const EditMode = enum {
    insert,
    overwrite,
};

pub const LineEditor = struct {
    buffer: [CAPACITY]u8 = undefined,
    length: usize = 0,
    cursor: usize = 0,
    selection_anchor: ?usize = null,
    mode: EditMode = .insert,

    pub fn reset(self: *LineEditor) void {
        self.length = 0;
        self.cursor = 0;
        self.mode = .insert;
        self.clearSelection();
    }

    pub fn text(self: *const LineEditor) []const u8 {
        return self.buffer[0..self.length];
    }

    pub fn moveLeft(self: *LineEditor) void {
        if (self.cursor > 0) {
            self.cursor -= 1;
        }
    }

    pub fn moveRight(self: *LineEditor) void {
        if (self.cursor < self.length) {
            self.cursor += 1;
        }
    }

    pub fn moveHome(self: *LineEditor) void {
        self.cursor = 0;
    }

    pub fn moveEnd(self: *LineEditor) void {
        self.cursor = self.length;
    }

    pub fn toggleMode(self: *LineEditor) void {
        self.mode = switch (self.mode) {
            .insert => .overwrite,
            .overwrite => .insert,
        };
    }

    pub fn writeChar(self: *LineEditor, char: u8) bool {
        if (char < 32 or char > 126) return false;

        const replacing_selection = self.hasSelection();

        if (replacing_selection) {
            const start = self.selectionStart();
            const end = self.selectionEnd();
            const removed = end - start;

            // Validar antes de modificar el buffer.
            if (self.length - removed >= CAPACITY) {
                return false;
            }

            _ = self.deleteSelection();
        }

        if (self.mode == .insert or replacing_selection) {
            if (self.length >= CAPACITY) return false;

            var i = self.length;
            while (i > self.cursor) {
                self.buffer[i] = self.buffer[i - 1];
                i -= 1;
            }

            self.buffer[self.cursor] = char;
            self.length += 1;
        } else {
            if (self.cursor == self.length) {
                if (self.length >= CAPACITY) return false;
                self.length += 1;
            }

            self.buffer[self.cursor] = char;
        }

        self.cursor += 1;
        self.clearSelection();
        return true;
    }

    pub fn backspace(self: *LineEditor) bool {
        if (self.hasSelection()) {
            return self.deleteSelection();
        }
        if (self.cursor == 0) return false;

        var i = self.cursor - 1;
        while (i + 1 < self.length) : (i += 1) {
            self.buffer[i] = self.buffer[i + 1];
        }

        self.length -= 1;
        self.cursor -= 1;
        return true;
    }

    pub fn delete(self: *LineEditor) bool {
        if (self.cursor >= self.length) return false;

        var i = self.cursor;
        while (i + 1 < self.length) : (i += 1) {
            self.buffer[i] = self.buffer[i + 1];
        }

        self.length -= 1;
        return true;
    }

    pub fn visibleOffset(
        self: *const LineEditor,
        current_offset: usize,
        visible_width: usize,
    ) usize {
        if (visible_width == 0) return 0;

        var offset = current_offset;

        if (self.cursor < offset) {
            offset = self.cursor;
        } else if (self.cursor - offset >= visible_width) {
            offset = self.cursor - visible_width + 1;
        }

        return offset;
    }

    pub fn hasSelection(self: *const LineEditor) bool {
        const anchor = self.selection_anchor orelse return false;
        return anchor != self.cursor;
    }

    pub fn selectionStart(self: *const LineEditor) usize {
        const anchor = self.selection_anchor orelse return self.cursor;
        return @min(anchor, self.cursor);
    }

    pub fn selectionEnd(self: *const LineEditor) usize {
        const anchor = self.selection_anchor orelse return self.cursor;
        return @max(anchor, self.cursor);
    }

    pub fn clearSelection(self: *LineEditor) void {
        self.selection_anchor = null;
    }

    pub fn selectAll(self: *LineEditor) void {
        self.selection_anchor = 0;
        self.cursor = self.length;
    }

    pub fn moveLeftSelecting(self: *LineEditor) void {
        if (self.selection_anchor == null) {
            self.selection_anchor = self.cursor;
        }
        self.moveLeft();
    }

    pub fn moveRightSelecting(self: *LineEditor) void {
        if (self.selection_anchor == null) {
            self.selection_anchor = self.cursor;
        }
        self.moveRight();
    }

    pub fn moveHomeSelecting(self: *LineEditor) void {
        if (self.selection_anchor == null) {
            self.selection_anchor = self.cursor;
        }
        self.moveHome();
    }

    pub fn moveEndSelecting(self: *LineEditor) void {
        if (self.selection_anchor == null) {
            self.selection_anchor = self.cursor;
        }
        self.moveEnd();
    }

    pub fn deleteSelection(self: *LineEditor) bool {
        if (!self.hasSelection()) return false;

        const start = self.selectionStart();
        const end = self.selectionEnd();
        const removed = end - start;

        var i = start;
        while (i + removed < self.length) : (i += 1) {
            self.buffer[i] = self.buffer[i + removed];
        }

        self.length -= removed;
        self.cursor = start;
        self.clearSelection();

        return true;
    }

    pub fn isSelected(
        self: *const LineEditor,
        index: usize,
    ) bool {
        if (!self.hasSelection()) return false;

        return index >= self.selectionStart() and
            index < self.selectionEnd();
    }

    pub fn moveLeftNormal(self: *LineEditor) void {
        if (self.hasSelection()) {
            self.cursor = self.selectionStart();
            self.clearSelection();
        } else {
            self.moveLeft();
        }
    }

    pub fn moveRightNormal(self: *LineEditor) void {
        if (self.hasSelection()) {
            self.cursor = self.selectionEnd();
            self.clearSelection();
        } else {
            self.moveRight();
        }
    }
};

//Pruebas
const std = @import("std");

test "insercion en medio del texto" {
    var editor = LineEditor{};

    for ("Holo") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    editor.moveLeft();
    editor.moveLeft();

    try std.testing.expect(editor.writeChar('a'));

    try std.testing.expectEqualStrings(
        "Hoalo",
        editor.text(),
    );

    try std.testing.expectEqual(@as(usize, 3), editor.cursor);
}

test "modo overwrite reemplaza caracteres" {
    var editor = LineEditor{};

    for ("Holo") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    editor.moveHome();
    editor.moveRight();
    editor.toggleMode();

    try std.testing.expect(editor.writeChar('a'));

    try std.testing.expectEqualStrings(
        "Halo",
        editor.text(),
    );

    try std.testing.expectEqual(@as(usize, 4), editor.length);
    try std.testing.expectEqual(EditMode.overwrite, editor.mode);
}

test "backspace y delete respetan el cursor" {
    var editor = LineEditor{};

    for ("ABCDE") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    editor.moveHome();
    editor.moveRight();
    editor.moveRight();

    try std.testing.expect(editor.backspace());
    try std.testing.expectEqualStrings("ACDE", editor.text());

    try std.testing.expect(editor.delete());
    try std.testing.expectEqualStrings("ADE", editor.text());

    try std.testing.expectEqual(@as(usize, 1), editor.cursor);
}

test "capacidad maxima protege el buffer" {
    var editor = LineEditor{};

    for (0..CAPACITY) |_| {
        try std.testing.expect(editor.writeChar('X'));
    }

    try std.testing.expect(!editor.writeChar('Y'));

    try std.testing.expectEqual(CAPACITY, editor.length);
    try std.testing.expectEqual(CAPACITY, editor.cursor);
}

test "viewport se desplaza cuando el cursor sale" {
    var editor = LineEditor{};

    for ("ABCDEFGHIJ") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    const offset = editor.visibleOffset(0, 5);

    try std.testing.expectEqual(@as(usize, 6), offset);
}

test "viewport permanece estable con cursor visible" {
    var editor = LineEditor{};

    for ("ABCDEFGHIJ") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    editor.moveHome();
    for (0..4) |_| editor.moveRight();

    const offset = editor.visibleOffset(2, 5);

    try std.testing.expectEqual(@as(usize, 2), offset);
}

test "seleccion hacia la izquierda" {
    var editor = LineEditor{};

    for ("ABCDE") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    editor.moveLeftSelecting();
    editor.moveLeftSelecting();

    try std.testing.expect(editor.hasSelection());
    try std.testing.expectEqual(@as(usize, 3), editor.selectionStart());
    try std.testing.expectEqual(@as(usize, 5), editor.selectionEnd());
}

test "reemplazar seleccion en modo insert" {
    var editor = LineEditor{};

    for ("ABCDE") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    editor.moveHome();
    editor.moveRight();
    editor.moveRight();

    editor.moveRightSelecting();
    editor.moveRightSelecting();

    try std.testing.expect(editor.writeChar('X'));

    try std.testing.expectEqualStrings("ABXE", editor.text());
    try std.testing.expect(!editor.hasSelection());
}

test "reemplazar seleccion en modo overwrite" {
    var editor = LineEditor{};

    for ("ABCDE") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    editor.moveHome();
    editor.moveRight();

    editor.moveRightSelecting();
    editor.moveRightSelecting();

    editor.toggleMode();

    try std.testing.expect(editor.writeChar('X'));

    try std.testing.expectEqualStrings("AXDE", editor.text());
    try std.testing.expectEqual(EditMode.overwrite, editor.mode);
}

test "identificar caracteres seleccionados" {
    var editor = LineEditor{};

    for ("ABCDE") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    editor.moveHome();
    editor.moveRight();
    editor.moveRightSelecting();
    editor.moveRightSelecting();

    try std.testing.expect(!editor.isSelected(0));
    try std.testing.expect(editor.isSelected(1));
    try std.testing.expect(editor.isSelected(2));
    try std.testing.expect(!editor.isSelected(3));
    try std.testing.expect(!editor.isSelected(4));
}

test "escribir no deja una seleccion residual" {
    var editor = LineEditor{};

    for ("ABCDE") |char| {
        try std.testing.expect(editor.writeChar(char));
    }

    editor.moveLeftSelecting();
    editor.moveRightSelecting();

    try std.testing.expect(!editor.hasSelection());

    try std.testing.expect(editor.writeChar('X'));

    try std.testing.expect(!editor.hasSelection());
    try std.testing.expect(editor.selection_anchor == null);

    try std.testing.expectEqualStrings(
        "ABCDEX",
        editor.text(),
    );
}
