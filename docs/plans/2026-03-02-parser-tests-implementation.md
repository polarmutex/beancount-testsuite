# Parser Test Suite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add comprehensive parser testing to the Beancount test suite, extending the existing lexer infrastructure to validate AST structure and semantic errors.

**Architecture:** Extend types.zig with AST nodes, update yaml_parser.zig to handle both test types, refactor bridge to unified mode-based design, extend reporter for AST diffs, create 6 minimal parser test files.

**Tech Stack:** Zig, Python (Beancount parser), YAML, JSON protocol

---

## Phase 1: Type System Extensions

### Task 1: Add Parser Types to types.zig

**Files:**
- Modify: `src/types.zig:74-end`

**Step 1: Write test for ASTNode equality**

Add after existing tests in `src/types.zig`:

```zig
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
```

**Step 2: Run test to verify it fails**

Run: `zig build test`
Expected: Compilation error "ASTNode not defined"

**Step 3: Add ASTNode struct**

Add after the `TestSuite` struct definition:

```zig
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
```

**Step 4: Run test to verify it passes**

Run: `zig build test`
Expected: PASS - "ASTNode equality" tests succeed

**Step 5: Commit**

```bash
git add src/types.zig
git commit -m "feat(types): add ASTNode struct with equality comparison

Add recursive AST node structure for parser tests:
- node_type for directive type
- attributes hashmap for key-value pairs
- children array for nested nodes
- deep equality comparison

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Add ParserTest and ParserError Types

**Files:**
- Modify: `src/types.zig:end`

**Step 1: Write test for ParserError**

Add to `src/types.zig` tests:

```zig
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
```

**Step 2: Run test to verify it fails**

Run: `zig build test`
Expected: Compilation error "ParserError not defined"

**Step 3: Add ParserError and ParserTest structs**

Add after `ASTNode`:

```zig
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
```

**Step 4: Run test to verify it passes**

Run: `zig build test`
Expected: PASS

**Step 5: Add TestCase union**

Add after `ParserTest`:

```zig
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
```

**Step 6: Commit**

```bash
git add src/types.zig
git commit -m "feat(types): add ParserTest and ParserError types

Add parser test structures:
- ParserError for error expectations
- ParserTest for test cases
- TestCase union for type discrimination
- ParserTestSuite for parser test files

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 2: YAML Parser Extension

### Task 3: Add Parser Test YAML Parsing

**Files:**
- Modify: `src/yaml_parser.zig:64-end`

**Step 1: Write test for parsing parser YAML**

Create test file: `spec/parser/test_minimal.yaml`

```yaml
version: "1.0"
category: "parser/test"
description: "Minimal parser test"

tests:
  - name: "Simple test"
    input: "2024-01-01 open Assets:Checking"
    expected_entries:
      - node_type: "Open"
        attributes:
          date: "2024-01-01"
          account: "Assets:Checking"
        children: []
    expected_errors: []
```

Add test to `src/yaml_parser.zig`:

```zig
test "Parse parser test file" {
    const allocator = testing.allocator;

    const suite = try parseParserTestFile(allocator, "spec/parser/test_minimal.yaml");
    defer {
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
    try testing.expectEqualStrings("parser/test", suite.category);
    try testing.expect(suite.tests.len == 1);
}

fn freeASTNode(allocator: std.mem.Allocator, node: types.ASTNode) void {
    allocator.free(node.node_type);

    var iter = node.attributes.iterator();
    while (iter.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    node.attributes.deinit();

    for (node.children) |child| {
        freeASTNode(allocator, child);
    }
    allocator.free(node.children);
}
```

**Step 2: Run test to verify it fails**

Run: `zig build test 2>&1 | head -20`
Expected: Compilation error "parseParserTestFile not defined"

**Step 3: Implement parseParserTestFile**

Add after `parseTestFile`:

