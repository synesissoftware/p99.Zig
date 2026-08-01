// src/root.zig : p99.Zig

const std = @import("std");

/// Low-cost performance percentile histogram using 64 buckets.
///
/// Tracks event durations with nanosecond precision across 64 logarithmic
/// power-of-two spacing buckets. This is extremely efficient and suited
/// for high-frequency low-overhead timing measurements.
pub const Histogram = struct {
    event_count: u64 = 0,
    event_time_total: u64 = 0,
    has_overflowed: bool = false,
    min_event_time: ?u64 = null,
    max_event_time: ?u64 = null,
    buckets: [64]u64 = [_]u64{0} ** 64,

    // API (class) methods

    /// Calculates the bucket index for a given elapsed time in nanoseconds.
    ///
    /// The index is computed logarithmic-wise based on the power of two of
    /// the value. Specifically, it maps:
    /// - `0` and `1` to bucket `0`;
    /// - `2` and `3` to bucket `1`;
    /// - `4` to `7` to bucket `2`;
    /// - `8` to `15` to bucket `3`;
    /// - ...
    /// - `(1 << 63)` to `u64::MAX` to bucket `63`;
    ///
    /// This is extremely fast because it is implemented via the CPU's
    /// `@clz` (count leading zeros) instruction, avoiding loop and
    /// branching logic.
    pub fn bucketIndex(time_in_ns: u64) usize {
        if (time_in_ns <= 1) {
            return 0;
        }

        return @as(usize, 64 - @clz(time_in_ns) - 1);
    }

    /// Returns the inclusive range `(lower_bound, upper_bound)` of
    /// nanoseconds represented by the given bucket index.
    ///
    /// - Index `0` represents `[0, 1]` nanoseconds;
    /// - Any index `i` from `1` to `63` represents `[2^i, 2^(i+1) - 1]`;
    pub fn bucketRange(index: usize) ?[2]u64 {
        if (index >= 64) {
            return null;
        }

        if (index == 0) {
            return [2]u64{ 0, 1 };
        }

        const lower = @as(u64, 1) << @intCast(index);
        const upper = if (index == 63) std.math.maxInt(u64) else (@as(u64, 1) << @intCast(index + 1)) - 1;

        return [2]u64{ lower, upper };
    }

    // Mutating methods

    /// Clears the instance, resetting all values to the equivalent of a
    /// newly constructed instance.
    pub fn clear(self: *Histogram) void {
        self.* = .{};
    }

    /// Pushes an event with the given duration in nanoseconds.
    pub fn pushEventTimeNs(self: *Histogram, time_in_ns: u64) bool {
        if (self.tryAddNsToTotalAndUpdateMinMax_(time_in_ns)) {
            self.event_count += 1;

            const bucket = bucketIndex(time_in_ns);
            self.buckets[bucket] += 1;

            return true;
        }

        return false;
    }

    /// Pushes an event with the given duration in microseconds.
    pub fn pushEventTimeUs(self: *Histogram, time_in_us: u64) bool {
        const res = @mulWithOverflow(time_in_us, 1_000);
        if (res[1] != 0) {
            self.has_overflowed = true;

            return false;
        }

        return self.pushEventTimeNs(res[0]);
    }

    /// Pushes an event with the given duration in milliseconds.
    pub fn pushEventTimeMs(self: *Histogram, time_in_ms: u64) bool {
        const res = @mulWithOverflow(time_in_ms, 1_000_000);
        if (res[1] != 0) {
            self.has_overflowed = true;

            return false;
        }

        return self.pushEventTimeNs(res[0]);
    }

    /// Pushes an event with the given duration in seconds.
    pub fn pushEventTimeS(self: *Histogram, time_in_s: u64) bool {
        const res = @mulWithOverflow(time_in_s, 1_000_000_000);
        if (res[1] != 0) {
            self.has_overflowed = true;

            return false;
        }

        return self.pushEventTimeNs(res[0]);
    }

    // Non-mutating methods

    /// Returns the count of events in a specific bucket.
    pub fn bucketValue(self: *const Histogram, index: usize) ?u64 {
        if (index < 64) {
            return self.buckets[index];
        }

        return null;
    }

    /// Returns a reference to all 64 buckets.
    pub fn getBuckets(self: *const Histogram) *const [64]u64 {
        return &self.buckets;
    }

    /// Number of events counted.
    pub fn eventCount(self: *const Histogram) u64 {
        return self.event_count;
    }

    /// Returns the total event time in nanoseconds, if no overflow
    /// occurred.
    pub fn eventTimeTotal(self: *const Histogram) ?u64 {
        if (self.has_overflowed) {
            return null;
        }

        return self.event_time_total;
    }

    /// Returns the total event time in nanoseconds, regardless of whether
    /// overflow has occurred.
    pub fn eventTimeTotalRaw(self: *const Histogram) u64 {
        return self.event_time_total;
    }

    /// Indicates whether overflow has occurred.
    pub fn hasOverflowed(self: *const Histogram) bool {
        return self.has_overflowed;
    }

    /// Returns the minimum event time observed, if any.
    pub fn minEventTime(self: *const Histogram) ?u64 {
        return self.min_event_time;
    }

    /// Returns the maximum event time observed, if any.
    pub fn maxEventTime(self: *const Histogram) ?u64 {
        return self.max_event_time;
    }

    /// Returns the approximated duration (in nanoseconds) at the given
    /// percentile.
    pub fn valueAtPercentile(self: *const Histogram, percentile: f64) ?u64 {
        if (self.event_count == 0) {
            return null;
        }

        const p = std.math.clamp(percentile, @as(f64, 0.0), @as(f64, 100.0));

        if (p <= 0.0) {
            return self.min_event_time;
        }

        if (p >= 100.0) {
            return self.max_event_time;
        }

        const target_rank = @as(f64, @floatFromInt(self.event_count)) * (p / 100.0);
        var accumulated: u64 = 0;

        for (self.buckets, 0..) |count, i| {
            if (count > 0) {
                const prev_accumulated = accumulated;
                accumulated += count;

                if (@as(f64, @floatFromInt(accumulated)) >= target_rank) {
                    const range = bucketRange(i) orelse return null;
                    const lower = range[0];
                    const upper = range[1];

                    const target_offset = target_rank - @as(f64, @floatFromInt(prev_accumulated));
                    const range_width = if (i == 63)
                        @as(f64, @floatFromInt(std.math.maxInt(u64) - lower))
                    else
                        @as(f64, @floatFromInt(upper - lower));

                    const fraction = target_offset / @as(f64, @floatFromInt(count));
                    const interpolated = @as(f64, @floatFromInt(lower)) + (range_width * fraction);
                    var value = @as(u64, @intFromFloat(std.math.round(interpolated)));

                    if (self.min_event_time) |min| {
                        if (value < min) {
                            value = min;
                        }
                    }

                    if (self.max_event_time) |max| {
                        if (value > max) {
                            value = max;
                        }
                    }

                    return value;
                }
            }
        }

        return self.max_event_time;
    }

    /// Returns the approximated duration (in nanoseconds) at the 50th
    /// percentile (p50).
    pub fn valueAtP50(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 1) / 2;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Returns the approximated duration (in nanoseconds) at the 75th
    /// percentile (p75).
    pub fn valueAtP75(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 3) / 4;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Returns the approximated duration (in nanoseconds) at the 90th
    /// percentile (p90).
    pub fn valueAtP90(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 90) / 100;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Returns the approximated duration (in nanoseconds) at the 95th
    /// percentile (p95).
    pub fn valueAtP95(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 95) / 100;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Returns the approximated duration (in nanoseconds) at the 99th
    /// percentile (p99).
    pub fn valueAtP99(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 99) / 100;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Returns the approximated duration (in nanoseconds) at the 99.5th
    /// percentile (p99.5).
    pub fn valueAtP99_5(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 995) / 1000;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Returns the approximated duration (in nanoseconds) at the 99.9th
    /// percentile (p99.9).
    pub fn valueAtP99_9(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 999) / 1000;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Returns the approximated duration (in nanoseconds) at the 99.99th
    /// percentile (p99.99).
    pub fn valueAtP99_99(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 9999) / 10000;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Returns the approximated duration (in nanoseconds) at the 99.999th
    /// percentile (p99.999).
    pub fn valueAtP99_999(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 99999) / 100000;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Returns the approximated duration (in nanoseconds) at the 99.9999th
    /// percentile (p99.9999).
    pub fn valueAtP99_999_9(self: *const Histogram) ?u64 {
        const target_rank = (@as(u128, self.event_count) * 999999) / 1000000;

        return self.valueAtTargetRankImpl(@as(u64, @intCast(target_rank)));
    }

    /// Custom format function for printing the Histogram.
    pub fn format(
        self: Histogram,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Histogram{{ .event_count = {d}, .event_time_total = ", .{self.event_count});

        if (self.eventTimeTotal()) |total| {
            try writer.print("{d}", .{total});
        } else {
            try writer.writeAll("null");
        }

        try writer.print(", .has_overflowed = {}, .min_event_time = ", .{self.has_overflowed});

        if (self.min_event_time) |min| {
            try writer.print("{d}", .{min});
        } else {
            try writer.writeAll("null");
        }

        try writer.print(", .max_event_time = ", .{});

        if (self.max_event_time) |max| {
            try writer.print("{d}", .{max});
        } else {
            try writer.writeAll("null");
        }

        try writer.writeAll(", .buckets = { ");

        var first = true;

        for (self.buckets, 0..) |count, i| {
            if (count > 0) {
                if (!first) {
                    try writer.writeAll(", ");
                }

                first = false;

                try writer.print("\"{d}\": {d}", .{ i, count });
            }
        }

        try writer.writeAll(" } }");
    }

    // Implementation

    fn tryAddNsToTotalAndUpdateMinMax_(self: *Histogram, time_in_ns: u64) bool {
        if (self.has_overflowed) {
            return false;
        }

        const res = @addWithOverflow(self.event_time_total, time_in_ns);
        if (res[1] != 0) {
            self.has_overflowed = true;

            return false;
        }

        self.event_time_total = res[0];

        if (self.min_event_time) |min_val| {
            if (time_in_ns < min_val) {
                self.min_event_time = time_in_ns;
            }
        } else {
            self.min_event_time = time_in_ns;
        }

        if (self.max_event_time) |max_val| {
            if (time_in_ns > max_val) {
                self.max_event_time = time_in_ns;
            }
        } else {
            self.max_event_time = time_in_ns;
        }

        return true;
    }

    fn valueAtTargetRankImpl(self: *const Histogram, target_rank: u64) ?u64 {
        if (self.event_count == 0) {
            return null;
        }

        var accumulated: u64 = 0;

        for (self.buckets, 0..) |count, i| {
            if (count > 0) {
                const prev_accumulated = accumulated;
                accumulated += count;

                if (accumulated >= target_rank) {
                    const range = bucketRange(i) orelse return null;
                    const lower = range[0];
                    const upper = range[1];

                    const target_offset = target_rank - prev_accumulated;

                    const interpolated = if (target_offset == 0)
                        lower
                    else blk: {
                        const range_width = if (i == 63) std.math.maxInt(u64) - lower else upper - lower;

                        if (range_width <= std.math.maxInt(u64) / @max(target_offset, 1)) {
                            break :blk lower + (range_width * target_offset) / count;
                        } else {
                            const val_u128 = @as(u128, lower) + (@as(u128, range_width) * @as(u128, target_offset)) / @as(u128, count);

                            break :blk @as(u64, @intCast(val_u128));
                        }
                    };

                    var value = interpolated;

                    if (self.min_event_time) |min| {
                        if (value < min) {
                            value = min;
                        }
                    }

                    if (self.max_event_time) |max| {
                        if (value > max) {
                            value = max;
                        }
                    }

                    return value;
                }
            }
        }

        return self.max_event_time;
    }
};

test "TEST_Histogram_Default" {
    const h = Histogram{};

    try std.testing.expectEqual(@as(u64, 0), h.eventCount());
    try std.testing.expectEqual(@as(?u64, 0), h.eventTimeTotal());
    try std.testing.expectEqual(@as(u64, 0), h.eventTimeTotalRaw());
    try std.testing.expect(!h.hasOverflowed());
    try std.testing.expectEqual(@as(?u64, null), h.minEventTime());
    try std.testing.expectEqual(@as(?u64, null), h.maxEventTime());
}

test "TEST_Histogram_bucketIndex" {
    try std.testing.expectEqual(@as(usize, 0), Histogram.bucketIndex(0));
    try std.testing.expectEqual(@as(usize, 0), Histogram.bucketIndex(1));
    try std.testing.expectEqual(@as(usize, 1), Histogram.bucketIndex(2));
    try std.testing.expectEqual(@as(usize, 1), Histogram.bucketIndex(3));
    try std.testing.expectEqual(@as(usize, 2), Histogram.bucketIndex(4));
    try std.testing.expectEqual(@as(usize, 2), Histogram.bucketIndex(7));
    try std.testing.expectEqual(@as(usize, 3), Histogram.bucketIndex(8));
    try std.testing.expectEqual(@as(usize, 3), Histogram.bucketIndex(15));
    try std.testing.expectEqual(@as(usize, 4), Histogram.bucketIndex(16));
    try std.testing.expectEqual(@as(usize, 4), Histogram.bucketIndex(31));
    try std.testing.expectEqual(@as(usize, 10), Histogram.bucketIndex(1024));
    try std.testing.expectEqual(@as(usize, 10), Histogram.bucketIndex(2047));
    try std.testing.expectEqual(@as(usize, 63), Histogram.bucketIndex(1 << 63));
    try std.testing.expectEqual(@as(usize, 63), Histogram.bucketIndex(std.math.maxInt(u64)));
}

test "TEST_Histogram_bucketRange" {
    try std.testing.expectEqual([2]u64{ 0, 1 }, Histogram.bucketRange(0).?);
    try std.testing.expectEqual([2]u64{ 2, 3 }, Histogram.bucketRange(1).?);
    try std.testing.expectEqual([2]u64{ 4, 7 }, Histogram.bucketRange(2).?);
    try std.testing.expectEqual([2]u64{ 8, 15 }, Histogram.bucketRange(3).?);
    try std.testing.expectEqual([2]u64{ 16, 31 }, Histogram.bucketRange(4).?);
    try std.testing.expectEqual([2]u64{ 1024, 2047 }, Histogram.bucketRange(10).?);
    try std.testing.expectEqual([2]u64{ 1 << 63, std.math.maxInt(u64) }, Histogram.bucketRange(63).?);
    try std.testing.expect(Histogram.bucketRange(64) == null);
}

test "TEST_Histogram_PUSH_EVENTS" {
    var h = Histogram{};

    try std.testing.expect(h.pushEventTimeNs(1));
    try std.testing.expect(h.pushEventTimeNs(3));
    try std.testing.expect(h.pushEventTimeUs(10));
    try std.testing.expect(h.pushEventTimeMs(5));
    try std.testing.expect(h.pushEventTimeS(2));

    try std.testing.expectEqual(@as(u64, 5), h.eventCount());
    try std.testing.expect(!h.hasOverflowed());
    try std.testing.expectEqual(@as(?u64, 1), h.minEventTime());
    try std.testing.expectEqual(@as(?u64, 2_000_000_000), h.maxEventTime());
    try std.testing.expectEqual(@as(?u64, 2_005_010_004), h.eventTimeTotal());

    try std.testing.expectEqual(@as(u64, 1), h.buckets[0]);
    try std.testing.expectEqual(@as(u64, 1), h.buckets[1]);
    try std.testing.expectEqual(@as(u64, 1), h.buckets[13]);
    try std.testing.expectEqual(@as(u64, 1), h.buckets[22]);
    try std.testing.expectEqual(@as(u64, 1), h.buckets[30]);

    h.clear();

    try std.testing.expectEqual(@as(u64, 0), h.eventCount());
    try std.testing.expectEqual(@as(?u64, 0), h.eventTimeTotal());
}

test "TEST_Histogram_OVERFLOW" {
    var h = Histogram{};

    try std.testing.expect(h.pushEventTimeNs(std.math.maxInt(u64)));
    try std.testing.expectEqual(@as(?u64, std.math.maxInt(u64)), h.eventTimeTotal());
    try std.testing.expect(!h.hasOverflowed());

    try std.testing.expect(!h.pushEventTimeNs(1));
    try std.testing.expect(h.hasOverflowed());
    try std.testing.expectEqual(@as(?u64, null), h.eventTimeTotal());
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64)), h.eventTimeTotalRaw());
}

