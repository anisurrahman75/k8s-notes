### Feature:

- High Performance
- It uses aggressive parallelism and asynchrony.
- It also has CSI driver https://github.com/yandex-cloud/csi-s3
- It supports S3 compatible API

## Install
https://github.com/yandex-cloud/geesefs/tree/master?tab=readme-ov-file#installation

```bash
wget -qO geesefs https://github.com/yandex-cloud/geesefs/releases/latest/download/geesefs-linux-amd64 \
  sudo chmod +x geesefs
```
### Example
```bash
mkdir geesefs-mount
geesefs --endpoint=https://s3.amazonaws.com kubestash geesefs-mount

time restic backup ./fuse
repository a77d7752 opened (version 2, compression level auto)
created new cache in /home/ubuntu/.cache/restic
no parent snapshot found, will read all files
[0:00]          0 index files loaded

Files:        1000 new,     0 changed,     0 unmodified
Dirs:           51 new,     0 changed,     0 unmodified
Added to the repository: 9.766 GiB (9.767 GiB stored)

processed 1000 files, 9.766 GiB in 4:18
snapshot 0b81b9da saved

________________________________________________________
Executed in  259.05 secs    fish           external
   usr time  228.89 secs  600.00 micros  228.89 secs
   sys time   55.03 secs  469.00 micros   55.03 secs
```