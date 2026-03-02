# Beancount Parser Test Suite Design

**Date**: 2026-03-02
**Status**: Approved
**Target**: Comprehensive Parser Validation (Grammar + Semantics)

## Overview

Extension of the Beancount test suite to add comprehensive parser testing covering AST structure validation and semantic error detection. This builds on the existing lexer test infrastructure by extending components to handle parser tests while maintaining backward compatibility.

## Goals

1. Validate Beancount parser behavior across all directive types
2. Test both successful parsing (AST structure) and error cases (semantic validation)
3. Reuse 70% of existing lexer infrastructure
4. Support comprehensive testing (grammar + semantics + edge cases)
5. Maintain backward compatibility with all existing lexer tests

## Architecture

### Extension Model

Parser tests extend the existing lexer infrastructure rather than replacing it. The system automatically detects test type from the YAML `category` field and routes accordingly.

**Test Type Detection**:
```yaml
# Lexer test
category: "lexer/basic"

# Parser test
category: "parser/open_close"
```

**Component Extensions**:
- `types.zig`: Add `ASTNode` struct alongside existing `Token`
- `yaml_parser.zig`: Parse `expected_entries` and `expected_errors` fields
- `bridge/bridge.py`: Accept `--mode lexer|parser` CLI parameter
- `reporter.zig`: Dispatch to token diff vs AST diff formatting
- `runner.zig`: Spawn bridge with appropriate mode based on test category

**Backward Compatibility**: All existing lexer tests continue working unchanged. The harness detects test type and routes accordingly.

## Type System Extensions

### New Types in `types.zig`

```zig
// Generic AST node - can represent any Beancount directive
pub const ASTNode = struct {
    node_type: []const u8,           // "Transaction", "Open", "Balance", etc.
    attributes: std.StringHashMap([]const u8),  // Key-value pairs
    children: []const ASTNode,       // Nested nodes (postings, etc.)

    pub fn eql(self: ASTNode, other: ASTNode, allocator: std.mem.Allocator) bool {
        // Deep comparison of type, attributes, and children
    }
};

// Parser-specific test structures
pub const ParserTest = struct {
    name: []const u8,
    input: []const u8,
    expected_entries: []const ASTNode,
    expected_errors: []const ParserError,
};

pub const ParserError = struct {
    error_type: []const u8,          // "DuplicateAccountError", etc.
    message: []const u8,             // Error message pattern (regex)
    line: ?usize,                    // Optional line number
};

// Discriminated union for test types
pub const TestCase = union(enum) {
    lexer: Test,           // Existing lexer test
    parser: ParserTest,    // New parser test
};
```

**Design Rationale**:
- `ASTNode` is recursive and generic - works for all Beancount directives
- String-based attributes match serialization decision (everything as strings)
- Separation of `expected_entries` and `expected_errors` allows comprehensive validation
- `TestCase` union allows single runner to handle both test types

## YAML Schema for Parser Tests

### Parser Test File Format

```yaml
version: "1.0"
category: "parser/open_close"
description: "Open and close directive parsing"

tests:
  # Valid parse - entries expected
  - name: "Simple open directive"
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

  # Parse error - error expected
  - name: "Duplicate account open"
    input: |
      2024-01-01 open Assets:Checking
      2024-01-02 open Assets:Checking
    expected_entries:
      - node_type: "Open"
        attributes:
          date: "2024-01-01"
          account: "Assets:Checking"
        children: []
    expected_errors:
      - error_type: "DuplicateError"
        message: ".*already.*opened"
        line: 2

  # Multi-directive test
  - name: "Open then close"
    input: |
      2024-01-01 open Assets:Checking
      2024-12-31 close Assets:Checking
    expected_entries:
      - node_type: "Open"
        attributes:
          date: "2024-01-01"
          account: "Assets:Checking"
        children: []
      - node_type: "Close"
        attributes:
          date: "2024-12-31"
          account: "Assets:Checking"
        children: []
    expected_errors: []
```

**Key Schema Features**:
- `expected_entries`: Array of AST nodes representing parsed directives
- `expected_errors`: Array of error objects (empty if no errors expected)
- `attributes`: Flat key-value pairs as strings
- `children`: Nested AST nodes for complex structures (postings, currencies)
- `message` in errors: Regex pattern for flexible matching

## Python Bridge Changes

### Unified Bridge Structure

