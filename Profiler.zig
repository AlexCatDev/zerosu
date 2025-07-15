const std = @import("std");

const HashMapType = std.StringHashMap(std.time.Instant);

var _profileMap: ?HashMapType = null;

pub const Profiler = struct {
    fn getMap() *HashMapType {
        if (_profileMap == null) {
            _profileMap = HashMapType.init(std.heap.c_allocator);
        }

        return &_profileMap.?;
    }

    pub fn Start(name: []const u8) void {
        const map = getMap();

        const now = std.time.Instant.now() catch return;

        map.*.put(name, now) catch return;
    }

    pub fn End(name: []const u8) void {
        const now = std.time.Instant.now() catch return;

        const map = getMap();

        if (map.*.get(name)) |prev| {
            const duration_ns = now.since(prev);
            const duration_us = (@as(f64, @floatFromInt(duration_ns)) / 1_000.0);
            const dur: i64 = @intFromFloat(duration_us);

            std.debug.print("Profiler [{s}] Took {d} us\n", .{ name, dur });
        }
    }
};
