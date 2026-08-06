# Lab 05 — Trace a Docker container to Linux

## Goal

Start a disposable, resource-limited container; find its host PID; inspect namespaces and cgroup v2 files; compare kernel evidence with Docker output.

## Requirements and commands

Docker daemon access, cgroup v2, and a local image that provides `sh` and `sleep`. Default `IMAGE=alpine:latest`. The script refuses to pull: load/pull the chosen image yourself, then run `./run.sh`. Override with `IMAGE=...`.

## Explanation and expected output

Docker starts `sleep` with 0.5 CPU, 128 MiB memory, and 64 tasks. Host and container namespace IDs differ for the commonly isolated types. `/proc/PID/cgroup` resolves to finite `cpu.max`, `memory.max`, and `pids.max`. `docker inspect` reports the requested settings; `docker stats` reports live usage. User namespace may match on a normal rootful daemon.

## Cleanup

An EXIT trap and `./cleanup.sh` remove only the generated `primitives-inspect-*` container. Docker also receives `--rm`. The image is retained.

## Common errors

Permission denied on the Docker socket means the user lacks daemon access. Missing local image is intentional; the lab avoids hidden network activity. Rootless or nested Docker can produce different cgroup paths and namespace sharing.

## Review questions

1. How was the host PID found? 2. Which namespace IDs differ? 3. How does `--cpus=.5` appear in `cpu.max`? 4. Which Docker field maps to `memory.max`? 5. Why can host tools see the process?

