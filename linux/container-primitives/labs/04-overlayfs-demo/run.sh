#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
state="$self_dir/.state"
lower="$state/lower" upper="$state/upper" work="$state/work" merged="$state/merged"

if [[ ${1:-} != --execute ]]; then
  cat <<EOF
Preview: create $state, then sudo mount one OverlayFS at $merged.
Run: $0 --execute
Cleanup: $self_dir/cleanup.sh
EOF
  exit 0
fi
grep -qw overlay /proc/filesystems || { echo 'OverlayFS unavailable' >&2; exit 1; }
[[ ! -e $state ]] || { echo 'State exists; run cleanup.sh first.' >&2; exit 1; }
mkdir -p -- "$lower" "$upper" "$work" "$merged"
printf 'from immutable lower\n' >"$lower/edit-me.txt"
printf 'hidden after deletion\n' >"$lower/delete-me.txt"

sudo mount -t overlay overlay -o "lowerdir=$lower,upperdir=$upper,workdir=$work" "$merged"
printf 'Read lower through merged: '; cat "$merged/edit-me.txt"
printf 'edited through merged\n' >"$merged/edit-me.txt"
printf 'created in writable layer\n' >"$merged/new.txt"
rm -- "$merged/delete-me.txt"
printf '\nMerged tree:\n'; find "$merged" -maxdepth 1 -printf '%y %f\n' | sort
printf '\nUpper tree (whiteout display is kernel-dependent):\n'
sudo find "$upper" -maxdepth 1 -printf '%y %m %f\n' | sort
printf '\nLower edit remains: '; cat "$lower/edit-me.txt"
echo "Cleanup: $self_dir/cleanup.sh"

