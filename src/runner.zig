const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");
const bridge_mod = @import("bridge.zig");

/// Result of executing a single test case.
/// Note: actual_tokens is an owned slice that must be freed by the caller.
pub const TestResult = struct {
    test_name: []const u8,
    passed: bool,
    expected_tokens: []const types.Token,
    actual_tokens: []types.Token, // Caller must free this slice
    error_message: ?[]const u8,
};

/// Result of executing a single parser test case.
/// Note: Caller must free actual_entries and actual_errors and their nested content.
pub const ParserTestResult = struct {
    test_name: []const u8,
    passed: bool,
    expected_entries: []const types.ASTNode,
    actual_entries: []types.ASTNode, // Caller must free
    expected_errors: []const types.ParserError,
    actual_errors: []types.ParserError, // Caller must free
    error_message: ?[]const u8,
};

pub const Runner = struct {
    allocator: std.mem.Allocator,
    bridge: bridge_mod.Bridge,

    pub fn init(allocator: std.mem.Allocator, bridge_path: []const u8) !Runner {
        const bridge = try bridge_mod.Bridge.init(allocator, bridge_path, "lexer");
        return Runner{
            .allocator = allocator,
            .bridge = bridge,
        };
    }

    pub fn initParser(allocator: std.mem.Allocator, bridge_path: []const u8) !Runner {
        const bridge = try bridge_mod.Bridge.init(allocator, bridge_path, "parser");
        return Runner{
            .allocator = allocator,
            .bridge = bridge,
        };
    }

    pub fn deinit(self: *Runner) void {
        self.bridge.deinit();
    }

    pub fn runTest(self: *Runner, test_case: types.Test) !TestResult {
        // Send input to bridge
        const response_json = try self.bridge.sendInput(test_case.input);
        defer self.allocator.free(response_json);

        // Parse JSON response
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response_json,
            .{},
        );
        defer parsed.deinit();

        // Extract tokens from JSON
        const tokens_array = parsed.value.object.get("tokens") orelse {
            return TestResult{
                .test_name = test_case.name,
                .passed = false,
                .expected_tokens = test_case.expected,
                .actual_tokens = &[_]types.Token{},
                .error_message = "No tokens in response",
            };
        };

        var actual_tokens = std.ArrayList(types.Token).init(self.allocator);
        defer actual_tokens.deinit();

        for (tokens_array.array.items) |token_val| {
            const token = types.Token{
                .type = token_val.object.get("type").?.string,
                .value = token_val.object.get("value").?.string,
                .line = @intCast(token_val.object.get("line").?.integer),
                .column = @intCast(token_val.object.get("column").?.integer),
            };
            try actual_tokens.append(token);
        }

        // Compare tokens
        const passed = tokensEqual(test_case.expected, actual_tokens.items);

        return TestResult{
            .test_name = test_case.name,
            .passed = passed,
            .expected_tokens = test_case.expected,
            .actual_tokens = try actual_tokens.toOwnedSlice(),
            .error_message = if (passed) null else "Token mismatch",
        };
    }

    fn tokensEqual(expected: []const types.Token, actual: []const types.Token) bool {
        if (expected.len != actual.len) return false;

        for (expected, actual) |exp, act| {
            if (!exp.eql(act)) return false;
        }

        return true;
    }

    pub fn runParserTest(self: *Runner, test_case: types.ParserTest) !ParserTestResult {
        // Send input to bridge
        const response_json = try self.bridge.sendInput(test_case.input);
        defer self.allocator.free(response_json);

        // Parse JSON response
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response_json,
            .{},
        );
        defer parsed.deinit();

        // Extract entries and errors from JSON
        const entries_array = parsed.value.object.get("entries") orelse {
            return ParserTestResult{
                .test_name = test_case.name,
                .passed = false,
                .expected_entries = test_case.expected_entries,
                .actual_entries = &[_]types.ASTNode{},
                .expected_errors = test_case.expected_errors,
                .actual_errors = &[_]types.ParserError{},
                .error_message = "No entries in response",
            };
        };

        const errors_array = parsed.value.object.get("errors") orelse {
            return ParserTestResult{
                .test_name = test_case.name,
                .passed = false,
                .expected_entries = test_case.expected_entries,
                .actual_entries = &[_]types.ASTNode{},
                .expected_errors = test_case.expected_errors,
                .actual_errors = &[_]types.ParserError{},
                .error_message = "No errors field in response",
            };
        };

        // Deserialize entries
        var actual_entries = std.ArrayList(types.ASTNode).init(self.allocator);
        defer actual_entries.deinit();

        for (entries_array.array.items) |entry_val| {
            const entry = try self.deserializeASTNode(entry_val);
            try actual_entries.append(entry);
        }

        // Deserialize errors
        var actual_errors = std.ArrayList(types.ParserError).init(self.allocator);
        defer actual_errors.deinit();

        for (errors_array.array.items) |error_val| {
            const err = try self.deserializeParserError(error_val);
            try actual_errors.append(err);
        }

        // Compare entries and errors
        const entries_match = try self.entriesEqual(test_case.expected_entries, actual_entries.items);
        const errors_match = try self.errorsEqual(test_case.expected_errors, actual_errors.items);
        const passed = entries_match and errors_match;

        return ParserTestResult{
            .test_name = test_case.name,
            .passed = passed,
            .expected_entries = test_case.expected_entries,
            .actual_entries = try actual_entries.toOwnedSlice(),
            .expected_errors = test_case.expected_errors,
            .actual_errors = try actual_errors.toOwnedSlice(),
            .error_message = if (passed) null else "AST or error mismatch",
        };
    }

    fn deserializeASTNode(self: *Runner, json_val: std.json.Value) !types.ASTNode {
        const obj = json_val.object;

        // Extract node_type
        const node_type = obj.get("node_type").?.string;
        const node_type_owned = try self.allocator.dupe(u8, node_type);

        // Extract attributes
        const attrs_obj = obj.get("attributes").?.object;
        var attributes = std.StringHashMap([]const u8).init(self.allocator);

        var iter = attrs_obj.iterator();
        while (iter.next()) |entry| {
            const key_owned = try self.allocator.dupe(u8, entry.key_ptr.*);
            const val_owned = try self.allocator.dupe(u8, entry.value_ptr.*.string);
            try attributes.put(key_owned, val_owned);
        }

        // Extract children
        const children_array = obj.get("children").?.array;
        var children = std.ArrayList(types.ASTNode).init(self.allocator);

        for (children_array.items) |child_val| {
            const child = try self.deserializeASTNode(child_val);
            try children.append(child);
        }

        return types.ASTNode{
            .node_type = node_type_owned,
            .attributes = attributes,
            .children = try children.toOwnedSlice(),
        };
    }

    fn deserializeParserError(self: *Runner, json_val: std.json.Value) !types.ParserError {
        const obj = json_val.object;

        const error_type = obj.get("error_type").?.string;
        const message = obj.get("message").?.string;

        const line: ?usize = if (obj.get("line")) |line_val| blk: {
            break :blk if (line_val == .null) null else @as(usize, @intCast(line_val.integer));
        } else null;

        return types.ParserError{
            .error_type = try self.allocator.dupe(u8, error_type),
            .message = try self.allocator.dupe(u8, message),
            .line = line,
        };
    }

    fn entriesEqual(self: *Runner, expected: []const types.ASTNode, actual: []const types.ASTNode) !bool {
        _ = self;
        if (expected.len != actual.len) return false;

        for (expected, actual) |exp, act| {
            if (!exp.eql(act)) return false;
        }

        return true;
    }

    fn errorsEqual(self: *Runner, expected: []const types.ParserError, actual: []const types.ParserError) !bool {
        _ = self;
        if (expected.len != actual.len) return false;

        for (expected, actual) |exp, act| {
            // Compare error type
            if (!std.mem.eql(u8, exp.error_type, act.error_type)) return false;

            // For message, use regex matching if expected contains regex patterns
            // For now, simple string equality
            if (!std.mem.eql(u8, exp.message, act.message)) return false;

            // Compare line if both have it
            if (exp.line != act.line) return false;
        }

        return true;
    }
};

test "Runner executes single test" {
    const allocator = testing.allocator;

    const expected_tokens = [_]types.Token{
        types.Token{
            .type = "DATE",
            .value = "2024-01-15",
            .line = 1,
            .column = 1,
        },
    };

    const test_case = types.Test{
        .name = "Simple date",
        .input = "2024-01-15",
        .expected = &expected_tokens,
    };

    var runner = try Runner.init(allocator, "bridge/bridge.py");
    defer runner.deinit();

    const result = try runner.runTest(test_case);
    defer allocator.free(result.actual_tokens);

    try testing.expect(result.passed);
}
