#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
state="$self_dir/.state" merged="$state/merged"
[[ -e $state ]] || { echo 'Nothing to clean.'; exit 0; }
if mountpoint -q "$merged"; then
  [[ $(findmnt -n -o FSTYPE --target "$merged") == overlay ]] || { echo 'Mounted target is not OverlayFS; refusing.' >&2; exit 1; }
  sudo umount "$merged"
fi
mountpoint -q "$merged" && { echo 'Mount remains; refusing removal.' >&2; exit 1; }
[[ $state == "$self_dir/.state" && $state != / ]] || exit 1
rm -rf -- "$state"
echo 'OverlayFS lab cleaned.'

