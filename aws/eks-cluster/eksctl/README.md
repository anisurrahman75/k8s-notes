# Create Cluster With Configuration
```bash
eksctl create cluster -f cluster-config.yaml
```

# Delete Cluster 
```bash
eksctl delete cluster -f cluster.yaml --disable-nodegroup-eviction
```
# Get KubeConfig
```bash
eksctl utils write-kubeconfig --cluster kubestash-credless --region us-east-1 --kubeconfig cluster.yaml
```