**File**: `bridge/bridge.py` (renamed from `lexer_bridge.py`)

```python
#!/usr/bin/env python3
import sys
import json
from argparse import ArgumentParser

def lexer_mode(input_text):
    """Existing lexer functionality"""
    from beancount.parser import lexer
    # ... existing lexer logic ...
    return {"tokens": [...]}

def parser_mode(input_text):
    """New parser functionality"""
    from beancount.parser import parser

    # Parse the input as a complete file
    entries, errors, options = parser.parse_string(input_text)

    # Serialize entries to AST nodes
    serialized_entries = [serialize_entry(e) for e in entries]

    # Serialize errors
    serialized_errors = [serialize_error(e) for e in errors]

    return {
        "entries": serialized_entries,
        "errors": serialized_errors
    }

def serialize_entry(entry):
    """Convert Beancount directive to AST node dict"""
    node = {
        "node_type": entry.__class__.__name__,
        "attributes": {},
        "children": []
    }

    # Extract attributes (date, account, etc.)
    for field in entry._fields:
        value = getattr(entry, field)
        if value is not None and not isinstance(value, (list, tuple)):
            node["attributes"][field] = str(value)

    # Extract children (postings, tags, links, etc.)
    if hasattr(entry, 'postings') and entry.postings:
        node["children"] = [serialize_posting(p) for p in entry.postings]

    return node

def serialize_posting(posting):
    """Convert posting to AST node"""
    return {
        "node_type": "Posting",
        "attributes": {
            "account": str(posting.account),
            "amount": str(posting.units) if posting.units else ""
        },
        "children": []
    }

def serialize_error(error):
    """Convert Beancount error to error dict"""
    return {
        "error_type": error.__class__.__name__,
        "message": str(error.message),
        "line": error.source.get('lineno') if error.source else None
    }

def main():
    parser_args = ArgumentParser()
    parser_args.add_argument('--mode', choices=['lexer', 'parser'], required=True)
    args = parser_args.parse_args()

    for line in sys.stdin:
        request = json.loads(line)
        input_text = request['input']

        if args.mode == 'lexer':
            result = lexer_mode(input_text)
        else:
            result = parser_mode(input_text)

        print(json.dumps(result))
        sys.stdout.flush()

if __name__ == '__main__':
    main()
```

**Key Design Points**:
- Mode selected via CLI arg: `python bridge.py --mode parser`
- Uses `beancount.parser.parser.parse_string()` for full file parsing
- All Python types serialized to strings (dates, decimals, amounts)
- Recursive serialization for nested structures (postings)
- Errors include type, message, and optional line number
- Same JSON-over-stdin protocol as lexer mode

## Reporter Enhancements

### AST Diff Formatting

The reporter will format parser test failures differently from lexer failures to provide clear diagnostics for AST mismatches.

**Entry Count Mismatch**:
```
FAIL: Open then close
  Expected 2 entries, got 1

  Expected entries:
    1. Open (date: 2024-01-01, account: Assets:Checking)
    2. Close (date: 2024-12-31, account: Assets:Checking)

  Actual entries:
    1. Open (date: 2024-01-01, account: Assets:Checking)
```

**Attribute Mismatch**:
```
FAIL: Simple open directive
  Entry 0 (Open) attribute mismatch:

    Expected: account = "Assets:Checking"
    Actual:   account = "Assets:Savings"
```

**Error Mismatch**:
```
FAIL: Duplicate account open
  Expected 1 error, got 0

  Expected errors:
    - DuplicateError at line 2: ".*already.*opened"

  Actual errors: (none)
```

**Children Mismatch** (for transactions with postings):
```
FAIL: Transaction with two postings
  Entry 0 (Transaction) children count mismatch:
    Expected: 2 children
    Actual:   1 children

  Missing child:
    - Posting (account: Expenses:Coffee, amount: 5.00 USD)
```

**Reporter Dispatch Logic**:
```zig
pub fn formatFailure(test_case: TestCase, writer: anytype) !void {
    switch (test_case) {
        .lexer => try formatTokenDiff(test_case.lexer, writer),
        .parser => try formatASTDiff(test_case.parser, writer),
    }
}
```

## Test File Organization

### Parser Test Files in `spec/parser/`

**1. `open_close.yaml`** - Account lifecycle directives
- **Minimal**: 3 tests (simple open, open with currencies, simple close)
- **Comprehensive**: ~15 tests
  - Open with single currency, multiple currencies
  - Close directive
  - Open/close same account (valid sequence)
  - Duplicate open error
  - Close unopened account error
  - Invalid account names

