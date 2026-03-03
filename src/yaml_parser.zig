const std = @import("std");
const yaml = @import("yaml");
const types = @import("types.zig");

pub fn parseTestFile(allocator: std.mem.Allocator, file_path: []const u8) !types.TestSuite {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    var yaml_doc = try yaml.Yaml.load(allocator, content);
    defer yaml_doc.deinit();

    const root = yaml_doc.docs.items[0].map;

    // Duplicate all strings since parsed object will be freed
    const version = try allocator.dupe(u8, root.get("version").?.string);
    const category = try allocator.dupe(u8, root.get("category").?.string);
    const description = try allocator.dupe(u8, root.get("description").?.string);

    var tests = std.ArrayList(types.Test).init(allocator);
    defer tests.deinit();

    const tests_list = root.get("tests").?.list;

    for (tests_list) |test_node| {
        const test_map = test_node.map;
        const test_name = try allocator.dupe(u8, test_map.get("name").?.string);
        const input = try allocator.dupe(u8, test_map.get("input").?.string);

        var expected_tokens = std.ArrayList(types.Token).init(allocator);
        defer expected_tokens.deinit();

        const expected_list = test_map.get("expected").?.list;

        for (expected_list) |token_node| {
            const token_map = token_node.map;
            const token = types.Token{
                .type = try allocator.dupe(u8, token_map.get("type").?.string),
                .value = try allocator.dupe(u8, token_map.get("value").?.string),
                .line = @intCast(token_map.get("line").?.int),
                .column = @intCast(token_map.get("column").?.int),
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

/// Parse an AST node from YAML representation
fn parseASTNode(allocator: std.mem.Allocator, node: yaml.Value) !types.ASTNode {
    const node_map = node.map;

    const node_type = try allocator.dupe(u8, node_map.get("node_type").?.string);

    var attributes = std.StringHashMap([]const u8).init(allocator);
    errdefer attributes.deinit();

    if (node_map.get("attributes")) |attrs_value| {
        const attrs_map = attrs_value.map;
        var iter = attrs_map.iterator();
        while (iter.next()) |entry| {
            const key = try allocator.dupe(u8, entry.key_ptr.*);
            const value = try allocator.dupe(u8, entry.value_ptr.*.string);
            try attributes.put(key, value);
        }
    }

    var children = std.ArrayList(types.ASTNode).init(allocator);
    defer children.deinit();

    if (node_map.get("children")) |children_value| {
        const children_list = children_value.list;
        for (children_list) |child_node| {
            const child = try parseASTNode(allocator, child_node);
            try children.append(child);
        }
    }

    return types.ASTNode{
        .node_type = node_type,
        .attributes = attributes,
        .children = try children.toOwnedSlice(),
    };
}

/// Free an ASTNode and all its children recursively
pub fn freeASTNode(allocator: std.mem.Allocator, node: types.ASTNode) void {
    // Free node_type
    allocator.free(node.node_type);

    // Free attributes
    var iter = node.attributes.iterator();
    while (iter.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    var attrs_copy = node.attributes;
    attrs_copy.deinit();

    // Free children recursively
    for (node.children) |child| {
        freeASTNode(allocator, child);
    }
    allocator.free(node.children);
}

/// Parse a parser test file (YAML) and return a ParserTestSuite
pub fn parseParserTestFile(allocator: std.mem.Allocator, file_path: []const u8) !types.ParserTestSuite {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    var yaml_doc = try yaml.Yaml.load(allocator, content);
    defer yaml_doc.deinit();

    const root = yaml_doc.docs.items[0].map;

    // Duplicate all strings since parsed object will be freed
    const version = try allocator.dupe(u8, root.get("version").?.string);
    const category = try allocator.dupe(u8, root.get("category").?.string);
    const description = try allocator.dupe(u8, root.get("description").?.string);

    var tests = std.ArrayList(types.ParserTest).init(allocator);
    defer tests.deinit();

    const tests_list = root.get("tests").?.list;

    for (tests_list) |test_node| {
        const test_map = test_node.map;
        const test_name = try allocator.dupe(u8, test_map.get("name").?.string);
        const input = try allocator.dupe(u8, test_map.get("input").?.string);

        // Parse expected_entries
        var expected_entries = std.ArrayList(types.ASTNode).init(allocator);
        defer expected_entries.deinit();

        if (test_map.get("expected_entries")) |entries_value| {
            const entries_list = entries_value.list;
            for (entries_list) |entry_node| {
                const ast_node = try parseASTNode(allocator, entry_node);
                try expected_entries.append(ast_node);
            }
        }

        // Parse expected_errors
        var expected_errors = std.ArrayList(types.ParserError).init(allocator);
        defer expected_errors.deinit();

        if (test_map.get("expected_errors")) |errors_value| {
            const errors_list = errors_value.list;
            for (errors_list) |error_node| {
                const error_map = error_node.map;
                const error_type = try allocator.dupe(u8, error_map.get("error_type").?.string);
                const message = try allocator.dupe(u8, error_map.get("message").?.string);
                const line: ?usize = if (error_map.get("line")) |line_value|
                    @intCast(line_value.int)
                else
                    null;

                const parser_error = types.ParserError{
                    .error_type = error_type,
                    .message = message,
                    .line = line,
                };
                try expected_errors.append(parser_error);
            }
        }

        const test_case = types.ParserTest{
            .name = test_name,
            .input = input,
            .expected_entries = try expected_entries.toOwnedSlice(),
            .expected_errors = try expected_errors.toOwnedSlice(),
        };

        try tests.append(test_case);
    }

    return types.ParserTestSuite{
        .version = version,
        .category = category,
        .description = description,
        .tests = try tests.toOwnedSlice(),
    };
}

const testing = std.testing;

test "Parse test file" {
    const allocator = testing.allocator;

    const suite = try parseTestFile(allocator, "spec/lexer/tokens_basic.yaml");
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
    try testing.expect(suite.tests.len > 0);
    try testing.expectEqualStrings("Keyword: txn", suite.tests[0].name);
}

test "Parse parser test file" {
    const allocator = testing.allocator;

    const suite = try parseParserTestFile(allocator, "spec/parser/test_minimal.yaml");
    defer {
        // Free all allocated strings and structures
        for (suite.tests) |test_case| {
            // Free expected_entries
            for (test_case.expected_entries) |entry| {
                freeASTNode(allocator, entry);
            }
            allocator.free(test_case.expected_entries);

            // Free expected_errors
            for (test_case.expected_errors) |err| {
                allocator.free(err.error_type);
                allocator.free(err.message);
            }
            allocator.free(test_case.expected_errors);

            allocator.free(test_case.name);
            allocator.free(test_case.input);
        }
        allocator.free(suite.tests);
        allocator.free(suite.version);
        allocator.free(suite.category);
        allocator.free(suite.description);
    }

    try testing.expectEqualStrings("1.0", suite.version);
    try testing.expectEqualStrings("parser", suite.category);
    try testing.expect(suite.tests.len > 0);
    try testing.expectEqualStrings("Open directive", suite.tests[0].name);

    // Verify the AST structure
    const first_test = suite.tests[0];
    try testing.expectEqual(@as(usize, 1), first_test.expected_entries.len);

    const open_node = first_test.expected_entries[0];
    try testing.expectEqualStrings("Open", open_node.node_type);
    try testing.expectEqual(@as(usize, 2), open_node.attributes.count());
    try testing.expectEqualStrings("2024-01-01", open_node.attributes.get("date").?);
    try testing.expectEqualStrings("Assets:Checking", open_node.attributes.get("account").?);

    // Verify children
    try testing.expectEqual(@as(usize, 1), open_node.children.len);
    const currency_node = open_node.children[0];
    try testing.expectEqualStrings("Currency", currency_node.node_type);
    try testing.expectEqualStrings("USD", currency_node.attributes.get("value").?);
    try testing.expectEqual(@as(usize, 0), currency_node.children.len);

    // Verify no errors expected
    try testing.expectEqual(@as(usize, 0), first_test.expected_errors.len);
}
