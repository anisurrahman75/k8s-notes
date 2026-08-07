#!/usr/bin/env bash
set -euo pipefail

demo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
binary="$demo_dir/bin/resource-burner"

if [[ ! -x "$binary" ]]; then
  "$demo_dir/scripts/build.sh"
fi

systemd-run --user --collect \
  --unit=resource-burner-demo \
  --description='Bounded CPU and memory demo' \
  --property=CPUQuota=50% \
  --property=MemoryHigh=128M \
  --property=MemoryMax=160M \
  --property=MemorySwapMax=0 \
  --property=TasksMax=32 \
  "$binary" -cpu-workers=2 -memory-mib=128 "$@"

echo "Follow logs: journalctl --user -fu resource-burner-demo.service"
echo "Stop:        systemctl --user stop resource-burner-demo.service"
