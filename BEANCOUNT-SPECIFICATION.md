# Beancount Formal Specification
## A Multi-Layer Implementation-Independent Standard

**Version**: 0.1.0-draft
**Status**: Proposal
**Authors**: Community-driven
**Purpose**: Enable interoperable Beancount implementations across languages

---

## 1. Introduction

### 1.1 Motivation

With multiple Beancount implementations emerging (Rust, Zig, Clojure, Go, etc.), the ecosystem needs an **implementation-independent specification** that:

1. **Defines canonical behavior** independent of Python reference implementation
2. **Enables compliance testing** for alternative implementations
3. **Facilitates language evolution** through RFC-style governance
4. **Preserves interoperability** via standard data interchange formats

### 1.2 Design Principles

- **Layered specification**: Separate syntax, semantics, and data model concerns
- **Test-driven compliance**: Reference test suite defines conformance
- **Language-agnostic**: No bias toward any implementation language
- **Backward compatible**: Preserve existing Beancount file compatibility
- **Extensible**: Plugin and custom directive support

### 1.3 Relationship to Reference Implementation

The Python Beancount implementation serves as the **reference implementation** for v2.x behavior. This specification aims to:
- Formalize implicit behaviors from reference implementation
- Define explicit semantics for edge cases
- Enable divergence for v3.x evolution

---

## 2. Specification Layers

### Layer 1: Lexical Syntax (Tokens)
**Format**: Flex-compatible regular expressions
**Reference**: `beancount/parser/lexer.l`
**Compliance**: Implementations MUST recognize identical token streams

### Layer 2: Grammar (Syntax)
**Format**: EBNF + Bison/YACC reference
**Reference**: `beancount/parser/grammar.y`
**Compliance**: Implementations MUST accept identical parse trees

### Layer 3: Semantic Model (Behavior)
**Format**: Operational semantics + test suite
**Reference**: This document + compliance tests
**Compliance**: Implementations MUST produce equivalent outputs

### Layer 4: Data Interchange (Protocol Buffers)
**Format**: Protocol Buffer v3 definitions
**Reference**: `beancount/v3/beancount.proto` (planned)
**Compliance**: Implementations MUST serialize/deserialize identically

### Layer 5: Plugin API
**Format**: Interface contracts + behavior specifications
**Reference**: Plugin developer guide
**Compliance**: Implementations SHOULD support standard plugin interfaces

---

## 3. Layer 1: Lexical Specification

### 3.1 Token Catalog

#### 3.1.1 Structural Tokens
```ebnf
INDENT      := [ \t]+          (* at line beginning *)
EOL         := \n | \r\n       (* line terminator *)
WHITESPACE  := [ \t]+          (* inline, non-significant *)
COMMENT     := ';' [^\n]*      (* line comment *)
```

#### 3.1.2 Keywords (Case-Sensitive)
```ebnf
TXN       := "txn"
BALANCE   := "balance"
OPEN      := "open"
CLOSE     := "close"
COMMODITY := "commodity"
PAD       := "pad"
EVENT     := "event"
PRICE     := "price"
NOTE      := "note"
DOCUMENT  := "document"
QUERY     := "query"
CUSTOM    := "custom"
PUSHTAG   := "pushtag"
POPTAG    := "poptag"
PUSHMETA  := "pushmeta"
POPMETA   := "popmeta"
OPTION    := "option"
INCLUDE   := "include"
PLUGIN    := "plugin"
```

#### 3.1.3 Literals
```ebnf
DATE     := DIGIT{4} '-' DIGIT{2} '-' DIGIT{2}
          | DIGIT{4} '/' DIGIT{2} '/' DIGIT{2}

NUMBER   := [+-]? DIGIT+ ('.' DIGIT+)?
          | [+-]? DIGIT{1,3} (',' DIGIT{3})+ ('.' DIGIT+)?

STRING   := '"' ( [^"\\\n] | ESCAPE_SEQ )* '"'

ACCOUNT  := ACCOUNT_TYPE ':' COMPONENT ( ':' COMPONENT )*
ACCOUNT_TYPE := 'Assets' | 'Liabilities' | 'Equity' | 'Income' | 'Expenses'
COMPONENT    := [A-Z0-9] [A-Za-z0-9-]*

CURRENCY := [A-Z] [A-Z0-9'._-]* [A-Z]
          | '/' [A-Z0-9]+

TAG      := '#' [A-Za-z0-9-_/.]+
LINK     := '^' [A-Za-z0-9-_/.]+

KEY      := [a-z] [a-z0-9-_]*   (* metadata key *)
```

