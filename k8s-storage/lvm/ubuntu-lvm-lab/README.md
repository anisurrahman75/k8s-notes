### Disable KVM kernal extension
```bash
sudo rmmod kvm_amd   # or kvm_intel if Intel CPU
sudo rmmod kvm
```

Now,
```bash
vagrant up
vagrant ssh 
```


### Delete Vagratfile if faced error while vagrant up
```bash
VBoxManage list vms
VBoxManage unregistervm <vm-name> --delete


vagrant box list
vagrant box remove <box-name>
```