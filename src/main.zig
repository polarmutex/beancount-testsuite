const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Beancount Test Suite v0.1.0\n", .{});
}

test "basic test" {
    try std.testing.expect(true);
}
