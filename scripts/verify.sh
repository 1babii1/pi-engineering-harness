#!/usr/bin/env bash
# Deterministic, change-scoped verification.
#
#   verify.sh [quick|standard|full] [--all]
#
# Looks at what changed (tracked diff vs HEAD, staged, and NEW untracked files), works out which
# project areas are affected, finds the project directory for each area (the nearest ancestor with
# a solution / package.json), runs the matching verify-* script, and prints a PASS / FAIL / NOT RUN
# report. Exit code: 0 all PASS, 1 any FAIL, 2 nothing failed but something could not run.
#
# Levels: quick | standard | full. Backend runs build + test at every level. Frontend skips the
# production build at `quick`. Kubernetes manifests are validated at standard/full. Project-specific
# commands override auto-detection through .pi/project/commands.sh (see the verify-* scripts).
set -euo pipefail

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LEVEL="quick"
ALL=0

usage() { echo "Usage: $0 [quick|standard|full] [--all]" >&2; }
for arg in "$@"; do
  case "$arg" in
    quick|standard|full) LEVEL="$arg";;
    --all) ALL=1;;
    -h|--help) usage; exit 0;;
    *) usage; exit 2;;
  esac
done

if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then cd "$root"; fi
in_git=0; git rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git=1

changed=()
if [[ $in_git -eq 1 ]]; then
  if [[ $ALL -eq 1 ]]; then
    mapfile -d '' changed < <(git ls-files -z --cached --others --exclude-standard | sort -zu)
  else
    mapfile -d '' changed < <(
      {
        git diff --name-only -z HEAD 2>/dev/null || git diff --name-only -z 2>/dev/null || true
        git diff --name-only -z --cached 2>/dev/null || true
        git ls-files -z --others --exclude-standard
      } | sort -zu)
  fi
else
  echo "Not a git repository: cannot detect changes. Run the area scripts in $SCRIPTS directly." >&2
  exit 2
fi

