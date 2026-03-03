#!/usr/bin/env python3
"""Python bridge for Beancount lexer and parser testing."""

import argparse
import json
import sys
from io import StringIO


def tokenize_with_beancount(input_text):
    """Tokenize input using Beancount lexer."""
    try:
        from beancount.parser import lexer

        # Tokenize using Beancount's lex_iter_string
        # Returns tuples of (type, lineno, text_bytes, value)
        token_iter = lexer.lex_iter_string(input_text)
        tokens = []

        # Track position for column calculation
        lines = input_text.split('\n')

        for tok in token_iter:
            tok_type = tok[0]
            tok_line = tok[1]
            tok_text = tok[2].decode('utf-8') if isinstance(tok[2], bytes) else tok[2]
            tok_value = tok[3]

            # Calculate column by finding token text in the line
            # Beancount uses 1-indexed lines
            line_idx = tok_line - 1
            if 0 <= line_idx < len(lines):
                col = lines[line_idx].find(tok_text) + 1  # 1-indexed column
            else:
                col = 1

            # Convert value to string representation
            # Use tok_text as value when tok_value is None (common for keywords/operators)
            if tok_value is None:
                value_str = tok_text
            else:
                value_str = str(tok_value)

            tokens.append({
                "type": tok_type,
                "value": value_str,
                "line": tok_line,
                "column": col,
            })

        return {"tokens": tokens}

    except ImportError as e:
        return {
            "error": "ImportError",
            "message": "Failed to import beancount",
            "details": str(e)
        }
    except Exception as e:
        return {
            "error": "LexerError",
            "message": str(e),
            "details": str(type(e).__name__)
        }


def serialize_error(error):
    """Convert Beancount error to error dict."""
    line = None
    if hasattr(error, 'source') and error.source:
        line = error.source.get('lineno')

    return {
        "error_type": error.__class__.__name__,
        "message": str(error.message),
        "line": line
    }


def serialize_posting(posting):
    """Convert posting to AST node."""
    attributes = {
        "account": str(posting.account),
    }

    # Add units (amount) if present
    if posting.units:
        attributes["amount"] = str(posting.units)

    return {
        "node_type": "Posting",
        "attributes": attributes,
        "children": []
    }


def serialize_entry(entry):
    """Convert Beancount directive to AST node dict."""
    node = {
        "node_type": entry.__class__.__name__,
        "attributes": {},
        "children": []
    }

    # Extract attributes from named tuple fields
    for field in entry._fields:
        value = getattr(entry, field)

        # Skip None, lists, tuples (these become children or are ignored)
        if value is None or isinstance(value, (list, tuple)):
            continue

        # Convert everything to string
        node["attributes"][field] = str(value)

    # Handle postings as children (for Transaction directives)
    if hasattr(entry, 'postings') and entry.postings:
        node["children"] = [serialize_posting(p) for p in entry.postings]

    # Handle currencies as children (for Open directives)
    if hasattr(entry, 'currencies') and entry.currencies:
        node["children"] = [{"node_type": "Currency", "attributes": {"value": c}, "children": []}
                           for c in entry.currencies]

    return node


def parser_mode(input_text):
    """Parse input using Beancount parser."""
    try:
        from beancount.parser import parser

        # Parse as complete file
        entries, errors, options = parser.parse_string(input_text)

        # Serialize entries
        serialized_entries = [serialize_entry(e) for e in entries]

        # Serialize errors
        serialized_errors = [serialize_error(e) for e in errors]

        return {
            "entries": serialized_entries,
            "errors": serialized_errors
        }

    except ImportError as e:
        return {
            "error": "ImportError",
            "message": "Failed to import beancount.parser",
            "details": str(e)
        }
    except Exception as e:
        return {
            "error": "ParserError",
            "message": str(e),
            "details": str(type(e).__name__)
        }


def parse_with_beancount(input_text):
    """Parse input using Beancount parser (stub for future implementation)."""
    return {
        "error": "NotImplemented",
        "message": "Parser mode not yet implemented",
        "details": "Use --mode lexer for tokenization"
    }


def main():
    """Read JSON requests from stdin, process based on mode, write JSON responses to stdout."""
    parser = argparse.ArgumentParser(description='Beancount lexer/parser bridge')
    parser.add_argument('--mode', choices=['lexer', 'parser'], required=True,
                        help='Operation mode: lexer for tokenization, parser for parsing')
    args = parser.parse_args()

    # Dispatch based on mode
    if args.mode == 'lexer':
        process_func = tokenize_with_beancount
    elif args.mode == 'parser':
        process_func = parser_mode
    else:
        sys.stderr.write(f"Invalid mode: {args.mode}\n")
        sys.exit(1)

    for line in sys.stdin:
        try:
            request = json.loads(line)
            input_text = request.get("input", "")

            response = process_func(input_text)
            print(json.dumps(response))
            sys.stdout.flush()

        except json.JSONDecodeError as e:
            error_response = {
                "error": "JSONDecodeError",
                "message": "Invalid JSON in request",
                "details": str(e)
            }
            print(json.dumps(error_response))
            sys.stdout.flush()
        except Exception as e:
            error_response = {
                "error": "BridgeError",
                "message": str(e),
                "details": str(type(e).__name__)
            }
            print(json.dumps(error_response))
            sys.stdout.flush()


if __name__ == "__main__":
    main()
