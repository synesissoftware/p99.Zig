const std = @import("std");
const p99 = @import("p99");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var buffer: [4096]u8 = undefined;
    var stdout_impl = std.Io.File.stdout().writer(io, &buffer);
    const stdout = &stdout_impl.interface;

    try stdout.print("p99.Zig Benchmark Suite starting...\n\n", .{});

    // 1. Benchmark: Pushing sequential events
    {
        const count = 100_000;
        const trials = 50;
        var total_ns: u64 = 0;

        // Warmup phase (to heat caches and scale CPU frequency)
        {
            var warmup_h = p99.Histogram{};
            var i: u64 = 1;
            while (i <= 10_000) : (i += 1) {
                var val = i;
                std.mem.doNotOptimizeAway(&val);
                _ = warmup_h.pushEventTimeNs(val);
            }
            std.mem.doNotOptimizeAway(&warmup_h);
        }

        // Multiple trials for statistical stability
        var t: usize = 0;
        while (t < trials) : (t += 1) {
            var h = p99.Histogram{};
            const start = std.Io.Clock.awake.now(io);
            var i: u64 = 1;
            while (i <= count) : (i += 1) {
                var val = i;
                std.mem.doNotOptimizeAway(&val); // Force LLVM to treat input as dynamic runtime value!
                _ = h.pushEventTimeNs(val);
            }
            const elapsed = start.untilNow(io, .awake);
            std.mem.doNotOptimizeAway(&h); // Prevent LLVM from deleting the loop!
            total_ns += @as(u64, @intCast(elapsed.nanoseconds));
        }

        const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(count * trials));

        try stdout.print("Benchmark: Push Sequential Events\n", .{});
        try stdout.print("  Total events: {d} (across {d} trials)\n", .{count * trials, trials});
        try stdout.print("  Average/push: {d:.2} ns\n\n", .{avg_ns});
    }

    // 2. Benchmark: Pushing random events (1ns to 10s wide-range)
    {
        const count = 100_000;
        const trials = 50;
        var total_ns: u64 = 0;
        var seed: u64 = 12345;

        // Warmup
        {
            var warmup_h = p99.Histogram{};
            var i: u64 = 1;
            while (i <= 10_000) : (i += 1) {
                seed = seed *% 6364136223846793005 +% 1442695040888963407;
                var val = (seed % 10_000_000_000) + 1;
                std.mem.doNotOptimizeAway(&val);
                _ = warmup_h.pushEventTimeNs(val);
            }
            std.mem.doNotOptimizeAway(&warmup_h);
        }

        var t: usize = 0;
        while (t < trials) : (t += 1) {
            var h = p99.Histogram{};
            const start = std.Io.Clock.awake.now(io);
            var i: u64 = 1;
            while (i <= count) : (i += 1) {
                seed = seed *% 6364136223846793005 +% 1442695040888963407;
                var val = (seed % 10_000_000_000) + 1;
                std.mem.doNotOptimizeAway(&val); // Force LLVM to treat input as dynamic runtime value!
                _ = h.pushEventTimeNs(val);
            }
            const elapsed = start.untilNow(io, .awake);
            std.mem.doNotOptimizeAway(&h); // Prevent loop deletion
            total_ns += @as(u64, @intCast(elapsed.nanoseconds));
        }

        const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(count * trials));

        try stdout.print("Benchmark: Push Random Events (1ns to 10s wide-range)\n", .{});
        try stdout.print("  Total events: {d} (across {d} trials)\n", .{count * trials, trials});
        try stdout.print("  Average/push: {d:.2} ns\n\n", .{avg_ns});
    }

    // 3. Benchmark: Percentile Queries (valueAtP99 on 10s wide-range)
    {
        var h = p99.Histogram{};
        const count = 100_000;
        var seed: u64 = 12345;
        var i: u64 = 1;
        while (i <= count) : (i += 1) {
            seed = seed *% 6364136223846793005 +% 1442695040888963407;
            const val = (seed % 10_000_000_000) + 1;
            _ = h.pushEventTimeNs(val);
        }
        std.mem.doNotOptimizeAway(&h);

        const query_count = 10_000;
        const trials = 50;
        var total_ns: u64 = 0;

        // Warmup
        {
            var q: u64 = 0;
            while (q < 1_000) : (q += 1) {
                var val = h.valueAtP99();
                std.mem.doNotOptimizeAway(&val);
            }
        }

        var t: usize = 0;
        while (t < trials) : (t += 1) {
            const start = std.Io.Clock.awake.now(io);
            var q: u64 = 0;
            while (q < query_count) : (q += 1) {
                std.mem.doNotOptimizeAway(&h); // Force LLVM to assume 'h' might be modified, preventing loop hoisting/caching!
                var val = h.valueAtP99();
                std.mem.doNotOptimizeAway(&val); // Prevent query loop deletion
            }
            const elapsed = start.untilNow(io, .awake);
            total_ns += @as(u64, @intCast(elapsed.nanoseconds));
        }

        const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(query_count * trials));

        try stdout.print("Benchmark: Percentile Queries (valueAtP99 on 10s wide-range)\n", .{});
        try stdout.print("  Total queries: {d} (across {d} trials)\n", .{query_count * trials, trials});
        try stdout.print("  Average/query: {d:.2} ns\n\n", .{avg_ns});
    }

    // 4. Benchmark: Clear
    {
        const trials = 50;
        const loop_count = 10_000;
        var total_ns: u64 = 0;

        // Warmup
        {
            var warmup_h = p99.Histogram{};
            var i: usize = 0;
            while (i < 1_000) : (i += 1) {
                warmup_h.clear();
                std.mem.doNotOptimizeAway(&warmup_h);
            }
        }

        var t: usize = 0;
        while (t < trials) : (t += 1) {
            var h = p99.Histogram{};
            _ = h.pushEventTimeNs(100);
            _ = h.pushEventTimeNs(200);

            const start = std.Io.Clock.awake.now(io);
            var i: usize = 0;
            while (i < loop_count) : (i += 1) {
                h.clear();
                std.mem.doNotOptimizeAway(&h);
            }
            const elapsed = start.untilNow(io, .awake);
            total_ns += @as(u64, @intCast(elapsed.nanoseconds));
        }

        const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(loop_count * trials));

        try stdout.print("Benchmark: Clear\n", .{});
        try stdout.print("  Total clears: {d} (across {d} trials)\n", .{loop_count * trials, trials});
        try stdout.print("  Average/clear: {d:.2} ns\n\n", .{avg_ns});
    }

    // 5. Benchmark: Generic Percentile Queries (valueAtPercentile)
    {
        var h = p99.Histogram{};
        const count = 100_000;
        var seed: u64 = 12345;
        var i: u64 = 1;
        while (i <= count) : (i += 1) {
            seed = seed *% 6364136223846793005 +% 1442695040888963407;
            const val = (seed % 10_000_000_000) + 1; // 10-second wide-range
            _ = h.pushEventTimeNs(val);
        }
        std.mem.doNotOptimizeAway(&h);

        const query_count = 10_000;
        const trials = 50;
        var total_ns: u64 = 0;

        // Warmup
        {
            var q: u64 = 0;
            while (q < 1_000) : (q += 1) {
                var val = h.valueAtPercentile(99.0);
                std.mem.doNotOptimizeAway(&val);
            }
        }

        var t: usize = 0;
        while (t < trials) : (t += 1) {
            const start = std.Io.Clock.awake.now(io);
            var q: u64 = 0;
            while (q < query_count) : (q += 1) {
                std.mem.doNotOptimizeAway(&h);
                var val = h.valueAtPercentile(99.0);
                std.mem.doNotOptimizeAway(&val);
            }
            const elapsed = start.untilNow(io, .awake);
            total_ns += @as(u64, @intCast(elapsed.nanoseconds));
        }

        const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(query_count * trials));

        try stdout.print("Benchmark: Generic Percentile Queries (valueAtPercentile(99.0))\n", .{});
        try stdout.print("  Total queries: {d} (across {d} trials)\n", .{query_count * trials, trials});
        try stdout.print("  Average/query: {d:.2} ns\n\n", .{avg_ns});
    }

    try stdout.flush();
}
