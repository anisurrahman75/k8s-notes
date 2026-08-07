# `systemd-run`

> The command is `systemd-run`, not `systemctl-run`.

`systemctl` controls units that already exist. `systemd-run` creates a temporary
unit around a command and starts it immediately.

```text
systemd-run   create and start a transient unit
systemctl     inspect, stop, restart, or change that unit
journalctl    read the unit's logs
```

This is useful when a command is temporary, but running it directly from a shell
is too weak. You may want a name, logs, a CPU/memory budget, automatic cleanup,
or a sandbox without first writing a unit file.

## What actually happens?

Suppose we run:

```bash
systemd-run --user --unit=hello /usr/bin/printf 'hello\n'
```

The flow is:

```text
your terminal
    │ asks the user service manager over D-Bus
    ▼
systemd --user
    │ creates hello.service and its cgroup
    │ starts /usr/bin/printf inside that cgroup
    ▼
journal receives stdout/stderr; systemd records exit status
```

The command normally returns as soon as systemd starts the job. The program may
still be running in the background.

```bash
systemctl --user status hello.service
journalctl --user -u hello.service
```

The unit is **transient**: its generated definition lives under `/run`, not in
`~/.config/systemd/user` or `/etc/systemd/system`, and disappears after reboot.

## `--user` or system-wide?

```bash
systemd-run --user ...       # your user manager; no sudo
sudo systemd-run ...         # system manager; machine-wide privileges
```

Start with `--user`. It is safer and sufficient for the demo. A user manager can
only use cgroup controllers and sandbox features delegated to it. Machine-wide
device policy, CPU affinity, or some namespace options may need the system
manager.

User services may stop when you log out unless lingering is enabled:

```bash
loginctl show-user "$USER" -p Linger
sudo loginctl enable-linger "$USER"   # only when background-after-logout is wanted
```

## Transient service: background work

Without `--scope`, `systemd-run` creates a `.service` and asks the service
manager to start the executable.

From `linux/systemd/demo`:

```bash
bin=$(realpath ./bin/resource-burner)

systemd-run --user \
  --unit=burn-demo \
  --description='CPU and memory experiment' \
  --collect \
  "$bin" -cpu-workers=1 -memory-mib=64 -duration=30s
```

Read it line by line:

- `--user`: use my per-user service manager.
- `--unit=burn-demo`: choose a predictable name; the real name becomes
  `burn-demo.service`.
- `--description=...`: human-friendly text in `systemctl status`.
- `--collect`: unload the unit after it finishes and is no longer referenced.
- everything after the options is the executable plus its arguments.

Because it is a service, the command returns quickly. Use these afterward:

```bash
systemctl --user status burn-demo.service
journalctl --user -fu burn-demo.service
systemctl --user stop burn-demo.service
```

Use a transient service for a background batch job, import, backup, or experiment
that should continue independently of the launching terminal.

## Transient scope: keep it in the foreground

With `--scope`, `systemd-run` starts the command itself and asks systemd to place
the process in a transient `.scope` cgroup.

```bash
systemd-run --user --scope \
  --unit=burn-demo \
  --collect \
  "$bin" -cpu-workers=1 -memory-mib=64 -duration=30s
```

Now the unit is `burn-demo.scope`. The terminal stays attached, output is shown
directly, and Ctrl-C reaches the program. This is a good fit for an interactive
command that mainly needs resource limits.

The distinction to remember:

| Question | Transient service | Transient scope |
| --- | --- | --- |
| Who starts the program? | service manager | `systemd-run` |
| Does the initial command return immediately? | normally yes | normally no |
| Default output location | journal | current terminal |
| Unit suffix | `.service` | `.scope` |
| Typical use | background job | foreground/interactive command |

## Wait, output, and terminal behavior

These switches solve different problems:

- `--wait`: wait until the transient service finishes and report its result.
- `--pipe`: connect the service's stdin/stdout/stderr to the caller.
- `--pty`: give the service an interactive pseudo-terminal.
- `--collect`: unload the unit after it becomes inactive.

