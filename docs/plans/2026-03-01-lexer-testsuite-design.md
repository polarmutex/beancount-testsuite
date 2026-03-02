# Beancount Lexer Test Suite Design

**Date**: 2026-03-01
**Status**: Approved
**Target**: Python Beancount Reference Implementation Validation

## Overview

A comprehensive test suite for validating the Beancount lexer specification (Layer 1) against the Python reference implementation. The system uses a Zig test harness communicating with a Python bridge to execute YAML-defined tests.

## Goals

1. Validate that the formal specification matches Python Beancount's actual lexer behavior
2. Provide comprehensive lexer test coverage (all 6 test files from spec section 3.3)
3. Create reusable test infrastructure for future grammar/semantic layers
4. Enable CI/CD integration for continuous validation
5. Prove the Zig + Python bridge approach works before expanding to other layers

## Architecture

### Three-Layer Design

**1. Test Definitions Layer** (`spec/lexer/*.yaml`)
- YAML files following the specification format (section 3.3)
- Each test has: name, input, expected tokens with type/value/line/column
- 6 files: basic, numbers, strings, accounts, currencies, edge_cases

**2. Zig Test Harness** (`src/`)
- Reads YAML test files using a Zig YAML library
- Spawns Python bridge process for each test file
- Sends test inputs via JSON over stdin
- Receives tokenized results via JSON from stdout
- Compares actual vs expected tokens
- Generates test reports (TAP format or JUnit XML)
- Exit code 0 for all pass, non-zero for failures

**3. Python Bridge** (`bridge/lexer_bridge.py`)
- Minimal wrapper around `beancount.parser.lexer`
- Reads JSON from stdin: `{"input": "2024-01-15 * \"Test\""}`
- Tokenizes using Beancount lexer
- Returns JSON to stdout: `{"tokens": [{"type": "DATE", "value": "2024-01-15", "line": 1, "column": 1}, ...]}`
- Handles errors gracefully with error objects in JSON

### Communication Protocol

The harness and bridge communicate via JSON over stdin/stdout pipes, keeping them loosely coupled. This allows easy replacement of the Python bridge with other implementations later.

## Components & Directory Structure

```
beancount-testsuite/
├── spec/
│   └── lexer/
│       ├── tokens_basic.yaml          # Keywords, operators, flags
│       ├── tokens_numbers.yaml        # Integer, decimal, comma-separated
│       ├── tokens_strings.yaml        # Escape sequences, multiline
│       ├── tokens_accounts.yaml       # Account patterns, validation
│       ├── tokens_currencies.yaml     # Currency codes, special chars
│       └── tokens_edge_cases.yaml     # Ambiguous tokens, whitespace
├── src/
│   ├── main.zig                       # CLI entry point, arg parsing
│   ├── runner.zig                     # Test execution engine
│   ├── yaml.zig                       # YAML parsing (use zig-yaml lib)
│   ├── bridge.zig                     # Python process management
│   ├── reporter.zig                   # Test result formatting
│   └── types.zig                      # Test/Token data structures
├── bridge/
│   ├── lexer_bridge.py                # Python wrapper for Beancount
│   └── requirements.txt               # beancount dependency
├── test/
│   └── fixtures/                      # Test harness validation files
│       ├── valid_minimal.yaml
│       ├── invalid_token.yaml
│       └── malformed.yaml
├── .github/
│   └── workflows/
│       └── test.yml                   # CI: run tests on push/PR
├── build.zig                          # Zig build configuration
├── docs/
│   ├── README.md                      # Usage instructions
│   ├── CONTRIBUTING.md                # How to add tests
│   └── plans/
│       └── 2026-03-01-lexer-testsuite-design.md  # This document
└── BEANCOUNT-SPECIFICATION.md         # (existing)
```

### Component Responsibilities

**main.zig**
- Parse CLI arguments (`--verbose`, `--filter`, `--format`, test file paths)
- Discover test files in `spec/lexer/`
- Invoke runner with configuration
- Handle exit codes

**runner.zig**
- Orchestrate test execution across all test files
- Manage Python bridge process lifecycle
- Collect and aggregate test results
- Coordinate with reporter for output

**bridge.zig**
- Spawn Python subprocess: `python bridge/lexer_bridge.py`
- Manage stdin/stdout pipes for JSON communication
- Handle process timeouts and crashes
- Clean up processes on completion

**yaml.zig**
- Deserialize YAML test files using zig-yaml library
- Validate schema compliance
- Convert to internal `TestSuite` data structures

**reporter.zig**
- Format test results for output
- Support multiple formats: human-readable (default), TAP, JUnit XML
- Generate diffs for failures
- Summary statistics

**types.zig**
- Data structures: `TestSuite`, `Test`, `Token`, `ExpectedToken`
- JSON serialization/deserialization helpers
- Common type definitions used across modules

## Data Flow

### End-to-End Test Execution

