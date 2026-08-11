# **Mount Namespaces**

> **Prerequisite:** [../1.namespaces/](../1.namespaces/README.md)

## **Files in this folder**

| # | File | Topic |
|---|------|-------|
| 1 | [1.first-namespace.md](1.first-namespace.md) | Hands-on: your own mount table |
| 2 | [2.propagation.md](2.propagation.md) | shared / private / slave — the part that surprises everyone |
| 3 | [3.bind-mounts.md](3.bind-mounts.md) | Bind mounts, read-only binds, the 2-step remount |
| 4 | [4.overlayfs.md](4.overlayfs.md) | Layers — what a container image actually is |
| 5 | [5.rootfs.md](5.rootfs.md) | Build a real root filesystem from scratch |
| 6 | [6.pivot-root.md](6.pivot-root.md) | `chroot` vs `pivot_root`, and a complete filesystem sandbox |

---

## **The Idea**

> A mount namespace gives a process its **own copy of the mount table** — its own answer to "what filesystem is at path X?"

It was the **first** namespace Linux ever got (2.4.19, 2002), which is why its clone flag is the generic-sounding `CLONE_NEWNS`.

```
   HOST MOUNT NAMESPACE              SANDBOX MOUNT NAMESPACE
   /            ext4                 /            (its own rootfs)
   /home        ext4                 /proc        proc
   /proc        proc                 /tmp         tmpfs
   /sys         sysfs                (that's all)
   /run         tmpfs
   ... 68 mounts                     ... 3 mounts
```

Both tables describe the same disks. Neither can change the other.

---

## **Why it matters most**

A PID namespace without a mount namespace is half a sandbox — `ps` still reads the host's `/proc` ([../2.pid/3.mount-proc.md](../2.pid/3.mount-proc.md)). The mount namespace is what turns *"my own PID numbers"* into *"my own machine"*.

It is also where **the container image lives**. `docker run alpine` is, at the filesystem layer:

```
overlayfs(image layers + a writable layer)   →   pivot_root into it
```

Nothing more exotic than that, and you'll build it by hand in [4.overlayfs.md](4.overlayfs.md) and [6.pivot-root.md](6.pivot-root.md).

---

## **Quick smoke test**

```bash
findmnt | wc -l                          # host
unshare -Urm bash -c 'findmnt | wc -l'   # your own copy
```

```
68
66
```

You got a **copy** — not an empty table. That's the first thing that surprises people, and [2.propagation.md](2.propagation.md) explains what that copy is still connected to.

---

**Start here → [1.first-namespace.md](1.first-namespace.md)**
