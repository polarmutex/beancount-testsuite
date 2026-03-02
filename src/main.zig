const std = @import("std");

// Import modules to include their tests
const types = @import("types.zig");
const bridge = @import("bridge.zig");
const runner = @import("runner.zig");
const reporter = @import("reporter.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Beancount Test Suite v0.1.0\n", .{});
}

test "basic test" {
    try std.testing.expect(true);
}

// Reference imports to include their tests
comptime {
    _ = types;
    _ = bridge;
    _ = runner;
    _ = reporter;
}
