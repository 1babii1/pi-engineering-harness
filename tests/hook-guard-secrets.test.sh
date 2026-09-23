#!/usr/bin/env bash
# Behavior tests for hooks/guard-secrets.py: feed it a PreToolUse JSON payload on stdin, assert
# exit code 2 (block) or 0 (allow). Grouped as block-cases and allow-cases so a change that widens
# or narrows the patterns shows up as a count mismatch, not just individual failures.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=tests/lib.sh
source tests/lib.sh

HOOK="python3 $ROOT_DIR/hooks/guard-secrets.py"

run_hook() { # run_hook <json> -> exit code (never fails the test script itself)
  echo "$1" | $HOOK >/dev/null 2>/tmp/guard-secrets-test.err
  echo $?
}

assert_blocked() {
  local json="$1" label="$2"
  local rc; rc="$(run_hook "$json")"
  [[ "$rc" == "2" ]] && ok "$label" || bad "$label" "expected exit 2, got $rc"
}

assert_allowed() {
  local json="$1" label="$2"
  local rc; rc="$(run_hook "$json")"
  [[ "$rc" == "0" ]] && ok "$label" || bad "$label" "expected exit 0, got $rc"
}

tool() { # tool <name> <tool_input-json> -> full payload
  printf '{"tool_name":"%s","tool_input":%s}' "$1" "$2"
}

# --- block: file/search tools --------------------------------------------------------------
assert_blocked "$(tool Read '{"file_path":".env"}')" "blocks Read .env"
assert_blocked "$(tool Read '{"file_path":".env.local"}')" "blocks Read .env.local"
assert_blocked "$(tool Read '{"file_path":"config/.env.production"}')" "blocks Read nested .env.production"
assert_blocked "$(tool Edit '{"file_path":".env"}')" "blocks Edit .env"
assert_blocked "$(tool Write '{"file_path":".env"}')" "blocks Write .env"
assert_blocked "$(tool MultiEdit '{"file_path":"x.txt","edits":[{"file_path":".env"}]}')" "blocks MultiEdit targeting .env in edits[]"
assert_blocked "$(tool Grep '{"pattern":"foo","path":".env"}')" "blocks Grep path=.env"
assert_blocked "$(tool Glob '{"pattern":"**/.env*"}')" "blocks Glob pattern **/.env* (the real Glob tool's shape)"
assert_blocked "$(tool Grep '{"pattern":"x","glob":".env*"}')" "blocks Grep glob .env*"
assert_blocked "$(tool Read '{"file_path":"src/../.env"}')" "blocks Read via a .. segment"
assert_blocked "$(tool Read '{"file_path":".ENV"}')" "blocks .ENV (case-insensitive filesystems)"
assert_blocked "$(tool Read '{"file_path":"VAULT.ENC.JSON"}')" "blocks VAULT.ENC.JSON (case-insensitive filesystems)"
assert_blocked "$(tool Read '{"file_path":"secrets/vault.enc.json"}')" "blocks Read *.enc.json"
assert_blocked "$(tool Read '{"file_path":"vault.enc.yaml"}')" "blocks Read *.enc.yaml"
assert_blocked "$(tool Read '{"file_path":"~/.ssh/id_rsa"}')" "blocks Read id_rsa"
assert_blocked "$(tool Read '{"file_path":"~/.ssh/id_ed25519"}')" "blocks Read id_ed25519"
assert_blocked "$(tool Read '{"file_path":"cert.pem"}')" "blocks Read *.pem"
assert_blocked "$(tool Read '{"file_path":"client.p12"}')" "blocks Read *.p12"
assert_blocked "$(tool Read '{"file_path":"app.pfx"}')" "blocks Read *.pfx"
assert_blocked "$(tool Read '{"file_path":"~/.config/sops/age/keys.txt"}')" "blocks Read age keys.txt"
assert_blocked "$(tool NotebookEdit '{"notebook_path":".env"}')" "blocks NotebookEdit notebook_path=.env"

