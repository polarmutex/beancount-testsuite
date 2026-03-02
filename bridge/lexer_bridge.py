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
