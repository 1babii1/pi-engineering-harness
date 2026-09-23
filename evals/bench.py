#!/usr/bin/env python3
"""Agent-run benchmark: does installing the harness change what an agent answers?

  bench.py --agent claude --variants bare,harness --trials 3 [--category concurrency] [--cases id,id]
           [--profile "fullstack production"] [--out evals/results/<name>] [--max-cost-usd 5] [--dry-run]

For every (case, trial, variant) it makes a fresh scratch project (`bare`: empty; `harness`: the harness
installed with `install.sh --agent <agent> <profile>`), runs the case's task through a runner
(`evals/runners/<agent>.sh`, see its header for the contract), and grades the answer with the SAME
deterministic graders as `./eval.sh grade` (must_match / must_not_match). Standard library only.

Read the numbers for what they are:
- The graders are regex heuristics over prose. A pass means the answer contains the key concepts and none
  of the forbidden recommendations, not that it is good. Prose criteria are listed as NOT GRADED.
- A run that errors (timeout, CLI failure, budget) is counted as an error, never as a pass or a fail.
- Isolation depends on the runner and is printed in the report header; do not compare across agents.
- Small trial counts prove nothing. Report the count next to every rate; the README asks for repeated runs.

Exit: 0 finished, 2 could not run (bad arguments, missing runner/agent). Failing answers are data, not errors.
"""
from __future__ import annotations

import argparse
import datetime
import itertools
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import run as evalrun  # noqa: E402  (the case loader and graders live there)

VARIANTS = ("bare", "harness")
# Prepended to every task for BOTH variants. The cases are self-contained design questions but the scratch
# project has no code, so without this an agent may ask for the code instead of answering, and the
# harness rule "do not invent APIs" would push that variant to ask more often: a confound, not a signal.
DEFAULT_PREAMBLE = (
    "This is a design/engineering question. There is no application code to inspect, so do not ask for "
    "code or clarification: give your concrete recommendation, the key trade-offs, and any assumptions "
    "you make, in prose."
)


def select_cases(ids: str | None, category: str | None) -> list[dict]:
    cases = [c for _, c in evalrun.load_cases() if evalrun.has_deterministic(c)]
    if ids:
        wanted = [i.strip() for i in ids.split(",") if i.strip()]
        unknown = sorted(set(wanted) - {c["id"] for c in cases})
        if unknown:
            raise SystemExit(f"unknown or non-deterministic case ids: {', '.join(unknown)}")
        cases = [c for c in cases if c["id"] in wanted]
    if category:
        cases = [c for c in cases if c.get("category") == category]
    return cases


def make_template(variant: str, agent: str, profile: list[str], base: Path) -> Path:
    """One template project per variant; every run gets a copy so installs happen once."""
    template = base / f"template-{variant}"
    template.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=template, check=True)
    if variant == "harness":
        env = {**os.environ, "TARGET": str(template)}
        proc = subprocess.run(
            [str(ROOT / "install.sh"), "--agent", agent, *profile], env=env, capture_output=True, text=True
        )
        if proc.returncode != 0:
            raise SystemExit(f"install.sh failed for the harness variant:\n{proc.stdout}\n{proc.stderr}")
    return template


def run_one(runner: Path, template: Path, case: dict, variant: str, base: Path, timeout: int, preamble: str) -> dict:
    workdir = base / f"run-{uuid.uuid4().hex[:8]}"
    shutil.copytree(template, workdir, symlinks=True)
    task_file = workdir.parent / f"{workdir.name}.task"
    task_file.write_text((preamble + "\n\n" if preamble else "") + case["task"], encoding="utf-8")
    meta_file = workdir.parent / f"{workdir.name}.meta.json"
    env = {**os.environ, "BENCH_META_FILE": str(meta_file), "BENCH_CASE_ID": case["id"], "BENCH_VARIANT": variant}
    record: dict = {"case": case["id"], "variant": variant}
    try:
        proc = subprocess.run(
            [str(runner), str(workdir), str(task_file)], env=env, capture_output=True, text=True, timeout=timeout
        )
    except subprocess.TimeoutExpired:
        return {**record, "status": "error", "error": f"timeout after {timeout}s"}
    if proc.returncode != 0 or not proc.stdout.strip():
        detail = (proc.stderr.strip().splitlines() or ["empty answer"])[-1][:200]
        return {**record, "status": "error", "error": f"runner exit {proc.returncode}: {detail}"}
    results, _ = evalrun.grade_text(case, proc.stdout)
    record.update(
        status="pass" if all(ok for ok, _ in results) else "fail",
        failed_checks=[label for ok, label in results if not ok],
        response=proc.stdout,
    )
    if meta_file.is_file():
        record["meta"] = json.loads(meta_file.read_text())
    return record


