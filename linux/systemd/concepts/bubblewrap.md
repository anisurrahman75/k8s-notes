# Bubblewrap (`bwrap`)

Bubblewrap is a small tool for building a process sandbox from Linux namespaces
and mounts. You describe exactly which pieces of the host should appear inside
the sandbox, then bubblewrap runs one command in that constructed world.

The useful mental model is:

```text
bwrap starts with an empty temporary root
         + mounts I explicitly add
         + namespaces I explicitly unshare
         + the command I want to run
```

It is not a ready-made security policy. A careful argument list can create a
tight sandbox; a broad argument list can expose most of the host.

## First compare chroot, containers, and bwrap

- `chroot` changes the apparent root directory but does not by itself isolate
  processes, networking, users, or IPC.
- Bubblewrap combines a private mount tree with optional user, PID, network,
  IPC, UTS, and cgroup namespaces.
- An OCI container tool adds image management, lifecycle, networking, and a
  standard configuration format. Bubblewrap stays deliberately low-level.
- None of these is a virtual machine. The host kernel is still shared.

## Why the demo uses a static Go binary

A dynamically linked program usually needs an ELF loader and shared libraries.
For example, `/bin/bash` may need files under `/lib`, `/lib64`, and `/usr`.

The demo is built with:

```bash
CGO_ENABLED=0 go build ...
```

That produces a static binary, so the sandbox can stay very small:

```text
/
├─app/resource-burner   one read-only file from the host
├─dev/                  minimal device filesystem
├─proc/                 process view for the new PID namespace
└─tmp/                  empty writable tmpfs
```

No `/etc`, `/home`, `/usr`, or host root is mounted.

## Walk through the demo command

The script effectively runs:

```bash
bwrap \
  --unshare-all \
  --die-with-parent \
  --new-session \
  --clearenv \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --dir /app \
  --ro-bind ./bin/resource-burner /app/resource-burner \
  --chdir /tmp \
  /app/resource-burner -probe-path=/etc/passwd
```

Bubblewrap processes setup options and finally executes the last command.

### Namespace options

- `--unshare-all` requests separate user, IPC, PID, network, UTS, and cgroup
  namespaces where supported.
- The new PID namespace hides host processes. Bubblewrap also handles the PID 1
  responsibilities inside that namespace.
- The new network namespace does not share host interfaces. It is different
  from filtering selected destinations; there is simply no host network there.
- `--new-session` separates terminal session control from the parent session.

### Filesystem options

- `--proc /proc` mounts procfs for processes visible in the new PID namespace.
- `--dev /dev` creates a minimal device view instead of exposing host `/dev`.
- `--tmpfs /tmp` creates writable scratch space held in memory.
- `--dir /app` creates an empty directory in the new root.
- `--ro-bind SOURCE DEST` exposes one host path read-only.
- `--chdir /tmp` selects the command's starting directory.

### Lifetime and environment

- `--clearenv` removes inherited environment variables. This avoids leaking
  tokens or configuration, but also removes `PATH`, `HOME`, locale, and timezone
  settings unless you add them back with `--setenv`.
- `--die-with-parent` makes the sandbox die if the launching process disappears.
- Standard input, output, and error remain connected; isolation does not mean
  “no communication at all.”

## Prove the filesystem difference

Outside the sandbox:

```bash
cd linux/systemd/demo
./scripts/build.sh
./bin/resource-burner \
  -cpu-workers=0 -memory-mib=0 \
  -probe-path=/etc/passwd -duration=1ms
```

Expected: `readable=true`.

Inside the sandbox:

```bash
./scripts/run-bwrap.sh \
  -cpu-workers=0 -memory-mib=8 -duration=3s
```

Expected: `readable=false`, because `/etc` does not exist in the sandbox mount
namespace. The program reports only accessibility and byte count; it never
prints file content.

To expose only that one file, add:

```bash
--ro-bind /etc/passwd /etc/passwd
```

This is the core bubblewrap habit: grant the smallest mount that satisfies the
program instead of exposing an entire host directory.

## Read-only, writable, and empty paths

These three mount styles are easy to confuse:

```bash
--ro-bind /host/config /app/config    # host data visible, cannot be modified
--bind /host/output /app/output       # host data visible and writable
--tmpfs /app/cache                    # empty, writable, disappears on exit
```

A writable bind is a direct write channel to the host. Treat its source path as
part of the sandbox's security boundary.

For configuration, prefer `--ro-bind`. For disposable work, prefer `--tmpfs`.
Use `--bind` only for output that must survive after the sandbox exits.

## What about a normal dynamic program?

A teaching example can reuse host `/usr`:

```bash
bwrap --unshare-all \
  --ro-bind /usr /usr \
  --symlink usr/bin /bin \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  /bin/sh
```

The exact loader/library paths differ by distribution. This example also exposes
the whole host `/usr`, so it is much broader than the static Go sandbox. A
purpose-built root filesystem is easier to audit for a serious application.

Adding `--share-net` after `--unshare-all` deliberately keeps host networking:

```bash
bwrap --unshare-all --share-net ...
```

That may be required by an application, but it weakens isolation. Document why
every shared namespace or writable bind is needed.

## Capabilities and seccomp

Namespaces change what a process sees, but code inside a user namespace may
still have namespaced capabilities. Reduce them when they are unnecessary:

```bash
--cap-drop ALL
```

Bubblewrap can also accept a precompiled seccomp filter through a file
descriptor:

```bash
--seccomp FD
```

Bubblewrap does not invent the filter for you. Generating and maintaining the
syscall policy is a separate job, and the complete application must be tested.

## Add resource limits with systemd

Bubblewrap focuses on visibility and privilege boundaries. It does not set a
CPU or memory budget. Wrap it in a systemd scope:

```bash
cd linux/systemd/demo

systemd-run --user --scope --collect \
  --unit=isolated-burner \
  -p CPUQuota=25% \
  -p MemoryMax=64M \
  -p MemorySwapMax=0 \
  ./scripts/run-bwrap.sh \
  -cpu-workers=2 -memory-mib=32 -duration=10s
```

Now the layers are explicit:

```text
systemd/cgroup   CPU and memory budget
bubblewrap       mount, PID, network, IPC, UTS, user namespace setup
Unix/seccomp     remaining permissions and syscall policy
Go program       actual workload
```

## Common failures and unsafe shortcuts

### “No permissions to create new namespace”

The kernel, distribution, or outer container may disable unprivileged user
namespaces. Bubblewrap then fails before starting the command. Do not respond by
blindly running an untrusted command as root; understand the host policy first.

### Program says “No such file or directory,” but the file exists

For a dynamic executable, the missing object is often its ELF loader or a shared
library, not the executable itself:

```bash
file /path/to/program
ldd /path/to/program
```

Bind the required runtime deliberately or build/use a self-contained root.

### Binding the whole host root

```bash
--ro-bind / /
```

Read-only is not invisible. This exposes home directories, configuration,
metadata, and secrets for reading. It defeats the goal of the demo.

## Boundary checklist

Before trusting a bwrap command, ask:

1. Which host paths are visible?
2. Which of those paths are writable?
3. Is networking shared?
4. Which environment variables and file descriptors are inherited?
5. Which capabilities and syscalls remain?
6. What CPU, memory, and task limits exist outside bwrap?
7. Which kernel and LSM protections still apply?

The argument list is the policy. Audit the whole command, not merely the fact
that it uses `bwrap`.
