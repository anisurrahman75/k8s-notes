# Codex Task: Create a Short Linux Container Internals Course

## Goal

Create a short, practical course in the current directory that teaches me the essential Linux concepts behind containers.

I am a backend/Kubernetes engineer. I want to understand how containers work internally without studying every advanced kernel feature.

Keep the course focused, practical, and completable in approximately **5–7 study sessions**.

Do not only explain concepts in chat. Create all notes, scripts, and demos inside the current directory.

---

## What I Want to Learn

Focus only on these core concepts:

1. Linux processes and `/proc`
2. Linux namespaces
3. Linux cgroups v2
4. OverlayFS and container image layers
5. Container runtimes and the OCI model
6. How Docker and Kubernetes use these concepts
7. A small manual-container demonstration

Do not go deeply into:

- SELinux
- AppArmor
- advanced seccomp policies
- rootless container internals
- cgroup v1
- complex mount propagation
- advanced container networking
- container image distribution protocols
- storage drivers other than OverlayFS

Mention these topics briefly only when needed.

---

## Safety Rules

1. Work only inside the current directory.
2. Do not modify unrelated files.
3. Do not run destructive commands.
4. Do not make permanent host changes.
5. Read-only inspection commands may be run automatically.
6. Ask before running commands requiring:
   - `sudo`
   - mounts
   - network namespace changes
   - cgroup changes
   - package installation
7. Every privileged demo must include cleanup instructions.
8. Never fabricate command output.
9. Detect the current host environment before creating host-specific commands.

---

## First Step: Inspect the Environment

Create:

```text
environment.md
```

Inspect and document:

- Linux distribution
- Kernel version
- CPU architecture
- cgroup version
- Available cgroup v2 controllers
- Whether OverlayFS is available
- Whether Docker is installed
- Whether containerd is installed
- Whether `runc` is installed
- Whether `kubectl`, `crictl`, `ctr`, and `nerdctl` are installed

Use safe commands only.

Do not expose secrets, credentials, tokens, private keys, or unrelated environment variables.

---

## Required Directory Structure

Create this structure:

```text
.
├── README.md
├── environment.md
├── progress.md
├── glossary.md
├── notes/
│   ├── 01-processes-and-proc.md
│   ├── 02-linux-namespaces.md
│   ├── 03-cgroups-v2.md
│   ├── 04-overlayfs-and-image-layers.md
│   ├── 05-container-runtimes.md
│   ├── 06-docker-and-kubernetes.md
│   └── 07-final-summary.md
├── labs/
│   ├── 01-process-inspection/
│   │   ├── README.md
│   │   └── run.sh
│   ├── 02-namespace-demo/
│   │   ├── README.md
│   │   ├── run.sh
│   │   └── cleanup.sh
│   ├── 03-cgroup-v2-demo/
│   │   ├── README.md
│   │   ├── run.sh
│   │   └── cleanup.sh
│   ├── 04-overlayfs-demo/
│   │   ├── README.md
│   │   ├── run.sh
│   │   └── cleanup.sh
│   ├── 05-docker-inspection/
│   │   ├── README.md
│   │   ├── run.sh
│   │   └── cleanup.sh
│   ├── 06-wine-mt5-resource-limit/
│   │   ├── README.md
│   │   ├── run.sh
│   │   ├── inspect.sh
│   │   └── cleanup.sh
│   └── 07-manual-container/
│       ├── README.md
│       ├── run.sh
│       └── cleanup.sh
└── cheatsheet.md
```

Keep the repository small and easy to navigate.

---

## Note Format

Each note should contain:

1. What problem this concept solves
2. A simple mental model
3. Important Linux files or interfaces
4. Useful inspection commands
5. A small demonstration
6. Expected observations
7. How Docker uses it
8. How Kubernetes uses it
9. Common mistakes
10. Five review questions
11. A short summary

Start with simple explanations, then add technical details.

Avoid unnecessary theory.

---

# Course Modules

## Module 1: Processes and `/proc`

Teach:

- Program vs process
- PID and PPID
- Process tree
- Threads
- File descriptors
- Signals
- Process environment
- `/proc/<pid>/status`
- `/proc/<pid>/cmdline`
- `/proc/<pid>/fd`
- `/proc/<pid>/ns`
- `/proc/<pid>/cgroup`

Main idea:

> A container is still a normal Linux process.

The lab should start a normal process and inspect it from `/proc`.

---

## Module 2: Linux Namespaces

Teach only the important namespaces:

- PID
- Mount
- Network
- UTS
- IPC
- User

For each namespace explain:

- What it isolates
- How to inspect it using `/proc/<pid>/ns`
- How `lsns` works
- How `nsenter` works
- How `unshare` works

The lab should demonstrate:

- Creating a UTS namespace
- Changing the hostname inside it
- Creating a PID namespace
- Showing different PID views
- Comparing namespace IDs from the host and isolated process

Do not build complex networking in this course.

---

## Module 3: cgroups v2

This is a priority module.

Teach:

- What cgroups solve
- cgroup v2 hierarchy
- `cgroup.controllers`
- `cgroup.subtree_control`
- `cgroup.procs`
- `cpu.max`
- `cpu.weight`
- `cpu.stat`
- `memory.max`
- `memory.current`
- `memory.events`
- `pids.max`
- `pids.current`
- systemd slices and scopes
- CPU quota vs CPU weight
- Memory limit vs memory usage
- CPU throttling
- OOM behavior

The course must answer:

- How do I find the cgroup of a process?
- How do I find the cgroup of a Docker container?
- How do I inspect CPU quota?
- How do I inspect CPU weight?
- How do I inspect memory limits?
- How do I inspect current memory usage?
- How do I check CPU throttling?
- How do Docker CPU and memory options map to cgroup v2 files?

Create a helper script:

```text
inspect-cgroup.sh
```

It should accept a PID and show:

- cgroup path
- CPU quota
- CPU weight
- CPU statistics
- memory limit
- current memory
- memory events
- PID limit
- current PID count

Handle the value `max` correctly.

---

## Module 4: OverlayFS and Image Layers

Teach:

- Union filesystem
- Lower directory
- Upper directory
- Work directory
- Merged directory
- Copy-on-write
- Whiteouts
- Read-only image layers
- Writable container layer

The lab should demonstrate:

1. Reading a lower-layer file
2. Editing a lower-layer file
3. Creating a new file
4. Deleting a lower-layer file
5. Inspecting changes in the upper directory
6. Cleaning up mounts and temporary files

Explain how this maps to Docker image layers and a container's writable layer.

---

## Module 5: Container Runtimes

Teach the responsibilities of:

- Docker CLI
- Docker Engine
- containerd
- `runc`
- CRI-O
- Podman
- kubelet
- CRI
- OCI Runtime Specification
- OCI Image Specification

Keep this module architectural rather than exhaustive.

Clearly explain:

```text
docker run
    -> Docker Engine
    -> containerd
    -> runc
    -> Linux process
```

And:

```text
kubectl apply
    -> Kubernetes API
    -> kubelet
    -> CRI runtime
    -> OCI runtime
    -> Linux process
```

Explain the difference between:

- container engine
- high-level runtime
- low-level OCI runtime
- Kubernetes CRI

---

## Module 6: Docker and Kubernetes Mapping

Create a table mapping concepts:

| Linux concept | Docker usage | Kubernetes usage |
|---|---|---|
| PID namespace | Container process isolation | Pod/container process isolation |
| Network namespace | Container networking | Pod networking |
| Mount namespace | Container root filesystem | Pod volumes and container filesystem |
| cgroups | Container resource limits | Pod/container requests and limits |
| OverlayFS | Image and writable layers | Runtime image filesystem |
| OCI runtime | Starts container process | Runtime starts pod containers |

Docker lab:

1. Start a disposable container.
2. Find its host PID.
3. Inspect `/proc/<pid>/ns`.
4. Inspect `/proc/<pid>/cgroup`.
5. Read cgroup v2 CPU and memory files directly.
6. Compare with `docker inspect` and `docker stats`.
7. Stop and remove the container.

When Docker is unavailable, create the lab without executing it.

Kubernetes should be explained conceptually. Only add a small optional inspection section if a local cluster and permissions are available.

---

## Practical Lab: Run Wine + MetaTrader 5 with Resource Limits

Create a focused lab at:

```text
labs/06-wine-mt5-resource-limit/
```

The purpose of this lab is to show how cgroup v2 can constrain a real multi-process desktop application:

```text
Wine + MetaTrader 5
```

Do not install Wine or MetaTrader 5 automatically. Detect whether they are already available and document installation prerequisites separately.

The lab must support a configurable MT5 executable path, for example:

```bash
MT5_EXE="$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
```

Do not hardcode the user's home directory or Wine prefix.

Support environment variables such as:

```bash
WINEPREFIX
MT5_EXE
CPU_QUOTA
CPU_WEIGHT
MEMORY_MAX
MEMORY_HIGH
PIDS_MAX
```

Use safe defaults suitable for a demonstration, such as:

```text
CPU_QUOTA=100%
CPU_WEIGHT=100
MEMORY_HIGH=1G
MEMORY_MAX=1500M
PIDS_MAX=128
```

Clearly explain that:

