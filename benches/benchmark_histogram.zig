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
        var h = p99.Histogram{};
        const count = 100_000;

        const start = std.Io.Clock.awake.now(io);
        var i: u64 = 1;
        while (i <= count) : (i += 1) {
            _ = h.pushEventTimeNs(i);
        }
        const elapsed = start.untilNow(io, .awake);
        const ns = elapsed.nanoseconds;
        const avg_ns = @as(f64, @floatFromInt(ns)) / @as(f64, @floatFromInt(count));

        try stdout.print("Benchmark: Push Sequential Events\n", .{});
        try stdout.print("  Total events: {d}\n", .{count});
        try stdout.print("  Total time:   {d} ns\n", .{ns});
        try stdout.print("  Average/push: {d:.2} ns\n\n", .{avg_ns});
    }

    // 2. Benchmark: Pushing random events (using a simple LCG PRNG for speed)
    {
        var h = p99.Histogram{};
        const count = 100_000;
        var seed: u64 = 12345;

        const start = std.Io.Clock.awake.now(io);
        var i: u64 = 1;
        while (i <= count) : (i += 1) {
            // Simple LCG PRNG
            seed = seed *% 6364136223846793005 +% 1442695040888963407;
            const val = (seed % 1_000_000) + 1;
            _ = h.pushEventTimeNs(val);
        }
        const elapsed = start.untilNow(io, .awake);
        const ns = elapsed.nanoseconds;
        const avg_ns = @as(f64, @floatFromInt(ns)) / @as(f64, @floatFromInt(count));

        try stdout.print("Benchmark: Push Random Events (1ns to 1ms)\n", .{});
        try stdout.print("  Total events: {d}\n", .{count});
        try stdout.print("  Total time:   {d} ns\n", .{ns});
        try stdout.print("  Average/push: {d:.2} ns\n\n", .{avg_ns});
    }

    // 3. Benchmark: Percentile Queries
    {
        var h = p99.Histogram{};
        const count = 100_000;
        var seed: u64 = 12345;
        var i: u64 = 1;
        while (i <= count) : (i += 1) {
            seed = seed *% 6364136223846793005 +% 1442695040888963407;
            const val = (seed % 1_000_000) + 1;
            _ = h.pushEventTimeNs(val);
        }

        const query_count = 10_000;
        const start = std.Io.Clock.awake.now(io);
        var q: u64 = 0;
        while (q < query_count) : (q += 1) {
            _ = h.valueAtP99();
        }
        const elapsed = start.untilNow(io, .awake);
        const ns = elapsed.nanoseconds;
        const avg_ns = @as(f64, @floatFromInt(ns)) / @as(f64, @floatFromInt(query_count));

        try stdout.print("Benchmark: Percentile Queries (valueAtP99)\n", .{});
        try stdout.print("  Total queries: {d}\n", .{query_count});
        try stdout.print("  Total time:    {d} ns\n", .{ns});
        try stdout.print("  Average/query: {d:.2} ns\n\n", .{avg_ns});
    }

    try stdout.flush();
}
