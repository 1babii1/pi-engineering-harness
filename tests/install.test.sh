#!/usr/bin/env bash
# Behavioural tests for install.sh: safety (no data loss, no self-install, no partial install)
# and the ownership model documented at the top of install.sh.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
INSTALL="$ROOT_DIR/install.sh"

echo "install.sh"

# --- fresh install ---------------------------------------------------------------------------
T="$(new_dir)"
out="$(TARGET="$T" "$INSTALL" backend 2>&1)"; rc=$?
assert_eq "$rc" "0" "fresh install succeeds"
assert_file "$T/AGENTS.md" "AGENTS.md created"
assert_file "$T/.pi/laws/core.md" "laws installed"
assert_file "$T/.pi/skills/coding/testing/SKILL.md" "profile skill installed"
assert_file "$T/.pi/project/overview.md" "project-context stubs created"
[[ -x "$T/.harness/scripts/verify.sh" ]] && ok "scripts keep the executable bit" || bad "scripts keep the executable bit"
assert_no_file "$T/.harness/backup" "fresh install creates no backup"

# --- idempotent re-run -----------------------------------------------------------------------
out="$(TARGET="$T" "$INSTALL" backend 2>&1)"
assert_out_contains "$out" "created: 0   updated: 0   removed: 0" "re-run changes nothing"
assert_no_file "$T/.harness/backup" "re-run creates no backup"

# --- harness-owned edits are refreshed but backed up -----------------------------------------
echo "LOCAL LESSON" >> "$T/.pi/skills/coding/testing/SKILL.md"
out="$(TARGET="$T" "$INSTALL" backend 2>&1)"
assert_not_contains "$T/.pi/skills/coding/testing/SKILL.md" "LOCAL LESSON" "managed skill is refreshed to upstream"
bk="$(find "$T/.harness/backup" -path '*coding/testing/SKILL.md' 2>/dev/null | head -1)"
[[ -n "$bk" ]] && assert_contains "$bk" "LOCAL LESSON" "the edited skill was backed up first" || bad "the edited skill was backed up first" "no backup found"
assert_out_contains "$out" "Backup of replaced/removed files" "backup location is reported"

# --- stale file inside a managed skill is backed up then removed -----------------------------
echo "junk" > "$T/.pi/skills/coding/testing/extra-notes.md"
out="$(TARGET="$T" "$INSTALL" backend 2>&1)"
assert_no_file "$T/.pi/skills/coding/testing/extra-notes.md" "stale file inside a managed skill is pruned"
[[ -n "$(find "$T/.harness/backup" -name extra-notes.md 2>/dev/null)" ]] && ok "pruned file was backed up" || bad "pruned file was backed up"

# --- project-local skill that is not selected is never touched -------------------------------
mkdir -p "$T/.pi/skills/audit/local-only"
echo "mine" > "$T/.pi/skills/audit/local-only/SKILL.md"
TARGET="$T" "$INSTALL" backend >/dev/null 2>&1
assert_contains "$T/.pi/skills/audit/local-only/SKILL.md" "mine" "unselected project-local skill survives"

# --- project-owned entry files ---------------------------------------------------------------
echo "MY PROJECT RULE" >> "$T/AGENTS.md"
out="$(TARGET="$T" "$INSTALL" backend 2>&1)"
assert_contains "$T/AGENTS.md" "MY PROJECT RULE" "customised AGENTS.md is kept by default"
assert_out_contains "$out" "AGENTS.md differs from the harness version; kept" "the kept AGENTS.md is reported"
out="$(TARGET="$T" "$INSTALL" --overwrite-entry backend 2>&1)"
assert_not_contains "$T/AGENTS.md" "MY PROJECT RULE" "--overwrite-entry replaces AGENTS.md"
bk="$(find "$T/.harness/backup" -name AGENTS.md 2>/dev/null | head -1)"
[[ -n "$bk" ]] && assert_contains "$bk" "MY PROJECT RULE" "replaced AGENTS.md was backed up" || bad "replaced AGENTS.md was backed up"

# --- project data is never overwritten -------------------------------------------------------
echo "# my overview" > "$T/.pi/project/overview.md"
echo "# my inbox" > "$T/.pi/learnings/inbox.md"
TARGET="$T" "$INSTALL" backend >/dev/null 2>&1
assert_contains "$T/.pi/project/overview.md" "my overview" ".pi/project data preserved"
assert_contains "$T/.pi/learnings/inbox.md" "my inbox" "learnings inbox preserved"

