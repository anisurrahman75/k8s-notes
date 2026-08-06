#!/usr/bin/env bash
set -Eeuo pipefail
force=0
if [[ ${1:-} == --force ]]; then force=1; shift; fi
[[ $# -eq 1 ]] || { echo "Usage: $0 [--force] EXACT.scope" >&2; exit 2; }
scope=$1
[[ $scope =~ ^mt5-lab-[0-9]+-[0-9]+\.scope$ ]] || { echo 'Refusing non-lab scope name.' >&2; exit 2; }
cg=$(systemctl --user show "$scope" -p ControlGroup --value 2>/dev/null || true)
[[ -n $cg ]] || { echo 'Scope is already gone.'; exit 0; }

if (( force )); then
  echo "WARNING: sending SIGKILL only to processes in $scope; unsaved MT5 state may be lost." >&2
  systemctl --user kill --kill-whom=all --signal=SIGKILL "$scope" || true
else
  echo "Sending SIGTERM only to $scope (no global wineserver command)."
  systemctl --user kill --kill-whom=all --signal=SIGTERM "$scope" || true
  sleep 2
fi
path="/sys/fs/cgroup$cg"
if [[ -r $path/cgroup.procs ]]; then
  echo 'Remaining processes:'
  while read -r pid; do ps -o pid,ppid,cmd -p "$pid" --no-headers || true; done <"$path/cgroup.procs"
  if (( ! force )) && [[ -s $path/cgroup.procs ]]; then
    echo "Inspect first; if necessary: $0 --force $scope" >&2
  fi
else
  echo 'No processes remain in the scope.'
fi
echo 'Wine prefix and MT5 files were left intact.'

