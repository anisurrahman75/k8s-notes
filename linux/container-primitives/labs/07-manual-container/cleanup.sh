#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
rootfs="$self_dir/.rootfs"
[[ -e $rootfs ]] || { echo 'Nothing to clean.'; exit 0; }
if mountpoint -q "$rootfs"; then
  echo "Refusing to remove mounted path: $rootfs. Let the lab process exit first." >&2
  exit 1
fi
[[ $rootfs == "$self_dir/.rootfs" && $rootfs != / ]] || exit 1
rm -rf -- "$rootfs"
echo 'Manual-container temporary root removed.'

