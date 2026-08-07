#!/usr/bin/env bash
set -euo pipefail

demo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
binary="$demo_dir/bin/resource-burner"

if [[ ! -x "$binary" ]]; then
  "$demo_dir/scripts/build.sh"
fi

exec systemd-run --user --scope --collect \
  --unit=resource-burner-demo \
  --property=CPUQuota=50% \
  --property=MemoryHigh=128M \
  --property=MemoryMax=160M \
  --property=MemorySwapMax=0 \
  --property=TasksMax=32 \
  "$binary" -cpu-workers=2 -memory-mib=128 "$@"
