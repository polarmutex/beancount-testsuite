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
