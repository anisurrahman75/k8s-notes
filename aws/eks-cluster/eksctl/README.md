# Create Cluster With Configuration
```bash
eksctl create cluster -f cluster.yaml
```

# Delete Cluster 
```bash
eksctl delete cluster -f cluster.yaml --disable-nodegroup-eviction
```
# Get KubeConfig
```bash
eksctl utils write-kubeconfig --cluster kubestash-cred-less --region us-east-1 --kubeconfig cluster.yaml
```

```bash
eksctl scale nodegroup \
  --cluster kubestash-cred-less \
  --name ng-1 \
  --nodes 1 \
  --nodes-min 1 \
  --nodes-max 2
```

# Add a New node group to the existing cluster
```bash
eksctl create nodegroup -f cluster.yaml
```