```zig
pub fn parseParserTestFile(allocator: std.mem.Allocator, file_path: []const u8) !types.ParserTestSuite {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    var yaml_doc = try yaml.Yaml.load(allocator, content);
    defer yaml_doc.deinit();

    const root = yaml_doc.docs.items[0].map;

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

        const entries_list = test_map.get("expected_entries").?.list;
        for (entries_list) |entry_node| {
            const ast_node = try parseASTNode(allocator, entry_node);
            try expected_entries.append(ast_node);
        }

        // Parse expected_errors
        var expected_errors = std.ArrayList(types.ParserError).init(allocator);
        defer expected_errors.deinit();

        const errors_list = test_map.get("expected_errors").?.list;
        for (errors_list) |error_node| {
            const error_map = error_node.map;
            const parser_error = types.ParserError{
                .error_type = try allocator.dupe(u8, error_map.get("error_type").?.string),
                .message = try allocator.dupe(u8, error_map.get("message").?.string),
                .line = if (error_map.get("line")) |line_val| @as(?usize, @intCast(line_val.int)) else null,
            };
            try expected_errors.append(parser_error);
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

fn parseASTNode(allocator: std.mem.Allocator, node: yaml.Node) !types.ASTNode {
    const node_map = node.map;

    const node_type = try allocator.dupe(u8, node_map.get("node_type").?.string);

    // Parse attributes
    var attributes = std.StringHashMap([]const u8).init(allocator);
    const attrs_map = node_map.get("attributes").?.map;
    var attrs_iter = attrs_map.iterator();
    while (attrs_iter.next()) |entry| {
        const key = try allocator.dupe(u8, entry.key_ptr.*);
        const value = try allocator.dupe(u8, entry.value_ptr.*.string);
        try attributes.put(key, value);
    }

    // Parse children
    var children = std.ArrayList(types.ASTNode).init(allocator);
    defer children.deinit();

    const children_list = node_map.get("children").?.list;
    for (children_list) |child_node| {
        const child = try parseASTNode(allocator, child_node);
        try children.append(child);
    }

    return types.ASTNode{
        .node_type = node_type,
        .attributes = attributes,
        .children = try children.toOwnedSlice(),
    };
}
```

**Step 4: Run test to verify it passes**

Run: `zig build test 2>&1 | grep -A5 "Parse parser test file"`
Expected: PASS

**Step 5: Commit**

```bash
git add src/yaml_parser.zig spec/parser/test_minimal.yaml
git commit -m "feat(yaml_parser): add parser test file parsing

Implement parseParserTestFile for parser YAML:
- Parse expected_entries as AST nodes
- Parse expected_errors with regex patterns
- Recursive parseASTNode for nested structures
- Memory management for attributes hashmap

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 3: Python Bridge Refactoring

### Task 4: Rename and Add Mode Parameter to Bridge

**Files:**
- Rename: `bridge/lexer_bridge.py` → `bridge/bridge.py`
- Modify: `bridge/bridge.py:1-end`

**Step 1: Test bridge with --mode parameter**

Create test script: `bridge/test_bridge.sh`

```bash
#!/bin/bash
# Test that bridge accepts --mode parameter

echo '{"input": "txn"}' | python bridge/bridge.py --mode lexer | jq -e '.tokens'
if [ $? -eq 0 ]; then
    echo "✓ Lexer mode works"
else
    echo "✗ Lexer mode failed"
    exit 1
fi

echo "Test will fail until bridge.py supports --mode"
```

Run: `chmod +x bridge/test_bridge.sh && ./bridge/test_bridge.sh`
Expected: FAIL - "error: unrecognized arguments: --mode lexer"

**Step 2: Rename file**

```bash
git mv bridge/lexer_bridge.py bridge/bridge.py
```

**Step 3: Add argparse and mode parameter**

Modify `bridge/bridge.py` - change the `main()` function:

```python
def main():
    """Read JSON requests from stdin, tokenize, write JSON responses to stdout."""
    from argparse import ArgumentParser

    parser = ArgumentParser(description='Beancount test bridge')
    parser.add_argument('--mode', choices=['lexer', 'parser'], required=True,
                       help='Bridge mode: lexer or parser')
    args = parser.parse_args()

    for line in sys.stdin:
        try:
            request = json.loads(line)
            input_text = request.get("input", "")

            if args.mode == 'lexer':
                response = tokenize_with_beancount(input_text)
            else:
                response = {"error": "NotImplemented", "message": "Parser mode not yet implemented"}

            print(json.dumps(response))
            sys.stdout.flush()

        except json.JSONDecodeError as e:
            error_response = {
                "error": "JSONDecodeError",
                "message": "Invalid JSON in request",
                "details": str(e)
            }
            print(json.dumps(error_response))
            sys.stdout.flush()
        except Exception as e:
            error_response = {
                "error": "BridgeError",
                "message": str(e),
                "details": str(type(e).__name__)
            }
            print(json.dumps(error_response))
            sys.stdout.flush()
