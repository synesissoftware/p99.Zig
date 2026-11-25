const std = @import("std");
const p99 = @import("p99");

pub fn main(init: std.process.Init) !void {
    var buffer: [64]u8 = undefined;
    var stdout_impl = std.Io.File.stdout().writer(init.io, &buffer);
    const stdout = &stdout_impl.interface;

    try stdout.print("{s}\n", .{p99.VERSION});
    try stdout.flush();
}