For a non-interactive command whose output we want now:

```bash
systemd-run --user --wait --pipe --collect \
  /usr/bin/printf 'hello from a transient service\n'
```

For a terminal program, prefer `--pty`:

```bash
systemd-run --user --pty --collect /usr/bin/bash
```

Do not add every switch by habit. For example, `--scope` already keeps the
command attached to the current terminal, so `--pipe` is mainly useful for a
transient service.

## Add a cgroup budget

`--property=NAME=VALUE` (short form: `-p`) adds normal systemd unit properties.

```bash
systemd-run --user --scope --collect \
  --unit=burn-demo \
  -p CPUQuota=25% \
  -p MemoryHigh=128M \
  -p MemoryMax=160M \
  -p MemorySwapMax=0 \
  -p TasksMax=32 \
  "$bin" -cpu-workers=2 -memory-mib=128 -duration=30s
```

Meaning:

- both CPU workers together get at most 25% of one logical CPU;
- memory pressure starts near 128 MiB;
- 160 MiB is the hard memory ceiling;
- the unit cannot use swap;
- processes and threads together cannot exceed 32.

Confirm the configuration instead of assuming it worked:

```bash
systemctl --user show burn-demo.scope \
  -p ControlGroup \
  -p CPUQuotaPerSecUSec \
  -p MemoryHigh \
  -p MemoryMax \
  -p MemoryCurrent \
  -p TasksMax
```

`CPUQuota=25%` appears as `CPUQuotaPerSecUSec=250ms`, meaning 250 milliseconds of
CPU time in each one-second quota period.

## Working directory and environment

A service does not run inside your interactive shell. It does not know aliases
or shell functions, and it may have a different working directory and a smaller
environment.

Use explicit paths:

```bash
systemd-run --user --wait --pipe \
  --working-directory="$(pwd)" \
  --setenv=MODE=demo \
  /usr/bin/env
```

`--same-dir` is a shorter way to copy the current directory. `--setenv` passes
only values you choose. Avoid passing secrets through the command line because
unit properties and process arguments are inspectable.

Also remember that the executable is not parsed by a shell:

```bash
# This does not create out.txt; > is just another argument.
systemd-run --user /usr/bin/printf hello '>' out.txt

# Ask for a shell explicitly only when shell syntax is truly needed.
systemd-run --user /usr/bin/bash -c '/usr/bin/printf hello > out.txt'
```

## Run later with a transient timer

Timer options create two units: a `.timer` that decides *when* and a `.service`
that contains *what* to run.

```bash
systemd-run --user \
  --unit=morning-job \
  --on-calendar='tomorrow 09:00' \
  /absolute/path/to/job

systemctl --user list-timers morning-job.timer
systemctl --user status morning-job.timer morning-job.service
```

For a relative delay:

```bash
systemd-run --user --on-active=5m \
  --unit=delayed-job /absolute/path/to/job
```

Transient timers disappear at reboot. Write regular `.timer` and `.service`
files when the schedule is permanent or should be reviewed in version control.

## Common failures

### “Unit already exists”

The old unit is still active or loaded. Pick another name, stop/reset it, or use
`--collect` for experiments.

```bash
systemctl --user status burn-demo.service
systemctl --user stop burn-demo.service
systemctl --user reset-failed burn-demo.service
```

### Command works in my shell but fails as a service

Check the absolute executable path, working directory, environment, and quoting.

```bash
systemctl --user status burn-demo.service
journalctl --user -u burn-demo.service -b
systemctl --user cat burn-demo.service
```

### A property had no effect

Read it back with `systemctl show`. The controller may not be available or
delegated to the user manager, or the property may affect contention rather than
set a hard ceiling. For example, `CPUWeight=` does little when the CPU is idle;
`CPUQuota=` is the hard limit.

## When to write a real unit file

Use `systemd-run` while experimenting and for genuinely one-off work. Write a
normal unit when the workload is permanent, must start at boot, needs several
dependencies, or deserves configuration review and version control.
