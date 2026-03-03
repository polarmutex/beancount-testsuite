const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");
const runner_mod = @import("runner.zig");

pub const ParserTestResult = struct {
    test_name: []const u8,
    passed: bool,
    expected_entries: []const types.ASTNode,
    actual_entries: []const types.ASTNode,
    expected_errors: []const types.ParserError,
    actual_errors: []const types.ParserError,
    error_message: ?[]const u8,
};

pub fn Reporter(comptime WriterType: type) type {
    return struct {
        allocator: std.mem.Allocator,
        writer: WriterType,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, writer: WriterType) Self {
            return Self{
                .allocator = allocator,
                .writer = writer,
            };
        }

        pub fn reportResult(self: *Self, result: runner_mod.TestResult) !void {
            if (result.passed) {
                try self.writer.print("✓ {s}\n", .{result.test_name});
            } else {
                try self.writer.print("✗ {s}\n", .{result.test_name});
                if (result.error_message) |err| {
                    try self.writer.print("  Error: {s}\n", .{err});
                }
                try self.writer.print("  Expected {} tokens, got {}\n", .{
                    result.expected_tokens.len,
                    result.actual_tokens.len,
                });

                // Show token details for debugging
                if (result.expected_tokens.len > 0 and result.actual_tokens.len > 0) {
                    const exp = result.expected_tokens[0];
                    const act = result.actual_tokens[0];
                    try self.writer.print("  Expected[0]: type={s}, value={s}, line={}, col={}\n", .{
                        exp.type, exp.value, exp.line, exp.column
                    });
                    try self.writer.print("  Actual[0]:   type={s}, value={s}, line={}, col={}\n", .{
                        act.type, act.value, act.line, act.column
                    });
                }
            }
        }

        pub fn reportParserResult(self: *Self, result: ParserTestResult) !void {
            if (result.passed) {
                try self.writer.print("✓ {s}\n", .{result.test_name});
            } else {
                try self.writer.print("✗ {s}\n", .{result.test_name});

                if (result.error_message) |err| {
                    try self.writer.print("  Error: {s}\n", .{err});
                }

                // Entry count mismatch
                if (result.expected_entries.len != result.actual_entries.len) {
                    try self.writer.print("  Expected {} entries, got {}\n", .{
                        result.expected_entries.len,
                        result.actual_entries.len,
                    });

                    // Show expected entries summary
                    if (result.expected_entries.len > 0) {
                        try self.writer.print("\n  Expected entries:\n", .{});
                        for (result.expected_entries, 0..) |entry, i| {
                            try self.writer.print("    {}. {s}", .{ i + 1, entry.node_type });

                            // Show key attributes
                            if (entry.attributes.get("date")) |date| {
                                try self.writer.print(" (date: {s}", .{date});
                                if (entry.attributes.get("account")) |account| {
                                    try self.writer.print(", account: {s}", .{account});
                                }
                                try self.writer.print(")", .{});
                            }
                            try self.writer.print("\n", .{});
                        }
                    }

                    // Show actual entries summary
                    if (result.actual_entries.len > 0) {
                        try self.writer.print("\n  Actual entries:\n", .{});
                        for (result.actual_entries, 0..) |entry, i| {
                            try self.writer.print("    {}. {s}", .{ i + 1, entry.node_type });

                            if (entry.attributes.get("date")) |date| {
                                try self.writer.print(" (date: {s}", .{date});
                                if (entry.attributes.get("account")) |account| {
                                    try self.writer.print(", account: {s}", .{account});
                                }
                                try self.writer.print(")", .{});
                            }
                            try self.writer.print("\n", .{});
                        }
                    }
                }

                // Error count mismatch
                if (result.expected_errors.len != result.actual_errors.len) {
                    try self.writer.print("\n  Expected {} error(s), got {}\n", .{
                        result.expected_errors.len,
                        result.actual_errors.len,
                    });
                }
            }
        }

        pub fn reportSummary(self: *Self, total: usize, passed: usize) !void {
            const failed = total - passed;
            const percent = if (total > 0) (passed * 100) / total else 0;

            try self.writer.print("\n", .{});
            try self.writer.print("Results: {}/{} passed ({}%)\n", .{ passed, total, percent });

            if (failed > 0) {
                try self.writer.print("{} test(s) failed\n", .{failed});
            }
        }
    };
}

test "Reporter formats passing test" {
    const allocator = testing.allocator;

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var reporter = Reporter(@TypeOf(buffer.writer())).init(allocator, buffer.writer());

    const result = runner_mod.TestResult{
        .test_name = "Test name",
        .passed = true,
        .expected_tokens = &[_]types.Token{},
        .actual_tokens = &[_]types.Token{},
        .error_message = null,
    };

    try reporter.reportResult(result);

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "✓ Test name") != null);
}

test "Reporter formats failing test" {
    const allocator = testing.allocator;

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var reporter = Reporter(@TypeOf(buffer.writer())).init(allocator, buffer.writer());

    const result = runner_mod.TestResult{
        .test_name = "Failed test",
        .passed = false,
        .expected_tokens = &[_]types.Token{},
        .actual_tokens = &[_]types.Token{},
        .error_message = "Token mismatch",
    };

    try reporter.reportResult(result);

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "✗ Failed test") != null);
    try testing.expect(std.mem.indexOf(u8, output, "Token mismatch") != null);
}

test "Reporter formats parser test failure - entry count mismatch" {
    const allocator = testing.allocator;

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var reporter = Reporter(@TypeOf(buffer.writer())).init(allocator, buffer.writer());

    // Create parser test result with count mismatch
    var expected_attrs = std.StringHashMap([]const u8).init(allocator);
    defer expected_attrs.deinit();
    try expected_attrs.put("date", "2024-01-01");

    const expected_entry = types.ASTNode{
        .node_type = "Open",
        .attributes = expected_attrs,
        .children = &[_]types.ASTNode{},
    };

    const parser_result = ParserTestResult{
        .test_name = "Entry count test",
        .passed = false,
        .expected_entries = &[_]types.ASTNode{expected_entry},
        .actual_entries = &[_]types.ASTNode{},
        .expected_errors = &[_]types.ParserError{},
        .actual_errors = &[_]types.ParserError{},
        .error_message = "Entry count mismatch",
    };

    try reporter.reportParserResult(parser_result);

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "Expected 1 entries, got 0") != null);
}
