## Creating cluster

#### First go the kubespray repository 
```bash
cd ~/go/src/kubernetes-sigs/kubespray/kubespray/
```

```bash
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b -v --become --become-user=root --private-key=~/.ssh/id_rsa
```

## Deleting cluster
```bash
ansible-playbook -i inventory/mycluster/hosts.yaml reset.yml -b -v --become --become-user=root --private-key=~/.ssh/id_rsa
```

## Adding a new node (add node info to hosts.yaml)
```bash
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b -v --become --become-user=root --private-key=~/.ssh/id_rsa -l noobaa3
```


### Set labels to workers node
```bash
kubectl label node noobaa3 node-role.kubernetes.io/worker=
```