#### 3.1.4 Operators & Delimiters
```ebnf
PIPE       := '|'
AT         := '@'
ATAT       := '@@'
LCURL      := '{'
RCURL      := '}'
LCURLCURL  := '{{'
RCURLCURL  := '}}'
LPAREN     := '('
RPAREN     := ')'
COMMA      := ','
TILDE      := '~'
HASH       := '#'
ASTERISK   := '*'
SLASH      := '/'
COLON      := ':'
PLUS       := '+'
MINUS      := '-'
EQUAL      := '='
```

#### 3.1.5 Transaction Flags
```ebnf
FLAG := '!' | '&' | '?' | '%' | [A-Z] | [a-z]
```

### 3.2 Lexical Rules

#### 3.2.1 Whitespace Handling
1. **Line-initial whitespace** → `INDENT` token
2. **Inline whitespace** → discarded (not tokenized)
3. **Blank lines** → multiple `EOL` tokens

#### 3.2.2 Comment Processing
1. Lines beginning with `;` → entire line discarded
2. Inline `;` → remainder of line discarded
3. Comments do NOT produce tokens

#### 3.2.3 Token Precedence (Longest Match)
1. Keywords matched before identifiers
2. `@@` matched before `@`
3. `{{` matched before `{`
4. Multi-character operators before single-character

### 3.3 Compliance Test Requirements

Implementations MUST pass lexer tests in `spec/lexer/`:
```
spec/lexer/
  ├── tokens_basic.yaml          # Core token recognition
  ├── tokens_numbers.yaml        # Number format variations
  ├── tokens_strings.yaml        # String escaping
  ├── tokens_accounts.yaml       # Account name parsing
  ├── tokens_currencies.yaml     # Currency/commodity patterns
  └── tokens_edge_cases.yaml     # Ambiguous situations
```

**Test format**:
```yaml
- name: "Basic number token"
  input: "123.45"
  expected:
    - type: NUMBER
      value: "123.45"
      line: 1
      column: 1
```

---

## 4. Layer 2: Grammar Specification

### 4.1 EBNF Grammar

#### 4.1.1 Top-Level Structure
```ebnf
File ::= Declaration* EOF

Declaration ::=
    | Directive EOL
    | Entry EOL
    | PragmaDirective EOL
    | EOL              (* blank lines *)

Entry ::=
    | Transaction
    | BalanceDirective
    | OpenDirective
    | CloseDirective
    | CommodityDirective
    | PadDirective
    | EventDirective
    | NoteDirective
    | DocumentDirective
    | PriceDirective
    | QueryDirective
    | CustomDirective
```

#### 4.1.2 Transaction Grammar
```ebnf
Transaction ::=
    DATE TxnFlag TxnStrings TagsLinks EOL Posting+

TxnFlag ::= TXN | FLAG | ASTERISK | HASH

TxnStrings ::=
    | STRING                    (* narration only *)
    | STRING STRING             (* payee + narration *)

TagsLinks ::= (TAG | LINK)*

Posting ::=
    INDENT OptFlag ACCOUNT IncompleteAmount? CostSpec? Price? EOL
    KeyValueList?

OptFlag ::= FLAG?

IncompleteAmount ::=
    | (* empty - amount elided *)
    | NUMBER CURRENCY
    | NUMBER                    (* currency elided *)
    | CURRENCY                  (* number elided *)

CostSpec ::=
    | LCURL CostCompList RCURL           (* per-unit cost *)
    | LCURLCURL CostCompList RCURLCURL   (* total cost *)

CostCompList ::=
    | (* empty *)
    | CostComp
    | CostCompList COMMA CostComp

CostComp ::=
    | NUMBER CURRENCY          (* cost per unit *)
    | DATE                     (* acquisition date *)
    | STRING                   (* lot label *)
    | ASTERISK                 (* merge costs flag *)
    | HASH                     (* average cost booking *)

Price ::=
    | AT Amount                (* per-unit price *)
    | ATAT Amount              (* total price *)

Amount ::= NumberExpr CURRENCY

NumberExpr ::=
    | NUMBER
    | LPAREN NumberExpr RPAREN
    | NumberExpr PLUS NumberExpr
    | NumberExpr MINUS NumberExpr
    | NumberExpr ASTERISK NumberExpr
    | NumberExpr SLASH NumberExpr
    | PLUS NumberExpr
    | MINUS NumberExpr
```

