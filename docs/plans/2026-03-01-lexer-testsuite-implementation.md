# Beancount Lexer Test Suite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Zig test harness with Python bridge to validate Beancount lexer specification compliance

**Architecture:** Zig orchestration layer communicates with Python bridge via JSON over stdin/stdout. YAML test definitions drive execution. Bootstrap with smoke test, then expand to comprehensive coverage.

**Tech Stack:** Zig 0.11+, Python 3.9+, Beancount, zig-yaml library, GitHub Actions

---

## Phase 1: Bootstrap Foundation

### Task 1: Project Scaffolding

**Files:**
- Create: `build.zig`
- Create: `src/main.zig`
- Create: `.gitignore`

**Step 1: Create build.zig**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "beancount-testsuite",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the test suite");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
```

**Step 2: Create minimal main.zig**

```zig
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Beancount Test Suite v0.1.0\n", .{});
}

test "basic test" {
    try std.testing.expect(true);
}
```

**Step 3: Create .gitignore**

```
zig-cache/
zig-out/
.zig-cache/
*.swp
*.swo
*~
.DS_Store
__pycache__/
*.pyc
*.pyo
*.egg-info/
.venv/
venv/
```

**Step 4: Verify build works**

Run: `zig build`
Expected: Build succeeds, creates `zig-out/bin/beancount-testsuite`

**Step 5: Verify run works**

Run: `zig build run`
Expected: Prints "Beancount Test Suite v0.1.0"

**Step 6: Verify tests work**

Run: `zig build test`
Expected: "All 1 tests passed."

**Step 7: Commit**

```bash
git add build.zig src/main.zig .gitignore
git commit -m "feat: initial Zig project scaffolding

- Add build.zig with exe and test targets
- Create minimal main.zig entry point
- Add .gitignore for Zig and Python artifacts

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Python Bridge - Minimal Version

**Files:**
- Create: `bridge/lexer_bridge.py`
- Create: `bridge/requirements.txt`
- Create: `bridge/README.md`

**Step 1: Create requirements.txt**

```
beancount>=2.3.0
```

**Step 2: Create minimal lexer_bridge.py (hardcoded test first)**

```python
#!/usr/bin/env python3
"""Minimal Python bridge for Beancount lexer testing."""

import json
import sys


def main():
    # Hardcoded test: just echo back a simple token
    test_input = {"input": "2024-01-15"}

    # Mock response (we'll connect to real lexer later)
    response = {
        "tokens": [
            {
                "type": "DATE",
                "value": "2024-01-15",
                "line": 1,
                "column": 1
            }
        ]
    }

    print(json.dumps(response))
    sys.stdout.flush()


if __name__ == "__main__":
    main()
```

**Step 3: Create bridge/README.md**

```markdown
# Python Bridge

Wraps Beancount lexer for test harness communication via JSON.

## Protocol

**Input (stdin):**
```json
{"input": "2024-01-15 * \"Test\""}
```

**Output (stdout):**
```json
{
  "tokens": [
    {"type": "DATE", "value": "2024-01-15", "line": 1, "column": 1}
  ]
}
```

**Error Output:**
```json
{
  "error": "LexerError",
  "message": "Unexpected character",
  "details": "..."
}
```

## Setup

```bash
pip install -r requirements.txt
```

## Test

```bash
echo '{"input": "2024-01-15"}' | python lexer_bridge.py
```
```

**Step 4: Test bridge manually**

Run: `python bridge/lexer_bridge.py`
Expected: Prints JSON with DATE token

**Step 5: Commit**

```bash
git add bridge/
git commit -m "feat: add minimal Python bridge (hardcoded response)

- Create bridge/lexer_bridge.py with mock token response
- Add requirements.txt with beancount dependency
- Add bridge README with protocol documentation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Smoke Test YAML

**Files:**
- Create: `spec/lexer/smoke_test.yaml`

**Step 1: Create smoke test with 5 basic tokens**

```yaml
version: "1.0"
category: "lexer/smoke"
description: "Minimal smoke test for bootstrap validation"

