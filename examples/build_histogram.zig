const std = @import("std");
const p99 = @import("p99");

pub fn main(init: std.process.Init) !void {
    var buffer: [4096]u8 = undefined;
    var stdout_impl = std.Io.File.stdout().writer(init.io, &buffer);
    const stdout = &stdout_impl.interface;

    try stdout.print("p99.Zig Example: Building a Histogram\n\n", .{});

    var h = p99.Histogram{};

    // Push some latency measurements (in nanoseconds)
    _ = h.pushEventTimeNs(100);
    _ = h.pushEventTimeNs(250);
    _ = h.pushEventTimeNs(500);
    _ = h.pushEventTimeNs(1000);
    _ = h.pushEventTimeNs(5000);

    // Print the histogram using our custom format implementation
    try stdout.print("Histogram state:\n{f}\n\n", .{h});

    // Query percentiles
    const p50 = h.valueAtP50().?;
    const p90 = h.valueAtP90().?;
    const p99_val = h.valueAtP99().?;

    try stdout.print("Percentiles:\n", .{});
    try stdout.print("  P50:  {d} ns\n", .{p50});
    try stdout.print("  P90:  {d} ns\n", .{p90});
    try stdout.print("  P99:  {d} ns\n", .{p99_val});

    try stdout.flush();
}
