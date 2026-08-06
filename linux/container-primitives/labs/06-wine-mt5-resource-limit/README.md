# Lab 06 — Limit Wine + MetaTrader 5 as one workload

## Goal

Place the complete Wine/MT5 process tree in one cgroup v2 systemd scope, apply configurable CPU/memory/task controls, and prove the controls from kernel files. This lab does not install software, configure accounts, launch trades, or touch credentials.

> Resource limits control consumption; they do not provide the same isolation boundary as a virtual machine.

## Requirements and configuration

Required: cgroup v2, Wine, `systemd-run`, a running user systemd manager, an existing MT5 executable, and no pre-existing Wine processes for the selected prefix. A dedicated prefix is strongly recommended.

```bash
export WINEPREFIX="$HOME/.wine-mt5-lab"       # choose deliberately
export MT5_EXE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
export CPU_QUOTA=100% CPU_WEIGHT=100
export MEMORY_HIGH=1G MEMORY_MAX=1500M PIDS_MAX=128
./run.sh
```

The values are passed as separate, quoted arguments. `CPUQuota=100%` means about one full CPU of time, not all host CPUs. Quota is hard bandwidth. Weight is relative only during sibling contention. `MemoryHigh` causes reclaim pressure; `MemoryMax` is hard and may cause cgroup OOM kills. `TasksMax` counts processes and threads.

The user scope is preferred. If the user manager rejects limits, the script stops with an error and never silently uses `sudo`. After reviewing security/ownership implications, a system-level equivalent is conceptually:

```bash
sudo systemd-run --scope --unit=mt5-lab -p User="$(id -un)" \
  -p CPUQuota=100% -p CPUWeight=100 -p MemoryHigh=1G \
  -p MemoryMax=1500M -p TasksMax=128 wine "$MT5_EXE"
```

Do not execute that alternative without explicit approval. Direct cgroup-file management is possible only with correct delegation; systemd is the safer owner on this host.

## Why the complete tree matters

Wine can start a loader, `wineserver`, service/helper processes, MT5 children, and Expert Advisor-related processes. Limiting one terminal PID misses any helper in another cgroup. A `wineserver` is shared by processes using the same prefix; if it already exists outside the new scope, resource accounting and enforcement split. For reliable per-instance limits:

1. use a dedicated `WINEPREFIX` per instance;
2. confirm no process is already using that prefix;
3. start the entire Wine environment inside its own scope;
4. verify every related PID has the expected `/proc/PID/cgroup` path.

The script reports matching processes before launch but never kills them. A process command line does not always expose its prefix, so manually validate ambiguity.

## Inspection and proof

```bash
./inspect.sh mt5-lab-...scope
watch -n 1 ./inspect.sh mt5-lab-...scope
systemd-cgtop
pgrep -a -f 'wine|wineserver|terminal64.exe'
ps -eo pid,ppid,cgroup,cmd --forest
cat /proc/<pid>/cgroup
```

`inspect.sh` resolves `ControlGroup` instead of assuming systemd path layout. `cpu.max` proves quota; `cpu.weight` proves weight; memory and PID files prove those boundaries. In `cpu.stat`, `nr_periods` counts quota periods, `nr_throttled` periods that exhausted quota, and `throttled_usec` cumulative delayed time. Rising values show constraint. `memory.events` `oom`/`oom_kill` values above the pre-test baseline show allocation failure/kill activity.

### Controlled tests

- **CPU:** record `cpu.stat`, use MT5 normally, then compare. Do not launch an uncontrolled stressor.
- **Memory:** observe `memory.current`. Lower limits only for a disposable prefix with no real account or unsaved state. An overly low hard limit can terminate MT5.
- **Multiple instances:** give each a separate prefix and scope with independent settings. Cgroups isolate accounting/resources, not application accounts or trust.

## Cleanup

`./cleanup.sh EXACT.scope` sends `SIGTERM` only to that scope and reports survivors. It never runs global `wineserver -k` and leaves prefix/MT5 files intact. If processes remain, inspect them; `./cleanup.sh --force EXACT.scope` clearly warns and then sends `SIGKILL` only to the scope.

## Common errors

“Failed to connect to bus” means no user manager. “Property not supported” indicates systemd/controller delegation. An existing shared wineserver means the prefix was not isolated. A missing MT5 path must be fixed with `MT5_EXE`; the script never guesses account data.

## Review questions

1. Why constrain the whole tree? 2. How can a shared wineserver escape accounting? 3. Why separate prefixes? 4. How do quota/weight map to `cpu.max`/`cpu.weight`? 5. How do high/max/tasks map? 6. How do counters prove throttling? 7. What proves OOM? 8. What happens at `MemoryMax`? 9. Can instances have independent scopes? 10. Why is this not VM-grade isolation?