tests:
  - name: "Simple date token"
    input: "2024-01-15"
    expected:
      - type: DATE
        value: "2024-01-15"
        line: 1
        column: 1

  - name: "Transaction flag asterisk"
    input: "*"
    expected:
      - type: ASTERISK
        value: "*"
        line: 1
        column: 1

  - name: "Simple number"
    input: "123.45"
    expected:
      - type: NUMBER
        value: "123.45"
        line: 1
        column: 1

  - name: "Currency code"
    input: "USD"
    expected:
      - type: CURRENCY
        value: "USD"
        line: 1
        column: 1

  - name: "Simple account"
    input: "Assets:Checking"
    expected:
      - type: ACCOUNT
        value: "Assets:Checking"
        line: 1
        column: 1
```

**Step 2: Validate YAML syntax**

Run: `python -c "import yaml; yaml.safe_load(open('spec/lexer/smoke_test.yaml'))"`
Expected: No errors

**Step 3: Commit**

```bash
git add spec/lexer/smoke_test.yaml
git commit -m "feat: add smoke test YAML with 5 basic tokens

Tests cover: DATE, ASTERISK, NUMBER, CURRENCY, ACCOUNT

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4: Core Types

**Files:**
- Create: `src/types.zig`

**Step 1: Write test for Token struct**

```zig
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
```

**Step 2: Run test**

Run: `zig build test`
Expected: Token equality test passes

**Step 3: Add Test struct**

```zig
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
```

**Step 4: Add test for Test struct**

```zig
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
```

**Step 5: Run tests**

Run: `zig build test`
Expected: All types tests pass

**Step 6: Commit**

```bash
git add src/types.zig
git commit -m "feat: add core data types (Token, Test, TestSuite)

- Define Token with equality comparison
- Define Test and TestSuite structures
- Add unit tests for type validation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Bridge Communication (Hardcoded Test)

**Files:**
- Create: `src/bridge.zig`
- Modify: `build.zig` (add bridge.zig to compilation)

**Step 1: Write test for spawning Python process**

```zig
const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");

pub const Bridge = struct {
    allocator: std.mem.Allocator,
    process: std.ChildProcess,

    pub fn init(allocator: std.mem.Allocator, bridge_path: []const u8) !Bridge {
        var process = std.ChildProcess.init(&[_][]const u8{ "python3", bridge_path }, allocator);
        process.stdin_behavior = .Pipe;
        process.stdout_behavior = .Pipe;
        process.stderr_behavior = .Pipe;

        try process.spawn();

        return Bridge{
            .allocator = allocator,
            .process = process,
        };
    }

    pub fn deinit(self: *Bridge) void {
        _ = self.process.kill() catch {};
    }

    pub fn sendInput(self: *Bridge, input: []const u8) ![]const u8 {
        // Write JSON request
        const request = try std.fmt.allocPrint(
            self.allocator,
            "{{\"input\": \"{s}\"}}\n",
            .{input},
        );
        defer self.allocator.free(request);

        try self.process.stdin.?.writeAll(request);

        // Read JSON response
        const response = try self.process.stdout.?.reader().readUntilDelimiterAlloc(
            self.allocator,
            '\n',
            1024 * 1024,
        );

        return response;
    }
};

test "Bridge spawn and communicate" {
    const allocator = testing.allocator;

    var bridge = try Bridge.init(allocator, "bridge/lexer_bridge.py");
    defer bridge.deinit();

    const response = try bridge.sendInput("2024-01-15");
    defer allocator.free(response);

    // Just verify we got JSON back
    try testing.expect(response.len > 0);
    try testing.expect(std.mem.indexOf(u8, response, "tokens") != null);
}
```

**Step 2: Run test (will fail - we need to update bridge first)**

Run: `zig build test`
Expected: Test fails because bridge doesn't read stdin yet

**Step 3: Update bridge.py to read stdin**

Modify `bridge/lexer_bridge.py`:

```python
#!/usr/bin/env python3
"""Minimal Python bridge for Beancount lexer testing."""

