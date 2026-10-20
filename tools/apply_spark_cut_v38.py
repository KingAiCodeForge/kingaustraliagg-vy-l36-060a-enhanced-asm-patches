#!/usr/bin/env python3
"""Retired v38 compatibility entry: never read, modify or write a firmware image."""
from __future__ import annotations
import sys
MESSAGE = ("REFUSED: v38 is retired. Its bank-2 hook does not establish a call to "
           "the bank-1 payload. No file was read or written. See "
           "archive/rejected/v38/README.md and PATCH_STATUS.md. "
           "Do not guess another hook or patch-space address.")
class RetiredPatchError(RuntimeError):
    """Withdrawn code must not be applied or presented as a safe undo."""
def verify_binary(*args, **kwargs):
    raise RetiredPatchError(MESSAGE)
def verify_free_space(*args, **kwargs):
    raise RetiredPatchError(MESSAGE)
def apply_patch(*args, **kwargs):
    raise RetiredPatchError(MESSAGE)
def undo_patch(*args, **kwargs):
    raise RetiredPatchError(MESSAGE)
def main():
    print(MESSAGE, file=sys.stderr)
    return 2
if __name__ == "__main__":
    raise SystemExit(main())