def summarize(records: list[dict], header: dict) -> str:
    variants = [v for v in VARIANTS if any(r["variant"] == v for r in records)]
    cases = sorted({r["case"] for r in records})

    def cell(case: str | None, variant: str) -> str:
        rs = [r for r in records if r["variant"] == variant and (case is None or r["case"] == case)]
        graded = [r for r in rs if r["status"] in ("pass", "fail")]
        errors = len(rs) - len(graded)
        if not graded:
            return "-" + (f" ({errors} err)" if errors else "")
        passed = sum(r["status"] == "pass" for r in graded)
        return f"{passed}/{len(graded)}" + (f" (+{errors} err)" if errors else "")

    def cost(variant: str) -> float:
        return sum((r.get("meta") or {}).get("cost_usd") or 0 for r in records if r["variant"] == variant)

    lines = [
        f"# Benchmark {header['date']} - {header['agent']}",
        "",
        f"- agent: {header['info'].get('agent')} {header['info'].get('version')}",
        f"- isolation: {header['info'].get('isolation')}",
        f"- model: {header.get('model') or 'runner default'}",
        f"- harness: {header['harness_version']}, profile `{header['profile']}`",
        f"- trials per case and variant: {header['trials']}",
        f"- task preamble (both variants): {header['preamble'] or 'none'}",
        "- graders: deterministic regex heuristics only (`must_match` / `must_not_match`); prose criteria NOT GRADED",
        "- a pass rate is passed/graded runs; errored runs are shown separately and never counted as pass or fail",
        "",
        "| case | " + " | ".join(variants) + " |",
        "|---|" + "---|" * len(variants),
    ]
    for case in cases:
        lines.append(f"| {case} | " + " | ".join(cell(case, v) for v in variants) + " |")
    lines.append("| **all** | " + " | ".join(f"**{cell(None, v)}**" for v in variants) + " |")
    if any((r.get("meta") or {}).get("cost_usd") for r in records):
        lines += ["", "cost (USD, as reported by the agent): " + ", ".join(f"{v} {cost(v):.2f}" for v in variants)]
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--agent", required=True, choices=["claude", "codex", "pi"])
    ap.add_argument("--variants", default="bare,harness")
    ap.add_argument("--trials", type=int, default=3)
    ap.add_argument("--cases", help="comma-separated case ids")
    ap.add_argument("--category")
    ap.add_argument("--profile", default="fullstack production", help="install.sh profiles/skills for the harness variant")
    ap.add_argument("--runner", help="runner script (default: evals/runners/<agent>.sh)")
    ap.add_argument("--out", help="results directory (default: evals/results/<date>-<agent>)")
    ap.add_argument("--timeout", type=int, default=300, help="seconds per run")
    ap.add_argument("--max-cost-usd", type=float, default=5.0, help="stop starting runs once reported cost reaches this")
    ap.add_argument("--preamble", default=DEFAULT_PREAMBLE, help="text prepended to every task for both variants ("" to disable)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)

    variants = [v.strip() for v in args.variants.split(",") if v.strip()]
    if not variants or any(v not in VARIANTS for v in variants):
        print(f"--variants must be a subset of {','.join(VARIANTS)}", file=sys.stderr)
        return 2
    if args.trials < 1:
        print("--trials must be >= 1", file=sys.stderr)
        return 2
    cases = select_cases(args.cases, args.category)
    if not cases:
        print("no deterministic cases selected", file=sys.stderr)
        return 2
    runner = Path(args.runner) if args.runner else HERE / "runners" / f"{args.agent}.sh"
    if not os.access(runner, os.X_OK):
        print(f"runner not found or not executable: {runner}", file=sys.stderr)
        return 2

    total = len(cases) * len(variants) * args.trials
    if args.dry_run:
        print(f"{args.agent}: {len(cases)} cases x {len(variants)} variants x {args.trials} trials = {total} agent runs")
        print(f"each run is a real model call; the loop stops at {args.max_cost_usd:.2f} USD of reported cost")
        print("cases: " + ", ".join(c["id"] for c in cases))
        return 0

    info_proc = subprocess.run([str(runner), "info"], capture_output=True, text=True)
    if info_proc.returncode != 0:
        print(f"{runner.name} info failed: {info_proc.stderr.strip()}", file=sys.stderr)
        return 2
    info = json.loads(info_proc.stdout)

    date = datetime.date.today().isoformat()
    out = Path(args.out) if args.out else ROOT / "evals" / "results" / f"{date}-{args.agent}"
    (out / "responses").mkdir(parents=True, exist_ok=True)
    profile = args.profile.split()

    records: list[dict] = []
    spent = 0.0
    with tempfile.TemporaryDirectory(prefix="bench-") as tmp:
        base = Path(tmp)
        templates = {v: make_template(v, args.agent, profile, base) for v in variants}
        # Interleave variants within each case and trial so slow drift (model updates, load) hits both alike.
        for done, (trial, case, variant) in enumerate(itertools.product(range(1, args.trials + 1), cases, variants), 1):
            if spent >= args.max_cost_usd:
                print(f"stopping: reported cost {spent:.2f} USD reached --max-cost-usd", file=sys.stderr)
                break
            rec = run_one(runner, templates[variant], case, variant, base, args.timeout, args.preamble)
            rec["trial"] = trial
            spent += (rec.get("meta") or {}).get("cost_usd") or 0
            response = rec.pop("response", None)
            if response is not None:
                d = out / "responses" / case["id"]
                d.mkdir(exist_ok=True)
                (d / f"{variant}-{trial}.md").write_text(response, encoding="utf-8")
            records.append(rec)
            print(f"[{done}/{total}] {case['id']} {variant} #{trial}: {rec['status']}"
                  + (f" ({rec['error']})" if rec["status"] == "error" else ""), flush=True)

    header = {
        "date": date,
        "agent": args.agent,
        "info": info,
        "model": os.environ.get("BENCH_MODEL"),
        "harness_version": (ROOT / "VERSION").read_text().strip(),
        "profile": args.profile,
        "trials": args.trials,
        "preamble": args.preamble,
    }
    (out / "results.json").write_text(json.dumps({"header": header, "runs": records}, indent=2), encoding="utf-8")
    report = summarize(records, header)
    (out / "report.md").write_text(report, encoding="utf-8")
    print("\n" + report)
    print(f"results: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