test "TEST_Histogram_PERCENTILES_EMPTY" {
    const h = Histogram{};

    try std.testing.expectEqual(@as(?u64, null), h.valueAtPercentile(50.0));
    try std.testing.expectEqual(@as(?u64, null), h.valueAtP50());
    try std.testing.expectEqual(@as(?u64, null), h.valueAtP99());
}

test "TEST_Histogram_PERCENTILES_SINGLE_EVENT" {
    var h = Histogram{};

    try std.testing.expect(h.pushEventTimeNs(100));

    try std.testing.expectEqual(@as(?u64, 100), h.valueAtPercentile(0.0));
    try std.testing.expectEqual(@as(?u64, 100), h.valueAtPercentile(50.0));
    try std.testing.expectEqual(@as(?u64, 100), h.valueAtPercentile(99.0));
    try std.testing.expectEqual(@as(?u64, 100), h.valueAtPercentile(100.0));

    try std.testing.expectEqual(@as(?u64, 100), h.valueAtP50());
    try std.testing.expectEqual(@as(?u64, 100), h.valueAtP90());
    try std.testing.expectEqual(@as(?u64, 100), h.valueAtP99());
    try std.testing.expectEqual(@as(?u64, 100), h.valueAtP99_999_9());
}

test "TEST_Histogram_PERCENTILES_INTERPOLATION" {
    var h = Histogram{};

    try std.testing.expect(h.pushEventTimeNs(100)); // Bucket 6 [64, 127]
    try std.testing.expect(h.pushEventTimeNs(200)); // Bucket 7 [128, 255]

    const p50 = h.valueAtPercentile(50.0);
    const p99 = h.valueAtPercentile(99.0);

    try std.testing.expect(p50 != null);
    try std.testing.expect(p99 != null);

    try std.testing.expect(p50.? >= 100 and p50.? <= 200);
    try std.testing.expect(p99.? >= 100 and p99.? <= 200);

    try std.testing.expectEqual(@as(?u64, 100), h.valueAtPercentile(0.0));
    try std.testing.expectEqual(@as(?u64, 200), h.valueAtPercentile(100.0));

    try std.testing.expect(h.valueAtP50().? >= 100);
    try std.testing.expect(h.valueAtP99().? <= 200);
}

