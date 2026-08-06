#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$self_dir/../.." && pwd)
state="$self_dir/.unit"
[[ $(stat -fc %T /sys/fs/cgroup) == cgroup2fs ]] || { echo 'cgroup v2 required' >&2; exit 1; }
command -v systemd-run >/dev/null || { echo 'systemd-run not found' >&2; exit 1; }
systemctl --user show-environment >/dev/null || { echo 'User systemd manager unavailable' >&2; exit 1; }
unit="primitives-cgroup-$(date +%s)-$$.service"

systemd-run --user --unit="$unit" --collect --service-type=exec \
  -p CPUQuota=25% -p CPUWeight=100 -p MemoryHigh=64M -p MemoryMax=96M -p TasksMax=32 \
  bash -c 'exec -a primitives-cgroup-workload bash -c '\''end=$((SECONDS+30)); while (( SECONDS < end )); do :; done'\'''
printf '%s\n' "$unit" >"$state"
sleep 0.3
pid=$(systemctl --user show "$unit" -p MainPID --value)
[[ $pid =~ ^[1-9][0-9]*$ ]] || { echo "Could not resolve MainPID for $unit" >&2; exit 1; }
printf 'Unit: %s\nPID: %s\n\n' "$unit" "$pid"
"$root/inspect-cgroup.sh" "$pid"
printf '\nObserve: watch -n 1 %q %s\nCleanup: %s/cleanup.sh %s\n' "$root/inspect-cgroup.sh" "$pid" "$self_dir" "$unit"

