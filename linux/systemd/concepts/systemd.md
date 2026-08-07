# systemd

## Start with the problem

Linux needs something to start userspace after the kernel boots. It also needs
to keep services running, stop them in the correct order, collect their logs,
and shut the machine down cleanly. On most current distributions, that manager
is `systemd`.

The main systemd process normally has PID 1:

```bash
ps -p 1 -o pid,comm,args
```

PID 1 is more than “the first daemon.” It starts the rest of userspace, adopts
and reaps orphaned processes, coordinates service state, and handles shutdown.

The word *systemd* can mean two things:

- `systemd`, the PID 1 service manager;
- the systemd project, which also contains `systemctl`, `journalctl`,
  `systemd-run`, `loginctl`, timers, network tools, and more.

## The core object: a unit

systemd does not think only in terms of processes. It manages named **units**.
A unit describes a resource and its relationships to other units.

| Suffix | Represents | Example use |
| --- | --- | --- |
| `.service` | a process or daemon | web server |
| `.socket` | a listening socket | start service on first connection |
| `.timer` | a schedule | nightly backup |
| `.path` | a watched filesystem path | react to a new file |
| `.mount` | a mount point | mount data disk |
| `.target` | a group/synchronization point | multi-user boot state |
| `.slice` | a parent cgroup | shared resource budget |
| `.scope` | externally started processes | terminal command in a cgroup |

The full name matters: `demo.service` and `demo.socket` are different units.
systemctl often adds `.service` when the suffix is omitted, but writing it makes
notes and scripts clearer.

## What happens during boot?

A simplified picture:

```text
firmware → bootloader → Linux kernel → systemd (PID 1)
                                      ├─ mounts filesystems
                                      ├─ starts sockets/services
                                      ├─ reaches boot targets
                                      └─ starts login sessions
```

systemd builds a dependency graph and starts unrelated work in parallel. Unit
relationships describe both *what is needed* and *what must happen first*.

## Dependency is not ordering

This is a common source of confusion:

```ini
[Unit]
Wants=database.service
After=database.service
```

- `Wants=` pulls the database into the same transaction, but this service can
  still start if the database fails.
- `Requires=` is stronger: stopping or failing the required unit can affect this
  unit too.
- `After=` controls order only. It does not start the database by itself.

So `Requires=database.service` alone does **not** mean “start after database.”
Dependencies and ordering are two separate questions.

## A small service file

```ini
[Unit]
Description=Example worker
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
ExecStart=/usr/local/bin/example-worker --listen=:8080
Restart=on-failure
RestartSec=2s

[Install]
WantedBy=multi-user.target
```

Read the sections as:

- `[Unit]`: description and relationships to other units;
- `[Service]`: how this process starts, stops, and restarts;
- `[Install]`: what `systemctl enable` should link it to.

`ExecStart=` is not a shell line. Pipes, redirects, aliases, and `$()` are not
interpreted unless you explicitly invoke a shell. Direct execution is easier to
reason about and avoids quoting surprises.

## Start is not enable

```bash
sudo systemctl start example.service       # start now
sudo systemctl enable example.service      # arrange activation at boot
sudo systemctl enable --now example.service # both
```

The reverse is also separate:

```bash
sudo systemctl stop example.service
sudo systemctl disable example.service
sudo systemctl disable --now example.service
```

Enabling does not necessarily start a service now. Starting does not necessarily
make it survive a reboot.

## System manager versus user manager

There are usually two useful service-manager contexts:

```text
system manager   PID 1; machine services; systemctl ...
user manager     one per logged-in user; systemctl --user ...
```

User units live under `~/.config/systemd/user/`, run without `sudo`, and are good
for personal background processes. They do not automatically gain machine-wide
privileges. Always match the management command to where the unit was created.

## Where definitions come from

```text
/usr/lib/systemd/system/       distribution/package units
/etc/systemd/system/           administrator units and overrides
~/.config/systemd/user/        per-user units
/run/systemd/transient/        runtime units from systemd-run
```

After adding or changing a unit file, make the manager reload definitions:

```bash
sudo systemctl daemon-reload
sudo systemctl restart example.service
```

`daemon-reload` does not restart the service. `restart` does not reload changed
unit files. They are separate actions.

For a package unit, add a drop-in instead of editing `/usr/lib`:

```bash
sudo systemctl edit ssh.service
systemctl cat ssh.service
systemd-delta
```

Package upgrades can replace `/usr/lib` files; `/etc` overrides remain local and
visible.

## The normal debugging loop

```bash
systemctl status example.service
journalctl -u example.service -b
systemctl cat example.service
systemctl show example.service -p ActiveState -p SubState -p Result
systemctl list-dependencies example.service
```

- `status` gives the short human view and recent logs.
- `journalctl` gives the full logs (`-f` follows new messages).
- `cat` shows the base unit plus drop-ins.
- `show` exposes exact properties and is better for scripts.
- `list-dependencies` helps explain why a unit was pulled in.

Before installing a new file:

```bash
systemd-analyze verify ./example.service
```

For boot timing:

```bash
systemd-analyze time
systemd-analyze critical-chain
```

## Details worth keeping in memory

- `Type=exec` reports failure when the executable itself cannot be started. It is
  a good default for a simple long-running process.
- `Restart=on-failure` fits daemons; it is usually wrong for a successful
  one-shot job.
- systemd tracks the whole unit cgroup, not only the first PID. Forked children
  remain part of the service.
- `DynamicUser=yes` creates a short-lived service identity without a permanent
  `/etc/passwd` account.
- systemd can supervise and limit processes, but it cannot make a buggy
  application correct. Logs and application-level health still matter.
