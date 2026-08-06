# Lab 01 — Inspect a process

## Goal

Prove that a running program becomes an ordinary process with observable ancestry, threads, descriptors, namespace handles, and cgroup membership.

## Requirements and commands

Linux, Bash, `/proc`, `ps`, and `readlink`; no privilege. Run `./run.sh` from any directory. It starts only a temporary Bash/sleep child.

## Explanation and expected output

The script prints a PID, a `ps` row, selected status fields, a rendered command line, FDs, namespace identities, and `0::` cgroup membership. Numeric IDs and paths differ by session. The child shares this shell's namespaces because the lab does not isolate it.

## Cleanup

An EXIT trap sends `TERM` and waits for exactly the created child. Re-running is safe.

## Common errors

Hardened `/proc` settings may hide FDs owned by another user, though this lab owns its child. A very early interruption can make `/proc/PID` disappear; rerun.

## Review questions

1. Which value is the parent PID? 2. How many threads exist? 3. What do FDs 0–2 reference? 4. Which namespace IDs match the shell? 5. What happens to `/proc/PID` after cleanup?

