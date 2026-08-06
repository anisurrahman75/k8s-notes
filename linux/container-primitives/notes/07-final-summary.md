# 7 — Final synthesis

## The complete mental model

There is no single Linux “create container” syscall. A runtime prepares a root filesystem, configures mounts and credentials, selects namespaces, places a process in cgroups, applies capabilities/seccomp/LSM policy, and executes the requested program. The kernel schedules that program as a process.

```text
image layers → runtime snapshot/rootfs → mount namespace
                                      ↘ process ↔ /proc
runtime config → namespaces + cgroups ↗
Docker/Kubernetes → lifecycle around that process
```

Namespaces isolate views. Mounts/rootfs provide filesystem perspective. Cgroups account and control the complete process tree. OverlayFS efficiently composes immutable and writable filesystem changes. OCI defines portable image/runtime contracts. Engines and Kubernetes reconcile lifecycle around these primitives.

## Proof checklist

Given a containerized workload, you should now be able to:

1. Find its host PID and process ancestry.
2. Compare `/proc/PID/ns/*` identities with the host.
3. Resolve `0::/path` to `/sys/fs/cgroup/path`.
4. distinguish `cpu.max` (hard bandwidth) from `cpu.weight` (contention preference).
5. compare `memory.current` with `memory.high`/`memory.max` and inspect OOM counters.
6. find OverlayFS mount options and explain copy-up/whiteouts.
7. place Docker, containerd, CRI, and `runc` at the right responsibility layers.
8. explain how kubelet ultimately causes a Linux process to exist.

## What the manual demo omits

The capstone is deliberately not a runtime. It lacks robust user/capability handling, seccomp and LSM policy, pivot-root hardening, safe device setup, masked paths, networking/CNI, image verification/unpacking, logs, lifecycle supervision, exec/attach, checkpointing, and race-resistant cleanup. Namespaces alone are not a production security boundary.

## Common mistakes to retire

- “A container is a lightweight VM.” It shares the host kernel.
- “A namespace limits resources.” Cgroups do.
- “CPU weight is a cap.” It only arbitrates contention.
- “Deleting an image-layer file edits the layer.” A whiteout hides it.
- “Kubernetes creates namespaces directly.” Kubelet delegates execution through CRI/runtime layers.

## Final review questions

1. Build a one-sentence definition of a container without using “Docker.”
2. What evidence distinguishes two processes' views and resource groups?
3. Why must a multi-process application be constrained as a complete cgroup?
4. How does an immutable image become writable without changing its layers?
5. Trace `kubectl apply` to a scheduled Linux process and name each contract boundary.

## Summary

The durable debugging move is to cross abstraction boundaries: start with Docker or Kubernetes state, resolve the host process, then verify namespaces, cgroups, and mounts directly. Runtime claims become concrete kernel evidence.