test "TEST_Histogram_PERCENTILES_WIDE_RANGE" {
    var h = Histogram{};

    const values = [_]u64{
        1,
        10,
        100,
        1_000,
        10_000,
        100_000,
        1_000_000,
        10_000_000,
        100_000_000,
        1_000_000_000,
        10_000_000_000,
    };

    for (values) |v| {
        try std.testing.expect(h.pushEventTimeNs(v));
    }

    try std.testing.expectEqual(@as(u64, values.len), h.eventCount());
    try std.testing.expectEqual(@as(?u64, 1), h.minEventTime());
    try std.testing.expectEqual(@as(?u64, 10_000_000_000), h.maxEventTime());

    const p50 = h.valueAtP50().?;
    const p75 = h.valueAtP75().?;
    const p90 = h.valueAtP90().?;
    const p95 = h.valueAtP95().?;
    const p99 = h.valueAtP99().?;
    const p99_5 = h.valueAtP99_5().?;
    const p99_9 = h.valueAtP99_9().?;
    const p99_99 = h.valueAtP99_99().?;
    const p99_999 = h.valueAtP99_999().?;
    const p99_999_9 = h.valueAtP99_999_9().?;

    try std.testing.expect(p50 <= p75);
    try std.testing.expect(p75 <= p90);
    try std.testing.expect(p90 <= p95);
    try std.testing.expect(p95 <= p99);
    try std.testing.expect(p99 <= p99_5);
    try std.testing.expect(p99_5 <= p99_9);
    try std.testing.expect(p99_9 <= p99_99);
    try std.testing.expect(p99_99 <= p99_999);
    try std.testing.expect(p99_999 <= p99_999_9);

    try std.testing.expect(p50 >= 1);
    try std.testing.expect(p99_999_9 <= 10_000_000_000);
}

