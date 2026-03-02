# Beancount Formal Specification Framework - Summary

## What Was Created

A complete **implementation-independent specification framework** for Beancount that enables multiple language implementations to coexist with guaranteed interoperability.

### Documents Created

1. **`BEANCOUNT-SPECIFICATION.md`** - Core specification
   - Multi-layer specification architecture
   - Lexical, grammar, semantic, and data interchange layers
   - RFC-based governance process
   - Compliance testing framework

2. **`SPECIFICATION-EXAMPLE.md`** - Practical implementation guide
   - Real-world examples in Python, Clojure, and Rust
   - Cross-language Protocol Buffer serialization
   - Plugin API compatibility demonstrations
   - Compliance level declarations

3. **`RFC-0001-ZEROSUM-STANDARD.md`** - Example RFC
   - Standardizes the zerosum plugin
   - Shows RFC process in action
   - Includes compliance tests and migration plan

---

## Why Not SysML?

### The Question
Could SysML (Systems Modeling Language) be used to model Beancount as a standard for ports?

### The Answer: **Better Alternatives Exist**

| Approach | SysML | Proposed Framework |
|----------|-------|-------------------|
| **Target domain** | Hardware/physical systems | Text processing DSLs |
| **Specification format** | Visual diagrams (blocks, state machines) | EBNF grammars + operational semantics |
| **Tooling** | Enterprise tools (Cameo, EA) | Text-based, git-friendly |
| **Industry fit** | Systems engineering | Programming language design |
| **Verification** | Manual model validation | Executable test suites |
| **Interoperability** | Model exchange formats | Protocol Buffers + test-driven compliance |

**Verdict**: SysML is theoretically capable but practically ill-suited. The proposed framework uses domain-appropriate standards:

