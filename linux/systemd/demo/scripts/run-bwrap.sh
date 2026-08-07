#!/usr/bin/env bash
set -euo pipefail

demo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
binary="$demo_dir/bin/resource-burner"

if [[ ! -x "$binary" ]]; then
  "$demo_dir/scripts/build.sh"
fi

# The new mount namespace contains only the static binary, procfs, a minimal
# /dev, and an empty tmpfs. No host directory is mounted into the sandbox.
exec bwrap \
  --unshare-all \
  --die-with-parent \
  --new-session \
  --clearenv \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --dir /app \
  --ro-bind "$binary" /app/resource-burner \
  --chdir /tmp \
  /app/resource-burner -probe-path=/etc/passwd "$@"