test "TEST_Histogram_PERCENTILES_MANY_EVENTS" {
    var h = Histogram{};
    const count = 100_000;

    var i: u64 = 1;
    while (i <= count) : (i += 1) {
        try std.testing.expect(h.pushEventTimeNs(i));
    }

    try std.testing.expectEqual(@as(u64, count), h.eventCount());
    try std.testing.expectEqual(@as(?u64, 1), h.minEventTime());
    try std.testing.expectEqual(@as(?u64, count), h.maxEventTime());

    const p50 = h.valueAtP50().?;
    const p90 = h.valueAtP90().?;
    const p99 = h.valueAtP99().?;
    const p99_9 = h.valueAtP99_9().?;

    try std.testing.expectEqual(@as(u64, 50_000), p50);
    try std.testing.expectEqual(@as(u64, 100_000), p90);
    try std.testing.expectEqual(@as(u64, 100_000), p99);
    try std.testing.expectEqual(@as(u64, 100_000), p99_9);

    const p75 = h.valueAtP75().?;
    const p95 = h.valueAtP95().?;
    const p99_5 = h.valueAtP99_5().?;
    const p99_99 = h.valueAtP99_99().?;
    const p99_999 = h.valueAtP99_999().?;
    const p99_999_9 = h.valueAtP99_999_9().?;

    try std.testing.expect(p50 <= p75);
    try std.testing.expect(p75 <= p90);
    try std.testing.expect(p90 <= p95);
    try std.testing.expect(p95 <= p99);
    try std.testing.expect(p99 <= p99_5);
    try std.testing.expect(p99_5 <= p99_9);
    try std.testing.expect(p99_9 <= p99_99);
    try std.testing.expect(p99_99 <= p99_999);
    try std.testing.expect(p99_999 <= p99_999_9);
}
