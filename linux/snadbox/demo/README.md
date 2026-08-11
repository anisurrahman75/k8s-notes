# **Combined Demo — Build a Container by Hand**

> **PID namespace + mount namespace + cgroup v2 = a container.**
> Everything here runs **rootless**. No Docker, no daemon, no `sudo`.

## **Files**

| File | What it does |
| ---- | ------------ |
| [build-rootfs.sh](build-rootfs.sh) | Make a 2 MB busybox root filesystem |
| [minicontainer.sh](minicontainer.sh) | The container runtime — ~40 lines of shell |
| [inspect.sh](inspect.sh) | `docker inspect` + `kubectl describe`, by hand, from the host |

**Concepts behind each part:** [PID](../concepts/2.pid/) · [mount](../concepts/3.mount/) · [cgroup](../concepts/4.cgroup/)

---

## **Prerequisites**

```bash
stat -fc %T /sys/fs/cgroup                    # cgroup2fs
cat /proc/sys/user/max_user_namespaces        # > 0
command -v busybox unshare nsenter            # all present
cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers
```

```
cgroup2fs
124998
/usr/bin/busybox
/usr/bin/unshare
/usr/bin/nsenter
cpu memory pids
```

Missing busybox: `sudo apt install busybox-static`.

---

## **Run it**

```bash
cd demo
./build-rootfs.sh
```

```
==> building rootfs at /tmp/sandbox-rootfs
==> done
    applets : 273
    size    : 2.1M
    check   : busybox  (must be relative)
```

```bash
./minicontainer.sh -- /bin/whoami-really
```

```
┌─ minicontainer ─────────────────────────────────────
│ name     : mc-484132
│ rootfs   : /tmp/sandbox-rootfs
│ memory   : 64M          (memory.max, swap disabled)
│ cpu      : 25%           (cpu.max = 25000 100000)
│ pids     : 32            (pids.max)
│ cgroup   : /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/mc-484132
│ command  : /bin/whoami-really
└─────────────────────────────────────────────────────
pid            : 1
hostname       : sandbox
uid            : 0
root contains  : bin dev etc proc root sys tmp
mounts         : 9
visible procs  : 4
cgroup         : 0::/
```

**Read that output line by line — every value is a namespace or cgroup doing its job:**

| Line | Why | Concept |
| ---- | --- | ------- |
| `pid : 1` | PID namespace — our command is init | [2.pid/1](../concepts/2.pid/1.first-namespace.md) |
| `hostname : sandbox` | UTS namespace | [1.namespaces/3](../concepts/1.namespaces/3.create-and-enter.md) |
| `uid : 0` | user namespace — fake root, mapped to 1000 outside | [1.namespaces/2](../concepts/1.namespaces/2.user-namespace.md) |
| `root contains : bin dev etc …` | mount namespace + `pivot_root` | [3.mount/6](../concepts/3.mount/6.pivot-root.md) |
| `mounts : 9` | `/`, `/proc`, `/sys`, `/tmp` + 6 `/dev` nodes. The host has **68** | [3.mount/1](../concepts/3.mount/1.first-namespace.md) |
| `visible procs : 4` | the host has ~690 | [2.pid/3](../concepts/2.pid/3.mount-proc.md) |
| `cgroup : 0::/` | cgroup namespace hides the host's tree | [4.cgroup/6](../concepts/4.cgroup/6.cgroup-namespace.md) |

**Interactive:**

```bash
./minicontainer.sh
```

```
[sandbox] # ps
PID   USER     COMMAND
    1 root     /bin/sh
    5 root     ps
[sandbox] # hostname
sandbox
[sandbox] # ls /
bin  dev  etc  proc  root  sys  tmp
[sandbox] # exit
```

---

## **Prove each limit — three experiments**

### 1. Memory — the OOM killer fires

```bash
./minicontainer.sh -m 64M -- /bin/sh -c 'dd if=/dev/zero of=/tmp/big bs=1M count=200; echo "dd exit=$?"'
```

```
Killed
dd exit=137
```

**137 = 128 + 9 (SIGKILL)** — the exact exit code you see on a `kubectl describe pod` for an `OOMKilled` container. The `dd` wrote into `/tmp`, which is a **tmpfs**, so every byte was charged to `memory.max`. See [4.cgroup/3.memory.md](../concepts/4.cgroup/3.memory.md).

### 2. CPU — throttled, not killed

