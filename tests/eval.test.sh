#!/usr/bin/env bash
# Tests for the eval tooling itself (evals/run.py, eval.sh): the graders must be able to fail,
# the parser must agree with a real YAML parser, and structure checks must catch real breakage.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
command -v python3 >/dev/null 2>&1 || { echo "python3 is required; skipping"; exit 0; }

echo "evals/run.py + eval.sh"

# --- the shipped harness is clean --------------------------------------------------------------
python3 "$ROOT_DIR/evals/run.py" structure >/dev/null 2>&1; assert_eq "$?" "0" "the shipped harness passes its structure checks"
python3 "$ROOT_DIR/evals/run.py" lint >/dev/null 2>&1; assert_eq "$?" "0" "the shipped eval cases lint clean"
python3 "$ROOT_DIR/evals/run.py" selftest >/dev/null 2>&1; assert_eq "$?" "0" "every grader accepts its good and rejects its bad fixture"

# --- the mini parser agrees with PyYAML on every shipped case ------------------------------------
out="$(python3 - "$ROOT_DIR" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/evals")
import run
try:
    import yaml
except ImportError:
    print("SKIP no pyyaml"); raise SystemExit
bad = []
for path, ours in run.load_cases():
    theirs = yaml.safe_load(path.read_text(encoding="utf-8"))
    if ours != theirs:
        bad.append(str(path))
print("MISMATCH " + ",".join(bad) if bad else "SAME")
EOF
)"
case "$out" in
  SAME) ok "mini YAML parser equals PyYAML on all cases";;
  SKIP*) ok "mini YAML parser comparison skipped (PyYAML not installed)";;
  *) bad "mini YAML parser equals PyYAML on all cases" "$out";;
esac

# --- parser rejects what it does not understand (a typo must not be silently ignored) --------------
python3 - "$ROOT_DIR" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/evals")
import run
for label, text in [("no colon", "id x\n"), ("orphan indent", "  - a\n"), ("mixed", "k:\n  - a\n  b: c\n"), ("colon in plain scalar", "task: a: b\n")]:
    try:
        run.parse_case(text)
    except ValueError:
        continue
    print("ACCEPTED " + label); raise SystemExit(1)
EOF
assert_eq "$?" "0" "parser rejects malformed input"

# --- grade: exit codes and verdicts --------------------------------------------------------------
G="$ROOT_DIR/evals/fixtures"
python3 "$ROOT_DIR/evals/run.py" grade verification-not-run-is-not-pass "$G/verification-not-run-is-not-pass.good.md" >/dev/null 2>&1
assert_eq "$?" "0" "grade: a good response exits 0"
out="$(python3 "$ROOT_DIR/evals/run.py" grade verification-not-run-is-not-pass "$G/verification-not-run-is-not-pass.bad.md" 2>&1)"; rc=$?
assert_eq "$rc" "1" "grade: a bad response exits 1"
assert_out_contains "$out" "FAIL must_match" "grade: names the failed grader"
assert_out_contains "$out" "NOT GRADED" "grade: prose criteria are reported as NOT GRADED, never as PASS"
python3 "$ROOT_DIR/evals/run.py" grade no-such-case "$G/verification-not-run-is-not-pass.good.md" >/dev/null 2>&1
assert_eq "$?" "2" "grade: unknown case id exits 2"

# a response that satisfies every must_match but trips a must_not_match must still fail
printf 'SELECT id FROM users WHERE email = @email\nvar u = q.Result;\n' > "$TMP_ROOT/blocking.txt"
out="$(python3 "$ROOT_DIR/evals/run.py" grade backend-parameterized-query "$TMP_ROOT/blocking.txt" 2>&1)"; rc=$?
assert_eq "$rc" "1" "grade: tripping only a must_not_match fails"
assert_out_contains "$out" "FAIL must_not_match" "grade: names the forbidden pattern that matched"
assert_out_contains "$out" "PASS must_match" "grade: and still shows the must_match that passed"

# --- broken inputs are caught ---------------------------------------------------------------------
W="$(new_dir)"; cp -r "$ROOT_DIR/." "$W/h" 2>/dev/null; rm -rf "$W/h/.git"
H="$W/h"
run_in() { (cd "$H" && python3 evals/run.py "$@" 2>&1); }

