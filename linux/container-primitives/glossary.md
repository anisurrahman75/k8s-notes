# Glossary

- **cgroup** — a hierarchical process grouping used to account for and control resources.
- **cgroup namespace** — virtualizes the cgroup path a process sees; distinct from applying limits.
- **copy-up** — OverlayFS copying a lower-layer object into the upper layer before modification.
- **CRI** — Kubernetes' gRPC contract between kubelet and a CRI implementation such as containerd's CRI plugin or CRI-O.
- **container** — a userspace/runtime concept; the kernel sees processes, namespaces, cgroups, mounts, capabilities, and related controls.
- **container engine** — user-facing management layer such as Docker Engine or Podman.
- **file descriptor (FD)** — a process-local integer referring to an open file, socket, pipe, or other kernel object.
- **image layer** — a read-only filesystem change set plus metadata; layers form an image root filesystem.
- **namespace** — a kernel mechanism that gives a process a scoped view of a global resource.
- **OCI** — open specifications for runtime bundles, images, and distribution; `runc` implements the Runtime Specification.
- **PID 1** — first process in a PID namespace; it has special signal and child-reaping responsibilities.
- **rootfs** — filesystem tree presented as `/` to a container process.
- **runtime bundle** — directory containing `config.json` and a root filesystem for an OCI runtime.
- **scope** — systemd unit for externally started processes; useful for transient cgroup limits.
- **upper/lower/merged/work** — writable layer, read-only inputs, unified view, and OverlayFS bookkeeping directory.
- **whiteout** — upper-layer marker hiding a lower-layer entry from the merged view.

