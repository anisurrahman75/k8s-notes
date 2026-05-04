### Features:
- With Mountpoint, file operations map to GET and PUT operations against S3, allowing scalable file-based applications to burst to terabits per second of aggregate throughput, without any code changes. [link](https://aws.amazon.com/blogs/storage/the-inside-story-on-mountpoint-for-amazon-s3-a-high-performance-open-source-file-client/)
- read large objects from S3, potentially from many instances concurrently, without downloading them to local storage first

### Why AWS build Mountpoint? [Link](https://aws.amazon.com/blogs/storage/the-inside-story-on-mountpoint-for-amazon-s3-a-high-performance-open-source-file-client/)
- Mountpoint uses the same core technology as AWS SDKs whereas (rclone use rest API)
→ High reliability, high throughput, low latency.

- Mountpoint is written in Rust
→ Memory-safe, efficient, no garbage collection pauses.

- Mountpoint is formally verified using automated reasoning
→ Its behavior is mathematically checked for correctness.

### Notes:
- It doesn't give guarantee to work with compatible storages (e.g. minio, hetzner s3 storage) [Link](https://github.com/awslabs/mountpoint-s3/blob/main/README.md#compatibility-with-other-storage-services)
- But this issue tells that it works with minio: (Project Author Replied) [Link](https://github.com/awslabs/mountpoint-s3/issues/144)

## Example:

```bash
$ fast
 -> 216.28 Mbps

$ ./dummy-data.sh
$ time aws s3 cp ./dummy-data  s3://kubestash/fuse --recursive

Completed 88.0 MiB/~2.5 GiB (4.9 MiB/s) with ~256 file(s) remaining (calculating...)


Executed in   35.13 mins    fish           external
   usr time   20.17 secs    0.48 millis   20.17 secs
   sys time   13.29 secs    1.04 millis   13.29 secs


---
wget -qO restic.bz2 github.com/restic/restic/releases/download/v0.18.1/restic_0.18.1_linux_amd64.bz2 \
  && bzip2 -d restic.bz2 \
  && chmod 755 restic \
  && sudo mv restic /usr/local/bin/
---

$ mkdir mount-s3
$ mount-s3 kubestash mount-s3
---

$ time /usr/local/bin/restic backup ./fuse
  
Files:        1000 new,     0 changed,     0 unmodified
Dirs:           51 new,     0 changed,     0 unmodified
Added to the repository: 9.766 GiB (9.767 GiB stored)

processed 1000 files, 9.766 GiB in 1:36:23
snapshot b48e526e saved

real	96m23.673s
user	4m26.008s
sys	1m24.417s

```