sed -i "s/destructive operations/destructive operations, extra made-up thing/" "$H/AGENTS.md"
out="$(run_in structure)"
assert_out_contains "$out" "AGENTS.md: high-risk category list has drifted" "structure: a drifted high-risk list is caught"
assert_out_contains "$out" "extra made-up thing" "structure: names the unexpected extra item"
cp "$ROOT_DIR/AGENTS.md" "$H/AGENTS.md"

sed -i "s/, destructive operations//" "$H/.pi/skills/workflow/independent-verifier/SKILL.md"
out="$(run_in structure)"
assert_out_contains "$out" "independent-verifier/SKILL.md: high-risk category list has drifted" "structure: a missing item in another restatement is caught"
assert_out_contains "$out" "'destructive operations'" "structure: names the missing item"
cp "$ROOT_DIR/.pi/skills/workflow/independent-verifier/SKILL.md" "$H/.pi/skills/workflow/independent-verifier/SKILL.md"

sed -i '3s/.*/description: Use for high-risk work./' "$H/.pi/skills/workflow/independent-verifier/SKILL.md"
out="$(run_in structure)"
assert_out_contains "$out" "expected a high-risk category list but found none" "structure: a missing high-risk list entirely is caught"
cp "$ROOT_DIR/.pi/skills/workflow/independent-verifier/SKILL.md" "$H/.pi/skills/workflow/independent-verifier/SKILL.md"

printf 'id: architecture-dup\ncategory: architecture\ntask: t\nexpected:\n  - e\nmust_match:\n  - "("\n' > "$H/evals/cases/architecture/broken.yml"
out="$(run_in lint)"; rc=$?
assert_eq "$rc" "1" "lint: an invalid regex fails"
assert_out_contains "$out" "bad regex" "lint: says the regex is bad"
rm "$H/evals/cases/architecture/broken.yml"

printf 'id: architecture-nograder\ncategory: architecture\ntask: t\nexpected:\n  - e\n' > "$H/evals/cases/architecture/nograder.yml"
out="$(run_in lint)"; assert_out_contains "$out" "no deterministic grader" "lint: a case with no deterministic grader is flagged"
rm "$H/evals/cases/architecture/nograder.yml"

# a grader that accepts everything cannot tell good from bad -> selftest must fail
cp "$H/evals/fixtures/verification-not-run-is-not-pass.good.md" "$H/evals/fixtures/verification-not-run-is-not-pass.bad.md"
out="$(run_in selftest)"; rc=$?
assert_eq "$rc" "1" "selftest: identical good/bad fixtures fail"
assert_out_contains "$out" "cannot tell good from bad" "selftest: explains why"
cp "$ROOT_DIR/evals/fixtures/verification-not-run-is-not-pass.bad.md" "$H/evals/fixtures/"
printf 'Everything is fine.\n' > "$H/evals/fixtures/verification-not-run-is-not-pass.good.md"
out="$(run_in selftest)"; rc=$?
assert_eq "$rc" "1" "selftest: a GOOD fixture that a grader rejects fails"
assert_out_contains "$out" "GOOD fixture is rejected" "selftest: says the good fixture was rejected"
cp "$ROOT_DIR/evals/fixtures/verification-not-run-is-not-pass.good.md" "$H/evals/fixtures/"
rm "$H/evals/fixtures/architecture-cache-obligations.good.md"
out="$(run_in selftest)"; assert_out_contains "$out" "missing fixture" "selftest: a missing fixture fails"
cp "$ROOT_DIR/evals/fixtures/architecture-cache-obligations.good.md" "$H/evals/fixtures/"

printf 'services/auth-typo\n' >> "$H/profiles/backend"
out="$(run_in structure)"; rc=$?
assert_eq "$rc" "1" "structure: a profile naming an unknown skill fails"
assert_out_contains "$out" "unknown skill 'services/auth-typo'" "structure: names the unknown skill"
cp "$ROOT_DIR/profiles/backend" "$H/profiles/backend"

