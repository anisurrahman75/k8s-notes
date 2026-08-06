# Lab 04 — OverlayFS copy-on-write

## Goal

Observe lower-layer reads, copy-up on edit, upper-only creation, deletion/whiteout behavior, and safe unmounting.

## Requirements and commands

OverlayFS kernel support plus `sudo mount`/`umount`. `./run.sh` is preview-only. After reviewing it, use `./run.sh --execute`. All directories live under this lab's `.state`.

## Explanation and expected output

The script mounts `lower` + `upper` into `merged`. It reads a lower file, edits it through merged, creates a file, and deletes another lower file. Lower files remain unchanged. Upper contains the copied-up edit, new file, and a whiteout representation for the deletion. Output varies: whiteouts may be shown through device nodes or OverlayFS metadata.

## Cleanup

Run `./cleanup.sh`. It refuses to recursively remove `.state` while `merged` remains mounted, verifies an OverlayFS mount before `sudo umount`, and targets only the resolved lab directory.

## Common errors

Upper and work must be on the same filesystem and work must be empty. Nested/containerized hosts may expose OverlayFS but deny mounting. A busy merged directory means a shell/process still uses it; leave that directory and retry cleanup.

## Review questions

1. Which reads cause no copy? 2. Where does an edit appear? 3. How is deletion represented? 4. Why is work needed? 5. How does this resemble an image plus container layer?

