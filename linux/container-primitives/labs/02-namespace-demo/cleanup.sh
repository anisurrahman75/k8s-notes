#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state="$self_dir/.namespace.pid"
[[ -r $state ]] || { echo 'Nothing to clean.'; exit 0; }
read -r pid <"$state"
[[ $pid =~ ^[0-9]+$ ]] || { echo 'Invalid state file; remove it manually after inspection.' >&2; exit 1; }
if kill -0 "$pid" 2>/dev/null; then
  args=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)
  [[ $args == *primitives-namespace-lab* ]] || { echo "PID $pid does not match lab marker; refusing." >&2; exit 1; }
  sudo kill -TERM "$pid"
fi
rm -f -- "$state"
echo 'Namespace lab cleaned.'

