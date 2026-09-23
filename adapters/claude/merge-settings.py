#!/usr/bin/env python3
"""Merge the harness's Claude Code hooks into a project's .claude/settings.json.

  merge-settings.py <existing-settings.json | -> <harness-settings.json>   -> merged JSON on stdout

Only the `hooks` key is touched. Every other key (permissions, env, model, ...) is preserved
exactly. A harness hook entry is added only if no existing entry under the same event already runs
the same command, so re-running the installer never duplicates a hook. Existing hooks that are not
the harness's are kept in place. Standard library only.

Exit: 0 merged JSON printed, 2 the existing file is not valid JSON (the caller keeps it untouched).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def commands(entry: dict) -> set[str]:
    inner = entry.get("hooks")
    return {h.get("command") for h in inner if isinstance(h, dict)} if isinstance(inner, list) else set()


def merge(existing: dict, harness: dict) -> dict:
    result = dict(existing)
    hooks = result.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("existing 'hooks' is not an object")
    for event, entries in harness.get("hooks", {}).items():
        current = hooks.setdefault(event, [])
        if not isinstance(current, list):
            raise ValueError(f"existing hooks.{event} is not a list")
        present = set().union(*(commands(e) for e in current if isinstance(e, dict))) if current else set()
        for entry in entries:
            if not commands(entry) <= present:
                current.append(entry)
    return result


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    existing_path, harness_path = argv[1], argv[2]
    harness = json.loads(Path(harness_path).read_text())
    existing: dict = {}
    if existing_path != "-" and Path(existing_path).is_file():
        try:
            existing = json.loads(Path(existing_path).read_text())
            if not isinstance(existing, dict):
                raise ValueError("top-level JSON is not an object")
        except (json.JSONDecodeError, ValueError) as e:
            print(f"cannot merge into {existing_path}: {e}", file=sys.stderr)
            return 2
    try:
        merged = merge(existing, harness)
    except ValueError as e:
        print(f"cannot merge into {existing_path}: {e}", file=sys.stderr)
        return 2
    json.dump(merged, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
