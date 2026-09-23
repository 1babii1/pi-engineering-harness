#!/usr/bin/env bash
# verify-k8s.sh [file-or-dir ...]
# Validates Kubernetes manifests with kubeconform and/or kube-linter when installed (default target:
# ./k8s). A repository-owned K8S_VERIFY_CMD in .pi/project/commands.sh (or K8S_VERIFY_CMD_FILE)
# wins. Exit: 0 pass, 1 fail, 2 no validator installed / nothing to validate.
set -euo pipefail

ENV_FILE="${K8S_VERIFY_CMD_FILE:-.pi/project/commands.sh}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [[ -n "${K8S_VERIFY_CMD:-}" ]]; then
  # The command ran, so any non-zero exit is a real failure, never "not configured" (exit 2).
  bash -c "$K8S_VERIFY_CMD" || exit 1
  exit 0
fi

if [[ "${1:-}" == --helm ]]; then
  echo "A Helm chart changed: templates must be rendered before validation. Set K8S_VERIFY_CMD in .pi/project/commands.sh (for example: helm template ... | kubeconform -strict -summary -)." >&2
  exit 2
fi

targets=("$@")
if [[ ${#targets[@]} -eq 0 ]]; then
  [[ -d k8s ]] || { echo "No manifests given and no ./k8s directory." >&2; exit 2; }
  targets=(k8s)
fi

ran=0
status=0
if command -v kubeconform >/dev/null 2>&1; then
  # Custom resources have no bundled schema; skipping them is reported in kubeconform's summary
  # rather than failing every CRD-based manifest.
  kubeconform -strict -ignore-missing-schemas -summary "${targets[@]}" || status=1
  ran=1
fi
if command -v kube-linter >/dev/null 2>&1; then
  kube-linter lint "${targets[@]}" || status=1
  ran=1
fi
if [[ $ran -eq 0 ]]; then
  echo "Install kubeconform and/or kube-linter, or set K8S_VERIFY_CMD in .pi/project/commands.sh." >&2
  exit 2
fi
exit "$status"