# --- block: Bash ------------------------------------------------------------------------------
assert_blocked "$(tool Bash '{"command":"cat .env.local"}')" "blocks bash cat .env.local"
assert_blocked "$(tool Bash '{"command":"grep DATABASE_URL .env"}')" "blocks bash grep on .env"
assert_blocked "$(tool Bash '{"command":"sed -n 1,5p .env"}')" "blocks bash sed on .env"
assert_blocked "$(tool Bash '{"command":"printenv"}')" "blocks bare printenv"
assert_blocked "$(tool Bash '{"command":"env"}')" "blocks bare env"
assert_blocked "$(tool Bash '{"command":"cd app && env"}')" "blocks env after a compound command"
assert_blocked "$(tool Bash '{"command":"FOO=1 env"}')" "blocks env behind a variable assignment"
assert_blocked "$(tool Bash '{"command":"export -p"}')" "blocks export -p"
assert_blocked "$(tool Bash '{"command":"declare -x"}')" "blocks declare -x"
assert_blocked "$(tool Bash '{"command":"set"}')" "blocks bare set"
assert_blocked "$(tool Bash '{"command":"cat /proc/self/environ"}')" "blocks /proc/self/environ"
assert_blocked "$(tool Bash '{"command":"cat .env*"}')" "blocks a shell glob that expands to .env"
assert_blocked "$(tool Bash '{"command":"cat \".env\""}')" "blocks a quoted .env path"
assert_blocked "$(tool Bash '{"command":"sops -d secrets.enc.yaml"}')" "blocks sops -d on a vault"
assert_blocked "$(tool Bash '{"command":"source .env"}')" "blocks source .env"

# --- allow --------------------------------------------------------------------------------
assert_allowed "$(tool Read '{"file_path":".env.example"}')" "allows Read .env.example"
assert_allowed "$(tool Read '{"file_path":"src/environment.ts"}')" "allows Read environment.ts (not an env-file)"
assert_allowed "$(tool Read '{"file_path":"docs/env.md"}')" "allows Read docs/env.md"
assert_allowed "$(tool Grep '{"pattern":"\\.enc\\.json","path":"src"}')" "allows Grep whose search TEXT mentions .enc.json (not a path)"
assert_allowed "$(tool Read '{"file_path":"id_rsa.pub"}')" "allows Read id_rsa.pub (public key, not a secret)"
assert_allowed "$(tool Bash '{"command":"dotnet run"}')" "allows unrelated bash command"
assert_allowed "$(tool Bash '{"command":"secrets-run prod -- dotnet run"}')" "allows secrets-run invocation"
assert_allowed "$(tool Bash '{"command":"env -i dotnet run"}')" "allows env -i (sandboxing idiom, not a leak)"
assert_allowed "$(tool Read '{"file_path":"README.md"}')" "allows Read of an unrelated file"
assert_allowed "$(tool Bash '{"command":"cat .env.example"}')" "allows bash cat .env.example"
assert_allowed "$(tool Bash '{"command":"ASPNETCORE_ENVIRONMENT=Development dotnet run"}')" "allows an env-var assignment before a normal command"
assert_allowed "$(tool Bash '{"command":"source .venv/bin/activate"}')" "allows sourcing a virtualenv"
assert_allowed "$(tool Bash '{"command":"set -euo pipefail"}')" "allows set with options (not a variable dump)"
assert_allowed "$(tool Glob '{"pattern":"**/*.ts"}')" "allows an ordinary Glob"
rc="$(run_hook 'not json')"; assert_eq "$rc" "0" "malformed hook input fails open by design"
BADX="$(new_dir)"; mkdir -p "$BADX/.pi/project"; printf '(unclosed\n' > "$BADX/.pi/project/secret-patterns.txt"
rc=0; ( cd "$BADX" && printf '%s' "$(tool Read '{"file_path":".env"}')" | python3 "$ROOT_DIR/hooks/guard-secrets.py" >/dev/null 2>&1 ) || rc=$?
assert_eq "$rc" "2" "an invalid project pattern is ignored and the defaults still block"

# --- regressions from the independent verification (each was an allowed bypass) ---------------
assert_blocked "$(tool Bash '{"command":"cat .env.*"}')" "blocks bash glob .env.*"
assert_blocked "$(tool Bash '{"command":"rg x -g \".env.*\""}')" "blocks rg -g .env.*"
assert_blocked "$(tool Grep '{"pattern":"x","glob":".env.*"}')" "blocks Grep glob .env.*"
assert_blocked "$(tool Grep '{"pattern":"x","glob":"**/.env.*"}')" "blocks Grep glob **/.env.*"
assert_blocked "$(tool Grep '{"pattern":"x","glob":"*.enc.*"}')" "blocks Grep glob *.enc.*"
assert_blocked "$(tool Glob '{"pattern":"**/.env.*"}')" "blocks Glob **/.env.*"
assert_blocked "$(tool Bash '{"command":"(cat .env)"}')" "blocks a path followed by ) "
assert_blocked "$(tool Bash '{"command":"echo $(cat .env)"}')" "blocks a literal path inside \$( )"
assert_blocked "$(tool Bash '{"command":"echo `cat .env`"}')" "blocks a literal path inside backticks"
assert_blocked "$(tool Bash '{"command":"cat --file=.env"}')" "blocks --flag=.env"
assert_blocked "$(tool Bash '{"command":"docker run --env-file=.env x"}')" "blocks --env-file=.env"
assert_blocked "$(tool Bash '{"command":"git show HEAD:.env"}')" "blocks git show REV:.env"
assert_blocked "$(tool Bash '{"command":"git show HEAD:.env.local"}')" "blocks git show REV:.env.local"
for w in "sudo env" "time env" "command env" "exec env" "nohup env" "/usr/bin/env" 'bash -c "env"' "export" "declare -p" "env | sort" "env -0"; do
  assert_blocked "$(tool Bash "$(python3 -c 'import json,sys;print(json.dumps({"command":sys.argv[1]}))' "$w")")" "blocks env dump form: $w"
