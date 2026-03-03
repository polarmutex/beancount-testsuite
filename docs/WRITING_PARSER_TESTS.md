# Writing Parser Tests

## Introduction

Parser tests validate that Beancount implementations correctly parse input text into Abstract Syntax Trees (ASTs). These tests ensure consistent parsing behavior across different Beancount implementations.

## File Structure

Parser test files are YAML documents located in `spec/parser/`. Each file should focus on a specific directive type or parsing scenario.

### Basic Structure

```yaml
version: "1.0"
category: "parser/directives"
description: "Brief description of what this file tests"

tests:
  - name: "Test case name"
    input: "Beancount input text"
    expected:
      type: "directive_type"
      # Expected AST attributes
    expected_errors: []
```

## YAML Schema

### Top-Level Fields

- **version**: Schema version (currently "1.0")
- **category**: Test category using slash notation (e.g., "parser/directives", "parser/transactions")
- **description**: Human-readable description of the test file's purpose
- **tests**: Array of test cases

### Test Case Fields

- **name**: Descriptive name for the test case
- **input**: Beancount syntax to parse (string or multiline block)
- **expected**: Expected AST structure (for successful parsing)
- **expected_entries**: Alternative format using node_type hierarchy
- **expected_errors**: Array of expected parsing errors (empty if parsing should succeed)

## Input Format

### Single-Line Input

```yaml
input: "2020-01-01 open Assets:Checking"
```

### Multi-Line Input

Use YAML block scalar syntax for transactions and complex directives:

```yaml
input: |
  2020-01-15 * "Grocery store"
    Assets:Checking  -50.00 USD
    Expenses:Food     50.00 USD
```

## Expected Structure Formats

### Simple Format (Key-Value)

Best for straightforward directives:

```yaml
expected:
  type: "open"
  date: "2020-01-01"
  account: "Assets:Checking"
  currencies: ["USD"]
```

### Node Format (Hierarchical)

Best for complex nested structures:

```yaml
expected_entries:
  - node_type: Open
    attributes:
      date: "2024-01-01"
      account: "Assets:Checking"
    children:
      - node_type: Currency
        attributes:
          value: "USD"
        children: []
```

## Directive Type Examples

### Open Directive

```yaml
- name: "Open with currency constraint"
  input: "2020-01-01 open Assets:Checking USD"
  expected:
    type: "open"
    date: "2020-01-01"
    account: "Assets:Checking"
    currencies: ["USD"]
```

### Close Directive

```yaml
- name: "Simple close directive"
  input: "2020-12-31 close Assets:Checking"
  expected:
    type: "close"
    date: "2020-12-31"
    account: "Assets:Checking"
```

### Transaction

```yaml
- name: "Transaction with payee"
  input: |
    2020-01-15 * "Safeway" "Grocery shopping"
      Assets:Checking  -50.00 USD
      Expenses:Food     50.00 USD
  expected:
    type: "transaction"
    date: "2020-01-15"
    flag: "*"
    payee: "Safeway"
    narration: "Grocery shopping"
    postings:
      - account: "Assets:Checking"
        amount: "-50.00"
        currency: "USD"
      - account: "Expenses:Food"
        amount: "50.00"
        currency: "USD"
```

### Balance and Pad

```yaml
- name: "Balance assertion"
  input: "2020-03-01 balance Assets:Checking 1500.00 USD"
  expected:
    type: "balance"
    date: "2020-03-01"
    account: "Assets:Checking"
    amount: "1500.00"
    currency: "USD"

- name: "Pad directive"
  input: "2020-02-28 pad Assets:Checking Equity:Opening-Balances"
  expected:
    type: "pad"
    date: "2020-02-28"
    account: "Assets:Checking"
    source_account: "Equity:Opening-Balances"
```

### Price and Note

```yaml
- name: "Price directive"
  input: "2020-06-15 price AAPL 325.00 USD"
  expected:
    type: "price"
    date: "2020-06-15"
    commodity: "AAPL"
    amount: "325.00"
    currency: "USD"

- name: "Note directive"
  input: "2020-07-01 note Assets:Checking \"Account opened today\""
  expected:
    type: "note"
    date: "2020-07-01"
    account: "Assets:Checking"
    comment: "Account opened today"
```

### Tag Stack (pushtag/poptag)

