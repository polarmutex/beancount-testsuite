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