sed -i "s|reading-map.md.*|(reference removed for the test)|; s|system-design-decision-tree.md||" "$H/.pi/prompts/design.md" "$H/.pi/laws/signals.md" "$H/.pi/skills/architecture/system-design/SKILL.md" "$H/.pi/skills/workflow/engineering-reasoning/SKILL.md" 2>/dev/null
out="$(run_in structure)"
assert_out_contains "$out" "reading-map.md is not referenced" "structure: an orphaned reference file is flagged"
cp "$ROOT_DIR/.pi/prompts/design.md" "$ROOT_DIR/.pi/laws/signals.md" "$ROOT_DIR/.pi/skills/architecture/system-design/SKILL.md" "$H/.pi/prompts/"; cp "$ROOT_DIR/.pi/laws/signals.md" "$H/.pi/laws/"; cp "$ROOT_DIR/.pi/skills/architecture/system-design/SKILL.md" "$H/.pi/skills/architecture/system-design/"; cp "$ROOT_DIR/.pi/skills/workflow/engineering-reasoning/SKILL.md" "$H/.pi/skills/workflow/engineering-reasoning/"

sed -i '/^services\/auth$/d' "$H/profiles/backend" "$H/profiles/fullstack" "$H/profiles/high-risk"
out="$(run_in structure)"
assert_out_contains "$out" "no profile installs it" "structure: a skill the signals rely on must be installable"
cp "$ROOT_DIR/profiles/"* "$H/profiles/"

echo "See .pi/laws/nope.md for details." >> "$H/AGENTS.md"
out="$(run_in structure)"
assert_out_contains "$out" ".pi/laws/nope.md, which does not exist" "structure: a dangling path reference in AGENTS.md is caught"
cp "$ROOT_DIR/AGENTS.md" "$H/AGENTS.md"

printf '\nSee `coding/no-such-skill` for details.\n' >> "$H/.pi/skills/coding/testing/SKILL.md"
out="$(run_in structure)"; assert_out_contains "$out" 'refers to skill `coding/no-such-skill`' "structure: a reference to a non-existent skill is caught"
cp "$ROOT_DIR/.pi/skills/coding/testing/SKILL.md" "$H/.pi/skills/coding/testing/SKILL.md"

python3 - "$H" <<'EOF'
import sys
p=sys.argv[1]+"/AGENTS.md"
open(p,"a").write("x"*7000)
EOF
out="$(run_in structure)"; assert_out_contains "$out" "AGENTS.md is" "structure: an oversized always-loaded AGENTS.md is flagged"
cp "$ROOT_DIR/AGENTS.md" "$H/AGENTS.md"

printf -- '---\nname: broken\n---\n# no description\n' > "$H/.pi/skills/coding/testing/SKILL.md"
out="$(run_in structure)"; assert_out_contains "$out" "missing 'description'" "structure: a skill without a description is flagged"
cp "$ROOT_DIR/.pi/skills/coding/testing/SKILL.md" "$H/.pi/skills/coding/testing/SKILL.md"

chmod -x "$H/install.sh"
out="$(run_in structure)"; assert_out_contains "$out" "install.sh is not executable" "structure: a non-executable script is flagged"
chmod +x "$H/install.sh"

out="$(run_in structure)"; assert_eq "$?" "0" "structure: passes again once everything is restored"

# --- eval.sh --------------------------------------------------------------------------------------
"$ROOT_DIR/eval.sh" smoke >/dev/null 2>&1; assert_eq "$?" "0" "eval.sh smoke passes on the shipped harness"
"$ROOT_DIR/eval.sh" benchmark >/dev/null 2>&1; assert_eq "$?" "2" "eval.sh benchmark is NOT RUN (2), never a fake pass"
"$ROOT_DIR/eval.sh" bogus >/dev/null 2>&1; assert_eq "$?" "2" "eval.sh rejects unknown modes"
"$ROOT_DIR/eval.sh" grade verification-not-run-is-not-pass "$G/verification-not-run-is-not-pass.bad.md" >/dev/null 2>&1
assert_eq "$?" "1" "eval.sh grade propagates a failing verdict"
(cd "$H" && rm evals/fixtures/architecture-cache-obligations.bad.md && ./eval.sh smoke >/dev/null 2>&1); assert_eq "$?" "1" "eval.sh smoke fails when a check fails"

finish