```yaml
- name: "Pushtag directive"
  input: "pushtag #trip-2020"
  expected:
    type: "pushtag"
    tag: "trip-2020"

- name: "Poptag directive"
  input: "poptag #trip-2020"
  expected:
    type: "poptag"
    tag: "trip-2020"
```

### Options, Plugin, Include

```yaml
- name: "Option directive"
  input: "option \"title\" \"My Ledger\""
  expected:
    type: "option"
    key: "title"
    value: "My Ledger"

- name: "Plugin directive"
  input: "plugin \"beancount.plugins.auto_accounts\""
  expected:
    type: "plugin"
    name: "beancount.plugins.auto_accounts"

- name: "Include directive"
  input: "include \"accounts.beancount\""
  expected:
    type: "include"
    filename: "accounts.beancount"
```

## Expected Errors

For tests that should fail parsing, specify expected errors:

```yaml
- name: "Invalid date format"
  input: "20-01-01 open Assets:Checking"
  expected_errors:
    - type: "parse_error"
      message: "Invalid date format"
      line: 1
      column: 1
```

When `expected_errors` is non-empty, the test expects parsing to fail. When it's empty or omitted, parsing should succeed.

## Best Practices

### Test Organization

1. **One file per directive type**: Group related tests (e.g., all Open/Close tests in `open_close.yaml`)
2. **Progressive complexity**: Start with simple cases, then add edge cases
3. **Descriptive names**: Use clear test names that describe what's being validated
4. **Minimal examples**: Keep test cases as simple as possible while testing the specific feature

### Test Coverage

Ensure coverage of:
- Basic valid syntax
- Optional fields (with and without)
- Edge cases (empty strings, special characters)
- Error conditions (invalid syntax, missing fields)
- Variations (different flags, multiple currencies, etc.)

### Input Formatting

- Use single-line strings for simple directives
- Use YAML block scalars (`|`) for multi-line inputs
- Preserve proper indentation in multi-line inputs
- Avoid trailing whitespace

### Expected Structure

- Include all required fields in the expected structure
- Use consistent field names matching the parser's output
- Specify empty arrays explicitly for fields that should be empty
- Use strings for dates, amounts, and other parseable values

## Memory Management Notes

### For Test Framework Developers

Parser tests create AST nodes that must be properly managed:

1. **Allocation**: AST nodes are allocated by the parser being tested
2. **Ownership**: Test framework takes ownership of returned AST
3. **Cleanup**: Test framework must free all AST nodes after validation
4. **Expected Structure**: The expected YAML structure is used for comparison only; no AST nodes are created from it

### Memory Safety

When implementing parser test runners:
- Free all AST nodes after each test case
- Handle allocation failures gracefully
- Ensure cleanup happens even if validation fails
- Use arena allocators for temporary test data

## Running Parser Tests

### Single File

```bash
zig build run -- --mode parser spec/parser/open_close.yaml
```

### Multiple Files

```bash
zig build run -- --mode parser spec/parser/transactions.yaml
zig build run -- --mode parser spec/parser/balance_pad.yaml
```

### All Parser Tests

```bash
for file in spec/parser/*.yaml; do
  zig build run -- --mode parser "$file"
done
```

## Example Test File

Complete example of a well-structured parser test file:

```yaml
version: "1.0"
category: "parser/directives"
description: "Open and Close directive parsing tests"

tests:
  - name: "Simple open directive"
    input: "2020-01-01 open Assets:Checking"
    expected:
      type: "open"
      date: "2020-01-01"
      account: "Assets:Checking"
      currencies: []

  - name: "Open with currency constraint"
    input: "2020-01-01 open Assets:Checking USD"
    expected:
      type: "open"
      date: "2020-01-01"
      account: "Assets:Checking"
      currencies: ["USD"]

  - name: "Open with multiple currencies"
    input: "2020-01-01 open Assets:Checking USD,EUR,GBP"
    expected:
      type: "open"
      date: "2020-01-01"
      account: "Assets:Checking"
      currencies: ["USD", "EUR", "GBP"]

  - name: "Simple close directive"
    input: "2020-12-31 close Assets:Checking"
    expected:
      type: "close"
      date: "2020-12-31"
      account: "Assets:Checking"
```

## Contributing

When contributing parser tests:
1. Follow the established YAML schema
2. Add tests to appropriate category files
3. Ensure tests are minimal and focused
4. Include both positive (valid) and negative (error) test cases
5. Update this documentation if adding new directive types or patterns
