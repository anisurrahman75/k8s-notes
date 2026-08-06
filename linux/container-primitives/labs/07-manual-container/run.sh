#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
rootfs="$self_dir/.rootfs"

cleanup_outer() {
  if [[ -e $rootfs ]]; then
    if mountpoint -q "$rootfs"; then
      echo "Refusing removal: $rootfs is mounted in this namespace." >&2
      return 1
    fi
    [[ $rootfs == "$self_dir/.rootfs" && $rootfs != / ]] || return 1
    rm -rf -- "$rootfs"
  fi
}

if [[ ${1:-} == --inside ]]; then
  [[ $EUID -eq 0 ]] || { echo 'Inside setup requires root.' >&2; exit 1; }
  shift
  [[ ${1:-} == "$rootfs" ]] || { echo 'Unexpected rootfs argument.' >&2; exit 1; }
  mount --make-rprivate /
  mount -t tmpfs -o mode=755,size=128m tmpfs "$rootfs"
  mkdir -p -- "$rootfs/usr" "$rootfs/proc" "$rootfs/tmp"
  mount --rbind /usr "$rootfs/usr"
  mount -o remount,bind,ro "$rootfs/usr"
  ln -s usr/bin "$rootfs/bin"
  ln -s usr/lib "$rootfs/lib"
  [[ ! -e /lib64 ]] || ln -s usr/lib64 "$rootfs/lib64"
  mount -t proc -o nosuid,nodev,noexec proc "$rootfs/proc"
  hostname manual-container
  exec chroot "$rootfs" /bin/bash -c '
    echo "Inside hostname=$(hostname), PID=$$, root filesystem:" 
    findmnt / || true
    echo "Process view:"
    ps -eo pid,ppid,stat,cmd
    echo "Namespace identities:"
    for n in pid mnt uts; do readlink "/proc/self/ns/$n"; done
    echo "This shell exits after the observations."
  '
fi

if [[ ${1:-} != --execute ]]; then
  cat <<EOF
Preview only. This lab will use sudo for one transient unshare/mount/chroot process.
Temporary root: $rootfs
Run: $0 --execute
EOF
  exit 0
fi
for cmd in unshare mount chroot; do command -v "$cmd" >/dev/null || { echo "$cmd missing" >&2; exit 1; }; done
[[ -x /usr/bin/bash ]] || { echo '/usr/bin/bash is required.' >&2; exit 1; }
[[ ! -e $rootfs ]] || { echo 'Rootfs state exists; run cleanup.sh first.' >&2; exit 1; }
mkdir -p -- "$rootfs"
trap cleanup_outer EXIT INT TERM
sudo unshare --uts --pid --mount --fork "$0" --inside "$rootfs"