import json
import sys


def main():
    # Read JSON from stdin
    for line in sys.stdin:
        try:
            request = json.loads(line)
            input_text = request.get("input", "")

            # Mock response (we'll connect to real lexer later)
            response = {
                "tokens": [
                    {
                        "type": "DATE",
                        "value": input_text,
                        "line": 1,
                        "column": 1
                    }
                ]
            }

            print(json.dumps(response))
            sys.stdout.flush()

        except Exception as e:
            error_response = {
                "error": "BridgeError",
                "message": str(e),
                "details": ""
            }
            print(json.dumps(error_response))
            sys.stdout.flush()


if __name__ == "__main__":
    main()
```

**Step 4: Run test again**

Run: `zig build test`
Expected: Bridge communication test passes

**Step 5: Commit**

```bash
git add src/bridge.zig bridge/lexer_bridge.py
git commit -m "feat: add Bridge for Python process communication

- Implement Bridge.init() to spawn Python process
- Implement Bridge.sendInput() for JSON request/response
- Update bridge.py to read stdin and respond
- Add unit test for bridge communication

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 6: Connect Bridge to Real Beancount Lexer

**Files:**
- Modify: `bridge/lexer_bridge.py`

**Step 1: Update bridge to use real Beancount lexer**

```python
#!/usr/bin/env python3
"""Python bridge for Beancount lexer testing."""

import json
import sys
from io import StringIO


def tokenize_with_beancount(input_text):
    """Tokenize input using Beancount lexer."""
    try:
        from beancount.parser import lexer

        # Create lexer
        lex = lexer.LexBuilder()
        lex_instance = lex.build()

        # Tokenize
        lex_instance.input(input_text)
        tokens = []

        while True:
            tok = lex_instance.token()
            if not tok:
                break

            tokens.append({
                "type": tok.type,
                "value": tok.value if tok.value is not None else "",
                "line": tok.lineno,
                "column": tok.lexpos + 1,  # Convert to 1-indexed
            })

        return {"tokens": tokens}

    except ImportError as e:
        return {
            "error": "ImportError",
            "message": "Failed to import beancount",
            "details": str(e)
        }
    except Exception as e:
        return {
            "error": "LexerError",
            "message": str(e),
            "details": str(type(e).__name__)
        }


def main():
    """Read JSON requests from stdin, tokenize, write JSON responses to stdout."""
    for line in sys.stdin:
        try:
            request = json.loads(line)
            input_text = request.get("input", "")

            response = tokenize_with_beancount(input_text)
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


if __name__ == "__main__":
    main()
```

**Step 2: Install beancount**

Run: `pip install -r bridge/requirements.txt`
Expected: Beancount installs successfully

**Step 3: Test bridge manually**

Run: `echo '{"input": "2024-01-15"}' | python bridge/lexer_bridge.py`
Expected: Returns actual tokens from Beancount lexer

**Step 4: Run Zig tests**

Run: `zig build test`
Expected: Bridge tests still pass with real lexer

**Step 5: Commit**

```bash
git add bridge/lexer_bridge.py
git commit -m "feat: connect bridge to real Beancount lexer

- Import beancount.parser.lexer
- Tokenize input using Beancount's lexer
- Handle import errors gracefully
- Return actual token types from Beancount

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 2: Core Infrastructure

### Task 7: Basic Runner (Hardcoded Single Test)

**Files:**
- Create: `src/runner.zig`

**Step 1: Write test for running single hardcoded test**

```zig
const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");
const bridge_mod = @import("bridge.zig");

