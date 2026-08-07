#!/usr/bin/env bash
set -euo pipefail

demo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$demo_dir/bin"

CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o "$demo_dir/bin/resource-burner" "$demo_dir"
echo "Built $demo_dir/bin/resource-burner"
