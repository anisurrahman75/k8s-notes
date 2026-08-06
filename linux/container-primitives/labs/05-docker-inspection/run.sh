#!/usr/bin/env bash
set -Eeuo pipefail
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$self_dir/../.." && pwd)
state="$self_dir/.container"
image=${IMAGE:-alpine:latest}
name="primitives-inspect-$(date +%s)-$$"
created=0
cleanup() { if (( created )); then docker rm -f "$name" >/dev/null 2>&1 || true; rm -f -- "$state"; fi; }
trap cleanup EXIT INT TERM

command -v docker >/dev/null || { echo 'Docker not installed.' >&2; exit 1; }
docker info >/dev/null || { echo 'Docker daemon unavailable or access denied.' >&2; exit 1; }
docker image inspect "$image" >/dev/null 2>&1 || { echo "Image $image is not local. Pull/load it explicitly, then rerun." >&2; exit 1; }

docker run -d --rm --name "$name" --hostname primitives-demo \
  --cpus=.5 --cpu-shares=512 --memory=128m --pids-limit=64 \
  "$image" sh -c 'exec sleep 300' >/dev/null
created=1; printf '%s\n' "$name" >"$state"
pid=$(docker inspect -f '{{.State.Pid}}' "$name")
printf 'Container: %s\nHost PID: %s\n\nNamespace comparison (lab shell -> container):\n' "$name" "$pid"
for ns in pid mnt net uts ipc user; do
  printf '%-5s %-20s -> %s\n' "$ns" "$(readlink "/proc/$$/ns/$ns")" "$(readlink "/proc/$pid/ns/$ns")"
done
printf '\n'; "$root/inspect-cgroup.sh" "$pid"
printf '\nDocker settings:\n'
docker inspect -f 'NanoCPUs={{.HostConfig.NanoCpus}} CpuShares={{.HostConfig.CpuShares}} Memory={{.HostConfig.Memory}} PidsLimit={{.HostConfig.PidsLimit}}' "$name"
printf '\nDocker usage snapshot:\n'; docker stats --no-stream "$name"
printf '\nContainer will now be removed. Set KEEP=1 is intentionally unsupported; rerun for a fresh specimen.\n'

