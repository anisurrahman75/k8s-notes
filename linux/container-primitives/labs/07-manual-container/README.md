# Lab 07 — Assemble a tiny manual container

## Goal

Combine new UTS, PID, and mount namespaces with a temporary root filesystem and private `/proc` mount, then observe that the isolated command is still a host process.

## Requirements and commands

Linux `unshare`, `mount`, `chroot`, `/usr/bin/bash`, and explicit `sudo` approval. Preview with `./run.sh`. Execute with `./run.sh --execute`. The temporary root lives at `.rootfs`, contains a read-only bind of host `/usr`, and is removed afterward. No package or image download occurs.

The exercise uses the host userspace only to avoid downloading a rootfs; it is educational, not a strong root filesystem boundary.

## Explanation and expected output

The outer script starts `unshare --uts --pid --mount --fork`. Inside the new mount namespace it makes mount propagation private, mounts tmpfs as root, read-only binds `/usr`, creates standard merged-usr symlinks, mounts `/proc`, changes the UTS hostname, and `exec`s Bash through `chroot`. Expect Bash to report PID 1 and hostname `manual-container`; `ps` sees only its PID-namespace view. From another host terminal, `ps` still shows a host PID.

## Optional cgroup control

Namespaces do not constrain resources. To add a demonstration limit, a system administrator can wrap the reviewed `unshare` command in a uniquely named systemd scope with `CPUQuota`, `MemoryMax`, and `TasksMax`. That requires system-level approval and is not executed or silently selected by this lab; Lab 03 teaches the cgroup mechanics safely under the user manager.

## Cleanup

Mounts exist only in the temporary mount namespace and vanish when it exits. The outer script then runs the same guarded cleanup as `cleanup.sh`. Cleanup refuses deletion if `.rootfs` is still a mountpoint and never targets another path.

## Common errors

Nested hosts may deny `unshare`/mount despite feature availability. A missing `/usr/bin/bash` means this host-root technique is unsuitable. If cleanup reports a mount, inspect with `findmnt --target .rootfs` before doing anything manually.

## What is missing versus `runc`

No user namespace/mapping, capability bounding, seccomp, AppArmor/SELinux policy, safe `pivot_root`, device policy, masked `/proc` paths, network namespace/CNI, image verification, OCI config, logging, supervision, exec/attach, or race-hardened setup. Never run untrusted code here.

## Review questions

1. Which isolated views were created? 2. Why is `/proc` remounted? 3. Why make mount propagation private? 4. Why can the host still see PID 1? 5. Which production protections are absent?