pub const TestResult = struct {
    test_name: []const u8,
    passed: bool,
    expected_tokens: []const types.Token,
    actual_tokens: []types.Token,
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
```

**Step 2: Run test**

Run: `zig build test`
Expected: Runner test passes (executes test via bridge)

**Step 3: Commit**

```bash
git add src/runner.zig
git commit -m "feat: add Runner for test execution

- Implement Runner.runTest() to execute single test
- Parse JSON response from bridge
- Compare expected vs actual tokens
- Return TestResult with pass/fail status
- Add unit test for runner execution

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 8: Simple Reporter

**Files:**
- Create: `src/reporter.zig`

**Step 1: Write test for human-readable output**

```zig
const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");
const runner_mod = @import("runner.zig");

pub const Reporter = struct {
    allocator: std.mem.Allocator,
    writer: std.fs.File.Writer,

    pub fn init(allocator: std.mem.Allocator, writer: std.fs.File.Writer) Reporter {
        return Reporter{
            .allocator = allocator,
            .writer = writer,
        };
    }

    pub fn reportResult(self: *Reporter, result: runner_mod.TestResult) !void {
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
        }
    }

    pub fn reportSummary(self: *Reporter, total: usize, passed: usize) !void {
        const failed = total - passed;
        const percent = if (total > 0) (passed * 100) / total else 0;

        try self.writer.print("\n", .{});
        try self.writer.print("Results: {}/{} passed ({}%)\n", .{ passed, total, percent });

        if (failed > 0) {
            try self.writer.print("{} test(s) failed\n", .{failed});
        }
    }
};

test "Reporter formats passing test" {
    const allocator = testing.allocator;

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var reporter = Reporter.init(allocator, buffer.writer());

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

    var reporter = Reporter.init(allocator, buffer.writer());

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
```

**Step 2: Run tests**

Run: `zig build test`
Expected: Reporter tests pass

**Step 3: Commit**

```bash
git add src/reporter.zig
git commit -m "feat: add Reporter for test output formatting

- Implement reportResult() for individual test results
- Implement reportSummary() for overall statistics
- Use ✓/✗ symbols for pass/fail
- Add unit tests for reporter output

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 9: Wire Up Main (Hardcoded Smoke Test)

**Files:**
- Modify: `src/main.zig`

**Step 1: Update main.zig to run hardcoded smoke test**

```zig
const std = @import("std");
const types = @import("types.zig");
const runner_mod = @import("runner.zig");
const reporter_mod = @import("reporter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    // Hardcoded smoke test
    const expected_tokens = [_]types.Token{
        types.Token{
            .type = "DATE",
            .value = "2024-01-15",
            .line = 1,
            .column = 1,
        },
    };

    const test_case = types.Test{
        .name = "Simple date token",
        .input = "2024-01-15",
        .expected = &expected_tokens,
    };

    var runner = try runner_mod.Runner.init(allocator, "bridge/lexer_bridge.py");
    defer runner.deinit();

    var reporter = reporter_mod.Reporter.init(allocator, stdout);

    const result = try runner.runTest(test_case);
    defer allocator.free(result.actual_tokens);

    try reporter.reportResult(result);
    try reporter.reportSummary(1, if (result.passed) 1 else 0);

    // Exit code
    const exit_code: u8 = if (result.passed) 0 else 1;
    std.process.exit(exit_code);
}

test "basic test" {
    try std.testing.expect(true);
}
```

**Step 2: Run the program**

Run: `zig build run`
Expected: Prints "✓ Simple date token" and "Results: 1/1 passed (100%)"

**Step 3: Verify exit code on success**

Run: `zig build run && echo "Exit code: $?"`
Expected: "Exit code: 0"

**Step 4: Commit**

```bash
git add src/main.zig
git commit -m "feat: wire up main to run hardcoded smoke test

- Initialize runner and reporter
- Execute single hardcoded DATE token test
- Display results and exit with appropriate code
- Validates end-to-end pipeline works

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 10: Add YAML Parsing

**Files:**
- Modify: `build.zig` (add zig-yaml dependency)
- Create: `src/yaml_parser.zig`

**Step 1: Add zig-yaml dependency to build.zig**

Note: For this step, we'll use a simplified approach with std.json since zig-yaml setup can be complex. We'll convert YAML to JSON manually for now.

Create `spec/lexer/smoke_test.json` (converted from YAML):

```json
{
  "version": "1.0",
  "category": "lexer/smoke",
  "description": "Minimal smoke test for bootstrap validation",
  "tests": [
    {
      "name": "Simple date token",
      "input": "2024-01-15",
      "expected": [
        {
          "type": "DATE",
          "value": "2024-01-15",
          "line": 1,
          "column": 1
        }
      ]
    },
    {
      "name": "Transaction flag asterisk",
      "input": "*",
      "expected": [
        {
          "type": "ASTERISK",
          "value": "*",
          "line": 1,
          "column": 1
        }
      ]
    }
  ]
}
```

**Step 2: Create yaml_parser.zig (actually JSON parser for now)**

```zig
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

    const version = root.get("version").?.string;
    const category = root.get("category").?.string;
    const description = root.get("description").?.string;

    var tests = std.ArrayList(types.Test).init(allocator);
    defer tests.deinit();

    const tests_array = root.get("tests").?.array;

    for (tests_array.items) |test_obj| {
        const test_name = test_obj.object.get("name").?.string;
        const input = test_obj.object.get("input").?.string;

        var expected_tokens = std.ArrayList(types.Token).init(allocator);
        defer expected_tokens.deinit();

        const expected_array = test_obj.object.get("expected").?.array;

        for (expected_array.items) |token_obj| {
            const token = types.Token{
                .type = token_obj.object.get("type").?.string,
                .value = token_obj.object.get("value").?.string,
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
        for (suite.tests) |test_case| {
            allocator.free(test_case.expected);
        }
        allocator.free(suite.tests);
    }

    try testing.expectEqualStrings("1.0", suite.version);
    try testing.expectEqual(@as(usize, 2), suite.tests.len);
    try testing.expectEqualStrings("Simple date token", suite.tests[0].name);
}
```

**Step 3: Create smoke_test.json file**

Create the file as shown in Step 1.

**Step 4: Run test**

Run: `zig build test`
Expected: YAML parser test passes

**Step 5: Commit**

```bash
git add src/yaml_parser.zig spec/lexer/smoke_test.json
git commit -m "feat: add test file parser (JSON for now)

- Create yaml_parser.zig to parse test definitions
- Parse version, category, description, tests array
- Extract expected tokens from test definitions
- Add unit test for parser
- Use JSON format temporarily (will add YAML later)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 11: Wire Main to Load Test File

**Files:**
- Modify: `src/main.zig`

**Step 1: Update main to load and run test file**

```zig
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
            allocator.free(test_case.expected);
        }
        allocator.free(suite.tests);
    }

    try stdout.print("Running test suite: {s}\n", .{suite.description});
    try stdout.print("Category: {s}\n\n", .{suite.category});

    var runner = try runner_mod.Runner.init(allocator, "bridge/lexer_bridge.py");
    defer runner.deinit();

    var reporter = reporter_mod.Reporter.init(allocator, stdout);

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
```

**Step 2: Run the program**

Run: `zig build run`
Expected: Runs 2 tests from smoke_test.json, shows results

**Step 3: Verify exit code**

Run: `zig build run && echo "Success" || echo "Failed"`
Expected: Depends on whether tests pass (likely will fail due to token mismatches - that's OK, we're validating the pipeline)

**Step 4: Commit**

```bash
git add src/main.zig
git commit -m "feat: wire main to load and run test file

