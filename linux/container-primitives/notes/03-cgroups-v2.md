# 3 — Cgroups v2

## Problem and mental model

Namespaces answer “what can this process see?” Cgroups answer “which processes are accounted together, and what may they consume?” Cgroup v2 is one tree. Each process belongs to one cgroup in that tree; controllers distribute control down the hierarchy.

## Hierarchy and files

- `cgroup.controllers`: controllers available to children.
- `cgroup.subtree_control`: controllers enabled for child cgroups; entries are written with `+cpu`, `+memory`, etc.
- `cgroup.procs`: PIDs in a cgroup; `cgroup.threads` shows threads.
- `cpu.max`: hard bandwidth, `quota period` microseconds. `100000 100000` is about one CPU; `max 100000` has no quota.
- `cpu.weight`: 1–10000 relative share only when siblings contend; default is 100.
- `cpu.stat`: cumulative usage plus `nr_periods`, `nr_throttled`, and `throttled_usec` when supported.
- `memory.current`: current accounted memory; `memory.high` applies reclaim pressure; `memory.max` is the hard boundary.
- `memory.events`: cumulative `high`, `max`, `oom`, and `oom_kill` evidence.
- `pids.current` / `pids.max`: current tasks and limit. Threads count.

Systemd maps services, scopes, and slices onto this hierarchy. Prefer systemd transient units over manually creating subdirectories on a systemd-managed host because delegation and ownership are already coordinated.

## Inspection questions answered

```bash
cat /proc/<pid>/cgroup                    # path
./inspect-cgroup.sh <pid>                 # relevant files
docker inspect -f '{{.State.Pid}}' NAME   # host PID
systemctl show --property=ControlGroup UNIT
```

For Docker, find the host PID, resolve `0::/path`, and read `/sys/fs/cgroup/path/{cpu.max,cpu.weight,cpu.stat,memory.max,memory.current,memory.events}`. `docker run --cpus=1` normally maps to a one-CPU ratio in `cpu.max`; `--cpu-shares` is translated to a v2 weight; `--memory` maps to `memory.max`; `--pids-limit` maps to `pids.max`. Verify the files instead of depending on path naming or assuming exact rounding.

CPU quota is a hard time budget per period. Weight is a preference among busy siblings and does nothing when spare CPU exists. Repeated increases in `nr_throttled` prove quota exhaustion. `memory.current` is usage, not a configured limit. At `memory.max`, reclaim is attempted; if it cannot succeed, the cgroup may experience an OOM and one or more processes may be killed. Inspect `memory.events`, not merely exit status.

## Demonstration and expected observations

The cgroup lab starts a short CPU workload in a transient user service (a service is used because a shell script cannot reliably remain inside a synchronous scope through `systemd-run`). It compares `cpu.stat` and runs `inspect-cgroup.sh`. Expect usage counters to rise; throttling depends on the quota and workload. Cleanup stops only the generated unit.

## Docker and Kubernetes

Docker flags become runtime/OCI resource settings and then cgroup files. Kubernetes container limits become CRI/OCI settings. CPU limits normally become quota; CPU requests influence weight. Memory limits become hard boundaries; memory requests primarily guide scheduling and may influence runtime configuration/QoS behavior. Scheduling requests are not the same thing as runtime limits.

## Common mistakes

- reading only the leaf when a stricter ancestor can constrain it.
- interpreting `max` as zero.
- treating CPU weight as reservation or cap.
- expecting a memory limit to preallocate memory.
- moving only one PID when helpers/children live elsewhere.

## Review questions

1. How do you resolve a PID's unified cgroup path?
2. What is the difference between CPU quota and weight?
3. Which counters demonstrate throttling and OOM activity?
4. Why can an ancestor limit matter?
5. How do Docker/Kubernetes resource settings reach cgroup files?

## Summary

Cgroups group the whole workload, account it, and enforce explicit CPU, memory, and task policies. Files and changing counters provide the proof.

