#!/usr/bin/env bash
# Test script for bridge.py --mode parameter

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE="${SCRIPT_DIR}/bridge.py"

echo "Testing bridge.py --mode parameter..."

# Test 1: Lexer mode with valid input
echo "Test 1: Lexer mode with valid input"
RESULT=$(echo '{"input": "txn"}' | python3 "$BRIDGE" --mode lexer)
if echo "$RESULT" | jq -e '.tokens' > /dev/null 2>&1; then
    echo "  ✓ Lexer mode produces tokens"
else
    echo "  ✗ Lexer mode failed to produce tokens"
    echo "  Result: $RESULT"
    exit 1
fi

# Test 2: Parser mode works
echo "Test 2: Parser mode works"
RESULT=$(echo '{"input": "2024-01-01 open Assets:Checking"}' | python3 "$BRIDGE" --mode parser)
if echo "$RESULT" | jq -e '.entries[0].node_type == "Open"' > /dev/null 2>&1; then
    echo "  ✓ Parser mode works"
else
    echo "  ✗ Parser mode failed"
    echo "  Result: $RESULT"
    exit 1
fi

# Test 3: Missing --mode flag should fail
echo "Test 3: Missing --mode flag should fail"
ERROR_OUTPUT=$(echo '{"input": "txn"}' | python3 "$BRIDGE" 2>&1 || true)
if echo "$ERROR_OUTPUT" | grep -q "arguments are required: --mode"; then
    echo "  ✓ Missing --mode flag produces error"
else
    echo "  ✗ Missing --mode flag should produce error"
    echo "  Output: $ERROR_OUTPUT"
    exit 1
fi

# Test 4: Invalid --mode value should fail
echo "Test 4: Invalid --mode value should fail"
ERROR_OUTPUT=$(echo '{"input": "txn"}' | python3 "$BRIDGE" --mode invalid 2>&1 || true)
if echo "$ERROR_OUTPUT" | grep -q "invalid choice"; then
    echo "  ✓ Invalid --mode value produces error"
else
    echo "  ✗ Invalid --mode value should produce error"
    echo "  Output: $ERROR_OUTPUT"
    exit 1
fi

echo ""
echo "All tests passed! ✓"
