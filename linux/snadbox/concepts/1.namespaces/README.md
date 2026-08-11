# **Linux Namespaces — The Generic Concept**

> **Scope:** only what is true for **every** namespace type.
> Per-type depth lives in [../2.pid/](../2.pid/), [../3.mount/](../3.mount/), [../4.cgroup/](../4.cgroup/).
> **Everything runs as a normal user** — no `sudo`.

## **Files in this folder**

| # | File | Topic |
|---|------|-------|
| 1 | [1.syscalls-and-proc.md](1.syscalls-and-proc.md) | `clone`/`unshare`/`setns`, `/proc/PID/ns`, `lsns` |
| 2 | [2.user-namespace.md](2.user-namespace.md) | Why you don't need root — `uid_map` and fake root |
| 3 | [3.create-and-enter.md](3.create-and-enter.md) | `unshare` flags, first namespace, `nsenter` |
| 4 | [4.lifetime-and-nesting.md](4.lifetime-and-nesting.md) | When a namespace dies, pinning, nesting, ownership |
| 5 | [5.what-they-dont-isolate.md](5.what-they-dont-isolate.md) | The security limits — why cgroups and seccomp exist |

---

## **The One-Sentence Idea**

> A namespace **wraps a global kernel resource in an abstraction** so that processes inside it see their *own isolated instance* of that resource.

There is no such thing as "a container" in the kernel. A container is just:

```
a process
  + a set of namespaces   → what it can SEE      (this folder)
  + a cgroup              → what it can USE      (../4.cgroup/)
  + a root filesystem     → what files EXIST     (../3.mount/)
  + capabilities/seccomp  → what it can DO
```

Docker, containerd, runc and Kubernetes are orchestration on top of these primitives. In [../../demo/](../../demo/README.md) you build one by hand.

**Key mental model:** a namespace does **not** hide things by filtering. It hands the process a *different global table*. The host's hostname isn't hidden from a UTS namespace — the namespace has a **different hostname variable**. Nothing is scanned or denied; there is simply another copy.

---

## **The 8 Namespace Types**

| Namespace   | Flag (`clone`/`unshare`) | `unshare` opt | Isolates                                            | Since  |
| ----------- | ------------------------ | ------------- | --------------------------------------------------- | ------ |
| **Mount**   | `CLONE_NEWNS`            | `-m`          | Mount points / filesystem tree                      | 2.4.19 |
| **UTS**     | `CLONE_NEWUTS`           | `-u`          | Hostname & NIS domain name                          | 2.6.19 |
| **IPC**     | `CLONE_NEWIPC`           | `-i`          | System V IPC, POSIX message queues                  | 2.6.19 |
| **PID**     | `CLONE_NEWPID`           | `-p`          | Process ID number space                             | 2.6.24 |
| **Network** | `CLONE_NEWNET`           | `-n`          | NICs, IPs, routes, ports, iptables, sockets         | 2.6.29 |
| **User**    | `CLONE_NEWUSER`          | `-U`          | UID/GID mappings and **capabilities**               | 3.8    |
| **Cgroup**  | `CLONE_NEWCGROUP`        | `-C`          | Cgroup root directory (hides your position in tree) | 4.6    |
| **Time**    | `CLONE_NEWTIME`          | `-T`          | `CLOCK_MONOTONIC` / `CLOCK_BOOTTIME` offsets        | 5.6    |

> ⚠️ **UTS = "UNIX Time-Sharing System"**, not "time". Time isolation is the separate `time` namespace, and it only shifts monotonic/boot clocks — **never the wall clock**.

---

## **Check Your Kernel First**

Every demo in this folder assumes unprivileged user namespaces are enabled.

```bash
cat /proc/sys/user/max_user_namespaces      # must be > 0
sysctl kernel.unprivileged_userns_clone     # Debian/Ubuntu: must be 1
unshare -Ur id                              # smoke test
```

```
124998
kernel.unprivileged_userns_clone = 1
uid=0(root) gid=0(root) groups=0(root),65534(nogroup)
```

> ⚠️ If these are `0`, every rootless demo fails with `unshare: Operation not permitted`. Prefix commands with `sudo` and drop `-Ur` instead. Hardened distros and some cloud AMIs disable this because user namespaces have historically been a source of privilege-escalation CVEs.

---

**Start here → [1.syscalls-and-proc.md](1.syscalls-and-proc.md)**
