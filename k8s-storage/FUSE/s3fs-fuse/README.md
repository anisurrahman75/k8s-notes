### Features:
- compatible with Amazon S3, and other S3-based object stores(Refered this IBM and cloudflare docs)
- allows random writes and appends
- direct HTTP REST requests (signed requests) rather than relying on an `AWS SDK layer`, which is lacking.


## Install
```bash
sudo apt install s3fs
```

### Example
```bash
s3fs kubestash mount-s3fs -o ro


time /usr/local/bin/restic backup ./fuse
repository 4e2bc87b opened (version 2, compression level auto)
no parent snapshot found, will read all files
[0:00]          0 index files loaded

Files:        1000 new,     0 changed,     0 unmodified
Dirs:           51 new,     0 changed,     0 unmodified
Added to the repository: 9.766 GiB (9.767 GiB stored)

processed 1000 files, 9.766 GiB in 6:21
snapshot 832b4339 saved

real	6m21.335s
user	3m40.339s
sys	0m44.524s

```