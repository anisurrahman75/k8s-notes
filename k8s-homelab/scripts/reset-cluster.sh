#!/bin/bash
# Reset the cluster on a node

sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd $HOME/.kube
sudo systemctl restart kubelet

echo "Cluster reset complete. Run install-prereqs.sh to start over."