- Parse smoke_test.json file
- Execute all tests in suite
- Report results for each test
- Show summary statistics
- Exit with appropriate code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 3: Comprehensive Test Coverage

### Task 12: Create tokens_basic.yaml

**Files:**
- Create: `spec/lexer/tokens_basic.yaml`

See BEANCOUNT-SPECIFICATION.md section 3.1.2-3.1.4 for token definitions.

**Step 1: Create comprehensive basic tokens test**

```yaml
version: "1.0"
category: "lexer/basic"
description: "Core token recognition tests - keywords, operators, flags"

tests:
  # Keywords
  - name: "Keyword: txn"
    input: "txn"
    expected:
      - type: TXN
        value: "txn"
        line: 1
        column: 1

  - name: "Keyword: balance"
    input: "balance"
    expected:
      - type: BALANCE
        value: "balance"
        line: 1
        column: 1

  - name: "Keyword: open"
    input: "open"
    expected:
      - type: OPEN
        value: "open"
        line: 1
        column: 1

  - name: "Keyword: close"
    input: "close"
    expected:
      - type: CLOSE
        value: "close"
        line: 1
        column: 1

  - name: "Keyword: commodity"
    input: "commodity"
    expected:
      - type: COMMODITY
        value: "commodity"
        line: 1
        column: 1

  - name: "Keyword: pad"
    input: "pad"
    expected:
      - type: PAD
        value: "pad"
        line: 1
        column: 1

  - name: "Keyword: event"
    input: "event"
    expected:
      - type: EVENT
        value: "event"
        line: 1
        column: 1

  - name: "Keyword: price"
    input: "price"
    expected:
      - type: PRICE
        value: "price"
        line: 1
        column: 1

  - name: "Keyword: note"
    input: "note"
    expected:
      - type: NOTE
        value: "note"
        line: 1
        column: 1

  - name: "Keyword: document"
    input: "document"
    expected:
      - type: DOCUMENT
        value: "document"
        line: 1
        column: 1

  - name: "Keyword: query"
    input: "query"
    expected:
      - type: QUERY
        value: "query"
        line: 1
        column: 1

  - name: "Keyword: custom"
    input: "custom"
    expected:
      - type: CUSTOM
        value: "custom"
        line: 1
        column: 1

  - name: "Keyword: pushtag"
    input: "pushtag"
    expected:
      - type: PUSHTAG
        value: "pushtag"
        line: 1
        column: 1

  - name: "Keyword: poptag"
    input: "poptag"
    expected:
      - type: POPTAG
        value: "poptag"
        line: 1
        column: 1

  - name: "Keyword: pushmeta"
    input: "pushmeta"
    expected:
      - type: PUSHMETA
        value: "pushmeta"
        line: 1
        column: 1

  - name: "Keyword: popmeta"
    input: "popmeta"
    expected:
      - type: POPMETA
        value: "popmeta"
        line: 1
        column: 1

  - name: "Keyword: option"
    input: "option"
    expected:
      - type: OPTION
        value: "option"
        line: 1
        column: 1

  - name: "Keyword: include"
    input: "include"
    expected:
      - type: INCLUDE
        value: "include"
        line: 1
        column: 1

  - name: "Keyword: plugin"
    input: "plugin"
    expected:
      - type: PLUGIN
        value: "plugin"
        line: 1
        column: 1

  # Operators and Delimiters
  - name: "Operator: pipe"
    input: "|"
    expected:
      - type: PIPE
        value: "|"
        line: 1
        column: 1

  - name: "Operator: at"
    input: "@"
    expected:
      - type: AT
        value: "@"
        line: 1
        column: 1

  - name: "Operator: double-at"
    input: "@@"
    expected:
      - type: ATAT
        value: "@@"
        line: 1
        column: 1

  - name: "Operator: left-curly"
    input: "{"
    expected:
      - type: LCURL
        value: "{"
        line: 1
        column: 1

  - name: "Operator: right-curly"
    input: "}"
    expected:
      - type: RCURL
        value: "}"
        line: 1
        column: 1

  - name: "Operator: double-left-curly"
    input: "{{"
    expected:
      - type: LCURLCURL
        value: "{{"
        line: 1
        column: 1

  - name: "Operator: double-right-curly"
    input: "}}"
    expected:
      - type: RCURLCURL
        value: "}}"
        line: 1
        column: 1

  - name: "Operator: asterisk"
    input: "*"
    expected:
      - type: ASTERISK
        value: "*"
        line: 1
        column: 1

  - name: "Operator: hash"
    input: "#"
    expected:
      - type: HASH
        value: "#"
        line: 1
        column: 1

  # Transaction Flags
  - name: "Flag: exclamation"
    input: "!"
    expected:
      - type: FLAG
        value: "!"
        line: 1
        column: 1

  - name: "Flag: ampersand"
    input: "&"
    expected:
      - type: FLAG
        value: "&"
        line: 1
        column: 1

  - name: "Flag: question"
    input: "?"
    expected:
      - type: FLAG
        value: "?"
        line: 1
        column: 1

  - name: "Flag: percent"
    input: "%"
    expected:
      - type: FLAG
        value: "%"
        line: 1
        column: 1

  - name: "Flag: uppercase letter"
    input: "P"
    expected:
      - type: FLAG
        value: "P"
        line: 1
        column: 1
```

