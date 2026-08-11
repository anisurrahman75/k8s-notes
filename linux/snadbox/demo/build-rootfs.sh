#!/usr/bin/env bash
# build-rootfs.sh — create a minimal busybox root filesystem for minicontainer.sh
#
# Concepts:  concepts/3.mount/5.rootfs.md
# Usage:     ./build-rootfs.sh [ROOTFS_DIR]

set -euo pipefail

ROOTFS="${1:-/tmp/sandbox-rootfs}"

command -v busybox >/dev/null || {
  echo "busybox not found. Install it:  sudo apt install busybox-static" >&2
  exit 1
}

# busybox must be static — otherwise nothing works after pivot_root
if ldd "$(command -v busybox)" >/dev/null 2>&1; then
  echo "WARNING: your busybox is dynamically linked; copy its libraries too." >&2
fi

echo "==> building rootfs at $ROOTFS"
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"/{bin,proc,sys,dev,tmp,etc,root,oldroot}
chmod 1777 "$ROOTFS/tmp"

cp "$(command -v busybox)" "$ROOTFS/bin/"

# Placeholder files for the device nodes minicontainer.sh will bind-mount onto.
# We cannot mknod(2) in a user namespace, so we bind the host's nodes instead.
# The targets must live on an INHERITED filesystem (this rootfs dir), not on a
# tmpfs we mount inside the namespace — see concepts/3.mount/5.rootfs.md
for dev in null zero full random urandom tty; do
  : > "$ROOTFS/dev/$dev"
done

# RELATIVE symlinks — `busybox --install -s` writes ABSOLUTE host paths that
# break the moment we pivot_root. See concepts/3.mount/5.rootfs.md
( cd "$ROOTFS/bin" && for applet in $(./busybox --list); do
    [ "$applet" = busybox ] || ln -sf busybox "$applet"
  done )

cat > "$ROOTFS/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/:/bin/false
EOF

cat > "$ROOTFS/etc/group" <<'EOF'
root:x:0:
nogroup:x:65534:
EOF

echo sandbox            > "$ROOTFS/etc/hostname"
echo "nameserver 1.1.1.1" > "$ROOTFS/etc/resolv.conf"

cat > "$ROOTFS/etc/profile" <<'EOF'
export PATH=/bin
export PS1='[sandbox] # '
EOF

# a tiny in-sandbox self-check, used by the demo walkthrough
cat > "$ROOTFS/bin/whoami-really" <<'EOF'
#!/bin/sh
echo "pid            : $$"
echo "hostname       : $(hostname)"
echo "uid            : $(id -u)"
echo "root contains  : $(ls / | tr '\n' ' ')"
echo "mounts         : $(wc -l < /proc/mounts)"
echo "visible procs  : $(ls -d /proc/[0-9]* | wc -l)"
echo "cgroup         : $(cat /proc/self/cgroup)"
EOF
chmod +x "$ROOTFS/bin/whoami-really"

echo "==> done"
echo "    applets : $(ls "$ROOTFS/bin" | wc -l)"
echo "    size    : $(du -sh "$ROOTFS" | cut -f1)"
echo "    check   : $(ls -l "$ROOTFS/bin/sh" | sed 's/.*-> //')  (must be relative)"
