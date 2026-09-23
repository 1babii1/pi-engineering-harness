#!/usr/bin/env python3
"""PreToolUse hook: block reading/searching/editing secret material.

Claude Code invokes this as a PreToolUse hook and feeds it the tool call as JSON on stdin:
  {"tool_name": "Read", "tool_input": {"file_path": "..."}, ...}

Exit 2 blocks the tool call and feeds stderr back to the model as the reason. Exit 0 allows it.
This is defense in depth, not a sandbox: the Bash-command check is a regex over a shell command
line, not a real shell parser, so it will not catch every obfuscation (command substitution,
base64, a wrapper script). It catches the direct, common cases - accidentally or routinely reading
`.env`, an age key, a SOPS vault - the same class of mistake the project's own secrets policy
exists to prevent. It is not a substitute for OS-level permissions or a sandboxed runtime.

Known gaps, by design (a regex cannot close them): shell indirection (`cat $(echo .en)v`, variable
concatenation, base64), brace/partial globs (`.en{v,x}`, `.e*`), and a directory-wide Grep that
happens to search an un-gitignored `.env`. Files named in a command are also blocked when merely
mentioned (`git commit -m "..., .env, ..."`); the message tells the model to rephrase.

Standard library only, matching the rest of this harness's tooling (see evals/run.py).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# Allow-list: checked before any block pattern. Add project-specific exceptions here or in a
# project-owned .pi/project/secret-patterns.txt (see load_patterns()).
ALLOW_PATTERNS = [
    r"(^|/)\.env\.example$",
]

# Deny-list defaults. A project can extend (not replace) these via .pi/project/secret-patterns.txt,
# one Python regex per line, '#' comments and blank lines ignored.
DEFAULT_DENY_PATTERNS = [
    r"(^|/)\.env(\.[^/]+)?$",          # .env, .env.local, .env.production, ... (.env.example is allow-listed above)
    r"\.enc\.(json|ya?ml)$",           # SOPS-encrypted vaults
    r"(^|/)age/keys\.txt$",             # e.g. ~/.config/sops/age/keys.txt
    r"\.agekey$",
    r"(^|/)id_(rsa|ed25519|ecdsa|dsa)$",  # private key files; the matching .pub is not a secret
    r"\.pem$",
    r"\.p12$",
    r"\.pfx$",
    r"(^|/)\.npmrc$",                  # commonly carries a registry auth token
    r"(^|/)\.netrc$",
]

# Bash commands that read environment/secret state directly, regardless of path arguments.
BASH_DENY_PATTERNS = [
    r"(^|[;&|(]\s*)([A-Za-z_]\w*=\S*\s+)*env\b(?!\s*-i)",  # `env`, `FOO=1 env` (env -i is a sandboxing idiom, not a leak)
    r"\bprintenv\b",
    r"\bexport\s+-p\b",
    r"\bdeclare\s+-[a-zA-Z]*x",
    r"(^|[;&|(]\s*)set\s*($|[;&|)])",        # bare `set` dumps every variable
    r"/proc/[^\s/]+/environ",
]

FILE_INPUT_KEYS = ("file_path", "path", "notebook_path")
# Grep's `glob` narrows which files to search and can itself target secrets (e.g. ".env*").
# Grep's `pattern` is search text, never a path; Glob's `pattern` is a path glob (see check_paths).
SEARCH_INPUT_KEYS = ("glob",)


def load_patterns() -> list[str]:
    # Project-owned extension file, relative to the project root (Claude Code runs hooks there).
    # It lives under .pi/project/ because the installer never overwrites that directory, unlike
    # .harness/hooks/, which is refreshed on every install.
    extra_file = Path.cwd() / ".pi" / "project" / "secret-patterns.txt"
    extra: list[str] = []
    if extra_file.is_file():
        for line in extra_file.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            try:
                re.compile(line)
            except re.error as e:
                # Keep enforcing the defaults; say why the project's line was ignored.
                print(f"guard-secrets: ignoring invalid pattern in {extra_file}: {line!r} ({e})", file=sys.stderr)
                continue
            extra.append(line)
    return DEFAULT_DENY_PATTERNS + extra


def is_allowed(text: str) -> bool:
    return any(re.search(p, text, re.IGNORECASE) for p in ALLOW_PATTERNS)


def matches_any(text: str, patterns: list[str]) -> str | None:
    # IGNORECASE: `.ENV` / `VAULT.ENC.JSON` are the same file on a case-insensitive filesystem.
    for p in patterns:
        if re.search(p, text, re.IGNORECASE):
            return p
    return None


def check_paths(tool_name: str, tool_input: dict, deny_patterns: list[str]) -> str | None:
    values: list[str] = []
    if tool_name == "Glob" and isinstance(tool_input.get("pattern"), str):
        # Glob's `pattern` IS a path glob ("**/.env*"). Grep's `pattern` is search text and is
        # deliberately not checked.
        values.append(tool_input["pattern"].rstrip("*?"))
    for key in FILE_INPUT_KEYS:
        v = tool_input.get(key)
        if isinstance(v, str):
            values.append(v.strip())
    for key in SEARCH_INPUT_KEYS:
        v = tool_input.get(key)
        if isinstance(v, str):
            # Deny patterns are anchored ($) for exact filenames; a glob's own trailing wildcard
            # (e.g. "**/.env*") would sit after the match and defeat that anchor, so strip glob
            # wildcard characters from the end before testing - "**/.env*" -> "**/.env".
            values.append(v.rstrip("*?"))
    # MultiEdit-style batch edits.
    for edit in tool_input.get("edits", []) if isinstance(tool_input.get("edits"), list) else []:
        if isinstance(edit, dict) and isinstance(edit.get("file_path"), str):
            values.append(edit["file_path"])

    for text in values:
        if is_allowed(text):
            continue
        hit = matches_any(text, deny_patterns)
        if hit:
            return f"path '{text}' matches secret pattern: {hit}"
    return None


def check_bash(tool_input: dict, deny_patterns: list[str]) -> str | None:
    command = tool_input.get("command")
    if not isinstance(command, str):
        return None
    # Direct-path reads inside a shell command (cat .env, grep ... .env, etc.).
    for token in re.findall(r"[^\s;&|'\"><]+", command):
        # `cat .env*`: the glob's own trailing wildcard would defeat the `$` anchors (see check_paths).
        token = token.rstrip("*?")
        if is_allowed(token):
            continue
        hit = matches_any(token, deny_patterns)
        if hit:
            return f"command references '{token}', matching secret pattern: {hit}"
    hit = matches_any(command, BASH_DENY_PATTERNS)
    if hit:
        return f"command matches disallowed pattern: {hit}"
    return None


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        # Malformed input is not this hook's problem to solve; fail open rather than block
        # every tool call in the session over a parsing edge case.
        return 0

    tool_name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input", {})
    if not isinstance(tool_input, dict):
        return 0

    deny_patterns = load_patterns()

    reason = None
    if tool_name == "Bash":
        reason = check_bash(tool_input, deny_patterns)
    else:
        reason = check_paths(tool_name, tool_input, deny_patterns)

    if reason:
        print(
            f"Blocked by guard-secrets hook ({tool_name}): {reason}\n"
            "This harness's secrets policy treats .env*, SOPS vaults, key files, and credential "
            "stores as off-limits except .env.example. Use ~/.local/bin/secrets-run for the one "
            "process that actually needs the vault, never a general read/search/edit.",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