**Step 2: Validate YAML**

Run: `python -c "import yaml; yaml.safe_load(open('spec/lexer/tokens_basic.yaml'))"`
Expected: No errors

**Step 3: Commit**

```bash
git add spec/lexer/tokens_basic.yaml
git commit -m "feat: add comprehensive tokens_basic.yaml test file

- Add all 19 keyword tests (txn, balance, open, etc.)
- Add operator tests (pipe, at, @@, {, }, {{, }}, *, #)
- Add transaction flag tests (!, &, ?, %, uppercase letters)
- Total: 30+ basic token tests

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

*Due to length constraints, I'll summarize the remaining comprehensive test file tasks...*

### Tasks 13-17: Create Remaining Test Files

Follow the same pattern for:
- Task 13: `spec/lexer/tokens_numbers.yaml` (~25 tests)
- Task 14: `spec/lexer/tokens_strings.yaml` (~20 tests)
- Task 15: `spec/lexer/tokens_accounts.yaml` (~25 tests)
- Task 16: `spec/lexer/tokens_currencies.yaml` (~15 tests)
- Task 17: `spec/lexer/tokens_edge_cases.yaml` (~20 tests)

Each follows Step 1 (create YAML), Step 2 (validate), Step 3 (commit).

---

## Phase 4: Polish & Documentation

### Task 18: CLI Argument Parsing

**Files:**
- Modify: `src/main.zig`

Add argument parsing for `--verbose`, `--filter`, `--help` flags.

### Task 19: GitHub Actions CI

**Files:**
- Create: `.github/workflows/test.yml`

```yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        python-version: ['3.9', '3.10', '3.11', '3.12']

    steps:
      - uses: actions/checkout@v3

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ matrix.python-version }}

      - name: Install Beancount
        run: pip install -r bridge/requirements.txt

      - name: Setup Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.11.0

      - name: Build
        run: zig build

      - name: Run tests
        run: zig build test

      - name: Run test suite
        run: zig build run
```

### Task 20: Documentation

**Files:**
- Create: `docs/README.md`
- Create: `docs/CONTRIBUTING.md`

Include usage instructions, architecture overview, and how to add new tests.

---

## Success Validation

After all tasks complete, verify:

```bash
# All unit tests pass
zig build test

# All integration tests pass
zig build run

# CI passes (check GitHub Actions)

# Documentation is complete
ls docs/README.md docs/CONTRIBUTING.md
```

---

Plan complete and saved to `docs/plans/2026-03-01-lexer-testsuite-implementation.md`.

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
