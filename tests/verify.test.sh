#!/usr/bin/env bash
# Behavioural tests for scripts/verify*.sh. Uses stub `dotnet`, `npm` and `kubeconform` binaries
# placed first on PATH, so the tests prove WHICH commands are run, in WHICH directory and with
# WHAT verdict - without needing the real toolchains. Real `node` is used to read package.json.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
command -v node >/dev/null 2>&1 || { echo "node is required for verify tests; skipping"; exit 0; }

STUBS="$TMP_ROOT/stubs"; mkdir -p "$STUBS"
cat > "$STUBS/dotnet" <<'EOF'
#!/usr/bin/env bash
echo "dotnet $* (cwd=$PWD)" >> "$STUB_LOG"
[[ -n "${DOTNET_FAIL_ON:-}" && "$1" == "$DOTNET_FAIL_ON" ]] && exit 1
exit 0
EOF
cat > "$STUBS/npm" <<'EOF'
#!/usr/bin/env bash
echo "npm $* (cwd=$PWD CI=${CI:-})" >> "$STUB_LOG"
[[ -n "${NPM_FAIL_ON:-}" && "$*" == *"$NPM_FAIL_ON"* ]] && exit 1
exit 0
EOF
cat > "$STUBS/kubeconform" <<'EOF'
#!/usr/bin/env bash
echo "kubeconform $*" >> "$STUB_LOG"
exit "${KUBECONFORM_RC:-0}"
EOF
chmod +x "$STUBS"/*
export STUB_LOG="$TMP_ROOT/stub.log"
VERIFY="$ROOT_DIR/scripts/verify.sh"

new_repo() {
  local d; d="$(new_dir)"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t \
    && echo base > README.md && git add . && git commit -qm base ) >/dev/null
  echo "$d"
}
# verify <repo> [args...] -> sets OUT and RC; STUB_LOG is reset first
verify() {
  local repo="$1"; shift
  : > "$STUB_LOG"
  OUT="$(cd "$repo" && PATH="$STUBS:$PATH" "$VERIFY" "$@" 2>&1)"; RC=$?
}
log_has() { grep -qF -- "$1" "$STUB_LOG"; }
log_lines() { wc -l < "$STUB_LOG" | tr -d ' '; }

echo "verify.sh"

# --- backend: a NEW untracked file is detected, and the solution in a subdirectory is found ----
R="$(new_repo)"
mkdir -p "$R/backend/Svc" && touch "$R/backend/backend.slnx" && echo "class A{}" > "$R/backend/Svc/A.cs"
( cd "$R" && git add backend/backend.slnx && git commit -qm sln ) >/dev/null
echo "class B{}" > "$R/backend/Svc/B.cs"   # untracked only
verify "$R"
assert_eq "$RC" "0" "untracked .cs triggers backend verification and passes"
log_has "dotnet build backend/backend.slnx" && ok "builds the solution found in backend/ (not the repo root)" || bad "builds the solution found in backend/" "$(cat "$STUB_LOG")"
log_has "dotnet test backend/backend.slnx --no-build" && ok "runs tests against that solution" || bad "runs tests against that solution"
assert_out_contains "$OUT" "PASS     backend (backend)" "report lists backend as PASS"

# --- backend failure ---------------------------------------------------------------------------
export DOTNET_FAIL_ON=test; verify "$R"; unset DOTNET_FAIL_ON
assert_eq "$RC" "1" "failing dotnet test -> exit 1"
assert_out_contains "$OUT" "FAIL     backend" "report lists backend as FAIL"

# --- no changes --------------------------------------------------------------------------------
( cd "$R" && git add -A && git commit -qm all ) >/dev/null
verify "$R"
assert_eq "$RC" "0" "clean tree exits 0"
assert_out_contains "$OUT" "nothing to verify" "clean tree says nothing to verify"
assert_eq "$(log_lines)" "0" "clean tree runs no tools"
verify "$R" --all
log_has "dotnet build" && ok "--all verifies a clean tree" || bad "--all verifies a clean tree"

# --- deleted source file still counts as a backend change -------------------------------------
( cd "$R" && git rm -q backend/Svc/B.cs )
verify "$R"
log_has "dotnet build backend/backend.slnx" && ok "a deleted .cs triggers backend verification" || bad "a deleted .cs triggers backend verification"
( cd "$R" && git reset -q --hard )

# --- staged-only change ------------------------------------------------------------------------
echo "class C{}" > "$R/backend/Svc/C.cs"; ( cd "$R" && git add backend/Svc/C.cs )
verify "$R"
log_has "dotnet build" && ok "a staged-only change is detected" || bad "a staged-only change is detected"
( cd "$R" && git reset -q --hard && git clean -fdq )

# --- YAML false positives are gone --------------------------------------------------------------
R2="$(new_repo)"
printf 'services:\n  a:\n    image: x\n' > "$R2/docker-compose.yml"
mkdir -p "$R2/.github/workflows" && printf 'name: ci\non: push\n' > "$R2/.github/workflows/ci.yml"
printf 'key: value\n' > "$R2/config.yaml"
verify "$R2" standard
assert_out_contains "$OUT" "No known project area" "compose/workflow/plain yaml do not trigger k8s verification"
assert_eq "$(log_lines)" "0" "and no tool was invoked for them"

# --- k8s: detection by directory or by content; level gating ----------------------------------
mkdir -p "$R2/k8s" && printf 'apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: x\n' > "$R2/k8s/cm.yaml"
verify "$R2" quick
assert_eq "$RC" "2" "k8s change at quick level is NOT RUN (exit 2)"
assert_out_contains "$OUT" "NOT RUN" "quick reports NOT RUN for manifests"
assert_eq "$(log_lines)" "0" "quick does not invoke kubeconform"
verify "$R2" standard
log_has "kubeconform -strict -ignore-missing-schemas -summary k8s/cm.yaml" && ok "standard validates the changed manifest file" || bad "standard validates the changed manifest" "$(cat "$STUB_LOG")"
assert_eq "$RC" "0" "kubeconform pass -> exit 0"
KUBECONFORM_RC=1 verify "$R2" standard
assert_eq "$RC" "1" "kubeconform failure -> exit 1"
rm -rf "$R2/k8s"; printf 'apiVersion: apps/v1\nkind: Deployment\n' > "$R2/deploy.yaml"
verify "$R2" standard
log_has "kubeconform" && ok "a manifest outside k8s/ is recognised by apiVersion+kind" || bad "a manifest outside k8s/ is recognised by apiVersion+kind"
rm "$R2/deploy.yaml"

# --- helm: cannot be validated without rendering ------------------------------------------------
mkdir -p "$R2/helm/app/templates" && printf 'kind: X\n' > "$R2/helm/app/templates/a.yaml"
verify "$R2" standard
assert_eq "$RC" "2" "helm change is NOT RUN, never a silent pass"
assert_out_contains "$OUT" "K8S_VERIFY_CMD" "helm message says how to configure it"
# with a configured command, the same helm change runs it (from the repo root) instead of being NOT RUN
mkdir -p "$R2/.pi/project"; echo 'K8S_VERIFY_CMD="pwd > helm-ran.txt"' > "$R2/.pi/project/commands.sh"
verify "$R2" standard
assert_eq "$RC" "0" "helm change with K8S_VERIFY_CMD configured runs it and passes"
assert_eq "$(cat "$R2/helm-ran.txt" 2>/dev/null)" "$R2" "and runs it from the repository root"
rm -rf "$R2/helm" "$R2/.pi" "$R2/helm-ran.txt"

# --- frontend -----------------------------------------------------------------------------------
R3="$(new_repo)"
mkdir -p "$R3/frontend/src" "$R3/frontend/node_modules" "$R3/load-tests/k6"
printf '{"scripts":{"lint":"x","test":"x","build":"x"}}' > "$R3/frontend/package.json"
echo "export {}" > "$R3/frontend/src/a.ts"
verify "$R3" quick
assert_eq "$RC" "0" "frontend quick passes"
log_has "npm run lint (cwd=$R3/frontend CI=true)" && ok "runs lint inside frontend/ with CI=true (no watch-mode hang)" || bad "runs lint inside frontend/ with CI=true" "$(cat "$STUB_LOG")"
log_has "npm run test" && ok "runs test" || bad "runs test"
log_has "npm run build" && bad "quick must skip the production build" || ok "quick skips the production build"
verify "$R3" standard
log_has "npm run build" && ok "standard includes the build" || bad "standard includes the build"
NPM_FAIL_ON="run test" verify "$R3" standard
assert_eq "$RC" "1" "a failing frontend script -> exit 1"

echo "console.log(1)" > "$R3/load-tests/k6/main.js"
( cd "$R3" && git add -A && git commit -qm f ) >/dev/null
echo "console.log(2)" > "$R3/load-tests/k6/main.js"
verify "$R3" quick
assert_out_contains "$OUT" "No known project area" "a .js file with no package.json ancestor is not a frontend change"
assert_eq "$(log_lines)" "0" "and runs no npm"

rm -rf "$R3/frontend/node_modules"; echo "export const b=1" > "$R3/frontend/src/b.ts"
verify "$R3" quick
assert_eq "$RC" "2" "missing node_modules -> NOT RUN"
assert_out_contains "$OUT" "run 'npm install' first" "and says why"

# --- verdict precedence: FAIL beats NOT RUN ------------------------------------------------------
R4="$(new_repo)"
mkdir -p "$R4/api" "$R4/web" && touch "$R4/api/a.slnx" && echo "c" > "$R4/api/x.cs"
printf '{"scripts":{"test":"x"}}' > "$R4/web/package.json"; echo "x" > "$R4/web/i.ts"   # no node_modules
DOTNET_FAIL_ON=build verify "$R4"
assert_eq "$RC" "1" "FAIL (backend) outranks NOT RUN (frontend)"
assert_out_contains "$OUT" "NOT RUN  frontend" "both verdicts are reported"

# the other order: NOT RUN reported first (backend), FAIL later (frontend) must still end as FAIL
R4b="$(new_repo)"
mkdir -p "$R4b/api" "$R4b/web/node_modules" && touch "$R4b/api/a.sln" "$R4b/api/b.sln" && echo "c" > "$R4b/api/x.cs"
printf '{"scripts":{"test":"x"}}' > "$R4b/web/package.json"; echo "x" > "$R4b/web/i.ts"
NPM_FAIL_ON="run test" verify "$R4b"
assert_eq "$RC" "1" "a later FAIL outranks an earlier NOT RUN"
assert_out_contains "$OUT" "NOT RUN  backend" "the earlier NOT RUN is still reported"

# --- commands.sh override -----------------------------------------------------------------------
R5="$(new_repo)"
mkdir -p "$R5/.pi/project" "$R5/backend" && touch "$R5/backend/b.sln" && echo "c" > "$R5/backend/x.cs"
echo 'BACKEND_VERIFY_CMD="pwd > override-ran.txt"' > "$R5/.pi/project/commands.sh"
verify "$R5"
assert_eq "$RC" "0" "override command passes"
assert_eq "$(cat "$R5/override-ran.txt" 2>/dev/null)" "$R5" "override runs once from the repository root"
assert_eq "$(log_lines)" "0" "override replaces auto-detected dotnet calls"
echo 'BACKEND_VERIFY_CMD="exit 2"' > "$R5/.pi/project/commands.sh"
verify "$R5"
assert_eq "$RC" "1" "override exiting 2 is a FAIL, not masked as NOT RUN"

# --- nested solutions: the outermost ancestor that LISTS a directory is used; one that does not, is not ----
R8="$(new_repo)"
mkdir -p "$R8/backend/Svc" "$R8/backend/Other"
printf '<Solution><Project Path="Svc/Svc.csproj" /></Solution>\n' > "$R8/backend/backend.slnx"
touch "$R8/backend/Svc/Svc.slnx" "$R8/backend/Other/Other.slnx"
echo c > "$R8/backend/Svc/a.cs"; echo c > "$R8/backend/Other/b.cs"; echo "<x/>" > "$R8/backend/Directory.Packages.props"
verify "$R8"
log_has "dotnet build backend/backend.slnx" && ok "the aggregate solution runs" || bad "the aggregate solution runs"
log_has "dotnet build backend/Svc/Svc.slnx" && bad "nested solution listed by the aggregate is not built twice" || ok "nested solution listed by the aggregate is not built twice"
log_has "dotnet build backend/Other/Other.slnx" && ok "nested solution NOT listed by the aggregate still runs (no assumed coverage)" || bad "nested solution NOT listed by the aggregate still runs (no assumed coverage)" "$(cat "$STUB_LOG")"
# legacy .sln lists projects with backslashes
rm "$R8/backend/backend.slnx"; printf 'Project("{X}") = "Svc", "Svc\\Svc.csproj", "{Y}"\n' > "$R8/backend/backend.sln"
verify "$R8"
log_has "dotnet build backend/Svc/Svc.slnx" && bad "backslash paths in a legacy .sln are understood" || ok "backslash paths in a legacy .sln are understood"
# only the nested service changed: per-service solutions usually omit the test projects, so the
# aggregate that lists the service is used - a narrow build here could "pass" with zero tests run
R9="$(new_repo)"
mkdir -p "$R9/backend/Svc"; printf '<Solution><Project Path="Svc/Svc.csproj" /></Solution>\n' > "$R9/backend/backend.slnx"
touch "$R9/backend/Svc/Svc.slnx"; ( cd "$R9" && git add -A && git commit -qm s ) >/dev/null
echo c > "$R9/backend/Svc/a.cs"
verify "$R9"
log_has "dotnet build backend/backend.slnx" && ok "a change in one service builds the aggregate solution that lists it (includes tests)" || bad "a change in one service builds the aggregate solution that lists it" "$(cat "$STUB_LOG")"
log_has "dotnet build backend/Svc/Svc.slnx" && bad "the narrow per-service solution is not used when an aggregate lists it" || ok "the narrow per-service solution is not used when an aggregate lists it"
# an ancestor that does NOT list the service is not assumed to cover it
printf '<Solution><Project Path="Other/Other.csproj" /></Solution>\n' > "$R9/backend/backend.slnx"
verify "$R9"
log_has "dotnet build backend/Svc/Svc.slnx" && ok "an ancestor solution that does not list the service is not used" || bad "an ancestor solution that does not list the service is not used" "$(cat "$STUB_LOG")"
# sibling name that merely shares a prefix must not count as listed ("Svc2/" is not "Svc/")
printf '<Solution><Project Path="Svc2/Svc2.csproj" /></Solution>\n' > "$R9/backend/backend.slnx"
verify "$R9"
log_has "dotnet build backend/Svc/Svc.slnx" && ok "a prefix-sharing sibling (Svc2/) does not count as listing Svc/" || bad "a prefix-sharing sibling (Svc2/) does not count as listing Svc/"

# a name that merely CONTAINS the directory name ("OtherSvc/" vs "Svc/") is not a listing
printf '<Solution><Project Path="OtherSvc/OtherSvc.csproj" /></Solution>\n' > "$R9/backend/backend.slnx"
verify "$R9"
log_has "dotnet build backend/Svc/Svc.slnx" && ok "a substring match inside another name (OtherSvc/) does not count as listing Svc/" || bad "a substring match inside another name (OtherSvc/) does not count as listing Svc/" "$(cat "$STUB_LOG")"

# --- ambiguity / missing tooling / no git ---------------------------------------------------------
R6="$(new_repo)"
mkdir -p "$R6/b" && touch "$R6/b/one.sln" "$R6/b/two.sln" && echo c > "$R6/b/x.cs"
verify "$R6"
assert_eq "$RC" "2" "two solutions in one directory -> NOT RUN"
assert_out_contains "$OUT" "Cannot pick a single solution/project" "ambiguity is explained"
assert_eq "$(log_lines)" "0" "no guessing: dotnet is not invoked"

NOTOOLS="$TMP_ROOT/notools"; mkdir -p "$NOTOOLS"
for t in git bash sort dirname grep mkdir cat wc tr printf env; do ln -sf "$(command -v $t)" "$NOTOOLS/$t" 2>/dev/null; done
R7="$(new_repo)"; touch "$R7/a.slnx" "$R7/x.cs"
OUT="$(cd "$R7" && PATH="$NOTOOLS" "$VERIFY" 2>&1)"; RC=$?
assert_eq "$RC" "2" "no dotnet installed -> NOT RUN"
assert_out_contains "$OUT" "dotnet is not installed" "missing tool is named"

NOGIT="$(new_dir)"; touch "$NOGIT/x.cs"
OUT="$(cd "$NOGIT" && "$VERIFY" 2>&1)"; RC=$?
assert_eq "$RC" "2" "outside a git repository -> exit 2"
assert_out_contains "$OUT" "Not a git repository" "and says so"

"$VERIFY" bogus >/dev/null 2>&1; assert_eq "$?" "2" "unknown argument exits 2"

finish
