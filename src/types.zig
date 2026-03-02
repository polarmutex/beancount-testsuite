const std = @import("std");
const testing = std.testing;

pub const Token = struct {
    type: []const u8,
    value: []const u8,
    line: usize,
    column: usize,

    pub fn eql(self: Token, other: Token) bool {
        return std.mem.eql(u8, self.type, other.type) and
            std.mem.eql(u8, self.value, other.value) and
            self.line == other.line and
            self.column == other.column;
    }
};

test "Token equality" {
    const t1 = Token{
        .type = "DATE",
        .value = "2024-01-15",
        .line = 1,
        .column = 1,
    };
    const t2 = Token{
        .type = "DATE",
        .value = "2024-01-15",
        .line = 1,
        .column = 1,
    };
    const t3 = Token{
        .type = "NUMBER",
        .value = "123",
        .line = 1,
        .column = 1,
    };

    try testing.expect(t1.eql(t2));
    try testing.expect(!t1.eql(t3));
}

pub const Test = struct {
    name: []const u8,
    input: []const u8,
    expected: []const Token,
};

pub const TestSuite = struct {
    version: []const u8,
    category: []const u8,
    description: []const u8,
    tests: []const Test,
};

/// AST node representing a Beancount directive.
/// Memory ownership: Caller is responsible for:
/// - node_type string lifetime
/// - attributes HashMap (must call .deinit())
/// - children slice and nested ASTNode memory
pub const ASTNode = struct {
    node_type: []const u8,
    attributes: std.StringHashMap([]const u8),
    children: []const ASTNode,

    pub fn eql(self: ASTNode, other: ASTNode) bool {
        // Check node type
        if (!std.mem.eql(u8, self.node_type, other.node_type)) {
            return false;
        }

        // Check attribute count
        if (self.attributes.count() != other.attributes.count()) {
            return false;
        }

        // Check all attributes match
        var iter = self.attributes.iterator();
        while (iter.next()) |entry| {
            const other_value = other.attributes.get(entry.key_ptr.*) orelse return false;
            if (!std.mem.eql(u8, entry.value_ptr.*, other_value)) {
                return false;
            }
        }

        // Check children count
        if (self.children.len != other.children.len) {
            return false;
        }

        // Recursively check children
        for (self.children, other.children) |child_self, child_other| {
            if (!child_self.eql(child_other)) {
                return false;
            }
        }

        return true;
    }
};

pub const ParserError = struct {
    error_type: []const u8,
    message: []const u8,
    line: ?usize,
};

pub const ParserTest = struct {
    name: []const u8,
    input: []const u8,
    expected_entries: []const ASTNode,
    expected_errors: []const ParserError,
};

pub const TestCase = union(enum) {
    lexer: Test,
    parser: ParserTest,
};

pub const TestSuiteType = union(enum) {
    lexer: TestSuite,
    parser: ParserTestSuite,
};

pub const ParserTestSuite = struct {
    version: []const u8,
    category: []const u8,
    description: []const u8,
    tests: []const ParserTest,
};

test "Test struct creation" {
    const tokens = [_]Token{
        Token{
            .type = "DATE",
            .value = "2024-01-15",
            .line = 1,
            .column = 1,
        },
    };

    const test_case = Test{
        .name = "Simple date",
        .input = "2024-01-15",
        .expected = &tokens,
    };

    try testing.expectEqualStrings("Simple date", test_case.name);
    try testing.expectEqual(@as(usize, 1), test_case.expected.len);
}

test "ASTNode equality - simple nodes" {
    var attr_map1 = std.StringHashMap([]const u8).init(testing.allocator);
    defer attr_map1.deinit();
    try attr_map1.put("date", "2024-01-01");
    try attr_map1.put("account", "Assets:Checking");

    var attr_map2 = std.StringHashMap([]const u8).init(testing.allocator);
    defer attr_map2.deinit();
    try attr_map2.put("date", "2024-01-01");
    try attr_map2.put("account", "Assets:Checking");

    const node1 = ASTNode{
        .node_type = "Open",
        .attributes = attr_map1,
        .children = &[_]ASTNode{},
    };

    const node2 = ASTNode{
        .node_type = "Open",
        .attributes = attr_map2,
        .children = &[_]ASTNode{},
    };

    try testing.expect(node1.eql(node2));
}

test "ASTNode equality - different node types" {
    var attr_map1 = std.StringHashMap([]const u8).init(testing.allocator);
    defer attr_map1.deinit();

    var attr_map2 = std.StringHashMap([]const u8).init(testing.allocator);
    defer attr_map2.deinit();

    const node1 = ASTNode{
        .node_type = "Open",
        .attributes = attr_map1,
        .children = &[_]ASTNode{},
    };

    const node2 = ASTNode{
        .node_type = "Close",
        .attributes = attr_map2,
        .children = &[_]ASTNode{},
    };

    try testing.expect(!node1.eql(node2));
}

test "ASTNode equality - with children" {
    const allocator = testing.allocator;

    // Create child nodes
    var child1_attrs = std.StringHashMap([]const u8).init(allocator);
    defer child1_attrs.deinit();
    try child1_attrs.put("value", "USD");

    var child2_attrs = std.StringHashMap([]const u8).init(allocator);
    defer child2_attrs.deinit();
    try child2_attrs.put("value", "USD");

    const child1 = ASTNode{
        .node_type = "Currency",
        .attributes = child1_attrs,
        .children = &[_]ASTNode{},
    };

    const child2 = ASTNode{
        .node_type = "Currency",
        .attributes = child2_attrs,
        .children = &[_]ASTNode{},
    };

    // Create parent nodes with children
    var parent1_attrs = std.StringHashMap([]const u8).init(allocator);
    defer parent1_attrs.deinit();
    try parent1_attrs.put("account", "Assets:Checking");

    var parent2_attrs = std.StringHashMap([]const u8).init(allocator);
    defer parent2_attrs.deinit();
    try parent2_attrs.put("account", "Assets:Checking");

    var children1 = [_]ASTNode{child1};
    var children2 = [_]ASTNode{child2};

    const parent1 = ASTNode{
        .node_type = "Open",
        .attributes = parent1_attrs,
        .children = &children1,
    };

    const parent2 = ASTNode{
        .node_type = "Open",
        .attributes = parent2_attrs,
        .children = &children2,
    };

    try testing.expect(parent1.eql(parent2));
}

test "ParserError creation" {
    const err = ParserError{
        .error_type = "DuplicateError",
        .message = ".*already.*opened",
        .line = 2,
    };

    try testing.expectEqualStrings("DuplicateError", err.error_type);
    try testing.expectEqualStrings(".*already.*opened", err.message);
    try testing.expectEqual(@as(usize, 2), err.line.?);
}