1. **Flex/Bison grammars** (already exist in Beancount)
2. **EBNF notation** (programming language standard)
3. **Operational semantics** (mathematical formalism for behavior)
4. **Protocol Buffers** (Google's data interchange standard)
5. **Test-driven compliance** (executable specifications)

This matches how successful multi-implementation languages (Python, Rust, JavaScript) are specified.

---

## Architecture Overview

### Layer 1: Lexical Specification
**Format**: Flex-compatible regex + token catalog
**Compliance**: Identical token streams across implementations

```ebnf
DATE     := DIGIT{4} '-' DIGIT{2} '-' DIGIT{2}
NUMBER   := [+-]? DIGIT+ ('.' DIGIT+)?
ACCOUNT  := ACCOUNT_TYPE ':' COMPONENT ( ':' COMPONENT )*
```

### Layer 2: Grammar Specification
**Format**: EBNF + Bison/YACC reference
**Compliance**: Identical parse trees across implementations

```ebnf
Transaction ::= DATE TxnFlag TxnStrings TagsLinks EOL Posting+
Posting ::= INDENT ACCOUNT Amount? CostSpec? Price? EOL
```

### Layer 3: Semantic Specification
**Format**: Operational semantics + test suite
**Compliance**: Identical outputs for identical inputs

**Example**: Transaction balancing rule
```
∀ txn ∈ Transactions, ∀ currency ∈ Currencies:
  Σ(p.weight(currency) | p ∈ txn.postings) = 0
```

### Layer 4: Data Interchange
**Format**: Protocol Buffer v3 definitions
**Compliance**: Bit-identical serialization

**Benefit**: Parse with Python → process with Rust → report with Clojure

### Layer 5: Plugin API
**Format**: Interface contracts + behavior specs
**Compliance**: Plugins work across implementations

---

## Compliance Levels

### Level 1: Core Compliance (REQUIRED)
- ✅ Lexer tests pass
- ✅ Grammar tests pass
- ✅ Transaction balancing
- ✅ Amount interpolation
- ✅ Account lifecycle

**Minimal viable Beancount implementation**

### Level 2: Full Compliance (RECOMMENDED)
- ✅ Level 1 +
- ✅ Cost basis & lot matching
- ✅ Balance assertions
- ✅ Pad directives
- ✅ Protocol Buffer serialization

**Production-ready implementation**

### Level 3: Plugin Support (OPTIONAL)
- ✅ Level 2 +
- ✅ Plugin API implemented
- ✅ Standard plugins supported

**Full ecosystem compatibility**

---

## How Implementations Use This

### Example: limabean (Clojure)

**Current status**:
```clojure
(def spec-version "0.9.0")
(def compliance-level "Level 1")  ; Working toward Level 2
```

**Compliance workflow**:
```bash
# 1. Run compliance tests
$ clojure -M:test spec/semantics/balancing/

# 2. Identify gaps
Passed: 45/50 tests
Failed:
  - spec/semantics/cost_basis/average_booking.yaml
  - spec/semantics/pad/basic.yaml

# 3. Implement missing features
# 4. Re-test until 50/50 pass

# 5. Declare compliance
(def compliance-level "Level 2")
```

### Example: New Implementation (Zig)

**Starting from scratch**:
```zig
// 1. Implement lexer per Layer 1 spec
// 2. Run lexer compliance tests
// 3. Implement parser per Layer 2 spec
// 4. Run parser compliance tests
// 5. Implement core semantics per Layer 3 spec
// 6. Achieve Level 1 compliance
// 7. Add protobuf support
// 8. Achieve Level 2 compliance
```

**Compliance declaration**:
```zig
pub const SPEC_VERSION = "1.0.0";
pub const COMPLIANCE_LEVEL = .level_2;
```

**Users can trust**: Any Level 2 implementation produces identical results.

---

## RFC Process (Community Evolution)

### How Changes Are Proposed

1. **Draft RFC**: Author writes proposal (see `RFC-0001-ZEROSUM-STANDARD.md`)
2. **Community Review**: 2+ weeks discussion period
3. **Consensus**: Requires approval from:
   - 2+ implementation maintainers
   - Original author (Martin Blais) or delegate
4. **Merge**: RFC accepted → becomes specification requirement
5. **Implementation**: Implementations add feature to reach compliance

### Example: Zerosum Standardization

**Problem**: Zerosum plugin exists in Python, but behavior undefined for ports

**RFC-0001 proposes**:
- Formal matching algorithm
- Configuration schema (JSON Schema validation)
- 25 compliance tests
- Migration path for existing users

**Outcome**: All implementations (Python, Clojure, Rust, Zig) can implement identically

---

## Interoperability Example

### Multi-Language Pipeline

```mermaid
graph LR
    A[User writes<br/>ledger.beancount] --> B[Python: Parse]
    B --> C[Protocol Buffer]
    C --> D[Rust: Analytics<br/>blazing fast]
    D --> C2[Protocol Buffer]
    C2 --> E[Clojure: Reports<br/>interactive REPL]
    E --> F[PDF/HTML/JSON]
```

**Key benefit**: Each tool does what it's best at:
- **Python**: Rich ecosystem, compatibility
- **Rust**: Performance, safety, WebAssembly
- **Clojure**: Interactive development, functional purity

**Same file works everywhere**:
```bash
$ bean-check ledger.beancount       # Python
$ limabean check ledger.beancount   # Clojure
$ beancount-rs check ledger.beancount  # Rust
# All produce identical validation results
```

---

## Comparison with Other Language Specs

| Language | Spec Approach | Beancount (Proposed) |
|----------|---------------|----------------------|
| **Python** | CPython behavior + PEPs | Python impl + RFCs |
| **Rust** | Rust Reference (book) + RFCs | Spec doc + RFCs |
| **JavaScript** | ECMA-262 + test262 | Spec + test suite |
| **Go** | Language spec + Go impl | Spec + test suite |

**Pattern**: Successful multi-implementation languages use **specifications + compliance tests**, not SysML diagrams.

---

## Benefits to Beancount Ecosystem

### 1. Innovation Without Fragmentation
- Implementations can innovate (performance, features, platforms)
- Core behavior remains consistent
- Users aren't locked into one implementation

### 2. Language Evolution
- RFC process allows community-driven improvements
- Changes are documented and reviewed
- Breaking changes are explicit and versioned

### 3. Quality Assurance
- Bugs found once, fixed everywhere
- Comprehensive test coverage (community-driven)
- Clear conformance criteria

### 4. Documentation
- Specification IS documentation
- Executable tests provide examples
- Implementation-agnostic tutorials possible

### 5. Ecosystem Growth
- New tools can be confident they'll work
- Language bindings for more platforms
- Academic research can cite specification

---

## Next Steps

### For This Project (limabean-zerosum)

**Immediate**:
- [ ] Review `BEANCOUNT-SPECIFICATION.md`
- [ ] Run existing zerosum plugin against proposed tests
- [ ] Document limabean's compliance status

**Short-term**:
- [ ] Propose RFC-0001 to Beancount community
- [ ] Contribute test cases from limabean experience
- [ ] Achieve Level 1 compliance

**Long-term**:
- [ ] Implement Protocol Buffer serialization
- [ ] Achieve Level 2 compliance
- [ ] Add Clojure-specific innovations (REPL, spec validation)

### For Beancount Community

**RFC Submission**:
1. Post specification to beancount@googlegroups.com
2. Open GitHub discussion in beancount/beancount
3. Gather feedback from implementation authors
4. Iterate on specification based on feedback

**Test Suite Creation**:
1. Create `beancount/specification` repository
2. Port existing tests to YAML format
3. Organize by compliance level
4. Run against Python reference implementation

**Governance**:
1. Establish RFC approval process
2. Create specification versioning scheme
3. Form specification working group

---

## Resources Created

### In This Repository

```
limabean-zerosum/
├── BEANCOUNT-SPECIFICATION.md      # Main specification (10k words)
├── SPECIFICATION-EXAMPLE.md        # Practical examples (6k words)
├── RFC-0001-ZEROSUM-STANDARD.md    # Example RFC (5k words)
└── SPECIFICATION-SUMMARY.md        # This document
```

### Proposed Community Structure

```
beancount-specification/  (new repository)
├── specification.md           # Main spec (from our work)
├── rfcs/
│   ├── 0001-zerosum.md
│   ├── 0002-plugin-api.md
│   └── template.md
├── tests/
│   ├── lexer/
│   ├── grammar/
│   ├── semantics/
│   ├── features/
│   └── regression/
├── proto/
│   └── beancount/v3/
│       ├── directives.proto
│       └── amounts.proto
└── implementations/
    ├── python.md
    ├── limabean.md
    ├── beancount-rs.md
    └── registry.yaml
```

---

## FAQ

### Q: Is this replacing the Python implementation?
**A**: No. Python remains the reference implementation. This spec formalizes its behavior so others can implement consistently.

### Q: Do existing Beancount files need changes?
**A**: No. The specification describes current Beancount behavior. Files work unchanged.

### Q: What about Beancount v3?
**A**: This spec helps v3 by:
- Defining what MUST stay compatible
- Providing framework for v3 changes (via RFCs)
- Enabling v3 protobuf plan

### Q: How does this help limabean?
**A**:
1. Clear target behavior (no guessing)
2. Compliance tests (validation)
3. Community-backed standard (credibility)
4. Interoperability guarantees (ecosystem fit)

### Q: Who maintains the specification?
**A**: Community, with governance:
- RFCs require multi-implementation consensus
- Martin Blais (or delegate) has veto for core language
- Test suite is community-maintained

### Q: Can implementations extend beyond the spec?
**A**: Yes! Implementations can:
- Add new plugins (Level 3)
- Add language bindings
- Add UI/tools
- Optimize performance

Core behavior must match spec.

---

## Conclusion

### What We Answered

**Original question**: "Can SysML be used to model Beancount and create a standard for ports?"

**Answer**:
- ✅ **Yes**, a formal specification standard is valuable
- ❌ **No**, SysML is not the right tool
- ✅ **Better approach**: Multi-layer spec with EBNF + semantics + tests + protobuf

### What We Delivered

1. **Complete specification framework** (ready for community review)
2. **Practical implementation guide** (with Python/Clojure/Rust examples)
3. **Example RFC** (demonstrating governance process)
4. **Actionable roadmap** (for limabean and community)

### Impact

This framework enables:
- **Predictable multi-implementation ecosystem**
- **Community-driven language evolution**
- **Cross-language tooling** (parse once, use everywhere)
- **Academic and commercial adoption** (formal semantics)
- **Long-term Beancount sustainability** (not tied to single implementation)

### Call to Action

**For you**:
1. Review the specification documents
2. Test limabean against proposed compliance tests
3. Contribute feedback to RFC-0001

**For community**:
1. Discuss on beancount@googlegroups.com
2. Create `beancount-specification` repository
3. Port 100+ tests to YAML format
4. Establish RFC working group

**Together**: Build the foundation for the next decade of Beancount innovation.

---

**Created**: 2026-03-01
**Status**: Proposal for community review
**License**: CC-BY-4.0 (specification), MIT (examples)
**Contributing**: Feedback welcome via GitHub issues or mailing list