#### 4.1.3 Other Directives (Abbreviated)
```ebnf
OpenDirective ::=
    DATE OPEN ACCOUNT CurrencyList? BookingMethod? EOL KeyValueList?

CloseDirective ::=
    DATE CLOSE ACCOUNT EOL KeyValueList?

BalanceDirective ::=
    DATE BALANCE ACCOUNT AmountTolerance EOL KeyValueList?

AmountTolerance ::=
    | NUMBER CURRENCY
    | NUMBER TILDE NUMBER CURRENCY

PadDirective ::=
    DATE PAD ACCOUNT ACCOUNT EOL KeyValueList?

PriceDirective ::=
    DATE PRICE CURRENCY Amount EOL KeyValueList?

EventDirective ::=
    DATE EVENT STRING STRING EOL KeyValueList?

NoteDirective ::=
    DATE NOTE ACCOUNT STRING TagsLinks EOL KeyValueList?

DocumentDirective ::=
    DATE DOCUMENT ACCOUNT STRING TagsLinks EOL KeyValueList?

CommodityDirective ::=
    DATE COMMODITY CURRENCY EOL KeyValueList?

QueryDirective ::=
    DATE QUERY STRING STRING EOL KeyValueList?

CustomDirective ::=
    DATE CUSTOM STRING CustomValue* EOL KeyValueList?

CustomValue ::= STRING | NUMBER | CURRENCY | DATE | ACCOUNT | TAG | BOOL
```

#### 4.1.4 Metadata
```ebnf
KeyValueList ::= (INDENT KeyValue EOL)*

KeyValue ::= KEY COLON KeyValueValue

KeyValueValue ::=
    | STRING
    | ACCOUNT
    | DATE
    | CURRENCY
    | TAG
    | NUMBER
    | Amount
    | BOOL
```

#### 4.1.5 Pragma Directives
```ebnf
OptionDirective ::= OPTION STRING STRING EOL

PluginDirective ::= PLUGIN STRING STRING? EOL

IncludeDirective ::= INCLUDE STRING EOL

PushTagDirective ::= PUSHTAG TAG EOL

PopTagDirective ::= POPTAG TAG EOL

PushMetaDirective ::= PUSHMETA KeyValue EOL

PopMetaDirective ::= POPMETA KEY COLON EOL
```

### 4.2 Grammar Compliance Tests

Implementations MUST pass parser tests in `spec/grammar/`:
```
spec/grammar/
  ├── transactions/
  │   ├── basic_txn.yaml
  │   ├── multiposting.yaml
  │   ├── interpolation.yaml      # Amount elision
  │   ├── flags.yaml
  │   └── tags_links.yaml
  ├── directives/
  │   ├── open_close.yaml
  │   ├── balance.yaml
  │   ├── pad.yaml
  │   ├── price.yaml
  │   └── custom.yaml
  ├── amounts/
  │   ├── simple_amounts.yaml
  │   ├── expressions.yaml
  │   └── costs_prices.yaml
  └── metadata/
      └── key_value.yaml
```

---

## 5. Layer 3: Semantic Specification

### 5.1 Core Semantics

#### 5.1.1 Transaction Balancing

**Rule**: Within a transaction, postings MUST balance to zero for each currency.

**Formal definition**:
```
∀ txn ∈ Transactions, ∀ currency ∈ Currencies:
  Σ(p.weight(currency) | p ∈ txn.postings) = 0

where weight(posting, currency) =
  | posting.units.amount           if posting.units.currency = currency ∧ ¬posting.cost ∧ ¬posting.price
  | posting.units.amount × posting.cost.amount
                                   if posting.units.currency ≠ currency ∧ posting.cost.currency = currency
  | posting.units.amount × posting.price.amount
                                   if posting.units.currency ≠ currency ∧ posting.price.currency = currency
  | 0                              otherwise
```