done
assert_blocked "$(tool Read '{"file_path":".envrc"}')" "blocks .envrc (direnv usually exports secrets)"
assert_allowed "$(tool Bash '{"command":"env FOO=1 dotnet run"}')" "allows env running a command (not a dump)"
assert_allowed "$(tool Bash '{"command":"export FOO=bar"}')" "allows export with an assignment"
assert_allowed "$(tool Bash '{"command":"docker run --env-file=.env.example x"}')" "allows --env-file=.env.example"
assert_allowed "$(tool Bash '{"command":"git show HEAD:.env.example"}')" "allows git show REV:.env.example"
assert_allowed "$(tool Bash '{"command":"git show HEAD:src/environment.ts"}')" "allows git show of an unrelated file"

# --- project root: patterns load from $CLAUDE_PROJECT_DIR even when cwd is a subdirectory -------
SUB="$(new_dir)"; mkdir -p "$SUB/.pi/project" "$SUB/deep/er"
printf '(^|/)credentials\\.json$\n' > "$SUB/.pi/project/secret-patterns.txt"
rc=0; ( cd "$SUB/deep/er" && printf '%s' "$(tool Read '{"file_path":"credentials.json"}')" | CLAUDE_PROJECT_DIR="$SUB" python3 "$ROOT_DIR/hooks/guard-secrets.py" >/dev/null 2>&1 ) || rc=$?
assert_eq "$rc" "2" "project patterns are found via CLAUDE_PROJECT_DIR from a subdirectory"

# --- project-owned extension file ------------------------------------------------------------
EXT="$(new_dir)"; mkdir -p "$EXT/.pi/project"
printf '# comment\n\n(^|/)credentials\\.json$\n' > "$EXT/.pi/project/secret-patterns.txt"
rc=0; ( cd "$EXT" && printf '%s' "$(tool Read '{"file_path":"credentials.json"}')" | python3 "$ROOT_DIR/hooks/guard-secrets.py" >/dev/null 2>&1 ) || rc=$?
assert_eq "$rc" "2" "a pattern from .pi/project/secret-patterns.txt is enforced"
rc=0; ( cd "$EXT" && printf '%s' "$(tool Read '{"file_path":"README.md"}')" | python3 "$ROOT_DIR/hooks/guard-secrets.py" >/dev/null 2>&1 ) || rc=$?
assert_eq "$rc" "0" "the extension file does not block unrelated paths"

finish