# --- refuses to install into itself, without side effects ------------------------------------
before="$(cd "$ROOT_DIR" && git status --porcelain 2>/dev/null | wc -l)"
out="$(TARGET="$ROOT_DIR" "$INSTALL" backend 2>&1)"; rc=$?
assert_eq "$rc" "2" "self-install is refused"
assert_out_contains "$out" "Refusing to install the harness into itself" "self-install explains why"
[[ ! -e "$ROOT_DIR/.harness" ]] && ok "self-install leaves no .harness dir behind" || bad "self-install leaves no .harness dir behind"
after="$(cd "$ROOT_DIR" && git status --porcelain 2>/dev/null | wc -l)"
assert_eq "$after" "$before" "self-install does not change the working tree"
# a symlinked path to the harness must be refused too
ln -s "$ROOT_DIR" "$TMP_ROOT/harness-link"
TARGET="$TMP_ROOT/harness-link" "$INSTALL" backend >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "self-install via symlink is refused"

# --- unknown skill: fail before writing anything ---------------------------------------------
T2="$(new_dir)"
out="$(TARGET="$T2" "$INSTALL" backend no/such-skill 2>&1)"; rc=$?
assert_eq "$rc" "2" "unknown skill exits 2"
assert_out_contains "$out" "Unknown skill: no/such-skill" "unknown skill is named"
[[ -z "$(ls -A "$T2")" ]] && ok "unknown skill leaves the target untouched (no partial install)" || bad "unknown skill leaves the target untouched (no partial install)" "$(ls -A "$T2")"

# --- unknown option / agent / missing target -------------------------------------------------
TARGET="$T2" "$INSTALL" --bogus backend >/dev/null 2>&1; assert_eq "$?" "2" "unknown option exits 2"
TARGET="$T2" "$INSTALL" --agent nope backend >/dev/null 2>&1; assert_eq "$?" "2" "unknown agent exits 2"
TARGET="$T2/does-not-exist" "$INSTALL" backend >/dev/null 2>&1; assert_eq "$?" "2" "missing target dir exits 2"
"$INSTALL" >/dev/null 2>&1; assert_eq "$?" "1" "no arguments exits 1 with usage"

# --- dry run writes nothing ------------------------------------------------------------------
T3="$(new_dir)"
out="$(TARGET="$T3" "$INSTALL" --dry-run fullstack 2>&1)"; rc=$?
assert_eq "$rc" "0" "dry-run succeeds"
assert_out_contains "$out" "[dry-run] would have:" "dry-run announces itself"
[[ -z "$(ls -A "$T3")" ]] && ok "dry-run leaves the target empty" || bad "dry-run leaves the target empty"
echo "x" >> "$T/.pi/skills/coding/testing/SKILL.md"
snapshot="$(find "$T" -type f -printf '%p %s\n' | sort | md5sum)"
TARGET="$T" "$INSTALL" --dry-run backend >/dev/null 2>&1
assert_eq "$(find "$T" -type f -printf '%p %s\n' | sort | md5sum)" "$snapshot" "dry-run on an existing install changes nothing"