**Test requirement**: `spec/semantics/balancing/`

#### 5.1.2 Amount Interpolation

**Rule**: Exactly ONE posting per transaction MAY omit amount; that amount is auto-computed to balance.

**Algorithm**:
```python
def interpolate(transaction):
    elided_postings = [p for p in transaction.postings if not p.amount]

    if len(elided_postings) == 0:
        # All amounts specified - verify balance
        return verify_balance(transaction)

    if len(elided_postings) > 1:
        raise Error("Multiple elided amounts")

    # Compute residual for each currency
    residuals = {}
    for posting in transaction.postings:
        if posting.amount:
            currency = posting.weight_currency()
            amount = posting.weight_amount()
            residuals[currency] = residuals.get(currency, 0) - amount

    # Assign residual to elided posting
    if len(residuals) != 1:
        raise Error("Cannot interpolate - multiple currencies")

    currency, amount = residuals.popitem()
    elided_postings[0].amount = Amount(amount, currency)
```

**Test requirement**: `spec/semantics/interpolation/`

#### 5.1.3 Account Lifecycle

**States**: `UNOPENED` → `OPEN` → `CLOSED`

**Rules**:
1. Posting to `UNOPENED` account → ERROR (unless `auto_account_opening = TRUE`)
2. Posting to `CLOSED` account → ERROR
3. `open` directive on `OPEN` account → ERROR
4. `close` directive on `UNOPENED` or `CLOSED` account → ERROR
5. Parent account implicitly opened when child opened (if `auto_account_opening = TRUE`)

**Test requirement**: `spec/semantics/account_lifecycle/`

#### 5.1.4 Balance Assertions

**Semantics**:
```
balance_directive(date, account, expected_amount) asserts:
  inventory[account].get_currency_units(expected_amount.currency)
    AT END OF (date - 1 day)
  EQUALS expected_amount.number ± tolerance
```

**With tolerance**:
```
2024-01-15 balance Assets:Checking  1000.00 ~ 0.01 USD

Accepts: [999.99, 1000.01]
Rejects: 999.98, 1000.02
```

**Test requirement**: `spec/semantics/balance/`

#### 5.1.5 Pad Directive

**Semantics**:
```
Given:
  date1: pad Assets:Checking Equity:Opening-Balances
  date2: balance Assets:Checking 1000.00 USD

where date2 > date1

Algorithm:
  1. Compute inventory[Assets:Checking] at date1
  2. Compute required_amount = 1000.00 - inventory_amount
  3. Insert synthetic transaction at date1:
       date1 * "Opening balance for Assets:Checking (auto)"
         Assets:Checking      required_amount USD
         Equity:Opening-Balances
```

**Test requirement**: `spec/semantics/pad/`

#### 5.1.6 Cost Basis & Lot Matching

**Acquisition** (posting with cost):
```
2024-01-10 * "Buy stock"
  Assets:Investment:AAPL  10 AAPL {150.00 USD}
  Assets:Cash            -1500.00 USD

Creates lot:
  {commodity: AAPL, units: 10, cost: 150.00 USD, date: 2024-01-10, label: null}
```

**Reduction** (posting with cost spec):
```
2024-06-15 * "Sell stock"
  Assets:Investment:AAPL  -5 AAPL {150.00 USD}  @ 175.00 USD
  Assets:Cash              875.00 USD
  Income:Capital-Gains

Matches against lot with cost=150.00, reduces by 5 units
Interpolates Income:Capital-Gains = (175-150)*5 = 125.00 USD
```

**Booking methods** (when multiple lots match):
- `STRICT`: Error if ambiguous
- `FIFO`: First-in-first-out
- `LIFO`: Last-in-first-out
- `AVERAGE`: Average cost across lots
- `NONE`: Allow ambiguous (Python Beancount v2 default)

**Test requirement**: `spec/semantics/cost_basis/`

### 5.2 Plugin Transformation Semantics

**Plugin model**: Directives → Transform → Directives

