#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state="$self_dir/.last-scope"
log="$self_dir/.systemd-run.log"
: "${WINEPREFIX:=${HOME:?HOME is required}/.wine}"
: "${MT5_EXE:=$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe}"
: "${CPU_QUOTA:=100%}" "${CPU_WEIGHT:=100}" "${MEMORY_HIGH:=1G}" "${MEMORY_MAX:=1500M}" "${PIDS_MAX:=128}"

[[ $(stat -fc %T /sys/fs/cgroup) == cgroup2fs ]] || { echo 'cgroup v2 required' >&2; exit 1; }
for cmd in systemd-run systemctl wine; do command -v "$cmd" >/dev/null || { echo "$cmd not found" >&2; exit 1; }; done
systemctl --user show-environment >/dev/null || { echo 'User systemd manager unavailable; no sudo fallback attempted.' >&2; exit 1; }
[[ -f $MT5_EXE ]] || { printf 'MT5 executable not found: %s\nSet MT5_EXE and WINEPREFIX explicitly.\n' "$MT5_EXE" >&2; exit 1; }
[[ $CPU_WEIGHT =~ ^[0-9]+$ && $PIDS_MAX =~ ^[0-9]+$ ]] || { echo 'CPU_WEIGHT and PIDS_MAX must be integers.' >&2; exit 2; }

existing=$(pgrep -a -f 'wine|wineserver|terminal64\.exe' || true)
if [[ -n $existing ]]; then
  printf 'Existing Wine-like processes detected:\n%s\n' "$existing" >&2
  echo 'Verify none use this WINEPREFIX. The lab will not kill them.' >&2
fi

base="mt5-lab-$(date +%s)-$$"; scope="$base.scope"
printf 'Launching scope %s with prefix %s\n' "$scope" "$WINEPREFIX"
WINEPREFIX=$WINEPREFIX systemd-run --user --scope --unit="$base" \
  -p "CPUQuota=$CPU_QUOTA" -p "CPUWeight=$CPU_WEIGHT" \
  -p "MemoryHigh=$MEMORY_HIGH" -p "MemoryMax=$MEMORY_MAX" -p "TasksMax=$PIDS_MAX" \
  wine "$MT5_EXE" >"$log" 2>&1 &
launcher=$!

for _ in {1..30}; do
  systemctl --user show "$scope" -p ControlGroup --value >/dev/null 2>&1 && break
  kill -0 "$launcher" 2>/dev/null || { echo "systemd-run exited; see $log" >&2; exit 1; }
  sleep 0.1
done
cg=$(systemctl --user show "$scope" -p ControlGroup --value 2>/dev/null || true)
[[ -n $cg ]] || { echo "Scope did not start; see $log. No sudo fallback attempted." >&2; exit 1; }
printf '%s\n' "$scope" >"$state"
printf 'Scope: %s\nCgroup: %s\nInspect: %s/inspect.sh %s\nCleanup: %s/cleanup.sh %s\nLog: %s\n' \
  "$scope" "$cg" "$self_dir" "$scope" "$self_dir" "$scope" "$log"

