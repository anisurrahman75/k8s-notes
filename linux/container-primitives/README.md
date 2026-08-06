# Linux Container Primitives

This is a seven-session, hands-on course for engineers who use Docker or Kubernetes and want to see the Linux machinery underneath. The central idea is simple:

> A container is an ordinary Linux process given isolated views, resource controls, and a prepared filesystem.

## Start here

1. Read [environment.md](environment.md), then run `labs/01-process-inspection/run.sh`.
2. Work through `notes/01` to `notes/06` alongside the matching lab.
3. Use `notes/07-final-summary.md` and `cheatsheet.md` to consolidate the model.
4. Record progress and answers in [progress.md](progress.md).

| Session | Topic | Practical work | Privilege |
|---|---|---|---|
| 1 | Processes and `/proc` | Inspect a real process | None |
| 2 | Namespaces | Compare host and isolated views | `sudo` normally required |
| 3 | cgroups v2 | Inspect and limit a transient scope | User systemd manager |
| 4 | OverlayFS | See copy-up and whiteouts | `sudo mount` required |
| 5 | OCI and runtimes | Trace Docker/containerd/runc | Read-only |
| 6 | Docker and Kubernetes | Inspect a disposable Docker container | Docker access |
| 7 | Capstones | Wine/MT5 limits; manual container | User systemd; `sudo` for manual container |

## Safety contract

- Scripts use strict mode and resolve their own directories.
- Privileged labs print the exact action and require `--execute`; nothing silently elevates.
- Cleanup targets only resources created by a lab.
- Docker uses a unique name and `--rm`; Wine cleanup requires the exact scope name.
- No lab installs packages, changes persistent configuration, handles trading credentials, or runs a real trade.
- Expected output is described structurally because IDs, paths, and counters vary. Never paste credentials or complete process environments into study notes.

## Learning loop

For each session: predict what Linux will show, run the safe inspection, compare host and isolated views, connect the observation to Docker/Kubernetes, then answer the five review questions. The course intentionally omits advanced networking, cgroup v1, rootless internals, storage drivers other than OverlayFS, and deep LSM/seccomp policy design.

## Quick navigation

- [Host capability report](environment.md)
- [Glossary](glossary.md)
- [Progress tracker](progress.md)
- [Command cheatsheet](cheatsheet.md)
- [Validation report](validation-report.md)
- [`inspect-cgroup.sh`](inspect-cgroup.sh) — inspect the unified cgroup for any PID