**1. Discovery Phase**
- Zig harness scans `spec/lexer/` directory
- Loads all `*.yaml` files using zig-yaml parser
- Deserializes into `TestSuite` structs containing array of `Test` objects

**2. Execution Phase** (per test file)
- Harness spawns Python bridge: `python bridge/lexer_bridge.py`
- For each test in the file:
  - Zig sends JSON: `{"input": "2024-01-15"}`
  - Bridge tokenizes via `beancount.parser.lexer`
  - Bridge returns: `{"tokens": [{"type": "DATE", "value": "2024-01-15", "line": 1, "column": 1}]}`
  - Zig compares actual vs expected tokens field-by-field
  - Records pass/fail with details

**3. Validation Logic**
- For each token, compare: `type`, `value`, `line`, `column`
- Exact match required (no fuzzy matching)
- Token count must match exactly
- Any mismatch = test failure with diff output

**4. Reporting Phase**
- Aggregate results across all tests
- Generate report in requested format
- Print summary: `45/50 tests passed (90%)`
- Exit with code 0 (all pass) or 1 (any failures)

**5. CI Integration**
- GitHub Actions runs: `zig build test`
- Fails PR if any tests fail
- Uploads JUnit XML for test result visualization

### JSON Protocol Examples

**Request (Zig → Python):**
```json
{
  "input": "2024-01-15 * \"Coffee\" #food"
}
```

**Response (Python → Zig):**
```json
{
  "tokens": [
    {"type": "DATE", "value": "2024-01-15", "line": 1, "column": 1},
    {"type": "ASTERISK", "value": "*", "line": 1, "column": 12},
    {"type": "STRING", "value": "Coffee", "line": 1, "column": 14},
    {"type": "TAG", "value": "#food", "line": 1, "column": 23}
  ]
}
```

**Error Response:**
```json
{
  "error": "LexerError",
  "message": "Unexpected character '@' at line 1, column 5",
  "details": "..."
}
```

## Error Handling

### Test Execution Errors

**Python bridge crash:**
- Harness detects closed stdout
- Marks entire test file as failed
- Includes stderr in failure report
- Continues with next test file

**Invalid JSON from bridge:**
- Parse error reported with details
- Test marked failed
- Continue with next test

**Timeout:**
- Kill bridge after 5s per test (configurable via `--timeout`)
- Mark as timeout failure
- Include partial output if any

**Invalid YAML test file:**
- Report schema validation error
- Skip file, continue with others
- Exit code still non-zero

### Test Assertion Failures

**Token count mismatch:**
- Show expected vs actual count
- List all tokens side-by-side for comparison

**Token field mismatch:**
- Show diff for specific field
- Example: `expected type: NUMBER, got: STRING`

**Missing expected token:**
- Show position where expected token should be
- Display surrounding context

**Extra unexpected token:**
- Highlight the unexpected token
- Show its position and details

### Bridge Error Handling

**Beancount import failure:**
- Return JSON error: `{"error": "ImportError", "details": "Failed to import beancount"}`
- Test harness shows installation instructions

**Lexer exception:**
- Catch all exceptions in bridge
- Return as error object with traceback
- Test marked failed with exception details

**Invalid input encoding:**
- Return error with encoding details
- Suggest UTF-8 encoding

### Graceful Degradation

**Python not found:**
- Clear error message: `Python not found in PATH`
- Installation instructions for common platforms

**Beancount not installed:**
- Error message with: `pip install beancount`
- Link to installation documentation

**No test files found:**
- Warning message (not error)
- Exit code 0 (not a failure condition)
- Suggest checking directory structure

### Verbose Mode (`--verbose`)

When enabled, provides detailed output:
- Print each test name as it runs
- Show actual tokens for failed tests
- Include bridge stderr output
- Show timing information per test
- Display JSON communication (with `--debug`)

## Testing & Validation

### Testing the Test Harness

**Unit Tests (Zig)**
- `src/yaml.zig` tests: Parse valid/invalid YAML, schema validation
- `src/bridge.zig` tests: Mock stdin/stdout, test JSON serialization
- `src/reporter.zig` tests: Verify output formats (TAP, JUnit XML)
- Run via: `zig build test`

**Integration Tests**
- `test/fixtures/` contains known-good and known-bad test files
- `test/fixtures/valid_minimal.yaml`: Single test that should pass
- `test/fixtures/invalid_token.yaml`: Expected failure case
- `test/fixtures/malformed.yaml`: Invalid YAML syntax
- Harness runs these, verify exit codes and output
- Ensures end-to-end flow works correctly

### Bootstrap Validation

**Incremental Development:**
1. Create `spec/lexer/smoke_test.yaml` with 3-5 basic tokens
2. Get end-to-end flow working with this minimal test
3. Verify: Zig harness ↔ Python bridge ↔ Beancount lexer
4. Prove the approach before investing in comprehensive tests
5. Then expand to full 6-file coverage

### CI/CD Validation

