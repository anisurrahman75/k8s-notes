# **cgroups v2**

> **Prerequisite:** [../1.namespaces/](../1.namespaces/README.md) — especially [what namespaces don't isolate](../1.namespaces/5.what-they-dont-isolate.md)

## **Files in this folder**

| # | File | Topic |
|---|------|-------|
| 1 | [1.v2-basics.md](1.v2-basics.md) | The unified hierarchy, controllers, `subtree_control` |
| 2 | [2.rootless-delegation.md](2.rootless-delegation.md) | Getting a cgroup you can write to, without sudo |
| 3 | [3.memory.md](3.memory.md) | `memory.max`, `memory.high`, OOM kills, `memory.events` |
| 4 | [4.cpu.md](4.cpu.md) | `cpu.max`, `cpu.weight`, throttling, PSI |
| 5 | [5.pids.md](5.pids.md) | `pids.max` and surviving a fork bomb |
| 6 | [6.cgroup-namespace.md](6.cgroup-namespace.md) | `unshare -C` — hiding your position in the tree |
| 7 | [7.systemd-and-k8s.md](7.systemd-and-k8s.md) | `systemd-run`, and how Kubernetes limits map to these files |

---

## **The Idea**

> Namespaces control **what a process can see**. cgroups control **how much it can use**.

A cgroup is a **directory** under `/sys/fs/cgroup`. You put PIDs in a file, you write limits to other files, and the kernel enforces them. That's it — the entire API is a filesystem.

```bash
stat -fc %T /sys/fs/cgroup
```

```
cgroup2fs
```

> If that prints `tmpfs`, you're on cgroup **v1** (or hybrid) and the paths in this folder won't match. v1 is legacy; everything here is v2.

---

## **Why you need both**

A fully namespaced process — own PID space, own filesystem, own hostname — can still consume every core and every byte of RAM on the host. It has no idea it's doing anything wrong, and nothing stops it.

```bash
unshare -Urpf --mount-proc bash -c 'timeout 5 bash -c "while :; do :; done"' &
uptime      # host load climbs
```

Namespaces are the *view*. cgroups are the *budget*. A container is both.

---

## **The whole API in five commands**

```bash
CG=/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/demo.slice

mkdir  $CG                       # 1. create a cgroup
echo 50M   > $CG/memory.max      # 2. set a limit
echo 20000 100000 > $CG/cpu.max  # 3. and another
echo $$    > $CG/cgroup.procs    # 4. move a process in
cat $CG/memory.current           # 5. observe
```

Everything else is detail.

---

## **What each controller gives you**

| Controller | Key knobs | Covered in |
| ---------- | --------- | ---------- |
| `memory` | `memory.max`, `memory.high`, `memory.swap.max` | [3.memory.md](3.memory.md) |
| `cpu` | `cpu.max`, `cpu.weight` | [4.cpu.md](4.cpu.md) |
| `pids` | `pids.max` | [5.pids.md](5.pids.md) |
| `io` | `io.max`, `io.weight` | (root only on most systems) |
| `cpuset` | `cpuset.cpus`, `cpuset.mems` | (root only) |

**Check what you can actually use:**

```bash
cat /sys/fs/cgroup/cgroup.controllers                                        # what the kernel has
cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers   # what you get
```

```
cpuset cpu io memory hugetlb pids rdma misc dmem
cpu memory pids
```

Three of them, delegated to your user session by systemd — enough for every demo here. See [2.rootless-delegation.md](2.rootless-delegation.md).

---

**Start here → [1.v2-basics.md](1.v2-basics.md)**
