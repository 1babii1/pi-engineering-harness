#!/usr/bin/env bash
set -euo pipefail
mode="${1:-smoke}"
case "$mode" in smoke|regression|benchmark) ;; *) echo "Usage: $0 [smoke|regression|benchmark]" >&2; exit 2;; esac
printf 'Eval mode: %s\n' "$mode"
echo "This repository defines portable eval cases and graders. Connect execution to the chosen agent runtime before making benchmark claims."
find evals/cases -type f -maxdepth 3 | sort