```bash
for pct in 100 50 25; do
  echo "--- ${pct}% ---"
  time ./minicontainer.sh -c $pct -- /bin/sh -c 'i=0; while [ $i -lt 3000000 ]; do i=$((i+1)); done' >/dev/null
done
```

```
--- 100% ---   real 3.818s   user 3.581s
--- 50%  ---   real 7.538s   user 3.648s
--- 25%  ---   real 15.403s  user 3.798s
```

**Identical CPU time, wall time doubling each step.** The work didn't change; the rate did. Halve the quota, double the duration — `cpu.max` is a hard bandwidth ceiling, enforced even though 15 of the 16 cores were idle. See [4.cgroup/4.cpu.md](../concepts/4.cgroup/4.cpu.md).

### 3. PIDs — the fork bomb that isn't

```bash
./minicontainer.sh -p 16 -- /bin/sh -c 'i=0; while [ $i -lt 50 ]; do sleep 5 & i=$((i+1)); done; echo spawned'
```

```
/bin/sh: can't fork: Resource temporarily unavailable
```

`fork()` returned `EAGAIN` at 16 tasks. Nothing was killed, the host never noticed. Try the same without a cgroup and you lock up the machine. See [4.cgroup/5.pids.md](../concepts/4.cgroup/5.pids.md).

---

## **Inspect it from the host**

Terminal 1:

```bash
./minicontainer.sh --name demo -c 25 -- /bin/sh -c 'i=0; while [ $i -lt 5000000 ]; do i=$((i+1)); done'
```

Terminal 2:

```bash
./inspect.sh mc-demo
```

```
── cgroup: mc-demo ──────────────────────────────────
  memory.max      67108864
  memory.current  385024
  cpu.max         25000 100000
  pids.max        32
  pids.current    2

── events (the receipts) ────────────────────────────
  cpu.stat:      nr_periods 30
  cpu.stat:      nr_throttled 30          ← throttled in EVERY period
  cpu.stat:      throttled_usec 2212548   ← 2.2 seconds spent frozen

── pressure (PSI — rises BEFORE things die) ─────────
  cpu    some avg10=2.17 avg60=0.39 avg300=0.08

── processes (host PID -> namespace PID) ────────────
  488777   unshare --user --map-root-user  NSpid: 488777      <- unshare wrapper (still on the host)
  488778   /bin/sh -c i=0; while [ $i -lt  NSpid: 488778 1    <- container PID 1

── namespaces of PID 488778 ─────────────────────────
  user    user:[4026536043]      ISOLATED
  mnt     mnt:[4026536051]       ISOLATED
  pid     pid:[4026536057]       ISOLATED
  uts     uts:[4026536052]       ISOLATED
  ipc     ipc:[4026536054]       ISOLATED
  net     net:[4026531833]       shared with host
  cgroup  cgroup:[4026536059]    ISOLATED

── its filesystem, read from the host ───────────────
  ls /proc/488778/root/
  bin dev etc proc root sys tmp
```

**Three things worth pausing on:**

