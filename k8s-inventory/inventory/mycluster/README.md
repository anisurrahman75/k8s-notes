## Install Ansible
```bash
export VENVDIR=kubespray-venv
export KUBESPRAYDIR=/home/anisur/go/src/kubernetes-sigs/kubespray
python3 -m venv $VENVDIR
source $VENVDIR/bin/activate # If fish it'll give error, use `. kubespray-venv/bin/activate.fish`
cd $KUBESPRAYDIR
pip install -U -r requirements.txt
```

## Creating cluster

#### First go the kubespray repository 
```bash
cd ~/go/src/kubernetes-sigs/kubespray/kubespray/
export INVENTORY_DIR=/home/anisur/go/src/github.com/anisurrahman75/k8s-notes/k8s-inventory/inventory/

ansible-playbook -i $INVENTORY_DIR/mycluster/hosts.yaml cluster.yml -b -v --become --become-user=root --private-key=~/.ssh/id_rsa

# Now SSH tha control plane node and go /etc/kuberentes directory and get the admin.conf file
```

## Deleting cluster
```bash
ansible-playbook -i $INVENTORY_DIR/mycluster/hosts.yaml reset.yml -b -v --become --become-user=root --private-key=~/.ssh/id_rsa
```

## Adding a new node (add node info to hosts.yaml)
```bash
ansible-playbook -i $INVENTORY_DIR/mycluster/hosts.yaml cluster.yml -b -v --become --become-user=root --private-key=~/.ssh/id_rsa -l noobaa3
```


### Set labels to workers node
```bash
kubectl label node noobaa3 node-role.kubernetes.io/worker-<i>=
```