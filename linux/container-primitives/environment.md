# Environment report

Captured with read-only commands on 2026-08-05. Re-run the commands below if the host changes.

| Item | Finding |
|---|---|
| Distribution | Ubuntu 24.04.4 LTS (Noble) |
| Kernel | Linux 7.0.0-28-generic |
| Architecture | x86_64 |
| Cgroup mode | cgroup v2 (`cgroup2` mounted at `/sys/fs/cgroup`) |
| Controllers | `cpuset cpu io memory hugetlb pids rdma misc dmem` |
| OverlayFS | Available (`nodev overlay`) |
| Docker | Installed; client/server 29.6.2 |
| containerd / `ctr` | Installed |
| `runc` | Installed |
| `kubectl` | Installed |
| `crictl`, `nerdctl`, Podman | Not found |
| `systemd-run` / user manager | Installed / running |
| Wine | Installed |
| ShellCheck | Not found; validation uses `bash -n` |

The host can run the process and Docker labs. Namespace, OverlayFS, and manual-container labs still require explicit privilege even though kernel support exists. The MT5 lab can try a user transient scope, but the individual resource properties are verified at runtime because systemd delegation can differ by login session.

## Safe reproduction

```bash
uname -srm
sed -n '1,12p' /etc/os-release
findmnt -no FSTYPE,OPTIONS /sys/fs/cgroup
cat /sys/fs/cgroup/cgroup.controllers
grep -w overlay /proc/filesystems
command -v docker containerd runc kubectl crictl ctr nerdctl podman
docker version --format 'client={{.Client.Version}} server={{.Server.Version}}'
systemctl --user is-system-running
```

These commands do not enumerate environment variables, credentials, Kubernetes contexts, Docker configuration, or application data.

