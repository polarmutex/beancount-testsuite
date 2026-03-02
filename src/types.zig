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

pub const ASTNode = struct {
    node_type: []const u8,
    attributes: std.StringHashMap([]const u8),
    children: []const ASTNode,

    pub fn eql(self: ASTNode, other: ASTNode, allocator: std.mem.Allocator) !bool {
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
            if (!try child_self.eql(child_other, allocator)) {
                return false;
            }
        }

        return true;
    }
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

    try testing.expect(try node1.eql(node2, testing.allocator));
}

test "ASTNode equality - different node types" {
    var attr_map = std.StringHashMap([]const u8).init(testing.allocator);
    defer attr_map.deinit();

    const node1 = ASTNode{
        .node_type = "Open",
        .attributes = attr_map,
        .children = &[_]ASTNode{},
    };

    const node2 = ASTNode{
        .node_type = "Close",
        .attributes = attr_map,
        .children = &[_]ASTNode{},
    };

    try testing.expect(!try node1.eql(node2, testing.allocator));
}