**Contract**:
```python
def plugin_transform(entries: List[Directive],
                     options: Dict,
                     config: str) -> Tuple[List[Directive], List[Error]]:
    """
    Args:
      entries: Parsed and sorted directives
      options: Global options dict
      config: Plugin configuration string

    Returns:
      (transformed_entries, errors)

    Invariants:
      - Output entries MUST be sorted by date
      - Plugin MUST NOT modify entries in-place (immutability)
      - Errors MUST include source location metadata
    """
    pass
```

**Test requirement**: `spec/plugins/`

---

## 6. Layer 4: Data Interchange (Protocol Buffers)

### 6.1 Core Data Structures

```protobuf
syntax = "proto3";
package beancount.v3;

// Core directives
message Directive {
  oneof directive_type {
    Transaction transaction = 1;
    Balance balance = 2;
    Open open = 3;
    Close close = 4;
    Commodity commodity = 5;
    Pad pad = 6;
    Event event = 7;
    Note note = 8;
    Document document = 9;
    Price price = 10;
    Query query = 11;
    Custom custom = 12;
  }

  // Metadata common to all directives
  Metadata meta = 100;
}

message Transaction {
  Date date = 1;
  string flag = 2;
  optional string payee = 3;
  string narration = 4;
  repeated string tags = 5;
  repeated string links = 6;
  repeated Posting postings = 7;
}

message Posting {
  optional string flag = 1;
  string account = 2;
  optional Amount units = 3;
  optional CostSpec cost = 4;
  optional Amount price = 5;
  Metadata meta = 6;
}

message Amount {
  Decimal number = 1;
  string currency = 2;
}

message CostSpec {
  optional Amount number_per = 1;   // Per-unit cost
  optional Amount number_total = 2; // Total cost
  optional Date date = 3;
  optional string label = 4;
  optional bool merge_cost = 5;
}

message Open {
  Date date = 1;
  string account = 2;
  repeated string currencies = 3;
  optional string booking = 4;
}

message Balance {
  Date date = 1;
  string account = 2;
  Amount amount = 3;
  optional Decimal tolerance = 4;
}

// ... (other directive messages)

// Primitives
message Date {
  int32 year = 1;
  int32 month = 2;
  int32 day = 3;
}

message Decimal {
  string value = 1;  // String representation for precision
}

message Metadata {
  map<string, MetaValue> kv = 1;
  string filename = 2;
  int32 lineno = 3;
}

message MetaValue {
  oneof value {
    string str = 1;
    Decimal number = 2;
    Amount amount = 3;
    Date date = 4;
    string account = 5;
    string tag = 6;
    bool boolean = 7;
  }
}
```

### 6.2 Serialization Compliance

**Requirements**:
1. Implementations MUST serialize identical directives to identical protobuf bytes
2. Implementations MUST deserialize any conformant protobuf to equivalent directives
3. Decimal precision MUST be preserved (no float conversion)
4. Metadata order MUST be preserved (insertion order)

**Test requirement**: `spec/protobuf/`

---

## 7. Layer 5: Compliance Testing

### 7.1 Test Suite Organization

```
spec/
├── lexer/              # Token recognition tests
├── grammar/            # Parse tree tests
├── semantics/          # Behavior tests
│   ├── balancing/
│   ├── interpolation/
│   ├── cost_basis/
│   ├── account_lifecycle/
│   ├── balance/
│   └── pad/
├── plugins/            # Plugin API tests
├── protobuf/           # Serialization tests
└── regression/         # Real-world file tests
```

### 7.2 Test Format (YAML)

```yaml
# Example: spec/semantics/balancing/basic.yaml
version: "1.0"
category: "semantics/balancing"
tests:
  - name: "Simple balanced transaction"
    input: |
      2024-01-15 * "Paycheck"
        Assets:Checking   1000.00 USD
        Income:Salary    -1000.00 USD
    expected:
      status: SUCCESS
      directives:
        - type: Transaction
          postings: 2
          balanced: true

  - name: "Unbalanced transaction"
    input: |
      2024-01-15 * "Broken"
        Assets:Checking   1000.00 USD
        Income:Salary     -900.00 USD
    expected:
      status: ERROR
      error_type: "BalanceError"
      error_message_contains: "does not balance"
```

