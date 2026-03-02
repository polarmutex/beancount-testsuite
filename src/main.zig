const std = @import("std");
const types = @import("types.zig");
const runner_mod = @import("runner.zig");
const reporter_mod = @import("reporter.zig");
const yaml_parser = @import("yaml_parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    // Parse test file
    const test_file = "spec/lexer/smoke_test.json";
    const suite = try yaml_parser.parseTestFile(allocator, test_file);
    defer {
        for (suite.tests) |test_case| {
            for (test_case.expected) |token| {
                allocator.free(token.type);
                allocator.free(token.value);
            }
            allocator.free(test_case.expected);
            allocator.free(test_case.name);
            allocator.free(test_case.input);
        }
        allocator.free(suite.tests);
        allocator.free(suite.version);
        allocator.free(suite.category);
        allocator.free(suite.description);
    }

    try stdout.print("Running test suite: {s}\n", .{suite.description});
    try stdout.print("Category: {s}\n\n", .{suite.category});

    var runner = try runner_mod.Runner.init(allocator, "bridge/lexer_bridge.py");
    defer runner.deinit();

    var reporter = reporter_mod.Reporter(@TypeOf(stdout)).init(allocator, stdout);

    var passed_count: usize = 0;
    const total_count = suite.tests.len;

    for (suite.tests) |test_case| {
        const result = try runner.runTest(test_case);
        defer allocator.free(result.actual_tokens);

        try reporter.reportResult(result);

        if (result.passed) {
            passed_count += 1;
        }
    }

    try reporter.reportSummary(total_count, passed_count);

    const exit_code: u8 = if (passed_count == total_count) 0 else 1;
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
    _ = yaml_parser;
}
