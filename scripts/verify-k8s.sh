#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-k8s}"
ran=0
if command -v kubeconform >/dev/null 2>&1; then
  kubeconform -strict -summary "$TARGET"
  ran=1
fi
if command -v kube-linter >/dev/null 2>&1; then
  kube-linter lint "$TARGET"
  ran=1
fi
if [[ $ran -eq 0 ]]; then
  echo "Install kubeconform and/or kube-linter, or configure a project-specific verification command." >&2
  exit 2
fi
