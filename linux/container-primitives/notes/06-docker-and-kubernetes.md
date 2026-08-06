# 6 — Docker and Kubernetes mapping

## Problem and mental model

High-level tools compose Linux mechanisms; understanding the mapping turns troubleshooting from guesswork into inspection.

| Linux concept | Docker usage | Kubernetes usage |
|---|---|---|
| PID namespace | container process view | per-container or shared pod PID view |
| Network namespace | isolated container stack | normally one network stack/IP per pod |
| Mount namespace | image rootfs and mounts | per-container rootfs plus pod volumes |
| cgroups | resource accounting/limits | requests inform scheduling; limits reach runtime cgroups |
| OverlayFS | image plus writable layer | runtime-managed image snapshots on nodes |
| OCI runtime | starts container process | CRI implementation invokes runtime |

## Interfaces and commands

```bash
docker run -d --rm --name primitives-demo --cpus .5 --memory 128m nginx:alpine
pid=$(docker inspect -f '{{.State.Pid}}' primitives-demo)
sudo ls -l /proc/$pid/ns
cat /proc/$pid/cgroup
./inspect-cgroup.sh "$pid"
docker inspect primitives-demo
docker stats --no-stream primitives-demo
docker rm -f primitives-demo
```

The provided lab uses an already-present image by default so it does not unexpectedly access the network. Set `IMAGE` deliberately if another local image is preferred.

Kubernetes inspection is optional and read-only:

```bash
kubectl get nodes
kubectl get pod -A -o wide
kubectl get pod POD -n NS -o jsonpath='{.status.containerStatuses[*].containerID}'
```

A container ID can be resolved on its node with CRI tooling, but node access and permissions vary. Do not assume a `docker://` ID; modern clusters often report `containerd://` or `cri-o://`.

## Demonstration and expected observations

Lab 05 starts one disposable process, resolves the host PID, compares namespace identities to the lab shell, reads direct cgroup files, then compares them with Docker metadata/stats. Expect PID, mount, UTS, IPC, and network namespace identities to differ. User namespace may remain shared in rootful Docker. The cgroup should show finite CPU/memory values matching requested limits, subject to representation/rounding.

## How Kubernetes reaches Linux

The API server stores desired state. The scheduler binds a pod to a node. Kubelet observes it and calls CRI. The runtime prepares the sandbox, networking (through CNI integration), image snapshots, mounts, and OCI configuration. The OCI runtime asks the kernel to create the process. Controllers and the kubelet keep reconciling desired and actual state.

## Common mistakes

- equating CPU requests with a hard CPU cap.
- inspecting a container from the wrong node.
- assuming every pod container shares a PID namespace.
- assuming a container's writable layer persists after replacement.
- reading runtime UI output without verifying `/proc` and cgroup files.

## Review questions

1. Which Linux features implement each row in the table?
2. How do you go from Docker container name to host PID and cgroup?
3. Why does a pod normally have one IP but multiple root filesystems?
4. What is the difference between a Kubernetes request and limit?
5. Which component finally creates the Linux process?

## Summary

Docker and Kubernetes automate composition and lifecycle; namespaces, cgroups, mounts, and Linux processes remain the observable execution substrate.

