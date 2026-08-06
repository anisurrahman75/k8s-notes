#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state="$self_dir/.container"
[[ -r $state ]] || { echo 'Nothing to clean.'; exit 0; }
read -r name <"$state"
[[ $name =~ ^primitives-inspect-[0-9]+-[0-9]+$ ]] || { echo 'Refusing non-lab container name.' >&2; exit 1; }
docker rm -f "$name" >/dev/null 2>&1 || true
rm -f -- "$state"
echo "Removed $name (if it existed); image retained."

