const std = @import("std");

pub const MemoryMap = struct {
    entries_address: usize,
    entry_count: usize,
    entry_size: usize,

    pub fn entry(self: MemoryMap, index: usize) ?MemoryMapEntry {
        if (index >= self.entry_count) return null;

        const address = self.entries_address +
            index * self.entry_size;

        const ptr: *align(1) const MemoryMapEntry =
            @ptrFromInt(address);

        return ptr.*;
    }
};

pub fn findMemoryMap(info_address: u32) ?MemoryMap {
    if (info_address == 0) return null;
    if ((info_address & 7) != 0) return null;

    const base: usize = @intCast(info_address);

    const header: *align(1) const InfoHeader =
        @ptrFromInt(base);

    const total_size: usize = @intCast(header.total_size);

    if (total_size < 16) return null;
    if ((total_size & 7) != 0) return null;

    const end = std.math.add(usize, base, total_size) catch
        return null;

    var offset: usize = 8;

    while (offset < total_size) {
        const tag_address = std.math.add(
            usize,
            base,
            offset,
        ) catch return null;

        if (total_size - offset < @sizeOf(TagHeader))
            return null;

        const tag: *align(1) const TagHeader =
            @ptrFromInt(tag_address);

        const tag_size: usize = @intCast(tag.size);

        if (tag_size < @sizeOf(TagHeader))
            return null;

        if (tag_size > total_size - offset)
            return null;

        if (tag.tag_type == TAG_END) {
            return null;
        }

        if (tag.tag_type == TAG_MEMORY_MAP) {
            if (tag_size < @sizeOf(MemoryMapTag))
                return null;

            const mmap: *align(1) const MemoryMapTag =
                @ptrFromInt(tag_address);

            const entry_size: usize =
                @intCast(mmap.entry_size);

            if (entry_size < @sizeOf(MemoryMapEntry))
                return null;

            const entries_size =
                tag_size - @sizeOf(MemoryMapTag);

            if (entries_size % entry_size != 0)
                return null;

            return .{
                .entries_address = tag_address + @sizeOf(MemoryMapTag),
                .entry_count = entries_size / entry_size,
                .entry_size = entry_size,
            };
        }

        const aligned_size = std.math.add(
            usize,
            tag_size,
            7,
        ) catch return null;

        const advance = aligned_size & ~@as(usize, 7);

        if (advance > total_size - offset)
            return null;

        offset += advance;
    }

    _ = end;
    return null;
}
pub fn infoSize(info_address: u32) ?u32 {
    if (info_address == 0) return null;
    if ((info_address & 7) != 0) return null;

    const header: *align(1) const InfoHeader =
        @ptrFromInt(@as(usize, info_address));

    if (header.total_size < 16) return null;
    if ((header.total_size & 7) != 0) return null;

    const end = @as(u64, info_address) +
        @as(u64, header.total_size);

    if (end > 0x1_0000_0000) return null;

    return header.total_size;
}

pub const InfoHeader = extern struct {
    total_size: u32,
    reserved: u32,
};

pub const TagHeader = extern struct {
    tag_type: u32,
    size: u32,
};

pub const MemoryMapTag = extern struct {
    tag_type: u32,
    size: u32,
    entry_size: u32,
    entry_version: u32,
};

pub const MemoryMapEntry = extern struct {
    base_addr: u64,
    length: u64,
    entry_type: u32,
    reserved: u32,
};

pub const TAG_END: u32 = 0;
pub const TAG_MEMORY_MAP: u32 = 6;
pub const MEMORY_AVAILABLE: u32 = 1;
