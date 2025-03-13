# Deployments
![](https://lh6.googleusercontent.com/gvuDcfMIGRTT5Q_SHiHxYlYBiz6XPxu59oYqKRbIKMZ1-vtYI768u4_hvT11Dr1AFnEgi4le1nSJnHPCJrnowzfUbcBR59MNTmay7Ez-uL0YmRAye50BXc-kAeUYZBuG4I6rwdpVi8ihn5erP5nLtQk)
# Intro:

- Deployments enable you to easily move from one version of your code to the next. This “rollout” process is specifiable and careful. Deployment provides declarative updates for Pods and ReplicaSets.

- Imagine, we are upgrading application from v1 to v2

- ##### Can we :

    - Upgrade with zero downtime?
    - Upgrade sequentially, one after the other?
    - Pause and resume upgrade process?
    - Rollback upgrade to previous stable release?
# Features

- Updates & Rollback
- Multiple Replicas
- Upgrade
- Rollback
- Scale Up && Down
- Pause && Resume
# Deployment Types

- Recreate

    - Dummy deployment: shut version A completely and create version B

- RollingUpdate - Ramped or Incremental ( default Update of k8s)

    - Slow deployment replacing instances one after another.

- Canary

  - Manually update test and update incrementally, test new version and deploy 100%

- Blue / Green

    - User used both
# ManifestFile
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: nginx-deploy
    labels:
      app: nginx-app
  spec:
    replicas: 3
    selector:
      matchLabels:
        app: nginx-app
    template:
      metadata:
        labels:
          app: nginx-app
      spec:
        containers:
        - name: nginx-container
          image: nginx:1.7.9
          ports:
          - containerPort: 80
  ```
# Create and Display

- `$ kubernetes kubectl create -f Deployments.yaml`
- `$ kubectl apply -f Deployments.yaml`
- `$ kubectl get deploy -l app=nginx-app`
- `$ kubectl get po -l app=nginx-app`
# Update: 1.7.9—>1.9.1

- `$ kubectl set image deploy nginx-deploy nginx-container=nginx:1.9.1`
- Or,
- `$ kubectl edit deploy nginx-deploy`
- Or,
- Update yaml file and execute apply command:
- `$ kubectl get deployments &lt;deployments_name> -o yaml > <save_file_name>.yaml`
- Modify this yaml file
- Write apply cmd
# Rollback Deployment: 1.7.9 to 1.9.1

- `$ kubectl set image deploy nginx-deploy nginx-container=nginx:1.9.1 –record`
- `$ Kubectl rollout history deploy/nginx-deploy`
- `$ kubectl rollout status deploy/nginx-deploy –record`
- `$ Kubectl rollout status deploy/nginx-deploy`
# Scale up and down

- `$ kubectl scale deploy nginx-deploy --replicas=5`
- `$ kubectl get deployments`
# Delete

- `$ kubectl delete -f Deployment.yaml`
- `$ kubectl get pod -l app=nginx-app`
# Additional CMD:
- `$ kubectl rollout pause deployments kuard`
- `$ kubectl rollout resume deployments kuard`