**GitHub Actions Matrix:**
- Test on: Ubuntu (latest, 20.04), macOS (latest)
- Python versions: 3.9, 3.10, 3.11, 3.12
- Ensures Beancount compatibility across versions
- Cache Python dependencies for faster CI
- Upload test results as artifacts

**CI Workflow:**
```yaml
- Install Zig
- Install Python
- pip install -r bridge/requirements.txt
- zig build test
- Upload JUnit XML results
```

**Fail Fast Option:**
- Optional `--fail-fast` flag stops on first failure
- Useful for rapid iteration during development

### Documentation Tests

**Executable Documentation:**
- README examples must actually work
- Copy commands directly to CI
- Keep docs synchronized with actual CLI flags
- Version documentation with releases

## CLI Interface

### Basic Usage

```bash
# Run all lexer tests
zig build run

# Run specific test file
zig build run -- spec/lexer/tokens_basic.yaml

# Verbose output
zig build run -- --verbose

# Filter tests by name pattern
zig build run -- --filter "number"

# Generate JUnit XML
zig build run -- --format junit --output results.xml

# Debug mode (show JSON communication)
zig build run -- --debug
```

### CLI Flags

- `--verbose, -v`: Detailed output including token details
- `--debug`: Show JSON protocol communication
- `--filter <pattern>`: Run only tests matching pattern
- `--format <type>`: Output format (human, tap, junit)
- `--output <file>`: Write results to file
- `--timeout <seconds>`: Bridge timeout (default: 5)
- `--fail-fast`: Stop on first failure
- `--help, -h`: Show help message

## Implementation Phases

### Phase 1: Bootstrap (Smoke Test)
1. Set up Zig project structure with `build.zig`
2. Create minimal Python bridge (`lexer_bridge.py`)
3. Create `smoke_test.yaml` with 5 basic tokens
4. Implement basic Zig harness (no YAML parsing yet, hardcode test)
5. Get end-to-end flow working
6. **Validation**: One test passes through full pipeline

### Phase 2: Core Infrastructure
1. Add zig-yaml dependency for YAML parsing
2. Implement `yaml.zig` with schema validation
3. Implement `bridge.zig` for process management
4. Implement `reporter.zig` with human-readable output
5. Add error handling throughout
6. **Validation**: Smoke test runs via YAML file

### Phase 3: Comprehensive Test Coverage
1. Write all 6 lexer test YAML files:
   - `tokens_basic.yaml` (~30 tests)
   - `tokens_numbers.yaml` (~25 tests)
   - `tokens_strings.yaml` (~20 tests)
   - `tokens_accounts.yaml` (~25 tests)
   - `tokens_currencies.yaml` (~15 tests)
   - `tokens_edge_cases.yaml` (~20 tests)
2. Total: ~135 comprehensive lexer tests
3. **Validation**: All tests run, identify any spec/implementation mismatches

### Phase 4: CI/CD & Documentation
1. Set up GitHub Actions workflow
2. Write `docs/README.md` with usage instructions
3. Write `docs/CONTRIBUTING.md` for test authors
4. Add CLI polish (colors, progress bars)
5. Generate test coverage report
6. **Validation**: CI passes, documentation complete

## Success Criteria

- [ ] All 6 lexer test files implemented with ~135 total tests
- [ ] Zig harness successfully executes all tests
- [ ] Python bridge correctly wraps Beancount lexer
- [ ] Test results accurately identify pass/fail
- [ ] CI/CD integration working on GitHub Actions
- [ ] Documentation complete and accurate
- [ ] Zero known bugs in test harness
- [ ] <5% false positive rate (test bugs vs actual issues)

## Future Extensions

**Beyond Lexer Layer:**
- Grammar tests (Layer 2) can reuse same infrastructure
- Semantic tests (Layer 3) require different bridge (not just lexer)
- Plugin tests (Layer 5) need plugin loading mechanism

**Alternative Implementations:**
- Replace Python bridge with Rust/Zig/Clojure implementations
- Comparative testing across implementations
- Performance benchmarking

**Test Enhancements:**
- Property-based testing (generate random valid inputs)
- Fuzzing for edge case discovery
- Performance regression testing

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Spec doesn't match Beancount | High | This is the goal - document discrepancies |
| Python FFI complexity | Medium | Use simple stdin/stdout JSON, not C API |
| Zig learning curve | Medium | Start simple, iterate, community support |
| Test maintenance burden | Medium | Clear contributing guide, automated validation |
| CI flakiness | Low | Pin dependency versions, retry on failure |

## References

- Beancount Formal Specification: `BEANCOUNT-SPECIFICATION.md` (section 3: Layer 1)
- Beancount Python: https://github.com/beancount/beancount
- Zig YAML libraries: https://github.com/kubkon/zig-yaml
- Test format examples: BEANCOUNT-SPECIFICATION.md section 3.3

---

**Next Steps**: Create implementation plan using writing-plans skill.
