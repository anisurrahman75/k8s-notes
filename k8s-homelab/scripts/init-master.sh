#!/bin/bash

# Initialize cluster with kubeadm using the config file
sudo kubeadm init --config=../config/kubeadm-config.yaml

# Set up kubectl for the user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Master node initialized. Copy the 'kubeadm join' command from the output above."
echo "Next, install your preferred CNI plugin (e.g., Flannel, Calico) manually."