### 7.3 Compliance Levels

**Level 1: Core Compliance** (REQUIRED)
- All lexer tests pass
- All grammar tests pass
- All semantics/balancing tests pass
- All semantics/interpolation tests pass
- All semantics/account_lifecycle tests pass

**Level 2: Full Compliance** (RECOMMENDED)
- Level 1 +
- All semantics tests pass (including cost_basis, balance, pad)
- All protobuf tests pass

**Level 3: Plugin Support** (OPTIONAL)
- Level 2 +
- Plugin API implemented
- Standard plugins supported

---

## 8. Governance & Evolution (RFC Process)

### 8.1 RFC Workflow

**Proposing changes**:
1. Create `RFC-NNNN-title.md` in `rfcs/` directory
2. Open pull request for discussion
3. Community review period (minimum 2 weeks)
4. Approval requires consensus from:
   - At least 2 implementation maintainers
   - Original Beancount author (Martin Blais) or delegate
5. Merge RFC → creates reference implementation requirement

**RFC template**:
```markdown
# RFC-0001: Feature Title

- **Status**: Draft | Review | Accepted | Rejected | Implemented
- **Author**: Name <email>
- **Created**: YYYY-MM-DD
- **Updated**: YYYY-MM-DD

## Summary
One-paragraph explanation

## Motivation
Why this change?

## Detailed Design
Technical specification

## Backward Compatibility
Breaking changes?

## Reference Implementation
Link to implementation

## Alternatives Considered
What else was evaluated?

## Open Questions
Unresolved issues
```

### 8.2 Versioning

**Specification versions**: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (new compliance tests that fail old implementations)
- **MINOR**: Additive changes (new directives, optional features)
- **PATCH**: Clarifications, bug fixes in spec text

**Compatibility policy**:
- Implementations MUST declare supported spec version(s)
- Files MAY declare minimum spec version via:
  ```
  option "spec_version" "1.0.0"
  ```

---

## 9. Implementation Checklist

### For New Implementations

- [ ] **Lexer**: Implement token recognition per Layer 1
- [ ] **Parser**: Implement grammar per Layer 2
- [ ] **Core semantics**: Implement balancing, interpolation (Level 1)
- [ ] **Account lifecycle**: Implement open/close semantics
- [ ] **Balance assertions**: Implement balance directive verification
- [ ] **Cost basis**: Implement lot tracking (Level 2)
- [ ] **Compliance testing**: Pass all Level 1 tests
- [ ] **Protobuf support**: Implement serialization (Level 2)
- [ ] **Documentation**: Document spec version support
- [ ] **Submit to registry**: Add to `IMPLEMENTATIONS.md`

### For Existing Implementations

- [ ] **Gap analysis**: Run compliance test suite
- [ ] **Document deviations**: List non-conformant behaviors
- [ ] **Roadmap**: Plan for compliance improvements
- [ ] **Test contribution**: Submit tests for uncovered behaviors

---

## 10. References

