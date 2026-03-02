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