```

**Step 4: Run test to verify it passes**

Run: `./bridge/test_bridge.sh`
Expected: PASS - "✓ Lexer mode works"

**Step 5: Commit**

```bash
git add bridge/bridge.py bridge/test_bridge.sh
git commit -m "refactor(bridge): rename to bridge.py and add mode parameter

Unified bridge with mode selection:
- Add argparse for --mode lexer|parser
- Preserve existing lexer functionality
- Stub parser mode for next task

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Implement Parser Mode in Bridge

**Files:**
- Modify: `bridge/bridge.py:10-end`

**Step 1: Write test for parser mode**

Add to `bridge/test_bridge.sh`:

```bash
# Test parser mode
echo '{"input": "2024-01-01 open Assets:Checking"}' | python bridge/bridge.py --mode parser | jq -e '.entries[0].node_type == "Open"'
if [ $? -eq 0 ]; then
    echo "✓ Parser mode works"
else
    echo "✗ Parser mode failed"
    exit 1
fi
```

Run: `./bridge/test_bridge.sh`
Expected: FAIL - Parser mode returns NotImplemented error

**Step 2: Implement parser_mode function**

Add before `main()` in `bridge/bridge.py`:

```python
def parser_mode(input_text):
    """Parse input using Beancount parser."""
    try:
        from beancount.parser import parser

        # Parse as complete file
        entries, errors, options = parser.parse_string(input_text)

        # Serialize entries
        serialized_entries = [serialize_entry(e) for e in entries]

        # Serialize errors
        serialized_errors = [serialize_error(e) for e in errors]

        return {
            "entries": serialized_entries,
            "errors": serialized_errors
        }

    except ImportError as e:
        return {
            "error": "ImportError",
            "message": "Failed to import beancount.parser",
            "details": str(e)
        }
    except Exception as e:
        return {
            "error": "ParserError",
            "message": str(e),
            "details": str(type(e).__name__)
        }


def serialize_entry(entry):
    """Convert Beancount directive to AST node dict."""
    node = {
        "node_type": entry.__class__.__name__,
        "attributes": {},
        "children": []
    }

    # Extract attributes from named tuple fields
    for field in entry._fields:
        value = getattr(entry, field)

        # Skip None, lists, tuples (these become children or are ignored)
        if value is None or isinstance(value, (list, tuple)):
            continue

        # Convert everything to string
        node["attributes"][field] = str(value)

    # Handle postings as children (for Transaction directives)
    if hasattr(entry, 'postings') and entry.postings:
        node["children"] = [serialize_posting(p) for p in entry.postings]

    # Handle currencies as children (for Open directives)
    if hasattr(entry, 'currencies') and entry.currencies:
        node["children"] = [{"node_type": "Currency", "attributes": {"value": c}, "children": []}
                           for c in entry.currencies]

    return node


def serialize_posting(posting):
    """Convert posting to AST node."""
    attributes = {
        "account": str(posting.account),
    }

    # Add units (amount) if present
    if posting.units:
        attributes["amount"] = str(posting.units)

    return {
        "node_type": "Posting",
        "attributes": attributes,
        "children": []
    }


def serialize_error(error):
    """Convert Beancount error to error dict."""
    line = None
    if hasattr(error, 'source') and error.source:
        line = error.source.get('lineno')

    return {
        "error_type": error.__class__.__name__,
        "message": str(error.message),
        "line": line
    }
```

**Step 3: Update main() to use parser_mode**

Update the mode dispatch in `main()`:

```python
if args.mode == 'lexer':
    response = tokenize_with_beancount(input_text)
else:
    response = parser_mode(input_text)
```

