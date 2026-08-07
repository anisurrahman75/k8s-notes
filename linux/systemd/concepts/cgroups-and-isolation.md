# Cgroups and isolation

“Limit this process” and “isolate this process” sound similar, but they answer
different security and operations questions.

| Mechanism | Main question | Example |
| --- | --- | --- |
| cgroup | How much may the workload consume? | limit memory to 160 MiB |
| namespace | What part of the system can it see? | hide host processes/network |
| Unix identity/mode | Which files may this user access? | run as an unprivileged user |
| Linux capabilities | Which root-like powers remain? | remove mount capability |
| seccomp | Which syscalls may it make? | block uncommon kernel operations |
| LSM | What policy does SELinux/AppArmor allow? | deny access by security label |

Strong confinement normally combines several layers. A cgroup alone does not
stop a process reading files. A mount namespace alone does not stop it consuming
all CPU.

## Cgroup hierarchy

With cgroup v2, all processes belong to one tree. A simplified systemd layout:

```text
-.slice
├─system.slice                 system services
│ ├─sshd.service
│ └─resource-burner.service
├─user.slice                   users and their user managers
│ └─user-1000.slice
└─machine.slice                containers and virtual machines
```

A service or scope is normally a leaf. A `.slice` groups child units and can
apply one shared budget above them.

systemd owns this tree. Let systemd create units and move processes. Manually
creating directories under `/sys/fs/cgroup` can conflict with the manager and
will not produce a proper systemd unit lifecycle.

## Why parent limits matter

The demo includes `demo-workload.slice`:

```ini
[Slice]
CPUQuota=100%
MemoryMax=256M
TasksMax=64
```

The service joins it with:

```ini
[Service]
Slice=demo-workload.slice
```

Imagine two services below that slice:

```text
demo-workload.slice              MemoryMax=256M
├─worker-a.service               MemoryMax=200M
└─worker-b.service               MemoryMax=200M
```

Each child has a 200 MiB ceiling, but they cannot both consume 200 MiB at the
same time because their parent permits only 256 MiB total. Every ancestor's
policy still applies.

This is useful for a team, tenant, or application made of several services: give
the whole group a budget, then optionally divide it further among children.

## Resource control is not file isolation

This command limits CPU and memory:

```bash
systemd-run --user --scope \
  -p CPUQuota=25% -p MemoryMax=64M \
  /path/to/program
```

Unless normal file permissions say otherwise, that process can still read your
home directory. To reduce what a service sees and what privileges it holds, add
execution sandbox properties.

## systemd hardening layers

A reasonable starting set for a simple daemon:

```ini
[Service]
DynamicUser=yes
NoNewPrivileges=yes

ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes

ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
CapabilityBoundingSet=
RestrictAddressFamilies=AF_UNIX
```

What each group is doing:

### Identity and privilege

- `DynamicUser=yes` runs the service with a temporary unprivileged identity.
- `NoNewPrivileges=yes` prevents `execve()` from gaining privilege through
  setuid/setgid bits or file capabilities.
- `CapabilityBoundingSet=` with an empty value removes all Linux capabilities
  from the service.

### Filesystem and devices

- `ProtectSystem=strict` makes most of the filesystem read-only for the unit.
- `ProtectHome=yes` makes `/home`, `/root`, and `/run/user` inaccessible.
- `PrivateTmp=yes` gives the service private `/tmp` and `/var/tmp` views.
- `PrivateDevices=yes` gives it a small private `/dev` rather than all host
  devices.

If the daemon must write state, open only the needed path:

```ini
StateDirectory=my-app
# systemd creates /var/lib/my-app with suitable ownership.
```

Or add a narrow exception:

```ini
ReadWritePaths=/var/lib/my-app
```

### Kernel and network surface

- `ProtectKernelModules=yes` blocks loading/unloading kernel modules.
- `ProtectKernelTunables=yes` protects sysctl-style kernel controls.
- `ProtectControlGroups=yes` makes the cgroup filesystem read-only.
- `RestrictAddressFamilies=AF_UNIX` permits Unix sockets but not Internet
  sockets. Add `AF_INET AF_INET6` only when the service needs them.
- `PrivateNetwork=yes` creates a new network namespace with loopback only.

`RestrictAddressFamilies=` limits socket families; `PrivateNetwork=` changes the
network view. They are related but not interchangeable.

### Syscall filtering

```ini
SystemCallFilter=@system-service
SystemCallArchitectures=native
```

This uses seccomp to reduce available syscalls. Add it late and test it with the
real workload: language runtimes, DNS, logging, and libraries may use syscalls
that a tiny smoke test never reaches.

## Hardening is an allow-and-test loop

Do not paste twenty switches into production and hope. A useful loop is:

1. Run under a dedicated unprivileged identity.
2. Make the filesystem read-only and add precise writable state directories.
3. Remove capabilities the program does not need.
4. Restrict devices and networking.
5. Add syscall filtering after observing the complete workload.
6. Test startup, normal traffic, reload, failure, and shutdown.

Review the resulting unit:

```bash
systemd-analyze verify ./resource-burner.service
systemd-analyze security resource-burner.service
```

The security score is a checklist, not proof. It cannot evaluate application
protocols, business authorization, or every kernel/LSM rule.

## Debugging a denied or killed service

Start broad, then narrow down:

```bash
systemctl status UNIT
journalctl -u UNIT -b
systemctl show UNIT -p Result -p ExecMainCode -p ExecMainStatus
journalctl -k -b
```

Questions to ask:

1. Was it an ordinary application exit or a signal?
2. Did it cross `MemoryMax` and hit cgroup OOM?
3. Did seccomp reject a syscall?
4. Did AppArmor/SELinux deny access?
5. Did a read-only or hidden path break startup?

Find the cgroup and memory events:

```bash
cg=$(systemctl show UNIT -p ControlGroup --value)
sudo cat "/sys/fs/cgroup${cg}/memory.events"
```

Look for counters such as `high`, `max`, `oom`, and `oom_kill`. Counters show
that an event happened; the journal usually provides the human context.
