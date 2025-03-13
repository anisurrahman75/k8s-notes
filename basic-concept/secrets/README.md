## What is Secret?
-   A Secret is an object that contains a small amount of sensitive data such as a password, a token, or a key. Because Secrets can be created independently of the Pods that use them, there is less risk of the Secret (and its data) being exposed during the workflow of creating, viewing, and editing Pods. Secret can be mounted as data volumes or exposed as environment variables to be used by a container in a Pod.
-   Secrets are similar to ConfigMaps but are intended to hold confidential data

-   By default, Kubernetes Secrets are stored in plain text in the etcd storage for the cluster. In particular, anyone who has cluster administration rights in your cluster will be able to read all of the Secrets in the cluster. In recent versions of Kubernetes, support has been added for encrypting the Secrets with a user-supplied key, generally integrated into a cloud key store.
## Objective:
-   Kubernetes object to handle small amount of sensitive data
    - Password, token and key
- Reducing risk of exposing sensitive data
-  Secret are created outside of the pod and container
-  Secret has no clue has which pod is use it
-  After creating secret any pod can use secret by referencing that
-  Secret stores inside ETCD databases on kubernetes master
-  Secret size not more than 1 MB
-  We can inject secret inside pod into 2 ways:
     - Volumes
     - Env variables

    
## Create Secret
-   There are 2 ways to create a secret
    - Kubectl command line
    - Manifest File
### Create Secret using Kubectl CMD:
-   ![](https://lh6.googleusercontent.com/FEgaM3TSitgzRCc4Kh9FU2t-3Niw6YmLuXs64kA9hq2Fdm0nx1FdEdIKUJErpBKCgeyEQyZpjazUYMz2wMqe9xtsjQoksMUsbrLoCTJ3r5yxkiZM144b9yTZLpjj9abRPxqxnxuTv-kos09wyNNlYAM)

-   $ echo -n  ‘admin’ > ./username.txt
-   $ echo -n  ‘12345’ > ./password.txt
-   $  kubectl create secret generic db-user-pas --from-file=username.txt --from-file=password.txt
-   $ kubectl get secrets
-   $ kubectl describe secrets/db-user-pas

### Create Secret using Manifest File
-   $ echo -n ‘admin’ | base64
-   $ echo -n ‘12345’ | base 64


```yaml
api: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: <encrypted username>
  password: <encrypted password>

```

-   $ kubectl create -f my-secret.yaml
-   $ kubectl get secrets
-   $ kubectl describe secrets/mysecret
## Secrets inside a pot
### Using volume mount
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
spec:
  volumes:
    - name: secret-volume
      secret:
        secretName: db-user-pas
  containers:
    - image: busybox
      name: busybox
      command: ["/bin/sh"]
      args: ["-c", "sleep 10000000"]
      volumeMounts:
        - name: secret-volume
          mountPath: /mydata


```




-   $ kubectl create -f mysecret-pod.yaml
-   $ kubectl exec -it pods/busybox  -- sh
### Using Env variable
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
spec:
  containers:
    - image: busybox
      name: busybox
      command: ["/bin/sh"]
      args: ["-c", "sleep 600"]
      env:
        - name: myusername
          valueFrom:
            secretKeyRef:
              name: db-user-pas
              key: username.txt
        - name: password
          valueFrom:
            secretKeyRef:
              name: db-user-pas
              key: password.txt

```

-   $  kubectl create -f mysecret-pod-env.yaml
-   $  kubectl exec -it pods/busybox  -- sh