1. **Two processes, and only one is inside.** The `unshare` wrapper stayed in the host PID namespace — exactly the `--fork` behaviour from [2.pid/2.fork-rule.md](../concepts/2.pid/2.fork-rule.md). Its `NSpid` has one column; the container's init has two.
2. **`net` is shared.** This sandbox has full host network access. That's a deliberate gap — see [What's missing](#whats-missing).
3. **`ls /proc/PID/root/` reads the container's files from the host** with no `nsenter` and no shell inside it. This is how you debug a distroless container.

**Walk in:**

```bash
nsenter -t 488778 -a --preserve-credentials -- /bin/sh     # full docker exec
nsenter -t 488778 -m -- ls /                               # borrow just the filesystem
nsenter -t 488778 -p -- ps aux                             # borrow just the process table
```

---

## **How it works — the whole thing in order**

```bash
# ── 1. cgroup: the budget ──────────────────────── concepts/4.cgroup/
CG=/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/mc-demo
mkdir -p $CG
echo 64M            > $CG/memory.max
echo 0              > $CG/memory.swap.max
echo "25000 100000" > $CG/cpu.max
echo 32             > $CG/pids.max

# ── 2. join it BEFORE unsharing ────────────────── (children inherit membership)
echo $BASHPID > $CG/cgroup.procs

# ── 3. namespaces: the view ────────────────────── concepts/1.namespaces/
exec unshare --user --map-root-user \      # fake root -> everything below is rootless
             --mount --pid --fork \        # -p ALWAYS with -f
             --uts --ipc --cgroup \
             --propagation private \       # never leak our mounts to the host
  bash -c '
      hostname sandbox

      # ── 4. filesystem: the root ───────────────── concepts/3.mount/
      mount --bind $ROOTFS $ROOTFS         # pivot_root needs a MOUNT POINT
      cd $ROOTFS
      mkdir -p oldroot
      pivot_root . oldroot

      # host bash cannot exec any more — its libraries are gone.
      # Hand over to the STATIC busybox inside the new root.
      exec /bin/busybox sh -c "
          export PATH=/bin
          mount -t proc  proc  /proc       # ps/top must see OUR pids
          mount -t tmpfs tmpfs /tmp
          for d in null zero full random urandom tty; do
              mount --bind /oldroot/dev/\$d /dev/\$d
          done
          umount -l /oldroot               # cut the last link to the host
          exec \"\$@\"
      " -- "$@"
  '
```

**Nine steps. Everything else Docker does is packaging, images, and networking.**

---

## **Ordering rules you cannot break**

| # | Rule | If you get it wrong |
| - | ---- | ------------------- |
| 1 | Join the cgroup **before** `unshare -C` | the sandbox sees the host's cgroup path |
| 2 | `-p` **always** with `-f` | `unshare: mount /proc failed: Operation not permitted` |
| 3 | `mount --bind $ROOTFS $ROOTFS` before `pivot_root` | `pivot_root: … Invalid argument` |
| 4 | `mkdir oldroot` before `pivot_root` | `pivot_root: … No such file or directory` |
| 5 | `exec` a **static** binary after pivoting | `sh: mount: not found` for every command |
| 6 | Bind `/dev` nodes **before** `umount /oldroot` | `dd: can't open '/dev/zero'` |
| 7 | Use **relative** busybox symlinks | every applet breaks after the pivot |
| 8 | `umount -l` (lazy) the old root | `umount: /oldroot: target is busy` |

Every one of these was hit while writing this demo. They are the real content.

---

## **What's missing (deliberately)**

This is a teaching sandbox, not a runtime. Compared with `runc`:

| Missing | Why it matters | Where to add it |
| ------- | -------------- | --------------- |
| **Network namespace** | the sandbox has full host network | `unshare -n` + `veth` pair (needs root) |
| **seccomp** | ~350 syscalls reachable | `libseccomp` / `bwrap --seccomp` |
| **Capability dropping** | fake root keeps a full set inside the userns | `capsh --drop=...` |
| **`io` cgroup limits** | disk IO is unbounded | not delegated to users by default |
| **Read-only rootfs** | the sandbox can modify its own image | `mount -o remount,ro /` after pivot |
| **A real init** | no signal forwarding, no reaping | `tini` — [2.pid/5.reaping.md](../concepts/2.pid/5.reaping.md) |
| **OCI images** | busybox only | `docker export` — [3.mount/5.rootfs.md](../concepts/3.mount/5.rootfs.md) |

**Compare against a real hardened sandbox** — `bubblewrap` does all of it:

```bash
bwrap --ro-bind /tmp/sandbox-rootfs / --dev /dev --proc /proc \
      --unshare-all --die-with-parent /bin/busybox sh
```

---

## **Cleanup**

`minicontainer.sh` cleans its own cgroup on exit (`trap … EXIT`). If a run was killed hard:

```bash
CGROOT=/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service
for cg in $CGROOT/mc-*; do
  [ -d "$cg" ] || continue
  echo 1 > "$cg/cgroup.kill" 2>/dev/null
  rmdir "$cg" 2>/dev/null && echo "removed $cg"
done

rm -rf /tmp/sandbox-rootfs
```

---

## **Exercises**

1. **Break each rule above on purpose** and read the error. That's the fastest way to make them stick.
2. Run `./minicontainer.sh` in one terminal and `watch -n1 ./inspect.sh` in another while you stress it.
3. Swap the busybox rootfs for a real one: `docker create alpine | xargs docker export | tar -C /tmp/alpine -xf -` then `./minicontainer.sh -r /tmp/alpine -- /bin/sh`.
4. Add `--unshare-net` support and give the sandbox a `veth` pair ([1.namespaces/3](../concepts/1.namespaces/3.create-and-enter.md)).
5. Set `memory.high` to 80% of `memory.max` and watch `memory.events` under load — throttling instead of killing.
6. Add `tini` as PID 1 and confirm `SIGTERM` now reaches your process ([2.pid/4](../concepts/2.pid/4.pid1-semantics.md)).

---

← back to [concepts](../concepts/)
