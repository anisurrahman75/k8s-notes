### Installation
```bash
$ helm install csi-s3 yandex-s3/csi-s3 \
      --set secret.accessKey=$AWS_ACCESS_KEY_ID \
      --set secret.secretKey=$AWS_SECRET_ACCESS_KEY \
      --set secret.endpoint="https://s3.amazonaws.com" \
      --set storageClass.singleBucket="kubestash" \
      --namespace csi-s3 --create-namespace
      
      
kubectl get pods -n csi-s3
```

### Testing in EKS cluster (single node)

```bash
Allocatable:
  cpu:                7910m
  ephemeral-storage:  76163928346
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             31546540Ki
  pods:               58
```

