# Resource burner lab

The program creates busy goroutines and gradually allocates memory that stays
live. It logs once per second and handles `SIGINT`/`SIGTERM` cleanly.

Requirements: Linux, Go 1.22+, systemd with a user manager, and bubblewrap for
the last exercise.

## 1. Build and run directly

```bash
./scripts/build.sh
./bin/resource-burner -cpu-workers=1 -memory-mib=64 -duration=5s
```

Useful flags:

```text
-cpu-workers N     busy goroutines; 0 disables CPU load
-memory-mib N      retained allocation; 0 disables memory load
-step-mib N        allocation step size
-step-every 250ms  delay between steps
-duration 10s      0 means run until SIGINT/SIGTERM
-probe-path PATH   report whether PATH can be read; never print its contents
```

## 2. Foreground transient scope

```bash
./scripts/run-scope.sh -duration=15s
```

In another terminal:

```bash
systemctl --user status resource-burner-demo.scope
systemctl --user show resource-burner-demo.scope \
  -p ControlGroup -p CPUUsageNSec -p MemoryCurrent -p MemoryPeak
systemd-cgtop --user
```

Try changing `CPUQuota` in `scripts/run-scope.sh`, then compare hash iterations
per second. `50%` means half of one logical CPU, even with two workers.

## 3. Background transient service

```bash
./scripts/run-transient-service.sh -duration=30s
journalctl --user -fu resource-burner-demo.service
systemctl --user stop resource-burner-demo.service
```

The script returns after queueing the service. `--collect` removes the transient
unit after it becomes inactive and is no longer referenced.

## 4. Persistent system service

Review `systemd/resource-burner.service` first. It runs under a dynamic user and
has both cgroup limits and service hardening.

```bash
./scripts/build.sh
sudo install -D -m 0755 ./bin/resource-burner \
  /usr/local/libexec/resource-burner
sudo install -D -m 0644 ./systemd/resource-burner.service \
  /etc/systemd/system/resource-burner.service
sudo install -D -m 0644 ./systemd/demo-workload.slice \
  /etc/systemd/system/demo-workload.slice

sudo systemctl daemon-reload
sudo systemctl enable --now resource-burner.service
systemctl status resource-burner.service
journalctl -fu resource-burner.service
```

Clean up when finished:

```bash
sudo systemctl disable --now resource-burner.service
sudo systemctl revert resource-burner.service  # removes drop-ins, if any
sudo unlink /etc/systemd/system/resource-burner.service
sudo unlink /etc/systemd/system/demo-workload.slice
sudo unlink /usr/local/libexec/resource-burner
sudo systemctl daemon-reload
```

`unlink` is intentionally explicit: check each path before running it.

## 5. Cause and inspect memory pressure

The script normally allocates 128 MiB under `MemoryMax=160M`. To see a hard
limit, request more:

```bash
./scripts/run-scope.sh -memory-mib=512 -duration=30s
```

Depending on overhead and OOM policy, the process may be killed. Inspect:

```bash
systemctl --user status resource-burner-demo.scope
journalctl --user -b --grep='resource-burner\|oom'
journalctl -k -b --grep='oom\|Killed process'
```

## 6. Empty-filesystem bubblewrap sandbox

```bash
./scripts/run-bwrap.sh -cpu-workers=0 -memory-mib=8 -duration=3s
```

Look for `probe path="/etc/passwd" readable=false`. The sandbox sees only the
static binary, minimal `/dev`, its own `/proc`, and an empty `/tmp`.

Combine filesystem isolation with a cgroup budget:

```bash
systemd-run --user --scope --collect \
  -p CPUQuota=25% -p MemoryMax=64M -p MemorySwapMax=0 \
  ./scripts/run-bwrap.sh -cpu-workers=2 -memory-mib=32 -duration=10s
```

If bubblewrap reports that it cannot create a namespace, the host or outer
container has disabled unprivileged user namespaces. That is a platform policy,
not a reason to run an unknown sandbox command as root.
