# Container internals cheatsheet

Replace `<pid>`, `<container>`, and `<scope>`; do not type angle brackets literally.

| Command | Use |
|---|---|
| `ps -eo pid,ppid,stat,cgroup,cmd --forest` | Process ancestry and cgroup membership |
| `pstree -aps <pid>` | Ancestors and arguments for one process |
| `lsns -p <pid>` | Namespace types and IDs for a process |
| `readlink /proc/<pid>/ns/*` | Compare namespace inode identities |
| `nsenter -t <pid> -a` | Enter target namespaces; usually requires privilege |
| `unshare --uts --pid --fork --mount-proc sh` | Start a shell with new UTS/PID views |
| `cat /proc/<pid>/status` | Identity, state, threads, capabilities, namespace PIDs |
| `tr '\0' ' ' </proc/<pid>/cmdline` | Render NUL-separated command line |
| `ls -l /proc/<pid>/fd` | Inspect open descriptors; permission-sensitive |
| `cat /proc/<pid>/cgroup` | Unified cgroup path (`0::/path`) |
| `./inspect-cgroup.sh <pid>` | Resolve and read important cgroup v2 controls |
| `systemd-cgls` | Show systemd's cgroup tree |
| `systemd-cgtop` | Live cgroup resource view |
| `findmnt -t overlay` | Show active OverlayFS mounts and options |
| `mount -t overlay overlay -o ... merged` | Create OverlayFS mount; requires approval/root |
| `docker inspect <container>` | Engine metadata including host PID and limits |
| `docker stats --no-stream <container>` | Runtime-level resource snapshot |
| `docker top <container>` | Processes in a container |
| `ctr plugins ls` | containerd plugins; socket access may require privilege |
| `runc spec` | Generate a sample OCI `config.json` in the current directory |
| `kubectl get pod -o wide` | Pod placement and status (uses current context) |
| `kubectl exec <pod> -- cat /proc/1/status` | Inspect the container view; requires cluster permission |

## Direct cgroup v2 recipe

```bash
pid=<pid>
rel=$(awk -F: '$1=="0" {print $3}' /proc/$pid/cgroup)
base=/sys/fs/cgroup$rel
cat "$base/cpu.max" "$base/cpu.weight" "$base/cpu.stat"
cat "$base/memory.current" "$base/memory.max" "$base/memory.events"
cat "$base/pids.current" "$base/pids.max"
```

`cpu.max` is `quota period` in microseconds or `max period`; `cpu.weight` is relative under contention. Counters are evidence: compare snapshots rather than reading one in isolation.