**2. `transactions.yaml`** - Transaction directives with postings
- **Minimal**: 3 tests (simple txn, txn with 2 postings, unbalanced error)
- **Comprehensive**: ~30 tests
  - Basic transactions with flags (*, !, etc.)
  - Multiple postings
  - Postings with costs and prices
  - Tags and links
  - Transaction metadata
  - Unbalanced transaction errors
  - Invalid posting syntax

**3. `balance_pad.yaml`** - Balance assertions and pad directives
- **Minimal**: 2 tests (simple balance, simple pad)
- **Comprehensive**: ~12 tests
  - Balance assertions
  - Pad directives between accounts
  - Balance errors (assertion failures)
  - Invalid pad syntax

**4. `price_note.yaml`** - Price, note, document directives
- **Minimal**: 3 tests (one of each type)
- **Comprehensive**: ~15 tests
  - Price directives
  - Note directives with strings
  - Document directives with file paths
  - Invalid price formats
  - Missing required fields

**5. `metadata.yaml`** - Tag and metadata stack operations
- **Minimal**: 2 tests (pushtag/poptag, pushmeta/popmeta)
- **Comprehensive**: ~10 tests
  - pushtag/poptag pairs
  - pushmeta/popmeta pairs
  - Unbalanced stack errors
  - Metadata inheritance

**6. `options.yaml`** - Configuration directives
- **Minimal**: 3 tests (option, include, plugin)
- **Comprehensive**: ~12 tests
  - Option directives
  - Include directives
  - Plugin directives with arguments
  - Invalid option names
  - Missing plugin paths

**Total Coverage**:
- **Minimal**: ~16 tests across 6 files (bootstrap validation)
- **Comprehensive**: ~94 tests (full coverage goal)

**Bootstrap Strategy**: Create all 6 files with minimal examples first to prove the approach, then iteratively expand to comprehensive coverage.

## Data Flow and Execution

### End-to-End Parser Test Flow

**1. Discovery Phase**
- Runner scans `spec/parser/*.yaml` files
- `yaml_parser.zig` parses YAML and detects `category: "parser/*"`
- Creates `ParserTest` structs with `expected_entries` and `expected_errors`

**2. Bridge Initialization**
- Runner spawns: `python bridge/bridge.py --mode parser`
- Bridge loads Beancount parser once
- Waits for JSON input on stdin

**3. Test Execution** (per test)
- Zig sends: `{"input": "2024-01-01 open Assets:Checking"}`
- Bridge calls `parser.parse_string(input)`
- Bridge serializes entries and errors to JSON
- Bridge returns: `{"entries": [...], "errors": [...]}`
- Zig deserializes JSON into `ASTNode` and `ParserError` arrays

**4. Validation**
- **Entry validation**:
  - Count match: `expected_entries.len == actual_entries.len`
  - For each entry: compare `node_type`, `attributes` (key-by-key), `children` (recursively)
- **Error validation**:
  - Count match: `expected_errors.len == actual_errors.len`
  - For each error: match `error_type`, regex match `message`, optional line number
- Any mismatch = test failure

**5. Reporting**
- Reporter formats failures using AST diff logic
- Summary: `14/16 parser tests passed (87.5%)`
- Combined with lexer results: `Total: 58/66 tests passed (87.9%)`

**Bridge Process Lifecycle**:
- One bridge process per test file (reused across tests in that file)
- Reduces startup overhead compared to per-test processes
- Clean shutdown after file completes

## Error Handling and Edge Cases

### Parser-Specific Error Scenarios

**Complex AST Serialization Failures**:
- Bridge catches exceptions during `serialize_entry()`
- Returns error JSON: `{"error": "SerializationError", "details": "..."}`
- Test marked as infrastructure failure (not test failure)
- Continue with next test

**Regex Pattern Matching for Errors**:
- Error messages use regex patterns for flexibility
- Example: `".*already.*opened"` matches various phrasings
- Invalid regex in YAML = test file validation error
- Failed regex match = clear diff showing expected pattern vs actual message

**Recursive AST Comparison**:
- Deep comparison of nested children (transactions with postings)
- Handles arbitrary nesting depth
- Mismatches show path: `Entry 0 > Child 1 > Attribute "account"`

