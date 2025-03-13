# What is Pod?

* pods is the smallest unit of k8s
* Pod is rapper around one or more containers
* Pod is an abstraction layer over container
* Each worker nodes have multiple pods, then each pods contains multiple docker containers most cases single container
* Each pod has its own server and own ip addresses
* Pod can communicate with each other using ip addresses
* When a pods die, another pods create and communicate to another pod using services

# Pod Deployment

![img](https://lh6.googleusercontent.com/VRYXOBSh-KEX_1-8o8wnYFHgMMvG6SmMnlNf0NXbJbYKnSjCc3GYfiisMx4VYrQXOfn8fvPajdxdbaWVlrihtOwm5zrn_wscO5L0yJhl6eKOjQdnwD5mJ4N_hi_CsLoEOiv1gDi0UVCgUmtd5fA9reg)


# Pod Networking

![img](https://lh5.googleusercontent.com/1yU0gF4vuOxODV-hU-ZUJgLebNbHqSoE_9TN3_EQbmtYo5UeYh4BjaKxdw1MIliTTIUDJMJg7yfdapZ0YZS9Y33Fu7NiulEPEBvBgrOrpbD8SXedr1B35vEhn5LXcMBRioz1QdLryOKfikZddHykO-w)

* Each pod gets its own IP address and all containers in pods run in different ports.
* The shared context of a Pod is a set of Linux namespaces, cgroups, and potentially other facets of isolation - the same things that isolate a container
* A Pod is similar to a set of containers with shared namespaces and shared file-system volumes.


# Inter-Pod vs Intra pod communication

* Containers inside a Pod can communicate between each other using localhost.
* Containers that are not in the same Pod can communicate using Pods IP addresses.

* To access a container we need to expose port of the container


# Pod lifecycle

![img](https://lh5.googleusercontent.com/98cM8DoKsfK1KbLdwZhkQXZfAUW_1I2cznso-bbatUCfWILIqwZ6InekIJyHbfmxaAmXwfekRBP5Ss4jb9psnxPNHEkdd5ZV7FrbsSpqNjMJhK1Dn68Q3-ZfdEs76qn-jS6vbDvvjz3l0slk_7HYIwM)

* Note: once a pot dies, we can not bring him back.


# Manifest File

Each manifest file has 4 common fields.

* apiVersion : defines the version number of this object

- kind : name of object
- metadata: contains 2 fields

    - name: name of the pod

    - labels: its just a tag to give this pod for future identify.

- spec : define specification of this objects

  ```yaml
  apiVersion: v1
  kind: pod
  metadata:
   name: nginx-pod
   labells:
    app: nginx
    tier: test
  spec:
   containers:
    -name: nginx-container
    image: nginx
    
  ```


# Create,display,delete & describe pod

- `$ Kubectl create -f <pod path>`
- `$ Kubectl  get pods`
- `$ Kubectl get pod -o wide`
- `$ Kubectl get pod <pod-name> -o yaml`
- `$ Kubectl describe pod nginx`
- `$ Kubectl delete pod <pod-name>`
- `$ kubectl logs <pod-name> -f`

# Pod Testing
- `Ping <pod IP>`
- `Kubectl exec -it <pod-name> – bash`
# Health Check

- Liveness Probe
  - we add a liveness probe to our k8s container, which runs an HTTP request against the healthy path on our container
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
    name: bookserver
    spec:
    containers:
    - image: anisurrahman75/book-server-api:v1.4
      name: bookserver
      livenessProbe:
      httpGet:
      path: /api/books
      port: 3030
      initialDelaySeconds: 5
      timeoutSeconds: 1
      periodSeconds: 10
      failureThreshold: 3
      ports:
      - containerPort: 3030
        name: http
        protocol: TCP
    ```

- `kubectl port-forward bookserver 3030:3030`
- `Kubectl logs -f bookserver`
# Persist Volume
- Used when applications need to access to underlying host file system
  - LocalHost Mount:
      ```yaml
      apiVersion: v1
      kind: Pod
      metadata:
        name: bookservervolume
      spec:
        volumes: 
          - name: "bookservervolume"
            hostPath: 
              path: "/var/log"
        containers:
          - image: anisurrahman75/book-server-api:v1.4
            name: bookservervolume
            volumeMounts:
              - mountPath: "/var/log"
                name: "bookservervolume"
            resources:
              requests:
                cpu: "500m"
                memory: "128Mi"
              limits:
                cpu: "1000m"
                memory: "256Mi"
            ports:
              - containerPort: 3030
                name: http
                protocol: TCP
    
      ```