### Official Beancount Resources
- [Beancount Language Syntax](https://beancount.github.io/docs/beancount_language_syntax.html)
- [Grammar (Bison)](https://github.com/beancount/beancount/blob/master/beancount/parser/grammar.y)
- [Lexer (Flex)](https://github.com/beancount/beancount/blob/master/beancount/parser/lexer.l)
- [Beancount v3 Goals](https://beancount.github.io/docs/beancount_v3.html)

### Community Discussions
- [Towards a coherent Beancount developer community](http://www.mail-archive.com/beancount@googlegroups.com/msg07397.html)
- [Google Groups: Beancount](https://groups.google.com/g/beancount)

### Specification Inspirations
- [ECMAScript Specification](https://tc39.es/ecma262/)
- [Rust Reference](https://doc.rust-lang.org/reference/)
- [Protocol Buffers Language Guide](https://protobuf.dev/programming-guides/proto3/)

---

## Appendix A: Why Not SysML?

**Question**: Could SysML (Systems Modeling Language) be used to specify Beancount?

**Answer**: While theoretically possible, SysML is poorly suited for DSL specification:

| SysML Strengths | Beancount Needs |
|-----------------|-----------------|
| Hardware/physical systems | Text processing & data transformation |
| Block diagrams, state machines | Grammar rules, type systems |
| Systems engineering workflows | Language semantics, parsing |
| Tool-heavy (Enterprise Architect, Cameo) | Text-based, version-controllable specs |

**Better alternatives**:
1. **EBNF grammars**: Industry standard for language syntax
2. **Operational semantics**: Formal mathematical semantics for behavior
3. **Test suites**: Executable specifications (preferred for Beancount)
4. **Protocol Buffers**: Data interchange standard (planned for v3)

**Verdict**: Use domain-appropriate formalisms. EBNF + operational semantics + test-driven compliance > SysML for Beancount.

---

## Appendix B: Comparison with Programming Language Specs

| Language | Syntax Spec | Semantics Spec | Reference Impl | Compliance Tests |
|----------|-------------|----------------|----------------|------------------|
| **Python** | PEG grammar | CPython behavior | CPython | pytest suite |
| **Rust** | EBNF | Rust Reference | rustc | rustc tests |
| **JavaScript** | ECMA-262 formal grammar | ECMA-262 algorithms | V8, SpiderMonkey | test262 |
| **Beancount (proposed)** | EBNF + Bison | This document + tests | Python beancount | spec/ suite |

**Key insight**: Successful multi-implementation languages rely on **test-driven compliance** over prose specifications.

---

## Appendix C: Initial Implementation Ports

| Implementation | Language | Status | Spec Version | Notes |
|----------------|----------|--------|--------------|-------|
| **beancount** | Python | Reference | 1.0.0 | Original implementation |
| **limabean** | Clojure | Active | 0.9.0 | Plugin API exploration |
| **beancount-rs** | Rust | Active | 0.8.0 | Performance-focused |
| **zigcount** | Zig | Experimental | 0.5.0 | Memory-safe, fast |
| **gocount** | Go | Experimental | 0.6.0 | Concurrency primitives |

*(Hypothetical - actual implementations may vary)*

---

## Appendix D: Compliance Test Example

**Full test specification**:
```yaml
# spec/semantics/interpolation/basic.yaml
version: "1.0"
category: "semantics/interpolation"
description: "Tests for automatic amount inference"

tests:
  - name: "Single elided posting"
    input: |
      2024-01-15 * "Grocery shopping"
        Assets:Checking
        Expenses:Groceries  50.00 USD
    expected:
      status: SUCCESS
      directives:
        - type: Transaction
          date: "2024-01-15"
          narration: "Grocery shopping"
          postings:
            - account: "Assets:Checking"
              units:
                number: "-50.00"
                currency: "USD"
            - account: "Expenses:Groceries"
              units:
                number: "50.00"
                currency: "USD"

  - name: "Multiple elided postings - ERROR"
    input: |
      2024-01-15 * "Broken transaction"
        Assets:Checking
        Expenses:Groceries
    expected:
      status: ERROR
      error_type: "InterpolationError"
      error_message_contains: "cannot infer"

  - name: "Elided with multi-currency - ERROR"
    input: |
      2024-01-15 * "Currency exchange"
        Assets:Checking:USD
        Assets:Checking:EUR  100.00 EUR
        Expenses:Fees        5.00 USD
    expected:
      status: ERROR
      error_type: "InterpolationError"
      error_message_contains: "multiple currencies"
```

---

## Status & Next Steps

**Current status**: Draft specification (v0.1.0)

**Immediate actions**:
1. [ ] Community review and feedback
2. [ ] Create initial compliance test suite (100 tests)
3. [ ] Validate against Python reference implementation
4. [ ] Port tests to at least 2 alternative implementations
5. [ ] Establish RFC process and governance structure
6. [ ] Create `IMPLEMENTATIONS.md` registry

**Long-term goals**:
1. Beancount v3 adopts this specification formally
2. Protocol Buffer schema finalized
3. All major implementations achieve Level 2 compliance
4. Test suite reaches 1000+ tests covering edge cases

---

**Contributing**: See `CONTRIBUTING.md` for how to propose changes, submit tests, or register implementations.

**License**: This specification is released under CC-BY-4.0. Implementations may use any license.
