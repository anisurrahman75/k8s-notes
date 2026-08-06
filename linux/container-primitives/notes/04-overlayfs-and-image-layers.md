# 4 — OverlayFS and image layers

## Problem and mental model

Container images must share immutable content while each running container can write cheaply. OverlayFS presents one merged tree from read-only lower directories plus one writable upper directory. The work directory is private bookkeeping and must share a filesystem with upper.

Lookup starts at upper, then searches lower layers from left to right. Reading a lower file performs no copy. The first modification copies it to upper (“copy-up”) and edits the copy. A new file exists only in upper. Deleting a lower entry creates a whiteout/opaque representation in upper so the merged view hides it without changing the lower layer.

## Interfaces and commands

```bash
grep -w overlay /proc/filesystems
findmnt -t overlay -o TARGET,FSTYPE,OPTIONS
sudo mount -t overlay overlay \
  -o lowerdir=lower2:lower1,upperdir=upper,workdir=work merged
sudo umount merged
find upper -xdev -printf '%y %p\n'
```

The mount options are the authoritative source for the directories backing a particular overlay mount. Whiteout representation can vary with kernel/mount mode and may appear as a character device or metadata/xattr; use `ls -la`, `stat`, and `getfattr` where available rather than assuming one display.

## Demonstration and expected observations

The lab builds directories under its own `.state`, mounts the merged view only after `--execute`, then reads, edits, creates, and deletes files. Expect lower content to remain unchanged, modified/new objects to appear in upper, and deleted lower content to disappear from merged. Cleanup unmounts only the lab mount after verifying its source/fstype, then removes only `.state`.

## Docker and Kubernetes

OCI image layers are filesystem change sets plus metadata. A runtime snapshots/unpacks them using a snapshotter/storage driver; on this host Docker commonly uses OverlayFS. Image layers become lower content and a container gets a writable snapshot/layer. Volumes and bind mounts are separate mounts and do not behave like the container writable layer. Kubernetes delegates image filesystems to the node's CRI runtime; Kubernetes itself is not an OverlayFS implementation.

## Common mistakes

- calling an OCI archive layer an OverlayFS directory; the runtime translates between concepts.
- editing lower directories and expecting normal container semantics.
- placing upper and work on different filesystems.
- looking for a deleted file in upper without understanding whiteouts.
- unmounting a path without verifying it is the lab's OverlayFS mount.

## Review questions

1. What roles do lower, upper, work, and merged play?
2. When does copy-up occur?
3. How can a lower file be deleted without changing lower?
4. Why do two containers from one image need separate writable layers?
5. Why are Kubernetes volumes distinct from OverlayFS image layers?

## Summary

OverlayFS creates a cheap writable view over shared immutable files. Copy-up and whiteouts record changes without rewriting image layers.

