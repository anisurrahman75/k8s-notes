# 1 — Processes and `/proc`

## Problem and mental model

A program is bytes on disk; a process is one execution of those bytes with an identity, memory, threads, open files, credentials, and kernel state. Containers do not replace this model: the container's main application is visible to the host as a normal process.

Think of `/proc` as a live, permission-filtered window into kernel process state. It is not an ordinary stored filesystem. PID and mount namespaces can change which window a process sees.

## Important interfaces

- `/proc/<pid>/status`: state, parent, UIDs, thread count, capabilities, and namespace PID chain (`NSpid`).
- `cmdline`: NUL-separated arguments. It is not necessarily trustworthy; a process can change its visible arguments.
- `fd/`: descriptor symlinks. FD 0/1/2 conventionally mean stdin/stdout/stderr.
- `ns/`: namespace handles; equal `type:[inode]` values mean the same namespace of that type.
- `cgroup`: unified cgroup membership appears as `0::/path` on v2.
- `task/`: one directory per thread (TID).
- `environ`: potentially secret; avoid dumping it. Inspect only named, non-sensitive keys when justified.

Useful commands:

```bash
ps -eo pid,ppid,nlwp,stat,cmd --forest
pstree -aps <pid>
sed -n '1,35p' /proc/<pid>/status
tr '\0' ' ' </proc/<pid>/cmdline; echo
ls -l /proc/<pid>/fd /proc/<pid>/ns
cat /proc/<pid>/cgroup
kill -TERM <pid>                 # request graceful termination
```

Signals are asynchronous notifications. `SIGTERM` is catchable and asks for shutdown; `SIGKILL` is enforced by the kernel and cannot be handled. Threads share much of a process but have distinct TIDs; Linux accounts PIDs in cgroup `pids` controls as tasks/threads.

## Demonstration and expected observations

Run `../labs/01-process-inspection/run.sh`. It creates `sleep` with a signal trap, shows its parent relationship, descriptors, namespace IDs, and cgroup, then terminates only that child. Expect the host shell and child to share namespace IDs and usually a cgroup. `/proc` entries disappear after exit.

## Docker and Kubernetes

Docker asks a runtime to start the image command and records its host PID. Kubernetes asks a CRI runtime to start each container; kubelet later observes process/container status through CRI. A pod is not a process: it is a Kubernetes grouping whose containers usually share one network namespace and may share a PID namespace only when configured.

## Common mistakes

- Treating container PID 1 as invisible to the host; it merely has another PID in a nested PID namespace.
- equating one process with one thread.
- parsing `cmdline` as newline text or logging all of `environ`.
- sending `SIGKILL` before allowing graceful cleanup.
- assuming `/proc/<pid>` remains stable after the process exits; PIDs can eventually be reused.

## Review questions

1. Why can one executable have many processes?
2. How do PID and PPID describe ancestry?
3. Which files prove a process's namespace and cgroup membership?
4. Why may the same process have PID 1 inside and another PID outside?
5. What disappears from `/proc` when a process exits?

## Summary

The host kernel schedules container workloads as ordinary processes. `/proc` connects runtime abstractions to observable kernel facts.

