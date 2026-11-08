pub const Severity = enum {
    info,
    warning,
    critical,
};

pub const DiagnosticCode = enum {
    allocator_healthy,
    bitmap_not_initialized,
    bitmap_size_mismatch,
    allocation_state_inconsistent,
};

pub const DiagnosticResult = struct {
    code: DiagnosticCode,
    severity: Severity,
    affected_page: ?usize = null,
};
