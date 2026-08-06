#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state="$self_dir/.unit"
unit=${1:-}
if [[ -z $unit && -r $state ]]; then read -r unit <"$state"; fi
[[ -n $unit ]] || { echo 'Nothing to clean.'; exit 0; }
[[ $unit =~ ^primitives-cgroup-[0-9]+-[0-9]+\.service$ ]] || { echo 'Refusing non-lab unit name.' >&2; exit 1; }
systemctl --user stop "$unit" 2>/dev/null || true
rm -f -- "$state"
echo "Stopped $unit"

