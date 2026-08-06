#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state="$self_dir/.namespace.pid"

if [[ ${1:-} != --execute ]]; then
  cat <<EOF
Preview only. This lab will run:
  sudo unshare --uts --pid --mount --fork --mount-proc ...
It changes hostname and mounts /proc only inside new namespaces.
Run: $0 --execute
EOF
  exit 0
fi
[[ ! -e $state ]] || { echo "State exists; run cleanup.sh first" >&2; exit 1; }

host_uts=$(readlink /proc/self/ns/uts)
host_pidns=$(readlink /proc/self/ns/pid)
sudo unshare --uts --pid --mount --fork --mount-proc \
  bash -c 'hostname primitives-lab; exec -a primitives-namespace-lab bash -c '\''echo "Inside: pid=$$ hostname=$(hostname)"; ps -ef; while :; do sleep 30 & wait $!; done'\''' &
lab_pid=$!
printf '%s\n' "$lab_pid" >"$state"
sleep 0.5

printf 'Host PID: %s; host hostname: %s\n' "$lab_pid" "$(hostname)"
printf 'UTS: %s -> %s\n' "$host_uts" "$(sudo readlink "/proc/$lab_pid/ns/uts")"
printf 'PID: %s -> %s\n' "$host_pidns" "$(sudo readlink "/proc/$lab_pid/ns/pid")"
printf 'Inspect inside: sudo nsenter -t %s -m -u -p -- ps -ef\n' "$lab_pid"
printf 'Cleanup: %s/cleanup.sh\n' "$self_dir"

