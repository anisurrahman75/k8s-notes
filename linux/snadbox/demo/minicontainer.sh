#!/usr/bin/env bash
# minicontainer.sh — a container in ~40 lines of shell.
#
#   PID namespace    -> its own process tree, our command is PID 1
#   mount namespace  -> its own filesystem, pivot_root into a busybox rootfs
#   cgroup v2        -> hard limits on memory, CPU and process count
#   (+ UTS, IPC, user namespaces for free)
#
# Runs entirely rootless. Concepts: ../concepts/
#
# Usage:
#   ./minicontainer.sh                                  # interactive shell
#   ./minicontainer.sh -m 64M -c 25 -p 32 -- /bin/sh -c 'echo hi'
#   ./minicontainer.sh --name web -- /bin/whoami-really

set -euo pipefail

NAME="mc-$$"
ROOTFS="/tmp/sandbox-rootfs"
MEMORY="64M"          # memory.max
CPU_PERCENT="25"      # cpu.max, percent of ONE core
PIDS="32"             # pids.max
HOSTNAME_IN="sandbox"

usage() { sed -n '2,18p' "$0" | sed 's/^# \?//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--name)   NAME="mc-$2";     shift 2 ;;
    -r|--rootfs) ROOTFS="$2";      shift 2 ;;
    -m|--memory) MEMORY="$2";      shift 2 ;;
    -c|--cpu)    CPU_PERCENT="$2"; shift 2 ;;
    -p|--pids)   PIDS="$2";        shift 2 ;;
    -h|--help)   usage 0 ;;
    --)          shift; break ;;
    *)           echo "unknown option: $1" >&2; usage 1 ;;
  esac
done
CMD=( "${@:-/bin/sh}" )

# ---------------------------------------------------------------- preflight
[ -d "$ROOTFS/bin" ] || { echo "no rootfs at $ROOTFS — run ./build-rootfs.sh first" >&2; exit 1; }
[ "$(stat -fc %T /sys/fs/cgroup)" = cgroup2fs ] || { echo "need cgroup v2" >&2; exit 1; }
[ "$(cat /proc/sys/user/max_user_namespaces)" -gt 0 ] || { echo "unprivileged userns disabled" >&2; exit 1; }

# ------------------------------------------------------- 1. build the cgroup
# systemd delegates cpu/memory/pids to this subtree and chowns it to us.
# Concepts: ../concepts/4.cgroup/2.rootless-delegation.md
U=$(id -u)
CGROOT="/sys/fs/cgroup/user.slice/user-$U.slice/user@$U.service"
CG="$CGROOT/$NAME"

mkdir -p "$CG"
cleanup() {
  [ -d "$CG" ] || return 0
  echo 1 > "$CG/cgroup.kill" 2>/dev/null || true   # SIGKILL the whole subtree
  sleep 0.2
  rmdir "$CG" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "$MEMORY"                            > "$CG/memory.max"
echo 0                                    > "$CG/memory.swap.max"
echo "$(( CPU_PERCENT * 1000 )) 100000"   > "$CG/cpu.max"
echo "$PIDS"                              > "$CG/pids.max"

cat <<EOF
┌─ minicontainer ─────────────────────────────────────
│ name     : $NAME
│ rootfs   : $ROOTFS
│ memory   : $MEMORY          (memory.max, swap disabled)
│ cpu      : ${CPU_PERCENT}%           (cpu.max = $(cat "$CG/cpu.max"))
│ pids     : $PIDS            (pids.max)
│ cgroup   : $CG
│ command  : ${CMD[*]}
└─────────────────────────────────────────────────────
EOF

# ------------------------------------------- 2. join cgroup, 3. namespaces
# Order matters: join the cgroup from the HOST view first, then unshare -C so
# the sandbox sees itself at 0::/ . Everything forked afterwards inherits both.
(
  echo $BASHPID > "$CG/cgroup.procs"

  exec unshare \
      --user --map-root-user \
      --mount --pid --fork \
      --uts --ipc --cgroup \
      --propagation private \
      bash -c '
        set -e
        ROOTFS="$1"; HOSTNAME_IN="$2"; shift 2

        hostname "$HOSTNAME_IN"

        # pivot_root needs new_root to be a mount point -> bind it to itself
        # Concepts: ../concepts/3.mount/6.pivot-root.md
        mount --bind "$ROOTFS" "$ROOTFS"
        cd "$ROOTFS"
        mkdir -p oldroot          # a previous run rmdir(2)s this away
        pivot_root . oldroot

        # From here on the host bash cannot exec anything: its libraries are
        # gone. Hand over to the STATIC busybox that lives in the new root.
        exec /bin/busybox sh -c "
            export PATH=/bin HOME=/root PS1=\"[sandbox] # \"
            mount -t proc  proc  /proc     # own PID view for ps/top
            mount -t sysfs sys   /sys      2>/dev/null || true
            mount -t tmpfs tmpfs /tmp

            # a minimal /dev — bind the host nodes we allow, and nothing else.
            # NOT /dev/sda: a namespace does not protect you from a device node.
            for d in null zero full random urandom tty; do
                mount --bind /oldroot/dev/\$d /dev/\$d 2>/dev/null || true
            done

            umount -l /oldroot             # cut the last link to the host
            rmdir /oldroot 2>/dev/null || true
            exec \"\$@\"
        " -- "$@"
      ' -- "$ROOTFS" "$HOSTNAME_IN" "${CMD[@]}"
)
