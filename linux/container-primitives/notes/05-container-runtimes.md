# 5 — Container runtimes and OCI

## Problem and mental model

Namespaces and cgroups are kernel interfaces, but users need image management, lifecycle, logs, and stable APIs. The “runtime” label covers different layers, so reason from responsibilities rather than names.

```text
docker run
  → Docker CLI → Docker Engine → containerd → runc → Linux process

kubectl apply
  → API server/scheduler → kubelet → CRI implementation
  → OCI runtime (often runc) → Linux process
```

These are conceptual paths: shims, sandbox components, plugins, and implementation details sit between steps.

## Responsibilities and interfaces

| Layer | Examples | Responsibility |
|---|---|---|
| Container engine | Docker Engine, Podman | User API/UX, images, networks, volumes, lifecycle |
| High-level runtime | containerd, CRI-O | Image/snapshot/container lifecycle and supervision |
| Low-level OCI runtime | `runc`, `crun` | Consume an OCI bundle and create the namespaced/cgrouped process |
| Kubernetes CRI | containerd CRI plugin, CRI-O | Kubelet's runtime/image gRPC API |

Docker CLI is a client of the Engine API. containerd uses snapshotters and runtime shims; `runc` usually exits after creating the process, so it is not a long-lived container manager. CRI-O is designed around CRI. Podman is a daemonless user-facing engine. Kubelet is the node agent and CRI client, not an OCI runtime.

The OCI Image Specification describes image layout/config/layers; the Runtime Specification describes `config.json`, rootfs, process, mounts, namespaces, and resources in a runtime bundle. The Distribution Specification concerns registry transfer and is intentionally outside this course.

Useful read-only inspection:

```bash
docker info
docker version
ctr plugins ls
runc --version
systemctl status containerd docker
```

Socket access may be privileged. `runc spec` writes a sample config into the current directory, so use a disposable directory if exploring it.

## Small demonstration and observations

Run a Docker container, get its host PID, and compare `/proc/PID/ns` and cgroup files in Lab 05. The decisive output is a real host process whose isolation/resource values match engine metadata. Runtime processes and shims may also be visible in the ancestry.

## Docker and Kubernetes

Docker owns its UX and forwards lower-level lifecycle work to containerd. Kubernetes deliberately stops at CRI: kubelet does not require Docker and does not speak the Docker Engine API. A CRI runtime pulls/prepares images, establishes a pod sandbox, and invokes an OCI runtime to create container processes.

## Common mistakes

- saying Kubernetes “runs Docker” on every node.
- treating containerd and `runc` as interchangeable.
- assuming `runc` pulls images or provides networking.
- conflating OCI Image and Runtime specifications.
- treating the exact diagram as a forever-stable call stack instead of a responsibility map.

## Review questions

1. Which component turns an OCI bundle into a Linux process?
2. Why does `runc` not need to remain the container's parent manager?
3. What API connects kubelet to node runtime implementations?
4. What differs between OCI image and runtime specifications?
5. Which responsibilities belong to an engine rather than the kernel?

## Summary

Container tooling is a layered control path ending in ordinary Linux process creation. OCI standardizes artifacts and execution configuration; CRI standardizes kubelet's runtime boundary.