**Step 4: Run test to verify it passes**

Run: `./bridge/test_bridge.sh`
Expected: PASS - "✓ Parser mode works"

**Step 5: Manual validation test**

```bash
echo '{"input": "2024-01-01 open Assets:Checking USD"}' | python bridge/bridge.py --mode parser | jq '.'
```

Expected output:
```json
{
  "entries": [
    {
      "node_type": "Open",
      "attributes": {
        "date": "2024-01-01",
        "account": "Assets:Checking"
      },
      "children": [
        {
          "node_type": "Currency",
          "attributes": {"value": "USD"},
          "children": []
        }
      ]
    }
  ],
  "errors": []
}
```

**Step 6: Commit**

```bash
git add bridge/bridge.py bridge/test_bridge.sh
git commit -m "feat(bridge): implement parser mode

Add Beancount parser integration:
- parser_mode() using parse_string()
- serialize_entry() for AST conversion
- serialize_posting() for transaction postings
- serialize_error() for error objects
- All types converted to strings

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 4: Runner and Reporter Extensions

### Task 6: Update Bridge Module for Mode Parameter

**Files:**
- Modify: `src/bridge.zig:1-end`

**Step 1: Read current bridge.zig implementation**

```bash
cat src/bridge.zig | head -50
```

**Step 2: Update spawnBridge to accept mode parameter**

Modify the `Bridge.init()` or spawn method to accept mode:

```zig
pub fn init(allocator: std.mem.Allocator, bridge_path: []const u8, mode: []const u8) !Bridge {
    const argv = [_][]const u8{ "python3", bridge_path, "--mode", mode };

    var child = std.process.Child.init(&argv, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    return Bridge{
        .allocator = allocator,
        .process = child,
    };
}
```

**Step 3: Update callers in runner.zig**

Will update in next task - this is infrastructure change only.

**Step 4: Commit**

```bash
git add src/bridge.zig
git commit -m "feat(bridge): add mode parameter to init

Support --mode parameter for unified bridge:
- Accept mode as parameter
- Pass to Python bridge process
- Enables lexer/parser mode selection

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 7: Extend Reporter for Parser Tests

**Files:**
- Modify: `src/reporter.zig:1-end`

**Step 1: Write test for AST diff formatting**

Add test to `src/reporter.zig`:

```zig
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
```

**Step 2: Run test to verify it fails**

Run: `zig build test 2>&1 | grep "ParserTestResult"`
Expected: Compilation error "ParserTestResult not defined"

**Step 3: Add ParserTestResult struct**

Add to `src/reporter.zig` before the Reporter struct:

```zig
pub const ParserTestResult = struct {
    test_name: []const u8,
    passed: bool,
    expected_entries: []const types.ASTNode,
    actual_entries: []const types.ASTNode,
    expected_errors: []const types.ParserError,
    actual_errors: []const types.ParserError,
    error_message: ?[]const u8,
};
```

**Step 4: Implement reportParserResult**

Add method to Reporter:

```zig
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
```

**Step 5: Run test to verify it passes**

Run: `zig build test 2>&1 | grep -A3 "parser test failure"`
Expected: PASS

**Step 6: Commit**

```bash
git add src/reporter.zig
git commit -m "feat(reporter): add parser test result formatting

Add AST diff reporting:
- ParserTestResult struct
- reportParserResult() method
- Entry count mismatch formatting
- Error count mismatch formatting
- Summary of expected vs actual entries

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 5: Minimal Parser Test Files

### Task 8: Create spec/parser Directory and Test Files

**Files:**
- Create: `spec/parser/open_close.yaml`
- Create: `spec/parser/transactions.yaml`
- Create: `spec/parser/balance_pad.yaml`
- Create: `spec/parser/price_note.yaml`
- Create: `spec/parser/metadata.yaml`
- Create: `spec/parser/options.yaml`

**Step 1: Create directory**

```bash
mkdir -p spec/parser
```

**Step 2: Create open_close.yaml with minimal tests**

Create `spec/parser/open_close.yaml`:

```yaml
version: "1.0"
category: "parser/open_close"
description: "Open and close directive parsing"

tests:
  - name: "Simple open directive"
    input: "2024-01-01 open Assets:Checking"
    expected_entries:
      - node_type: "Open"
        attributes:
          date: "2024-01-01"
          account: "Assets:Checking"
        children: []
    expected_errors: []

  - name: "Open with currency"
    input: "2024-01-01 open Assets:Checking USD"
    expected_entries:
      - node_type: "Open"
        attributes:
          date: "2024-01-01"
          account: "Assets:Checking"
        children:
          - node_type: "Currency"
            attributes:
              value: "USD"
            children: []
    expected_errors: []

  - name: "Simple close directive"
    input: "2024-12-31 close Assets:Checking"
    expected_entries:
      - node_type: "Close"
        attributes:
          date: "2024-12-31"
          account: "Assets:Checking"
        children: []
    expected_errors: []
```

**Step 3: Create transactions.yaml with minimal tests**

Create `spec/parser/transactions.yaml`:

```yaml
version: "1.0"
category: "parser/transactions"
description: "Transaction directive parsing"

tests:
  - name: "Simple transaction"
    input: |
      2024-01-15 * "Coffee"
        Expenses:Coffee   5.00 USD
        Assets:Cash
    expected_entries:
      - node_type: "Transaction"
        attributes:
          date: "2024-01-15"
          flag: "*"
          narration: "Coffee"
        children:
          - node_type: "Posting"
            attributes:
              account: "Expenses:Coffee"
              amount: "5.00 USD"
            children: []
          - node_type: "Posting"
            attributes:
              account: "Assets:Cash"
            children: []
    expected_errors: []

  - name: "Transaction with payee"
    input: |
      2024-01-15 * "Cafe" "Coffee"
        Expenses:Coffee   5.00 USD
        Assets:Cash
    expected_entries:
      - node_type: "Transaction"
        attributes:
          date: "2024-01-15"
          flag: "*"
          payee: "Cafe"
          narration: "Coffee"
        children:
          - node_type: "Posting"
            attributes:
              account: "Expenses:Coffee"
              amount: "5.00 USD"
            children: []
          - node_type: "Posting"
            attributes:
              account: "Assets:Cash"
            children: []
    expected_errors: []

  - name: "Transaction with flag"
    input: |
      2024-01-15 ! "Pending coffee"
        Expenses:Coffee   5.00 USD
        Assets:Cash
    expected_entries:
      - node_type: "Transaction"
        attributes:
          date: "2024-01-15"
          flag: "!"
          narration: "Pending coffee"
        children:
          - node_type: "Posting"
            attributes:
              account: "Expenses:Coffee"
              amount: "5.00 USD"
            children: []
          - node_type: "Posting"
            attributes:
              account: "Assets:Cash"
            children: []
    expected_errors: []
```

**Step 4: Create balance_pad.yaml**

Create `spec/parser/balance_pad.yaml`:

```yaml
version: "1.0"
category: "parser/balance_pad"
description: "Balance and pad directive parsing"

tests:
  - name: "Simple balance assertion"
    input: "2024-01-15 balance Assets:Checking 100.00 USD"
    expected_entries:
      - node_type: "Balance"
        attributes:
          date: "2024-01-15"
          account: "Assets:Checking"
          amount: "100.00 USD"
        children: []
    expected_errors: []

  - name: "Simple pad directive"
    input: "2024-01-15 pad Assets:Checking Equity:Opening-Balances"
    expected_entries:
      - node_type: "Pad"
        attributes:
          date: "2024-01-15"
          account: "Assets:Checking"
          source_account: "Equity:Opening-Balances"
        children: []
    expected_errors: []
```

**Step 5: Create price_note.yaml**

Create `spec/parser/price_note.yaml`:

```yaml
version: "1.0"
category: "parser/price_note"
description: "Price, note, and document directive parsing"

tests:
  - name: "Simple price directive"
    input: "2024-01-15 price USD 1.35 CAD"
    expected_entries:
      - node_type: "Price"
        attributes:
          date: "2024-01-15"
          currency: "USD"
          amount: "1.35 CAD"
        children: []
    expected_errors: []

  - name: "Simple note directive"
    input: '2024-01-15 note Assets:Checking "Account opened"'
    expected_entries:
      - node_type: "Note"
        attributes:
          date: "2024-01-15"
          account: "Assets:Checking"
          comment: "Account opened"
        children: []
    expected_errors: []

  - name: "Simple document directive"
    input: '2024-01-15 document Assets:Checking "/path/to/statement.pdf"'
    expected_entries:
      - node_type: "Document"
        attributes:
          date: "2024-01-15"
          account: "Assets:Checking"
          filename: "/path/to/statement.pdf"
        children: []
    expected_errors: []
```

**Step 6: Create metadata.yaml**

Create `spec/parser/metadata.yaml`:

```yaml
version: "1.0"
category: "parser/metadata"
description: "Metadata stack directive parsing"

tests:
  - name: "Simple pushtag"
    input: "pushtag #trip-2024"
    expected_entries:
      - node_type: "PushTag"
        attributes:
          tag: "#trip-2024"
        children: []
    expected_errors: []

  - name: "Simple poptag"
    input: "poptag #trip-2024"
    expected_entries:
      - node_type: "PopTag"
        attributes:
          tag: "#trip-2024"
        children: []
    expected_errors: []
```

**Step 7: Create options.yaml**

Create `spec/parser/options.yaml`:

```yaml
version: "1.0"
category: "parser/options"
description: "Configuration directive parsing"

tests:
  - name: "Simple option directive"
    input: 'option "title" "My Ledger"'
    expected_entries:
      - node_type: "Option"
        attributes:
          key: "title"
          value: "My Ledger"
        children: []
    expected_errors: []

  - name: "Simple plugin directive"
    input: 'plugin "beancount.plugins.check_closing"'
    expected_entries:
      - node_type: "Plugin"
        attributes:
          name: "beancount.plugins.check_closing"
        children: []
    expected_errors: []

  - name: "Simple include directive"
    input: 'include "accounts.beancount"'
    expected_entries:
      - node_type: "Include"
        attributes:
          filename: "accounts.beancount"
        children: []
    expected_errors: []
```

**Step 8: Commit all test files**

```bash
git add spec/parser/
git commit -m "feat(spec): add minimal parser test files

Create 6 parser test files with minimal coverage:
- open_close.yaml: 3 tests
- transactions.yaml: 3 tests
- balance_pad.yaml: 2 tests
- price_note.yaml: 3 tests
- metadata.yaml: 2 tests
- options.yaml: 3 tests

Total: 16 minimal bootstrap tests

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 6: Integration and End-to-End Testing

### Task 9: Update Main to Support Parser Tests

**Files:**
- Modify: `src/main.zig:1-end`

**Step 1: Update main to detect test type and route appropriately**

This requires understanding category field and spawning bridge with correct mode.

Modify the main function to:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    // For now, hardcode parser test file
    const test_file = "spec/parser/open_close.yaml";

    // Detect test type from file path
    const is_parser_test = std.mem.indexOf(u8, test_file, "parser/") != null;

    if (is_parser_test) {
        try runParserTests(allocator, test_file, stdout);
    } else {
        try runLexerTests(allocator, test_file, stdout);
    }
}

