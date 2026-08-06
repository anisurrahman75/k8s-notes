# Lab 03 — Cgroup v2 with systemd

## Goal

Run a bounded workload, resolve its cgroup from `/proc`, and observe CPU, memory, and PID controls directly.

## Requirements and commands

Cgroup v2, a running user systemd manager, `systemd-run`, and the top-level `inspect-cgroup.sh`. Run `./run.sh`; no `sudo` is used. Inspect with the printed PID or `systemctl --user status UNIT`.

## Explanation and expected output

The lab creates a unique transient user **service** with `CPUQuota=25%`, `CPUWeight=100`, `MemoryHigh=64M`, `MemoryMax=96M`, and `TasksMax=32`. Here 25% is roughly one quarter of one CPU, not one quarter of the host. The service runs a short Bash CPU loop. Expect `cpu.max` to be finite and `cpu.stat` usage/throttling counters to grow. A user manager may reject properties when its hierarchy is not delegated; the script reports that rather than escalating.

## Cleanup

`./cleanup.sh [unit]` stops only a unit matching `primitives-cgroup-*.service`; the last generated name is recorded locally. Transient unit state is collected by systemd.

## Common errors

No user bus commonly means a non-login/SSH environment. A missing controller or rejected property is a delegation issue. `memory.current` below `memory.max` is normal; limits do not reserve memory.

## Review questions

1. What does `cpu.max` encode? 2. When does weight matter? 3. Which counter proves throttling? 4. What does `max` mean? 5. Why use systemd instead of writing arbitrary cgroup directories?

