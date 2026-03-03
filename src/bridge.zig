const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");

pub const Bridge = struct {
    allocator: std.mem.Allocator,
    process: std.process.Child,

    pub fn init(allocator: std.mem.Allocator, bridge_path: []const u8, mode: []const u8) !Bridge {
        var process = std.process.Child.init(&[_][]const u8{ "python3", bridge_path, "--mode", mode }, allocator);
        process.stdin_behavior = .Pipe;
        process.stdout_behavior = .Pipe;
        process.stderr_behavior = .Pipe;

        try process.spawn();

        return Bridge{
            .allocator = allocator,
            .process = process,
        };
    }

    pub fn deinit(self: *Bridge) void {
        _ = self.process.kill() catch {};
    }

    pub fn sendInput(self: *Bridge, input: []const u8) ![]const u8 {
        // Write JSON request
        const request = try std.fmt.allocPrint(
            self.allocator,
            "{{\"input\": \"{s}\"}}\n",
            .{input},
        );
        defer self.allocator.free(request);

        try self.process.stdin.?.writeAll(request);

        // Read JSON response
        const response = try self.process.stdout.?.reader().readUntilDelimiterAlloc(
            self.allocator,
            '\n',
            1024 * 1024,
        );

        return response;
    }
};

test "Bridge spawn and communicate" {
    const allocator = testing.allocator;

    var bridge = try Bridge.init(allocator, "bridge/bridge.py", "lexer");
    defer bridge.deinit();

    // Give the process time to start
    std.time.sleep(100 * std.time.ns_per_ms);

    const response = try bridge.sendInput("2024-01-15");
    defer allocator.free(response);

    // Just verify we got JSON back
    try testing.expect(response.len > 0);
    try testing.expect(std.mem.indexOf(u8, response, "tokens") != null);
}
