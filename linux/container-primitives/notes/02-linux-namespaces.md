# 2 — Linux namespaces

## Problem and mental model

Namespaces let processes receive different answers when they ask the same kernel about globally scoped resources. They isolate views, not resource consumption. Cgroups solve the latter.

| Type | Isolated view | Practical consequence |
|---|---|---|
| PID | process IDs and visible process tree | container init sees itself as PID 1 |
| Mount | mount table | container can have a distinct root and mounts |
| Network | interfaces, routes, ports, firewall state | a pod gets its own network stack |
| UTS | hostname/domain name | container hostname differs from host |
| IPC | SysV IPC and POSIX message queues | unrelated workloads do not share these objects |
| User | UID/GID mappings and capabilities | a namespace-root may map to an unprivileged host UID |

## Interfaces and inspection

`/proc/<pid>/ns/<type>` is a namespace handle. Compare its link identity with `readlink`; `lsns -p PID` adds ownership and process context. `nsenter -t PID -m -u -i -n -p` joins selected views. `unshare` creates new namespaces for a command.

```bash
readlink /proc/self/ns/{pid,mnt,net,uts,ipc,user}
lsns -p <pid>
sudo nsenter -t <pid> -m -u -i -n -p -- ps -ef
sudo unshare --uts --pid --fork --mount-proc bash
```

The first child of a new PID namespace becomes PID 1 *inside* it; the host still sees its host PID. A PID namespace normally needs a matching `/proc` mount to make tools such as `ps` show the new view. A mount namespace does not automatically make existing mounts private, which is why the lab explicitly uses safe mount propagation options.

## Demonstration and expected observations

Read and run `../labs/02-namespace-demo/README.md`. The lab creates UTS, PID, and mount namespaces, changes the isolated hostname, mounts a namespace-specific `/proc`, and compares namespace IDs from inside and outside. Expect UTS/PID/mount IDs to differ while the host hostname remains unchanged. Network, IPC, and user IDs remain shared because this focused lab does not unshare them.

## Docker and Kubernetes

Docker assembles several namespaces per container. Kubernetes' default pod network model places all containers in a pod in one network namespace, commonly established by a sandbox/pause container. Container mount filesystems remain distinct, while volumes make chosen paths share data. `shareProcessNamespace: true` makes pod containers share a PID namespace; it is not the default.

## Common mistakes

- Calling namespaces security boundaries by themselves; capabilities, seccomp, LSMs, filesystem setup, and kernel trust also matter.
- Confusing Kubernetes namespaces (API organization) with kernel namespaces.
- changing a hostname without a UTS namespace.
- using host `ps` output to infer the isolated PID view.
- forgetting PID-namespace PID 1 must reap orphaned children and handle signals.

## Review questions

1. What does each of the six namespace types isolate?
2. How can two namespace symlink identities prove separation?
3. Why does the host still see namespaced processes?
4. Why pair a new PID namespace with a new `/proc` mount?
5. Which namespace do containers in a normal Kubernetes pod share?

## Summary

Namespaces do not create a container object; they give ordinary processes carefully chosen, different views of shared kernel facilities.