# --- adapters --------------------------------------------------------------------------------
T4="$(new_dir)"
TARGET="$T4" "$INSTALL" --agent claude verification >/dev/null 2>&1
assert_contains "$T4/CLAUDE.md" "@AGENTS.md" "claude adapter installs CLAUDE.md"
assert_file "$T4/.claude/skills/pi-verification/SKILL.md" "claude adapter mirrors selected skills into .claude/skills"
assert_no_file "$T4/.claude/skills/pi-dotnet-backend" "claude adapter mirrors only the selected skills"
echo stale > "$T4/.claude/skills/pi-verification/stale.md"
TARGET="$T4" "$INSTALL" --agent claude verification >/dev/null 2>&1
assert_no_file "$T4/.claude/skills/pi-verification/stale.md" "a reinstall prunes stale files from a mirrored skill"
# --- claude hooks, verifier subagent, settings merge --------------------------------------------
assert_file "$T4/.harness/hooks/guard-secrets.py" "claude adapter installs the secrets guard hook"
assert_file "$T4/.harness/hooks/verify-on-stop.sh" "claude adapter installs the stop hook"
assert_contains "$T4/.claude/agents/pi-independent-verifier.md" "name: pi-independent-verifier" "the verifier subagent has frontmatter"
assert_contains "$T4/.claude/agents/pi-independent-verifier.md" "Do not trust, re-check" "the verifier subagent body comes from the skill"
assert_contains "$T4/.claude/settings.json" "guard-secrets.py" "settings.json wires the secrets guard"
assert_contains "$T4/.claude/settings.json" "verify-on-stop.sh" "settings.json wires the stop hook"
TC="$(new_dir)"; mkdir -p "$TC/.claude"
cat > "$TC/.claude/settings.json" <<'JSON'
{"permissions":{"allow":["Bash(dotnet build *)"]},"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"my-own-hook.sh"}]}]}}
JSON
TARGET="$TC" "$INSTALL" --agent claude verification >/dev/null 2>&1
assert_contains "$TC/.claude/settings.json" "my-own-hook.sh" "merge keeps the project's own hook"
assert_contains "$TC/.claude/settings.json" "Bash(dotnet build *)" "merge keeps permissions untouched"
assert_contains "$TC/.claude/settings.json" "guard-secrets.py" "merge adds the harness hook"
before="$(md5sum < "$TC/.claude/settings.json")"
out="$(TARGET="$TC" "$INSTALL" --agent claude verification 2>&1)"
assert_eq "$(md5sum < "$TC/.claude/settings.json")" "$before" "a second install does not duplicate hooks"
assert_eq "$(grep -c guard-secrets.py "$TC/.claude/settings.json")" "1" "the guard hook appears exactly once"
assert_eq "$(stat -c '%a' "$T4/.claude/settings.json")" "644" "a new settings.json is not created with mktemp's 600 mode"
assert_eq "$(stat -c '%a' "$T4/.claude/agents/pi-independent-verifier.md")" "644" "the verifier agent file is not created with mktemp's 600 mode"
TN="$(new_dir)"; mkdir -p "$TN/.claude"; echo '{"hooks":{"Stop":[{"hooks":null}]}}' > "$TN/.claude/settings.json"
TARGET="$TN" "$INSTALL" --agent claude verification >/dev/null 2>&1
assert_contains "$TN/.claude/settings.json" "verify-on-stop.sh" "an entry with hooks:null is tolerated by the merge"
TD="$(new_dir)"; mkdir -p "$TD/.claude"; echo '{ not json' > "$TD/.claude/settings.json"
out="$(TARGET="$TD" "$INSTALL" --agent claude verification 2>&1)"
assert_eq "$(cat "$TD/.claude/settings.json")" "{ not json" "an unparseable settings.json is left untouched"
assert_out_contains "$out" "NOT merged" "an unparseable settings.json is reported, not silently skipped"
TE="$(new_dir)"; TARGET="$TE" "$INSTALL" --agent claude --dry-run verification >/dev/null 2>&1
assert_no_file "$TE/.claude" "dry-run creates no .claude files"
TF="$(new_dir)"; TARGET="$TF" "$INSTALL" verification >/dev/null 2>&1
assert_no_file "$TF/.harness/hooks" "non-claude agents get no hooks directory"

T5="$(new_dir)"
TARGET="$T5" "$INSTALL" --agent cursor verification >/dev/null 2>&1
assert_file "$T5/.cursor/rules/engineering-harness.mdc" "cursor adapter installs the rule"
perm="$(stat -c '%a' "$T5/.cursor/rules/engineering-harness.mdc")"
assert_eq "$perm" "644" "cursor rule is not created with mktemp's 600 mode"

T7="$(new_dir)"
TARGET="$T7" "$INSTALL" --agent gemini verification >/dev/null 2>&1
assert_contains "$T7/GEMINI.md" "@./AGENTS.md" "gemini adapter installs GEMINI.md importing AGENTS.md"
echo "someone else's gemini rules" > "$T7/GEMINI.md"
out="$(TARGET="$T7" "$INSTALL" --agent gemini verification 2>&1)"
assert_contains "$T7/GEMINI.md" "someone else" "an existing different GEMINI.md is kept"
assert_out_contains "$out" "GEMINI.md differs from the harness version; kept" "and reported as kept"

# --- upgrade from <= 4.9.x: bare-name mirrors move to pi-* ---------------------------------------
TM="$(new_dir)"
mkdir -p "$TM/.pi/skills" "$TM/.claude/skills" "$TM/.claude/agents"
# What a 4.8/4.9 install left behind: the .pi copy and a byte-identical bare-name mirror (name: verification).
mkdir -p "$TM/.pi/skills/verification" "$TM/.claude/skills/verification"
printf -- '---\nname: verification\ndescription: old\n---\nold body\n' > "$TM/.pi/skills/verification/SKILL.md"
cp "$TM/.pi/skills/verification/SKILL.md" "$TM/.claude/skills/verification/SKILL.md"
# A bare-name skill that is NOT the harness's copy (user-written, or edited): must be left alone.
mkdir -p "$TM/.pi/skills/coding/testing" "$TM/.claude/skills/testing"
printf -- '---\nname: testing\ndescription: old\n---\nold body\n' > "$TM/.pi/skills/coding/testing/SKILL.md"
printf -- '---\nname: testing\ndescription: mine\n---\nmy own testing skill\n' > "$TM/.claude/skills/testing/SKILL.md"
printf -- '---\nname: independent-verifier\n---\nYou are the independent verifier.\n' > "$TM/.claude/agents/independent-verifier.md"
out="$(TARGET="$TM" "$INSTALL" --agent claude verification coding/testing 2>&1)"
assert_no_file "$TM/.claude/skills/verification" "the harness's old bare-name mirror is removed"
assert_file "$TM/.claude/skills/pi-verification/SKILL.md" "the pi-* mirror replaces it"
assert_no_file "$TM/.claude/agents/independent-verifier.md" "the old verifier agent file is removed"
assert_file "$TM/.claude/agents/pi-independent-verifier.md" "the pi-* verifier agent is installed"
assert_contains "$TM/.claude/skills/testing/SKILL.md" "my own testing skill" "a same-named skill that is not the harness's copy is left untouched"
assert_out_contains "$out" ".claude/skills/testing (not from this harness or edited" "the untouched same-named skill is reported"
bk="$(find "$TM/.harness/backup" -path '*/.claude/skills/verification/SKILL.md' | head -n1)"
assert_eq "$([[ -f "$bk" ]] && echo yes || echo no)" "yes" "the removed mirror is recoverable from the backup"
TM2="$(new_dir)"; cp -R "$TM/." "$TM2/" 2>/dev/null || true
rm -rf "$TM2/.pi" "$TM2/.claude"; mkdir -p "$TM2/.pi/skills/verification" "$TM2/.claude/skills/verification"
printf -- '---\nname: verification\ndescription: old\n---\nold body\n' > "$TM2/.pi/skills/verification/SKILL.md"
cp "$TM2/.pi/skills/verification/SKILL.md" "$TM2/.claude/skills/verification/SKILL.md"
TARGET="$TM2" "$INSTALL" --agent claude --dry-run verification >/dev/null 2>&1
assert_file "$TM2/.claude/skills/verification/SKILL.md" "dry-run does not remove the old mirror"
TM3="$(new_dir)"
mkdir -p "$TM3/.pi/skills/verification" "$TM3/.claude/skills/verification"
printf -- '---\nname: verification\ndescription: old\n---\nold body\n' > "$TM3/.pi/skills/verification/SKILL.md"
cp "$TM3/.pi/skills/verification/SKILL.md" "$TM3/.claude/skills/verification/SKILL.md"
TARGET="$TM3" "$INSTALL" --agent pi verification >/dev/null 2>&1
assert_file "$TM3/.claude/skills/verification/SKILL.md" "a non-claude install leaves an existing Claude mirror alone"
assert_no_file "$TM3/.claude/skills/pi-verification" "a non-claude install does not create a Claude mirror"

# --- version stamp and templates ---------------------------------------------------------------
T8="$(new_dir)"
out="$(TARGET="$T8" "$INSTALL" verification 2>&1)"
assert_eq "$(cat "$T8/.harness/VERSION")" "$(cat "$ROOT_DIR/VERSION")" "the harness version is stamped into the target"
assert_out_contains "$out" "harness $(cat "$ROOT_DIR/VERSION")" "the install summary names the version"
assert_file "$T8/.harness/templates/commands.sh.example" "the verify-overrides template is installed"
assert_file "$T8/.harness/templates/nested/backend.AGENTS.md" "nested AGENTS.md starters are installed"
echo "0.0.1" > "$T8/.harness/VERSION"
out="$(TARGET="$T8" "$INSTALL" verification 2>&1)"
assert_out_contains "$out" "harness 0.0.1 -> $(cat "$ROOT_DIR/VERSION")" "an upgrade reports old -> new version"

# --- every profile installs cleanly ----------------------------------------------------------
for p in "$ROOT_DIR"/profiles/*; do
  name="$(basename "$p")"
  T6="$(new_dir)"
  TARGET="$T6" "$INSTALL" "$name" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "profile '$name' installs"
done

finish
