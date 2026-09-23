#!/usr/bin/env python3
"""Deterministic eval tooling for the harness. Standard library only.

  run.py structure               harness self-consistency (profiles, skills, references, budgets)
  run.py lint                    eval case files are well-formed
  run.py selftest                every case's deterministic graders accept its good fixture and
                                 reject its bad fixture (proves the graders can tell them apart)
  run.py grade <case-id> <file>  grade an agent's response/diff against a case

Deterministic graders are heuristics over text (must_match / must_not_match regexes). They check
that key concepts are present and clearly forbidden recommendations are absent. Qualities they
cannot check stay as `expected`/`forbidden` prose for a human or an LLM judge and are reported as
NOT GRADED, never as PASS.

Exit codes: 0 ok, 1 failure, 2 nothing could be graded / not configured.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CASES_DIR = ROOT / "evals" / "cases"
FIXTURES_DIR = ROOT / "evals" / "fixtures"
AGENTS_BUDGET_BYTES = 6000
SKILL_DESCRIPTION_MAX = 500
# Paths the harness creates in a project at runtime; they do not exist in the harness source.
RUNTIME_PATH_PREFIXES = (".pi/work/", ".pi/project/", ".pi/learnings/", ".harness/backup")


# --------------------------------------------------------------------------- mini YAML (subset)
def _scalar(raw: str):
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == "'" and raw[-1] == "'":
        return raw[1:-1].replace("''", "'")
    if len(raw) >= 2 and raw[0] == '"' and raw[-1] == '"':
        return json.loads(raw)
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    # Real YAML rejects these in a plain scalar; accepting them here would let a case file pass
    # this tool and fail in every other YAML consumer.
    if ": " in raw or raw.endswith(":") or " #" in raw or raw[:1] in "'\"[{&*!|>%@`":
        raise ValueError(f"plain scalar needs quoting: {raw!r}")
    return raw


def parse_case(text: str) -> dict:
    """Parses the subset the case files use: `key: scalar`, `key:` followed by `  - scalar` items
    or `  k: scalar` entries. Anything else is an error, so a typo cannot be silently ignored."""
    data: dict = {}
    current: str | None = None
    for number, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line.startswith(" "):
            key, sep, rest = line.partition(":")
            if not sep or not key.strip() or " " in key.strip():
                raise ValueError(f"line {number}: expected 'key: value'")
            if rest.strip():
                data[key.strip()] = _scalar(rest)
                current = None
            else:
                data[key.strip()] = None
                current = key.strip()
            continue
        if current is None:
            raise ValueError(f"line {number}: indented line with no parent key")
        body = line.strip()
        if body.startswith("- "):
            if data[current] is None:
                data[current] = []
            if not isinstance(data[current], list):
                raise ValueError(f"line {number}: cannot mix list and map under '{current}'")
            data[current].append(_scalar(body[2:]))
        else:
            key, sep, rest = body.partition(":")
            if not sep:
                raise ValueError(f"line {number}: expected 'key: value'")
            if data[current] is None:
                data[current] = {}
            if not isinstance(data[current], dict):
                raise ValueError(f"line {number}: cannot mix list and map under '{current}'")
            data[current][key.strip()] = _scalar(rest)
    return data


def load_cases() -> list[tuple[Path, dict]]:
    cases = []
    for path in sorted(CASES_DIR.rglob("*.yml")):
        cases.append((path, parse_case(path.read_text(encoding="utf-8"))))
    return cases


# --------------------------------------------------------------------------------- case lint
REQUIRED_FIELDS = ("id", "category", "task", "expected")


def has_deterministic(case: dict) -> bool:
    return bool(case.get("must_match") or case.get("must_not_match"))


def lint_cases() -> list[str]:
    errors: list[str] = []
    seen: dict[str, Path] = {}
    for path, case in load_cases():
        where = path.relative_to(ROOT)
        for field in REQUIRED_FIELDS:
            if not case.get(field):
                errors.append(f"{where}: missing '{field}'")
        cid = case.get("id")
        if cid:
            if cid in seen:
                errors.append(f"{where}: duplicate id '{cid}' (also {seen[cid].relative_to(ROOT)})")
            seen[cid] = path
            if path.parent.name != case.get("category"):
                errors.append(f"{where}: category '{case.get('category')}' does not match folder '{path.parent.name}'")
            if not str(cid).startswith(f"{case.get('category')}-"):
                errors.append(f"{where}: id '{cid}' should start with '{case.get('category')}-'")
        for field in ("expected", "forbidden", "must_match", "must_not_match"):
            value = case.get(field)
            if value is not None and (not isinstance(value, list) or not all(isinstance(v, str) and v for v in value)):
                errors.append(f"{where}: '{field}' must be a list of non-empty strings")
        for field in ("must_match", "must_not_match"):
            for pattern in case.get(field) or []:
                try:
                    re.compile(pattern)
                except re.error as exc:
                    errors.append(f"{where}: bad regex in {field}: {pattern!r} ({exc})")
        mode = (case.get("checks") or {}).get("mode")
        if mode not in (None, "deterministic", "llm-judge", "mixed"):
            errors.append(f"{where}: unknown checks.mode '{mode}'")
        if not has_deterministic(case):
            errors.append(f"{where}: no deterministic grader (must_match/must_not_match); the README prefers them")
        if has_deterministic(case) and mode == "llm-judge":
            errors.append(f"{where}: has deterministic graders but checks.mode is 'llm-judge'; use 'mixed'")
    return errors


# ------------------------------------------------------------------------------------ grading
def grade_text(case: dict, text: str) -> tuple[list[tuple[bool, str]], list[str]]:
    results: list[tuple[bool, str]] = []
    for pattern in case.get("must_match") or []:
        results.append((re.search(pattern, text, re.MULTILINE) is not None, f"must_match     {pattern}"))
    for pattern in case.get("must_not_match") or []:
        results.append((re.search(pattern, text, re.MULTILINE) is None, f"must_not_match {pattern}"))
    ungraded = [f"expected:  {c}" for c in case.get("expected") or []] + [f"forbidden: {c}" for c in case.get("forbidden") or []]
    return results, ungraded


def cmd_grade(case_id: str, response: str) -> int:
    matching = [c for _, c in load_cases() if c.get("id") == case_id]
    if not matching:
        print(f"Unknown case id: {case_id}", file=sys.stderr)
        return 2
    case = matching[0]
    if not has_deterministic(case):
        print(f"{case_id}: no deterministic graders; nothing was graded (NOT RUN)")
        return 2
    results, ungraded = grade_text(case, Path(response).read_text(encoding="utf-8"))
    for ok, label in results:
        print(("PASS " if ok else "FAIL ") + label)
    if ungraded:
        print("NOT GRADED (needs a human or LLM judge):")
        for line in ungraded:
            print("  " + line)
    return 0 if all(ok for ok, _ in results) else 1


def cmd_selftest() -> int:
    failures = 0
    count = 0
    for path, case in load_cases():
        if not has_deterministic(case):
            continue
        cid = case["id"]
        good, bad = FIXTURES_DIR / f"{cid}.good.md", FIXTURES_DIR / f"{cid}.bad.md"
        for fixture in (good, bad):
            if not fixture.exists():
                print(f"FAIL {cid}: missing fixture {fixture.relative_to(ROOT)}")
                failures += 1
        if not (good.exists() and bad.exists()):
            continue
        count += 1
        good_results, _ = grade_text(case, good.read_text(encoding="utf-8"))
        bad_results, _ = grade_text(case, bad.read_text(encoding="utf-8"))
        missed = [label for ok, label in good_results if not ok]
        if missed:
            failures += 1
            print(f"FAIL {cid}: the GOOD fixture is rejected by: " + "; ".join(missed))
        elif all(ok for ok, _ in bad_results):
            failures += 1
            print(f"FAIL {cid}: the BAD fixture passes every grader, so they cannot tell good from bad")
        else:
            caught = sum(1 for ok, _ in bad_results if not ok)
            print(f"ok   {cid}: good accepted, bad rejected ({caught} grader(s) fired)")
    if count == 0:
        print("No cases with deterministic graders.", file=sys.stderr)
        return 2
    return 1 if failures else 0


# ------------------------------------------------------------------------------- structure
def frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        return {}
    fields = {}
    for line in match.group(1).splitlines():
        key, sep, value = line.partition(":")
        if sep:
            fields[key.strip()] = value.strip()
    return fields


def referenced_paths(text: str) -> set[str]:
    found = set()
    for raw in re.findall(r"(?<![\w/])(\.(?:pi|harness)/[A-Za-z0-9_./*-]+)", text):
        found.add(raw.rstrip(".,;:)`'\"*"))
    return found


def resolve_source(reference: str) -> Path | None:
    """Map a project-relative reference to where it lives in the harness source tree."""
    if reference.startswith(RUNTIME_PATH_PREFIXES):
        return None
    if reference.startswith(".harness/"):
        return ROOT / reference.removeprefix(".harness/")
    return ROOT / reference


HIGH_RISK_CANON = {
    "auth", "credentials", "payments", "migrations", "concurrency", "public contracts",
    "distributed coordination", "production infrastructure", "destructive operations",
}


def high_risk_items(text: str) -> set[str] | None:
    """Extracts the comma-separated high-risk category list from a line of prose (up to a
    sentence-ending '.', '(', or the phrase 'as high-risk'). Returns None if the text has no such
    list at all (nothing to check)."""
    match = re.search(r"(?:auth|Auth), credentials,(.*?)(?:\.|\(| as high-risk|$)", text)
    if not match:
        return None
    items = {"auth", "credentials"}
    for raw in match.group(1).replace("\n", " ").split(","):
        item = raw.strip().removeprefix("and ").strip(".\"'`) \t").lower()
        if item:
            items.add(item)
    return items


def structure_problems() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    skills_root = ROOT / ".pi" / "skills"

    skills = {}
    for skill_md in sorted(skills_root.rglob("SKILL.md")):
        rel = str(skill_md.parent.relative_to(skills_root))
        fm = frontmatter(skill_md)
        skills[rel] = fm
        if not fm.get("name"):
            errors.append(f"skill {rel}: missing 'name' in frontmatter")
        description = fm.get("description", "")
        if not description:
            errors.append(f"skill {rel}: missing 'description' in frontmatter")
        elif len(description) > SKILL_DESCRIPTION_MAX:
            errors.append(f"skill {rel}: description is {len(description)} chars (max {SKILL_DESCRIPTION_MAX}); it is always in context")
    names: dict[str, str] = {}
    for rel, fm in skills.items():
        name = fm.get("name")
        if name:
            if name in names:
                errors.append(f"skill name '{name}' used by both {names[name]} and {rel}")
            names[name] = rel

    used: set[str] = set()
    for profile in sorted((ROOT / "profiles").iterdir()):
        entries = [l.strip() for l in profile.read_text(encoding="utf-8").splitlines() if l.strip() and not l.lstrip().startswith("#")]
        if len(entries) != len(set(entries)):
            errors.append(f"profile {profile.name}: duplicate entries")
        for entry in entries:
            used.add(entry)
            if entry not in skills:
                errors.append(f"profile {profile.name}: unknown skill '{entry}'")
    for rel in sorted(set(skills) - used):
        warnings.append(f"skill {rel} is not part of any profile (install it by name)")

    agents = ROOT / "AGENTS.md"
    size = agents.stat().st_size
    if size > AGENTS_BUDGET_BYTES:
        errors.append(f"AGENTS.md is {size} bytes (budget {AGENTS_BUDGET_BYTES}); it is always in context")

    sources = [agents, *sorted((ROOT / ".pi").rglob("*.md")), *sorted((ROOT / "templates").rglob("*.md")), ROOT / "README.md"]
    referenced: set[str] = set()
    for source in sources:
        for reference in sorted(referenced_paths(source.read_text(encoding="utf-8"))):
            referenced.add(reference)
            if "*" in reference:
                continue
            target = resolve_source(reference)
            if target is not None and not target.exists():
                errors.append(f"{source.relative_to(ROOT)}: references {reference}, which does not exist in the harness")

    # Files meant to be consulted from elsewhere (not skills, not templates the installer places
    # unconditionally) are dead weight if nothing ever tells the agent to open them.
    for orphanable_dir, label in ((ROOT / ".pi" / "references", "reference"), (ROOT / ".pi" / "laws", "law")):
        for path in sorted(orphanable_dir.glob("*.md")):
            rel = str(path.relative_to(ROOT))
            if rel in ("core.md", "signals.md", "proof-obligations.md") or path.name in referenced:
                continue
            if rel not in referenced and path.name not in {r.rsplit("/", 1)[-1] for r in referenced}:
                warnings.append(f"{label} {rel} is not referenced from AGENTS.md, a prompt or a skill; nothing tells the agent to open it")

    skill_ref = re.compile(r"`((?:coding|audit|services|architecture|infrastructure|workflow)/[a-z][a-z-]*)`")
    for source in sources:
        for ref in sorted(set(skill_ref.findall(source.read_text(encoding="utf-8")))):
            if ref not in skills:
                errors.append(f"{source.relative_to(ROOT)}: refers to skill `{ref}`, which does not exist")

    # The high-risk category list is meant to have exactly one authoritative wording
    # (`.pi/laws/signals.md`'s "High risk" section) - every other restatement must match it
    # exactly, so a future edit to one cannot silently drift from the others (see AGENTS.md law
    # "state has one authoritative owner" / "copies create consistency obligations", which this
    # very list violated until it was checked).
    for source in (agents, ROOT / ".pi" / "skills" / "workflow" / "independent-verifier" / "SKILL.md"):  # README's own mention is a short, deliberately non-exhaustive teaser
        found = high_risk_items(source.read_text(encoding="utf-8"))
        if found is None:
            errors.append(f"{source.relative_to(ROOT)}: expected a high-risk category list but found none")
        elif found != HIGH_RISK_CANON:
            missing = HIGH_RISK_CANON - found
            extra = found - HIGH_RISK_CANON
            detail = "; ".join(filter(None, [f"missing {sorted(missing)}" if missing else "", f"unexpected {sorted(extra)}" if extra else ""]))
            errors.append(f"{source.relative_to(ROOT)}: high-risk category list has drifted from .pi/laws/signals.md ({detail})")

    for adapter in ("claude/CLAUDE.md", "gemini/GEMINI.md", "codex/README.md", "cursor/README.md", "pi/README.md"):
        path = ROOT / "adapters" / adapter
        if not path.exists():
            errors.append(f"adapters/{adapter} is missing")
        elif "AGENTS.md" not in path.read_text(encoding="utf-8"):
            errors.append(f"adapters/{adapter} does not point at AGENTS.md (the source of truth)")

    for script in sorted((ROOT / "scripts").glob("*.sh")) + [ROOT / "install.sh", ROOT / "eval.sh"]:
        if not script.stat().st_mode & 0o111:
            errors.append(f"{script.relative_to(ROOT)} is not executable")

    signals = (ROOT / ".pi" / "laws" / "signals.md").read_text(encoding="utf-8")
    for match in re.findall(r"Load `([a-z-]+/[a-z-]+)`", signals):
        if match not in skills:
            errors.append(f"signals.md tells the agent to load unknown skill '{match}'")
        elif match not in used:
            errors.append(f"signals.md tells the agent to load '{match}', but no profile installs it")
    return errors, warnings


def cmd_structure() -> int:
    errors, warnings = structure_problems()
    for w in warnings:
        print("warn " + w)
    for e in errors:
        print("FAIL " + e)
    if not errors:
        print("ok   harness structure is consistent")
    return 1 if errors else 0


def cmd_lint() -> int:
    try:
        errors = lint_cases()
    except ValueError as exc:
        print(f"FAIL case parse error: {exc}")
        return 1
    for e in errors:
        print("FAIL " + e)
    if not errors:
        print("ok   eval cases are well-formed")
    return 1 if errors else 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "structure":
        return cmd_structure()
    if len(argv) >= 2 and argv[1] == "lint":
        return cmd_lint()
    if len(argv) >= 2 and argv[1] == "selftest":
        return cmd_selftest()
    if len(argv) == 4 and argv[1] == "grade":
        return cmd_grade(argv[2], argv[3])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