- `CPUQuota=100%` means approximately one full CPU core of CPU time, not 100% of the entire host.
- CPU quota is a hard bandwidth limit.
- CPU weight affects relative scheduling only when CPU contention exists.
- `MemoryHigh` causes reclaim pressure and throttling behavior.
- `MemoryMax` is the hard memory limit.
- Exceeding `MemoryMax` may trigger a cgroup OOM kill.
- `TasksMax` limits the number of processes and threads in the scope.
- Wine may launch `wineserver`, helper processes, and MT5 child processes.
- Limiting only one PID is insufficient if related Wine processes escape into another cgroup.
- A dedicated `WINEPREFIX` is recommended for each independently limited MT5 instance.

### Preferred Implementation

Prefer a transient systemd scope on cgroup v2 hosts:

```bash
systemd-run --user --scope \
  --unit=mt5-lab \
  -p CPUQuota=100% \
  -p CPUWeight=100 \
  -p MemoryHigh=1G \
  -p MemoryMax=1500M \
  -p TasksMax=128 \
  wine "$MT5_EXE"
```

However, verify whether the user systemd manager supports the requested properties.

When the user manager cannot apply the limits, document and provide a system-level alternative that requires approval:

```bash
sudo systemd-run --scope \
  --unit=mt5-lab \
  -p User="$(id -un)" \
  -p CPUQuota=100% \
  -p CPUWeight=100 \
  -p MemoryHigh=1G \
  -p MemoryMax=1500M \
  -p TasksMax=128 \
  wine "$MT5_EXE"
```

Do not execute the `sudo` alternative automatically.

Also explain the direct cgroup v2 approach conceptually, but do not make it the default because delegation and permissions vary by systemd configuration.

### `run.sh`

Create `run.sh` that:

1. Verifies the host is using cgroup v2.
2. Verifies that `systemd-run` and `wine` are installed.
3. Resolves `WINEPREFIX` and `MT5_EXE`.
4. Verifies that the MT5 executable exists.
5. Creates a unique transient scope name.
6. Starts Wine + MT5 with configurable resource limits.
7. Prints the scope name and commands needed to inspect it.
8. Does not silently fall back to `sudo`.
9. Prints a clear error when the user systemd manager cannot apply the requested limits.
10. Avoids exposing account credentials or MT5 configuration data.

Use the exec form where practical and correctly quote paths containing spaces.

### `inspect.sh`

Create `inspect.sh` that accepts the systemd scope name and displays:

```bash
systemctl --user status <scope>
systemctl --user show <scope>
systemd-cgls --user-unit <scope>
```

Also resolve the scope's cgroup path and inspect these cgroup v2 files when present:

```text
cpu.max
cpu.weight
cpu.stat
memory.current
memory.high
memory.max
memory.events
memory.stat
pids.current
pids.max
cgroup.procs
cgroup.threads
```

The script must:

- handle `max` values;
- show process IDs and command names;
- show the Wine and MT5 process tree;
- explain `nr_periods`, `nr_throttled`, and `throttled_usec`;
- identify whether an OOM event occurred;
- calculate memory values in human-readable form;
- avoid assuming the exact systemd cgroup path.

Include commands to observe the scope continuously, such as:

```bash
systemd-cgtop
watch -n 1 ./inspect.sh <scope>
```

### Process-Tree Verification

The lab must explicitly verify whether these processes are in the same cgroup:

- `terminal64.exe`
- the Wine loader
- `wineserver`
- Wine helper processes
- MT5 child processes or Expert Advisor-related processes, when visible

Explain that an existing shared `wineserver` may belong to a previously started Wine prefix or scope.

For reliable isolation, the lab should recommend:

1. Use a dedicated `WINEPREFIX`.
2. Ensure no Wine process is already running for that prefix.
3. Start the complete Wine environment from inside the resource-limited scope.
4. Confirm all related PIDs have the expected `/proc/<pid>/cgroup` path.

Include inspection commands such as:

```bash
pgrep -a -f 'wine|wineserver|terminal64.exe'
cat /proc/<pid>/cgroup
ps -eo pid,ppid,cgroup,cmd --forest
```

Do not kill unrelated Wine processes.

### Controlled Tests

Document optional, careful tests:

1. **CPU test**
   - Observe normal MT5 usage.
   - Compare `cpu.stat` before and after activity.
   - Detect throttling.
   - Do not run an uncontrolled stress workload on the host.

2. **Memory test**
   - Observe `memory.current`.
   - Explain how to lower the limit only for a disposable test prefix.
   - Warn that an overly low `MemoryMax` may terminate MT5 and risk unsaved application state.
   - Never intentionally trigger an OOM against a real trading account or production terminal.

3. **Multiple MT5 instances**
   - Show conceptually how each instance can use a separate `WINEPREFIX` and systemd scope.
   - Give each scope independent CPU, memory, and PID limits.
   - Do not claim that cgroups provide application-level or account-level security isolation.

### `cleanup.sh`

Create `cleanup.sh` that:

1. Accepts the exact scope name.
2. Stops only that scope.
3. Attempts graceful termination first.
4. Uses stronger termination only after clearly warning the user.
5. Does not run `wineserver -k` globally.
6. Never kills Wine processes belonging to other prefixes or scopes.
7. Leaves the Wine prefix and MT5 files intact unless a disposable lab prefix was explicitly created.
8. Prints remaining processes in the scope after cleanup.

### Required Explanations

The lab README must answer:

1. Why should the whole Wine process tree be placed in one cgroup?
2. Why can a shared `wineserver` complicate resource accounting?
3. Why is a separate `WINEPREFIX` useful per MT5 instance?
4. How does `CPUQuota` map to `cpu.max`?
5. How does `CPUWeight` map to `cpu.weight`?
6. How do `MemoryHigh` and `MemoryMax` map to cgroup v2?
7. How does `TasksMax` map to `pids.max`?
8. How can I prove MT5 is actually constrained?
9. What happens when MT5 exceeds its memory limit?
10. Can I run multiple independently limited MT5 instances on one host?

Clearly state:

> Resource limits control consumption; they do not provide the same isolation boundary as a virtual machine.

Do not execute real trades, configure broker credentials, install Expert Advisors, or interact with a live trading account.

---

## Module 7: Manual Container Demo

Create a small educational script that combines:

1. A new UTS namespace
2. A new PID namespace
3. A new mount namespace
4. A minimal root filesystem or temporary filesystem
5. A mounted `/proc`
6. Optional cgroup v2 limits
7. Cleanup

The goal is to demonstrate:

> A container is a process with isolated views, resource controls, and a prepared filesystem.

Do not attempt to create a production container runtime.

Clearly explain what is missing compared with Docker or `runc`.

---

## Labs

Every lab README must include:

- Goal
- Requirements
- Commands
- Explanation
- Expected output
- Cleanup
- Common errors
- Review questions

Shell scripts should use:

```bash
set -Eeuo pipefail
```

where appropriate.

Scripts should be safe to run multiple times when practical.

Do not automatically run privileged labs.

---

## Progress Tracking

Create `progress.md` with checkboxes for each module:

```text
- [ ] Read note
- [ ] Ran lab
- [ ] Recorded observations
- [ ] Answered review questions
```

Suggested study order:

1. Processes
2. Namespaces
3. cgroups
4. OverlayFS
5. Runtimes
6. Docker/Kubernetes mapping
7. Wine + MT5 resource-limit lab
8. Manual-container demo

---

## Cheatsheet

Create `cheatsheet.md` with useful commands, including:

```bash
ps
pstree
lsns
nsenter
unshare
readlink /proc/<pid>/ns/*
cat /proc/<pid>/cgroup
systemd-cgls
systemd-cgtop
findmnt
mount
docker inspect
docker stats
```

For each command, explain what it is used for.

---

## Questions the Course Must Answer

By the end of the course, I should understand:

1. Why is a container a normal Linux process?
2. What does each important namespace isolate?
3. How can I prove two processes are in different namespaces?
4. Why does the host see container processes?
5. What does cgroup v2 control?
6. What is the difference between `cpu.max` and `cpu.weight`?
7. How do I inspect a container's CPU and memory limits?
8. What is copy-on-write?
9. How does OverlayFS create a writable container layer?
10. What is the difference between Docker, containerd, and `runc`?
11. What is CRI?
12. How does Kubernetes eventually create a Linux process?
13. How can I run Wine + MT5 inside a cgroup v2 resource limit?
14. How can I verify that Wine, wineserver, and MT5 are in the same cgroup?
15. Which Linux primitives are combined to create a container?

---

## Execution Order

Work in this order:

### Phase 1

Create:

- directory structure
- environment inspection
- README
- progress tracker
- glossary

### Phase 2

Create notes and labs for:

- processes
- namespaces
- cgroups v2
- OverlayFS

### Phase 3

Create notes for:

- runtimes
- Docker and Kubernetes mapping

### Phase 4

Create:

- Docker inspection lab
- Wine + MT5 resource-limit lab
- manual-container lab
- cheatsheet
- final summary

---

## Final Validation

Before finishing:

1. Show the final directory tree.
2. Run `bash -n` against shell scripts.
3. Run `shellcheck` if installed.
4. Confirm every privileged lab has cleanup instructions.
5. Confirm no unrelated files were modified.
6. Confirm no secrets were copied.
7. Create `validation-report.md` containing:
   - files created
   - scripts validated
   - labs executed
   - labs not executed
   - host limitations
   - suggested first lesson

---

## Final Response

At the end, give me a concise summary containing:

- modules created
- labs created
- labs executed
- labs awaiting permission
- important host findings
- the first file I should read

Start creating the course immediately. Do not stop after producing only an outline.