**Missing or Extra Attributes**:
- Expected attribute not in actual: show as missing
- Actual attribute not in expected: show as unexpected
- Helps catch Beancount version differences

**Null/None Handling**:
- Python `None` serialized as empty string `""`
- Optional fields in expected YAML can be omitted
- Omitted = don't validate (flexible matching)
- Explicit `""` = must be empty/None

**Bridge Compatibility**:
- Beancount version differences may affect AST structure
- Tests should use core fields that are stable across versions
- Version-specific tests can be marked with metadata

**Performance Considerations**:
- Large AST trees (100+ postings) may be slow to serialize
- Timeout per test configurable (default 10s for parser vs 5s for lexer)
- Deep recursion limits in JSON serialization

**Graceful Degradation**:
- If parser test fails to load, skip file but continue
- Report skipped parser tests separately
- Exit code reflects both lexer and parser results

## Implementation Phases

### Phase 1: Type System and Schema (Foundation)
1. Extend `types.zig` with `ASTNode`, `ParserTest`, `ParserError`
2. Update `yaml_parser.zig` to parse parser test schema
3. Add test case discrimination logic
4. **Validation**: Can parse parser YAML files into data structures

### Phase 2: Bridge Extension
1. Rename `lexer_bridge.py` to `bridge.py`
2. Add `--mode` parameter and argument parsing
3. Implement `parser_mode()` with `parse_string()` integration
4. Implement `serialize_entry()` and `serialize_error()`
5. **Validation**: Bridge returns correct JSON for sample inputs

### Phase 3: Validation and Reporting
1. Implement AST comparison in `types.zig` (`ASTNode.eql()`)
2. Implement error validation with regex matching
3. Extend `reporter.zig` with AST diff formatting
4. Update runner to spawn bridge with correct mode
5. **Validation**: End-to-end flow works with one test

### Phase 4: Minimal Test Files
1. Create all 6 parser test files with minimal examples (~16 tests total)
2. Run and validate all minimal tests pass
3. Fix any issues discovered
4. **Validation**: Bootstrap complete, all minimal tests pass

### Phase 5: Comprehensive Coverage
1. Expand each test file to comprehensive coverage (~94 tests total)
2. Document any spec/implementation mismatches discovered
3. Add edge cases and error scenarios
4. **Validation**: Full parser test coverage achieved

### Phase 6: Documentation and Polish
1. Update main README with parser test instructions
2. Update CONTRIBUTING guide for writing parser tests
3. Add CLI examples for running parser tests
4. **Validation**: Documentation complete and accurate

## Success Criteria

- [ ] All 6 parser test files created with comprehensive coverage
- [ ] Zig harness successfully executes parser tests
- [ ] Python bridge correctly serializes Beancount AST to JSON
- [ ] AST comparison correctly identifies matches and mismatches
- [ ] Error validation with regex matching works correctly
- [ ] Reporter provides clear diagnostics for failures
- [ ] All existing lexer tests continue passing (backward compatibility)
- [ ] Combined lexer + parser test suite runs in CI/CD
- [ ] Documentation complete for writing parser tests

## Future Extensions

**Additional Test Layers**:
- Grammar validation tests (Layer 2) - similar extension pattern
- Semantic consistency tests beyond parser errors
- Performance regression testing for parser

**Alternative Implementations**:
- Replace Python bridge with other Beancount implementations
- Comparative testing across implementations
- AST compatibility validation

**Test Enhancements**:
- Property-based testing for parser (generate random valid Beancount)
- Fuzzing for edge case discovery
- Round-trip testing (parse → serialize → parse)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Beancount AST too complex to serialize | High | Start simple, iterate, handle special cases |
| Regex matching too brittle | Medium | Use flexible patterns, document conventions |
| Type system complexity in Zig | Medium | Start with simple structs, refactor if needed |
| Performance issues with large ASTs | Low | Add timeouts, optimize serialization if needed |
| Breaking existing lexer tests | Medium | Run full test suite after each change |

## References

- Beancount Formal Specification: `BEANCOUNT-SPECIFICATION.md`
- Beancount Python Parser: https://github.com/beancount/beancount
- Existing Lexer Design: `docs/plans/2026-03-01-lexer-testsuite-design.md`
- Existing Implementation: `docs/plans/2026-03-01-lexer-testsuite-implementation.md`

---

**Next Steps**: Create implementation plan using writing-plans skill.
