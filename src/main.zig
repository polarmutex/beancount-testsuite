const std = @import("std");
const types = @import("types.zig");
const runner_mod = @import("runner.zig");
const reporter_mod = @import("reporter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    // Hardcoded smoke test
    const expected_tokens = [_]types.Token{
        types.Token{
            .type = "DATE",
            .value = "2024-01-15",
            .line = 1,
            .column = 1,
        },
    };

    const test_case = types.Test{
        .name = "Simple date token",
        .input = "2024-01-15",
        .expected = &expected_tokens,
    };

    var runner = try runner_mod.Runner.init(allocator, "bridge/lexer_bridge.py");
    defer runner.deinit();

    var reporter = reporter_mod.Reporter(@TypeOf(stdout)).init(allocator, stdout);

    const result = try runner.runTest(test_case);
    defer allocator.free(result.actual_tokens);

    try reporter.reportResult(result);
    try reporter.reportSummary(1, if (result.passed) 1 else 0);

    // Exit code
    const exit_code: u8 = if (result.passed) 0 else 1;
    std.process.exit(exit_code);
}

test "basic test" {
    try std.testing.expect(true);
}

// Reference imports to include their tests
comptime {
    _ = types;
    const bridge = @import("bridge.zig");
    _ = bridge;
    _ = runner_mod;
    _ = reporter_mod;
}
