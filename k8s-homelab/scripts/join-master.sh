#!/bin/bash
# Join a worker node to the cluster
# Usage: ./join-worker.sh "<kubeadm-join-command>"

JOIN_COMMAND="$1"

if [ -z "$JOIN_COMMAND" ]; then
  echo "Error: Please provide the kubeadm join command as an argument."
  exit 1
fi

# Execute the join command
sudo $JOIN_COMMAND

echo "Worker node joined successfully!"