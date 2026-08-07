# Resource control

A normal process can use as much CPU and memory as the machine lets it. systemd
can put a unit inside a cgroup and give that **group of processes** a budget.

```text
unit: resource-burner-demo.scope
└─ cgroup
   ├─ burner process
   ├─ its threads
   └─ any child processes

The policy applies to all of them together.
```

This differs from `ulimit`: an rlimit normally applies per process, while a
cgroup measures and controls a workload as a group.

## Two distinctions make the options easier

### Weight versus limit

- A **weight** decides who gets a larger share when workloads compete.
- A **limit** is a ceiling even when the machine is otherwise idle.

If only one job is using the CPU, `CPUWeight=10` may appear to do nothing.
`CPUQuota=10%` still throttles it.

### Pressure versus hard stop

- A soft/high boundary tells the kernel to reclaim or slow the workload first.
- A maximum is the last line; crossing it may make allocations fail or trigger
  the cgroup OOM killer.

That is why memory policy normally uses both `MemoryHigh` and `MemoryMax`.

## CPU controls

### `CPUWeight=`

Range: `1` to `10000`; default weight is normally `100`.

Imagine two busy sibling services:

```ini
# service A
CPUWeight=100

# service B
CPUWeight=300
```

During contention, B is eligible for roughly three times A's CPU share. This is
relative, not a promise of exact percentages.

### `CPUQuota=`

This is a hard time budget:

```text
CPUQuota=25%    one quarter of one logical CPU
CPUQuota=100%   one full logical CPU
CPUQuota=200%   up to two logical CPUs
```

Two Go worker goroutines under `CPUQuota=25%` do not each receive 25%; together,
the entire unit receives at most 25%.

### `AllowedCPUs=`

```ini
AllowedCPUs=0-1
```

This restricts execution to particular logical CPUs. It is placement, not a
time limit: the process could still fully use CPUs 0 and 1. The cpuset controller
often is not delegated to user services, so this commonly needs a system unit.

## Memory controls

Read them from gentlest to strictest:

| Property | Meaning |
| --- | --- |
| `MemoryLow=` | best-effort protection from reclaim |
| `MemoryHigh=` | preferred ceiling; reclaim/throttle above it |
| `MemoryMax=` | hard ceiling for the cgroup |
| `MemorySwapMax=` | maximum swap used by this cgroup |

A sensible small demo policy:

```ini
MemoryHigh=128M
MemoryMax=160M
MemorySwapMax=0
```

The 32 MiB gap gives reclaim and the program a chance to respond before the hard
ceiling. `MemorySwapMax=0` makes the behavior easier to observe, but it can make
memory pressure much more abrupt.

`MemoryMax=160M` does not mean the application can allocate exactly 160 MiB of
payload. The Go runtime, stacks, binary pages, and other charged memory also
count toward the cgroup.

## Tasks and I/O

### `TasksMax=`

A task means a process **or a thread**:

```ini
TasksMax=32
```

A heavily threaded program can reach this limit with only one visible process.

### I/O controls

```ini
IOWeight=100
IOReadBandwidthMax=/dev/nvme0n1 10M
IOWriteBandwidthMax=/dev/nvme0n1 5M
```

`IOWeight` is relative during contention. Bandwidth options are hard per-device
limits. Use the workload's real backing block device; device mapper, containers,
and overlay filesystems can make the correct device non-obvious.

## Worked experiment

From `linux/systemd/demo`:

```bash
./scripts/run-scope.sh -duration=30s
```

The script creates a transient scope with:

```text
CPUQuota=50%
MemoryHigh=128M
MemoryMax=160M
MemorySwapMax=0
TasksMax=32
```

In another terminal:

```bash
systemctl --user show resource-burner-demo.scope \
  -p ControlGroup \
  -p CPUUsageNSec \
  -p CPUQuotaPerSecUSec \
  -p MemoryCurrent \
  -p MemoryPeak \
  -p MemoryHigh \
  -p MemoryMax \
  -p TasksCurrent \
  -p TasksMax

systemd-cgtop --user
```

The configured property is named `CPUQuota`, while `systemctl show` exposes its
normalized internal form as `CPUQuotaPerSecUSec`.

## Change a running unit

```bash
systemctl --user set-property --runtime \
  resource-burner-demo.scope CPUQuota=20%
```

`--runtime` keeps the change under `/run`, so it does not survive reboot. Remove
the ceiling with:

```bash
systemctl --user set-property --runtime \
  resource-burner-demo.scope CPUQuota=infinity
```

For the burner, compare `hash_iterations` between 50% and 20%. The count should
grow more slowly after the quota is reduced.

## Trigger the hard memory ceiling

The demo normally requests 128 MiB. Ask for more than `MemoryMax`:

```bash
./scripts/run-scope.sh -memory-mib=512 -duration=30s
```

The process may be killed when the cgroup cannot reclaim enough memory. Inspect:

```bash
systemctl --user status resource-burner-demo.scope
journalctl --user -b --grep='resource-burner\|oom'
journalctl -k -b --grep='oom\|Killed process'
```

Do this only on a development machine. The cgroup contains the test, but severe
memory pressure can still affect responsiveness.

## Common misunderstandings

- Limits cover children too; `fork()` does not escape the unit cgroup.
- `CPUQuota=100%` means one logical CPU, not the whole multi-core machine.
- `MemoryMax` controls memory consumption, not filesystem or network access.
- User services only get controllers delegated by their parent `user.slice`.
- Accounting properties and available controllers depend on the kernel,
  systemd version, hierarchy, and delegation.

Find the actual cgroup path with:

```bash
systemctl --user show resource-burner-demo.scope -p ControlGroup
```
