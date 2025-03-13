# Kubernetes Homelab Setup with Kubeadm

This guide walks you through setting up a bare-metal Kubernetes cluster using `kubeadm` on three machines. You’ll manually copy and run scripts on each node.

## Prerequisites
- **3 Machines:**
    - Control Plane: `10.2.0.54` (e.g., hostname `anisur-0`)
    - Worker-1: `10.2.0.67`
    - Worker-2: `10.2.0.68`
- **OS:** Ubuntu 24.04 LTS
- **Hardware:** Minimum 2GB RAM and 2 CPUs per machine
- **Network:** Static IPs configured, SSH access enabled
- **Host Machine:** Where your `k8s-homelab` repo is stored

## Setup Steps

### 1. Prepare Your Repository
- On your **host machine** (not the cluster nodes), ensure your `k8s-homelab` repo is ready with the scripts, configs, and manifests from this project.

### 2. Install Prerequisites on All Nodes
- **For each node (`10.2.0.54`, `10.2.0.67`, `10.2.0.68`):**
- Copy the `scripts` directory from your host machine:
   ```bash
     scp -r ../k8s-homelab ubuntu@10.2.0.54:/home/ubuntu/
     scp -r ../k8s-homelab ubuntu@10.2.0.67:/home/ubuntu/
     scp -r ../k8s-homelab ubuntu@10.2.0.68:/home/ubuntu/
   ```
- SSH into the node:
    ```bash
    cd /home/ubuntu/k8s-homelab/scripts
    chmod +x *.sh
    sudo ./install-prereqs.sh
    ```
   This installs Docker, kubeadm, kubelet, kubectl, and disables swap.

### 3. Initialize the Control Plane (Master Node)
- SSH into the control plane (if not already there):
    ```bash
    cd /home/ubuntu/k8s-homelab/scripts
    chmod +x init-master.sh
    sudo ./init-master.sh
    ```
    - This uses `../config/kubeadm-config.yaml` to set up the Kubernetes control plane.


### 4. Join Worker Nodes
- For each worker node (10.2.0.67 and 10.2.0.68):
```bash
cd /home/ubuntu/k8s-homelab/scripts
chmod +x join-worker.sh
sudo ./join-worker.sh "kubeadm join 10.2.0.54:6443 --token ... --discovery-token-ca-cert-hash ... --node-name worker-2"
```
- Set label on each node: `kubectl label nodes anisur-1 node-role.kubernetes.io/worker=worker-1`

### 5. Install a Network Plugin (CNI)
```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```
