# Quiz answers

1. PID 1 initializes userspace, adopts and reaps orphaned processes, and is the
   final coordinator for shutdown. The kernel also treats signals to PID 1
   specially.
2. No. Dependency and ordering are separate; add `After=db.service` when order
   matters.
3. `start` activates now. `enable` creates boot/activation links for later.
4. Drop-ins survive package upgrades and show the local difference clearly.
5. Use a service for a manager-started background job; use a scope for a
   foreground or already-started process whose terminal behavior should remain.
6. A ceiling of two logical CPUs' worth of time.
7. Weight decides relative shares only when cgroups compete for CPU.
8. `MemoryHigh` applies pressure early; `MemoryMax` remains an emergency hard
   ceiling.
9. No. A task is a process or thread; both count.
10. No. Descendants stay in the cgroup and share its budget unless deliberately
    moved to another delegated unit.
11. No. It controls consumption, not filesystem visibility or permissions.
12. It is statically linked (`CGO_ENABLED=0`), so it needs no dynamic loader or
    shared libraries.
13. Read-only visibility of the entire host `/usr` tree. That is a large increase
    in sandbox surface.
14. No. Network namespaces control visibility; cgroups control CPU.
15. The kernel and explicitly inherited channels such as standard input/output.
16. Hash iterations per second should fall. Check
    `systemctl --user show UNIT -p CPUQuotaPerSecUSec`.
17. Add `--ro-bind /etc/passwd /etc/passwd`; bubblewrap creates destination
    parents as needed.
18. No. The parent's 512 MiB ceiling is shared across both child cgroups.
