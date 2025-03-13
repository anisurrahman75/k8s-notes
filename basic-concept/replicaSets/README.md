# Replications Controller

- Ensures that a specified number of pods are running at any time.
- Replication controllers and Pods are associated with 'Labels'.
- Advantages: High availability, load balancing
- Supports equality-based selectors
# ReplicaSet
- It creates multiple replica of pods instances for high availability and load balances purposes
- Ensures that a specified number of pods are running at any time
- Reconciliation Loops is constantly running, observing the current state
- ReplicaSet and Pods are associated with “Labels”
- Replication controller is replaced by replicaset (next-generation replication controller)
- Supports set-based selectors
# Selectors
- Selectors are used to filter Kubernetes objects based on a set of labels.

| key-point         |     Replications Controller= Equality-based                                                   | ReplicaSet = Set-based                                                                                                                              |
|-------------| ------------------------------------------------------ |-----------------------------------------------------------------------------------------------------------------------------------------------------|
|  
| Operators   | =,==,!=                                                | In , notion, exists                                                                                                                                 |
| Example     | Environment = production,Tier != frontend              | Environment in (production,qa),tier notion(frontend, backend)                                                                                       |
| Command     | Kubectl get pods -l environment=production             | Kubectl get pods -l environment i**n** ( production)                                                                                                |
| In manifest | Selector:    Environment: production    Tier: frontend | selector: matchExpressions:  \- {key: environment, operator: In, values:\[prod, qa]}  \- {key: tier, operator: NotIn, values: \[frontend, backend]} |
| Supports    | Services, Replication Controller                       | Job, Deployment, ReplicaSet and DaemonSet                                                                                                           |

# Manifest File of ReplicaSet
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
    name: nginx-rs
spec:
    replicas: 3
    selector: 
        matchLabels: 
            app: nginx-app
            tier: frontend
        matchExpressions:
            - {key: tier, operator: In, values: [frontend]}
    template:
        metadata:
            name: nginx-pod
            labels:
                app: nginx-app
                tier: frontend
        spec:
            containers:
            - name: nginx-container
              image: nginx
              ports: 
                - containerPort: 80
```
# Create, Display && Inspect ReplicaSet

- `$ kubectl apply -f nginx-rs.yaml`

- `$ kubectl get pods`

- `$ kubectl describe rs nginx-rs`

- Label Selectors example:

    - `$ kubectl get pods --show-labels`
    - `$ kubectl get pods --selector="ver=2"`
    - `$ kubectl get pods --selector="app=bandicoot,ver=2"`
    - `$ kubectl get pods --selector="app in (alpaca,bandicoot)"`
    - `$ kubectl get pods --selector="canary"`
    - `$ kubectl get pods --selector='!canary'`
    - `$ kubectl get pods -l 'ver=2,!canary'`


# Scaling up / down of ReplicaSet


- Scale Up: `$ Kubectl scale rs nginx-rs --replicas=5`
- Scale Down: `$ Kubectl scale rs nginx-rs --replicas=2`
- Note: Indeed, if the need is not acute, we generally recommend only making declarative changes as described in the following section
# Delete
- `$ Kubectl delete -f nginx-rx.yaml`
- `$ kubectl delete rs nginx-rs --cascade=false` [ deleting just ReplicaSet only]
