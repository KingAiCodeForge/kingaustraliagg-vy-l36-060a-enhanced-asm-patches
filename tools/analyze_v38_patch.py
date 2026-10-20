#!/usr/bin/env python3
"""Retired v38 report entry; importing this module performs no analysis or I/O."""

import sys

MESSAGE = (
    "REFUSED: this v38 report is retired. Its printed assembly contradicted "
    "its embedded bytes and did not verify bank context. "
    "No firmware was read or written. See archive/rejected/v38/README.md. "
    "Use hc11_static_review.py only for explicit bounded static checks; it "
    "provides no runtime approval."
)


def main():
    print(MESSAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
