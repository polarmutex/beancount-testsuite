# beancount-testsuite
WIP: a compliance test suite for beancount

## Overview
This project provides a comprehensive test suite for Beancount parsers and implementations. Tests are written in YAML format and can be run against any Beancount-compatible parser.

## Test Types

### Lexer Tests
Located in `spec/lexer/`, these tests validate tokenization of Beancount syntax.

### Parser Tests
Located in `spec/parser/`, these tests validate the parsing of Beancount directives into abstract syntax trees.

## Running Tests

### Lexer Tests
```bash
zig build run -- spec/lexer/tokens_basic.yaml
```

### Parser Tests
```bash
zig build run -- --mode parser spec/parser/open_close.yaml
```

## Parser Test Format

Parser tests validate that Beancount input is correctly parsed into the expected AST structure:

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
```

For detailed information on writing parser tests, see [docs/WRITING_PARSER_TESTS.md](docs/WRITING_PARSER_TESTS.md).

## Contributing
Contributions welcome. Please ensure all tests follow the YAML schema and include appropriate test coverage.