fn runLexerTests(allocator: std.mem.Allocator, test_file: []const u8, stdout: anytype) !void {
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

    var runner = try runner_mod.Runner.init(allocator, "bridge/bridge.py", "lexer");
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

fn runParserTests(allocator: std.mem.Allocator, test_file: []const u8, stdout: anytype) !void {
    // Parse parser test file
    const suite = try yaml_parser.parseParserTestFile(allocator, test_file);
    defer {
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

    try stdout.print("Running parser test suite: {s}\n", .{suite.description});
    try stdout.print("Category: {s}\n\n", .{suite.category});

    // For now, just print test count - full runner integration next
    try stdout.print("Loaded {} parser tests\n", .{suite.tests.len});
}

fn freeASTNode(allocator: std.mem.Allocator, node: types.ASTNode) void {
    allocator.free(node.node_type);

    var iter = node.attributes.iterator();
    while (iter.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    node.attributes.deinit();

    for (node.children) |child| {
        freeASTNode(allocator, child);
    }
    allocator.free(node.children);
}
```

**Step 2: Test parser file loading**

```bash
zig build run
```

Expected output:
```
Running parser test suite: Open and close directive parsing
Category: parser/open_close

Loaded 3 parser tests
```

**Step 3: Commit**

```bash
git add src/main.zig
git commit -m "feat(main): add parser test file detection and loading

Add runParserTests function:
- Detect parser vs lexer tests from file path
- Load and parse parser test files
- Memory management for AST nodes
- Bootstrap validation of parser test loading

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 10: Run End-to-End Parser Test

**Files:**
- Modify: `src/main.zig` (complete parser test execution)
- Modify: `src/runner.zig` (add parser test execution)

**Step 1: Extend Runner for parser tests**

This requires adding parser-specific test execution to runner.zig.

Note: This is a complex task that integrates bridge communication, JSON deserialization, and AST comparison. Break into substeps if needed during actual implementation.

**Step 2: Wire up complete flow**

Update `runParserTests` in main.zig to use runner for execution.

**Step 3: Test with minimal parser tests**

```bash
zig build run
```

Expected: Should execute all 3 open_close.yaml tests and report results.

**Step 4: Verify backward compatibility**

```bash
# Test that lexer tests still work
zig build run -- spec/lexer/tokens_basic.yaml
```

Expected: All lexer tests pass as before.

**Step 5: Commit**

```bash
git add src/runner.zig src/main.zig
git commit -m "feat: complete parser test execution pipeline

Wire up end-to-end parser testing:
- Runner executes parser tests via bridge
- JSON deserialization of entries and errors
- AST comparison and validation
- Reporter shows parser test results
- Backward compatible with lexer tests

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 7: Documentation and Finalization

### Task 11: Update README and Documentation

**Files:**
- Modify: `README.md`
- Create: `docs/WRITING_PARSER_TESTS.md`

**Step 1: Update README with parser test information**

Add section to README.md:

```markdown
## Parser Tests

Parser tests validate Beancount's parser behavior, including:
- AST structure for all directive types
- Semantic error detection
- Multi-directive files

### Running Parser Tests

```bash
# Run all parser tests
zig build run -- spec/parser/*.yaml

# Run specific parser test file
zig build run -- spec/parser/transactions.yaml
```

### Parser Test Format

Parser tests use YAML with expected AST nodes and errors:

```yaml
version: "1.0"
category: "parser/open_close"
tests:
  - name: "Simple open"
    input: "2024-01-01 open Assets:Checking"
    expected_entries:
      - node_type: "Open"
        attributes:
          date: "2024-01-01"
          account: "Assets:Checking"
        children: []
    expected_errors: []
```

See `docs/WRITING_PARSER_TESTS.md` for complete guide.
```

**Step 2: Create parser test writing guide**

Create `docs/WRITING_PARSER_TESTS.md` with comprehensive examples and best practices.

**Step 3: Commit documentation**

```bash
git add README.md docs/WRITING_PARSER_TESTS.md
git commit -m "docs: add parser test documentation

Add comprehensive parser test documentation:
- README section for parser tests
- WRITING_PARSER_TESTS.md guide
- YAML schema examples
- Best practices for test writing

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Success Criteria Checklist

After completing all tasks, verify:

- [ ] All existing lexer tests still pass
- [ ] All 16 minimal parser tests pass
- [ ] `zig build test` passes all unit tests
- [ ] Bridge works in both lexer and parser modes
- [ ] Reporter formats parser failures clearly
- [ ] Documentation is complete and accurate
- [ ] Git history shows incremental, logical commits

## Next Steps

After this plan is complete:

1. **Expand Parser Tests**: Add comprehensive coverage (~94 tests) to each file
2. **Add Error Tests**: Create tests for semantic validation errors
3. **CI/CD Integration**: Update GitHub Actions to run parser tests
4. **Performance Optimization**: Profile and optimize if needed

---

**Implementation Strategy**: Execute this plan task-by-task using TDD approach. Each task follows: test → fail → implement → pass → commit cycle.
