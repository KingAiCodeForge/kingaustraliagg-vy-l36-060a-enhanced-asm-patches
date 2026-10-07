"""Fail-closed helpers for writing firmware tools' output artifacts."""

from __future__ import annotations

from contextlib import ExitStack
from pathlib import Path
from typing import Iterable


def validate_output_paths(
    input_paths: Iterable[Path], output_paths: Iterable[Path]
) -> None:
    """Refuse aliases, duplicate outputs and overwrites before creating files."""
    inputs = {path.expanduser().resolve() for path in input_paths}
    outputs = [path.expanduser().resolve() for path in output_paths]
    if len(outputs) != len(set(outputs)):
        raise ValueError("output paths must be distinct")
    for path in outputs:
        if path in inputs:
            raise ValueError(f"output must not overwrite an input: {path.name}")
        if path.exists():
            raise FileExistsError(f"refusing to overwrite existing output: {path}")


def write_outputs_exclusive(payloads: Iterable[tuple[Path, bytes | str]]) -> None:
    """Reserve every destination before writing any payload."""
    items = list(payloads)
    for path, _payload in items:
        path.parent.mkdir(parents=True, exist_ok=True)
    with ExitStack() as stack:
        handles = []
        for path, payload in items:
            if isinstance(payload, bytes):
                handles.append(stack.enter_context(path.open("xb")))
            else:
                handles.append(
                    stack.enter_context(path.open("x", encoding="utf-8", newline=""))
                )
        for handle, (_path, payload) in zip(handles, items):
            handle.write(payload)
