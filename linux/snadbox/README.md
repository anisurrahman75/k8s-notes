# **Linux Sandboxing — Namespaces, PID, Mount, cgroups**

> **Author:** Anisur Rahman
> **Goal:** understand what a container actually *is* by building one by hand.
> **Everything here runs rootless** on a modern kernel — no Docker, no daemon, no `sudo`.

---

## **The claim**

There is no "container" object in the Linux kernel. A container is an ordinary process with four things attached:

```
a process
  + namespaces   → what it can SEE      concepts/1.namespaces, 2.pid, 3.mount
  + a cgroup     → what it can USE      concepts/4.cgroup
  + a rootfs     → what files EXIST     concepts/3.mount
  + seccomp/caps → what it can DO       (out of scope here)
```

Docker, containerd, runc and Kubernetes are orchestration on top of those primitives. By the end of [demo/](demo/README.md) you will have built a working one in ~40 lines of shell.

---

## **Structure**

```
snadbox/
├── concepts/
│   ├── 1.namespaces/   the generic mechanism — true for every namespace type
│   ├── 2.pid/          process isolation, PID 1, reaping
│   ├── 3.mount/        filesystem isolation, overlayfs, pivot_root
│   └── 4.cgroup/       resource limits — cgroup v2
└── demo/               PID + mount + cgroup, combined into a container
```

Each page is **concept first, then a runnable demo with its real output.** Every command and every output block in this folder was executed on kernel 6.17 and pasted back verbatim.

---

## **Reading order**

| | Folder | Read this for |
| - | ------ | ------------- |
| 1 | **[concepts/1.namespaces/](concepts/1.namespaces/README.md)** | the mechanism: `clone`/`unshare`/`setns`, `/proc/PID/ns`, user namespaces, what namespaces *don't* isolate |
| 2 | **[concepts/2.pid/](concepts/2.pid/README.md)** | PID 1 semantics, the `--fork` rule, zombie reaping, host↔container PID mapping |
| 3 | **[concepts/3.mount/](concepts/3.mount/README.md)** | mount propagation, bind mounts, overlayfs (= container images), `pivot_root` |
| 4 | **[concepts/4.cgroup/](concepts/4.cgroup/README.md)** | memory/CPU/PID limits, OOM kills, throttling, how k8s limits map to files |
| 5 | **[demo/](demo/README.md)** | **put it together — build and inspect a container** |

Short on time? Read the four folder `README.md` files, then go straight to [demo/](demo/README.md).

---

## **Check your machine first**

```bash
stat -fc %T /sys/fs/cgroup                    # cgroup2fs  (v2 required)
cat /proc/sys/user/max_user_namespaces        # > 0
sysctl kernel.unprivileged_userns_clone       # 1 on Debian/Ubuntu
unshare -Ur id                                # uid=0(root) — smoke test
command -v busybox unshare nsenter lsns findmnt
```

```
cgroup2fs
124998
kernel.unprivileged_userns_clone = 1
uid=0(root) gid=0(root) groups=0(root),65534(nogroup)
```

**If unprivileged user namespaces are disabled**, drop `-Ur` from every command and prefix with `sudo` — the kernel behaviour is identical, only the way you obtain the capability changes.

**Install what's missing:**

```bash
sudo apt install busybox-static util-linux bubblewrap
```

---

## **The 60-second version**

```bash
# see your namespaces
ls -l /proc/self/ns/

# a container-ish shell
unshare -Ur --fork --uts --ipc --pid --mount --net --mount-proc bash
  hostname sandbox && hostname     # own UTS
  echo $$                          # 1 — own PID namespace
  ps ax | wc -l                    # 5, not 690
  ip link                          # only a down loopback
  exit

# a resource budget
CG=/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/demo.slice
mkdir -p $CG
echo 50M > $CG/memory.max
echo "20000 100000" > $CG/cpu.max      # 20% of one core
echo $$ > $CG/cgroup.procs             # this shell is now limited
```

Namespaces gave the view. cgroups gave the budget. [demo/](demo/README.md) welds them together and adds a root filesystem.

---

## **The one-paragraph summary of each topic**

**Namespaces** wrap a global kernel resource so a process sees its own instance of it. Eight types; the **user** namespace is the enabler that lets an unprivileged user create all the others. Identity is the inode in `/proc/PID/ns/<type>` — same inode, same namespace. They isolate *visibility* only.

**PID namespaces** give a process tree its own numbering from 1. PID 1 is special: unhandled signals are discarded, orphans reparent to it, and its death kills the namespace. `-p` needs `-f` because a running process can never change its own PID namespace, and `--mount-proc` because `ps` reads `/proc`, not the kernel.

**Mount namespaces** give a private mount table — but a *connected* copy, governed by propagation (shared/private/slave). Container images are **overlayfs** stacks; the writable layer is `upperdir`. `pivot_root` (never `chroot`) swaps the root and lets you detach the host tree entirely.

**cgroups v2** are a filesystem: `mkdir` a directory, write limits to files, write PIDs to `cgroup.procs`. `memory.max` kills, `memory.high` throttles, `cpu.max` is a hard ceiling even on an idle machine, `cpu.weight` only matters under contention, `pids.max` is your fork-bomb insurance. Every Kubernetes `resources:` field is one of these files.

---

## **Cross-references worth remembering**

| Symptom you'll meet at work | Root cause | Page |
| --------------------------- | ---------- | ---- |
| Pod ignores `SIGTERM`, dies after 30 s | PID 1 has no signal handler | [2.pid/4](concepts/2.pid/4.pid1-semantics.md) |
| Container slowly runs out of processes | zombies, non-reaping PID 1 | [2.pid/5](concepts/2.pid/5.reaping.md) |
| Exit code 137, `OOMKilled` | `memory.max` | [4.cgroup/3](concepts/4.cgroup/3.memory.md) |
| Slow pod, low CPU usage | `cpu.max` throttling | [4.cgroup/4](concepts/4.cgroup/4.cpu.md) |
| Host mounts don't appear in the container | mount propagation | [3.mount/2](concepts/3.mount/2.propagation.md) |
| `readOnly: true` mount is writable | one-step `ro` bind | [3.mount/3](concepts/3.mount/3.bind-mounts.md) |
| `RUN rm secret` didn't remove the secret | overlayfs whiteout | [3.mount/4](concepts/3.mount/4.overlayfs.md) |
| Can't debug a distroless container | use `nsenter` / `/proc/PID/root` | [2.pid/6](concepts/2.pid/6.debugging.md) |

---

## **References**

* `man 7 namespaces`, `man 7 user_namespaces`, `man 7 pid_namespaces`, `man 7 mount_namespaces`, `man 7 cgroups`
* `man 2 unshare`, `man 2 setns`, `man 2 clone`, `man 2 pivot_root`
* Kernel docs: `Documentation/admin-guide/cgroup-v2.rst` — the authoritative cgroup v2 reference
* `Documentation/filesystems/sharedsubtree.rst` — mount propagation, the definitive explanation
* OCI Runtime Specification — what `runc` is contractually required to set up
