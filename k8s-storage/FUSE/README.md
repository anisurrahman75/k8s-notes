## Comparison
https://github.com/yandex-cloud/geesefs/blob/master/bench/README.md

## mountpoint-s3 (AWS Official)
1000 files, 50 nested each file 10MB
```bash

$ time /usr/local/bin/restic backup ./fuse
processed 1000 files, 9.766 GiB in 1:36:23
```

## S3FS
1000 files, 50 nested each file 10MB
```bash


```