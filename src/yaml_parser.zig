const std = @import("std");
const types = @import("types.zig");

pub fn parseTestFile(allocator: std.mem.Allocator, file_path: []const u8) !types.TestSuite {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
    defer parsed.deinit();

    const root = parsed.value.object;

    // Duplicate all strings since parsed object will be freed
    const version = try allocator.dupe(u8, root.get("version").?.string);
    const category = try allocator.dupe(u8, root.get("category").?.string);
    const description = try allocator.dupe(u8, root.get("description").?.string);

    var tests = std.ArrayList(types.Test).init(allocator);
    defer tests.deinit();

    const tests_array = root.get("tests").?.array;

    for (tests_array.items) |test_obj| {
        const test_name = try allocator.dupe(u8, test_obj.object.get("name").?.string);
        const input = try allocator.dupe(u8, test_obj.object.get("input").?.string);

        var expected_tokens = std.ArrayList(types.Token).init(allocator);
        defer expected_tokens.deinit();

        const expected_array = test_obj.object.get("expected").?.array;

        for (expected_array.items) |token_obj| {
            const token = types.Token{
                .type = try allocator.dupe(u8, token_obj.object.get("type").?.string),
                .value = try allocator.dupe(u8, token_obj.object.get("value").?.string),
                .line = @intCast(token_obj.object.get("line").?.integer),
                .column = @intCast(token_obj.object.get("column").?.integer),
            };
            try expected_tokens.append(token);
        }

        const test_case = types.Test{
            .name = test_name,
            .input = input,
            .expected = try expected_tokens.toOwnedSlice(),
        };

        try tests.append(test_case);
    }

    return types.TestSuite{
        .version = version,
        .category = category,
        .description = description,
        .tests = try tests.toOwnedSlice(),
    };
}

const testing = std.testing;

test "Parse test file" {
    const allocator = testing.allocator;

    const suite = try parseTestFile(allocator, "spec/lexer/smoke_test.json");
    defer {
        // Free all allocated strings in tokens
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

    try testing.expectEqualStrings("1.0", suite.version);
    try testing.expectEqual(@as(usize, 2), suite.tests.len);
    try testing.expectEqualStrings("Simple date token", suite.tests[0].name);
}
