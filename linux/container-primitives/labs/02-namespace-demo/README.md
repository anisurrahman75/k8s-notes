# Lab 02 — UTS, PID, and mount namespaces

## Goal

Create different hostname/process/mount views and prove them by comparing `/proc/PID/ns` identities.

## Requirements and commands

`unshare`, `nsenter`, `readlink`, and root permission on a host that allows namespace creation. Preview with `./run.sh`; execute only after review with `./run.sh --execute`. The script uses `sudo` only in execute mode.

The isolated child waits until cleanup so another terminal can run the printed `sudo nsenter ...` command.

## Explanation and expected output

Inside, hostname is `primitives-lab`, the shell is PID 1, and `/proc` shows the isolated process set. Outside, the host hostname is unchanged and the child has a normal host PID. UTS, PID, and mount namespace identities differ; net, IPC, and user remain shared.

## Cleanup

`./cleanup.sh` reads the lab-owned state file, validates a numeric live PID and its command marker, then terminates only that process. The child's private `/proc` mount disappears with its mount namespace.

## Common errors

`Operation not permitted` means the host/container policy blocks namespace creation. PID tools look wrong if `/proc` was not remounted; this lab uses `--mount-proc`. Do not substitute network namespace flags: networking is intentionally out of scope.

## Review questions

1. Which IDs changed? 2. Why does the host still see the child? 3. Why is the inside shell PID 1? 4. Why remount `/proc`? 5. Which views stayed shared?

