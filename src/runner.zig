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

pub const Runner = struct {
    allocator: std.mem.Allocator,
    bridge: bridge_mod.Bridge,

    pub fn init(allocator: std.mem.Allocator, bridge_path: []const u8) !Runner {
        const bridge = try bridge_mod.Bridge.init(allocator, bridge_path);
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

    var runner = try Runner.init(allocator, "bridge/lexer_bridge.py");
    defer runner.deinit();

    const result = try runner.runTest(test_case);
    defer allocator.free(result.actual_tokens);

    try testing.expect(result.passed);
}
