### Interview Questions on Kubernetes Cluster Setup

#### Beginner Level
1. **What is the purpose of `kubeadm` in setting up a Kubernetes cluster?**
    - Hint: Think about its role in initializing nodes and bootstrapping the cluster.

2. **Explain the steps to install prerequisites for a Kubernetes cluster on Ubuntu.**
    - Hint: Consider your `install-prereqs.sh` script (Docker, kubeadm, kubelet, swap).

3. **What command would you use to join a worker node to an existing cluster?**
    - Hint: Recall your `kubeadm join` command with token and hash.

4. **Why do you need a Container Network Interface (CNI) plugin in a Kubernetes cluster?**
    - Hint: Relate to your experience with Flannel and the `NotReady` state.

5. **What’s the difference between a control plane node and a worker node?**
    - Hint: Reflect on `master` vs. `worker-1` roles in your setup.

#### Intermediate Level
6. **How would you initialize a Kubernetes control plane node without hardcoding an IP address?**
    - Hint: Think about your `init-master.sh` tweak to avoid `--control-plane-endpoint=10.2.0.54`.

7. **What happens if you forget to install a CNI plugin after setting up a cluster with `kubeadm`?**
    - Hint: Recall `worker-1` being `NotReady` until Flannel was applied.

8. **How do you upgrade a Kubernetes master node from version 1.32.2 to 1.33.0 using `kubeadm`?**
    - Hint: Walk through your upgrade process (`upgrade apply`, `kubelet` restart).

9. **What’s the purpose of the `--node-name` flag in `kubeadm join`, and how did you use it?**
    - Hint: Relate to renaming `anisur-1` to `worker-1`.

10. **How can you prevent user workloads from scheduling on the master node?**
    - Hint: Think about the `NoSchedule` taint you applied or checked.

#### Advanced Level
11. **Describe how you would set up a high-availability (HA) Kubernetes cluster with multiple masters using `kubeadm`.**
    - Hint: Consider load balancers (e.g., HAProxy), external etcd, and `--control-plane-endpoint`.

12. **What steps would you take to minimize downtime when upgrading a worker node with active pods?**
    - Hint: Reflect on draining `worker-1` and the idea of adding `worker-2`.

13. **Explain the role of etcd in a Kubernetes cluster and how you’d back it up before an upgrade.**
    - Hint: Tie to your single-master setup and the `etcdctl snapshot save` command.

14. **How does Kubespray differ from `kubeadm` in deploying a production-ready cluster?**
    - Hint: Compare your manual `kubeadm` setup to Kubespray’s Ansible automation.

15. **What would you do if a worker node shows `NotReady` after joining the cluster, and how would you troubleshoot it?**
    - Hint: Use your experience with CNI issues and `kubectl describe node`.

#### Scenario-Based Questions
16. **You’ve set up a cluster with one master (10.2.0.54) and one worker (10.2.0.67). The master node fails. What’s the impact, and how would you recover?**
    - Hint: Single-master limitation; discuss backups and redeployment.

17. **A pod on your worker node is stuck in `Pending` after draining the node during an upgrade. Why might this happen, and how would you fix it?**
    - Hint: No available nodes; uncordon or add capacity.

18. **Your cluster is running version 1.32.2, and a new app requires a feature in 1.33.0. How would you plan and execute the upgrade with minimal disruption?**
    - Hint: Master first, then workers; consider `worker-2` for zero downtime.

19. **You’re tasked with deploying a production cluster using Kubespray on bare metal. How would you configure the inventory file for three nodes (master, worker-1, worker-2)?**
    - Hint: Use your `hosts.ini` example with Kubespray’s structure.

20. **During a cluster setup, you see a preflight error: `[ERROR IsPrivilegedUser]: user is not running as root`. How would you resolve this?**
    - Hint: Recall your `kubeadm join` fix with `sudo`.

#### Production-Focused Questions
21. **What open-source tools would you recommend for managing a production Kubernetes cluster, and why?**
    - Hint: Kubespray, K3s, Rancher—tie to your exploration.

22. **How would you monitor the health of a Kubernetes cluster in production?**
    - Hint: Prometheus, Grafana from your proposed structure.

23. **What’s the benefit of using GitOps (e.g., ArgoCD) in a production Kubernetes setup?**
    - Hint: Declarative management in `ci-cd/argocd/`.

24. **How would you secure a Kubernetes cluster running on bare metal?**
    - Hint: RBAC, OPA policies in `security/policies/`, network policies.

25. **You need to scale your cluster from 2 nodes (master, worker-1) to 3 nodes by adding worker-2. How would you do this in a production environment?**
    - Hint: Update `hosts.ini`, run Kubespray, or use `join-worker.sh`.

---

### Tips for Answering
- **Leverage Your Experience:** Reference your homelab (`10.2.0.54`, `worker-1`, Flannel) to ground answers in real examples.
- **Show Problem-Solving:** Explain how you’d troubleshoot (e.g., `kubectl describe`, logs).
- **Production Mindset:** Highlight HA, automation (Kubespray), and observability (Prometheus).

---

### Example Answer (Question 8)
**Q: How do you upgrade a Kubernetes master node from version 1.32.2 to 1.33.0 using `kubeadm`?**

**A:** "First, I’d check available versions with `apt-cache policy kubeadm` and install the target version: `sudo apt install -y kubeadm=1.33.0-1.1`. Then, I’d plan the upgrade with `sudo kubeadm upgrade plan` to verify compatibility. If user pods are on the master, I’d drain it with `kubectl drain master --ignore-daemonsets`, though in my single-master setup, this is optional since control plane pods stay up. Next, I’d apply the upgrade with `sudo kubeadm upgrade apply v1.33.0`, which updates the API server, controller manager, and etcd, causing a brief 10-30 second downtime. After that, I’d upgrade `kubelet` and `kubectl` with `sudo apt install -y kubelet=1.33.0-1.1 kubectl=1.33.0-1.1` and restart the kubelet: `sudo systemctl restart kubelet`. Finally, I’d uncordon the node if drained (`kubectl uncordon master`) and verify with `kubectl get nodes`. In my homelab, I practiced this on `10.2.0.54`, ensuring `worker-1` stayed operational."

---

Want me to refine these questions further (e.g., focus on Kubespray, add more scenarios)? Or practice answering a few with me? Which ones look toughest to you?