if [[ ${#changed[@]} -eq 0 ]]; then
  echo "No changed files detected; nothing to verify. (Use --all to verify the whole tree.)"
  exit 0
fi

# Closest ancestor directory of <path> that contains a file matching one of the globs.
nearest_dir() {
  local d g
  d="$(dirname "$1")"
  while :; do
    for g in "${@:2}"; do
      if compgen -G "$d/$g" >/dev/null; then echo "$d"; return 0; fi
    done
    if [[ "$d" == "." || "$d" == "/" ]]; then return 1; fi
    d="$(dirname "$d")"
  done
}

# Does the solution file(s) in <ancestor> list <dir> (a path relative to it)? Decided from the
# solution's own text (".slnx" uses "/", legacy ".sln" uses "\\"; the path opens with a quote, so
# "OtherSvc/" does not count as listing "Svc/"), never assumed.
lists_dir() { # lists_dir <ancestor> <relative dir>
  local s
  for s in "$1"/*.slnx "$1"/*.sln; do
    [[ -f "$s" ]] || continue
    if grep -qF -e "\"$2/" -e "\"${2//\//\\}\\" "$s"; then return 0; fi
  done
  return 1
}

# The solution directory to build for a changed backend file: start from the NEAREST solution
# (backend/AuthService/AuthService.slnx), then walk up and prefer the OUTERMOST ancestor solution
# that lists that directory (backend/backend.slnx). Per-service solutions frequently omit the test
# projects, so building only the nearest one can "pass" while running no tests at all; the
# aggregate that lists the service is the one that includes them. An ancestor that does not list
# the directory is not used, so nothing is assumed to be covered.
backend_dir() {
  local d anc best rel
  d="$(nearest_dir "$1" '*.slnx' '*.sln' || nearest_dir "$1" '*.csproj' || echo ".")"
  best="$d"; anc="$d"
  while [[ "$anc" != "." && "$anc" != "/" ]]; do
    anc="$(dirname "$anc")"
    rel="$d"; [[ "$anc" == "." ]] || rel="${d#"$anc"/}"
    if lists_dir "$anc" "$rel"; then best="$anc"; fi
  done
  echo "$best"
}

declare -A BACKEND_DIRS=() FRONTEND_DIRS=() K8S_FILES=()
helm_changed=0
for f in "${changed[@]}"; do
  case "$f" in
    *.cs|*.csproj|*.sln|*.slnx|*.props|*.targets|global.json)
      BACKEND_DIRS["$(backend_dir "$f")"]=1;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.css|*.scss|package.json|package-lock.json|tsconfig*.json)
      if d="$(nearest_dir "$f" package.json)"; then FRONTEND_DIRS["$d"]=1; fi;;
    *.yml|*.yaml)
      case "$f" in
        docker-compose*|*/docker-compose*|.github/*|*/.github/*) ;;
        helm/*|charts/*|*/helm/*|*/charts/*) helm_changed=1;;
        k8s/*|*/k8s/*|kubernetes/*|*/kubernetes/*|manifests/*|*/manifests/*) [[ -f "$f" ]] && K8S_FILES["$f"]=1;;
        *)
          # Only treat a YAML file as a Kubernetes manifest if it looks like one.
          if [[ -f "$f" ]] && grep -qE '^apiVersion:' "$f" && grep -qE '^kind:' "$f"; then K8S_FILES["$f"]=1; fi;;
      esac;;
  esac
done

names=(); results=(); reasons=()
worst=0
run_area() { # run_area <label> <cmd...>
  local label="$1" rc
  shift
  echo "==> $label"
  set +e
  "$@"
  rc=$?
  set -e
  names+=("$label")
  case "$rc" in
    0) results+=("PASS"); reasons+=("");;
    2) results+=("NOT RUN"); reasons+=("tooling/config missing - see output above"); [[ $worst -eq 1 ]] || worst=2;;
    *) results+=("FAIL"); reasons+=("exit $rc"); worst=1;;
  esac
}
not_run() { names+=("$1"); results+=("NOT RUN"); reasons+=("$2"); [[ $worst -eq 1 ]] || worst=2; }

export VERIFY_LEVEL="$LEVEL"
sorted() { printf '%s\n' "$@" | sort; }

if [[ ${#BACKEND_DIRS[@]} -gt 0 ]]; then
  mapfile -t dirs < <(sorted "${!BACKEND_DIRS[@]}")
  run_area "backend (${dirs[*]})" "$SCRIPTS/verify-backend.sh" "${dirs[@]}"
fi
if [[ ${#FRONTEND_DIRS[@]} -gt 0 ]]; then
  mapfile -t dirs < <(sorted "${!FRONTEND_DIRS[@]}")
  run_area "frontend (${dirs[*]})" "$SCRIPTS/verify-frontend.sh" "${dirs[@]}"
fi
if [[ "$LEVEL" != quick ]]; then
  if [[ ${#K8S_FILES[@]} -gt 0 ]]; then
    mapfile -t files < <(sorted "${!K8S_FILES[@]}")
    run_area "kubernetes (${#files[@]} manifest file(s))" "$SCRIPTS/verify-k8s.sh" "${files[@]}"
  fi
  if [[ $helm_changed -eq 1 ]]; then
    run_area "helm chart" "$SCRIPTS/verify-k8s.sh" --helm
  fi
elif [[ ${#K8S_FILES[@]} -gt 0 || $helm_changed -eq 1 ]]; then
  not_run "kubernetes" "manifests changed; run verify.sh standard to validate them"
fi

if [[ ${#names[@]} -eq 0 ]]; then
  echo "No known project area detected in the changed files. Use repository-specific verification commands."
  exit 0
fi

echo
echo "=== verification report (level: $LEVEL) ==="
for i in "${!names[@]}"; do
  printf '%-8s %s%s\n' "${results[$i]}" "${names[$i]}" "${reasons[$i]:+  [${reasons[$i]}]}"
done
exit "$worst"
