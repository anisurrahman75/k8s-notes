#!/usr/bin/env bash
set -Eeuo pipefail

usage() { echo "Usage: $0 PID" >&2; exit 2; }
[[ $# -eq 1 && $1 =~ ^[0-9]+$ ]] || usage
pid=$1
[[ -r /proc/$pid/cgroup ]] || { echo "Cannot read /proc/$pid/cgroup" >&2; exit 1; }
[[ $(stat -fc %T /sys/fs/cgroup) == cgroup2fs ]] || { echo "This helper requires cgroup v2" >&2; exit 1; }

relative=$(awk -F: '$1 == "0" { print $3; exit }' "/proc/$pid/cgroup")
[[ -n $relative ]] || { echo "No unified cgroup entry for PID $pid" >&2; exit 1; }
root=/sys/fs/cgroup
path="${root}${relative}"
[[ -d $path ]] || { echo "Resolved cgroup does not exist: $path" >&2; exit 1; }

show() {
  local label=$1 file=$2 value
  if [[ -r $path/$file ]]; then
    value=$(<"$path/$file")
    printf '\n%s (%s)\n%s\n' "$label" "$file" "$value"
  else
    printf '\n%s (%s): unavailable at this hierarchy level\n' "$label" "$file"
  fi
}

printf 'PID: %s\nCgroup path: %s\nFilesystem path: %s\n' "$pid" "$relative" "$path"
show 'CPU quota and period (max means no hard quota)' cpu.max
show 'CPU weight (relative share under contention)' cpu.weight
show 'CPU statistics' cpu.stat
show 'Memory hard limit (max means unlimited by this cgroup)' memory.max
show 'Current memory' memory.current
show 'Memory events (oom/oom_kill are cumulative)' memory.events
show 'PID/thread limit (max means unlimited by this cgroup)' pids.max
show 'Current PID/thread count' pids.current

