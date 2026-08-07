# Quiz

Try these without running commands first.

## Foundations

1. Why is PID 1 different from an ordinary long-running process?
2. Does `Requires=db.service` guarantee that the database starts first?
3. What is the difference between `start` and `enable`?
4. Why prefer `systemctl edit` over changing a package's unit file?

## systemd-run and cgroups

5. When would you choose a transient service over `--scope`?
6. What does `CPUQuota=200%` mean?
7. Why might `CPUWeight=10` appear to do nothing on an idle machine?
8. Why set `MemoryHigh` lower than `MemoryMax`?
9. Does `TasksMax=20` allow 20 processes plus unlimited threads?
10. A program forks ten children. Are they outside the unit's memory limit?

## Isolation

11. Does `MemoryMax=` prevent a process from reading `$HOME/.ssh`?
12. Why can the demo run in an empty bwrap root without `/lib`?
13. What access does `--ro-bind /usr /usr` grant?
14. Does `--unshare-net` enforce a CPU limit?
15. Name two things bubblewrap still shares with the host.

## Small experiments

16. Change the scope from `CPUQuota=50%` to `20%`. Which program metric should
    change, and which command shows systemd's configured quota?
17. Make `/etc/passwd` readable inside the sandbox without exposing all of
    `/etc`. Which bwrap mount would you add?
18. Put two services in one slice with `MemoryMax=512M`. Can each reliably use
    512 MiB at the same time?
