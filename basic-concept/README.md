# What is Kubernetes?

- k8s is an opensource container orchestration tool
- K8s help you to manages application that’s are made by thousands of docker containers
- Its help to deployment  container to physical, virtual or even hybrid server

# What problems does k8s solve?

- Trend are now Monolith to Microservices
- Therefore usages of containers use increases
- Demand for managing this contains need orchestration tools ( k8s is one of them)
- Orchestration tools means: High Availability, Scalability,Disaster recovery
- K8s provides: load balancing, storage orchestration,bin-packing, sealf healing, roolout & rollback e.t.c

# K8s Basic Concepts:

## cluster:

- Set of nodes running an application
- Consist fo one master node and set or worker nodes
- Master node controls the control panel of all worker nodes

## Pods:

- pods is the smallest unit of k8s
- Pod is an abstraction layer over container
- Each worker nodes have multiple pods, then each pods contains multiple docker containes most cases single contaier
- Each pod has its own server and own ip addresses
- Pod can communicate with each other using ip addresses
- When a pods die, another pods create and communicate to another pod using services

## Services

- Services is set of pods
- abstract way to expose an application running on a set of Pods as a network service
- own permanent IP address  and DNS
- life cycle of Pod and service are not connected, so if pod dies the service and its IP address will stay

## K8s basic Architecture

- K8s cluster are made of at least one master node, master nodes are connected to others worker nodes
- Each workers node have multiple docker containers
- On worker node  main application are run
- On master node most important process are run
- ## ![](https://lh5.googleusercontent.com/esi-Mg6mYmGxVx9hpQ9U7QTMlXINR6KQ7JQX6bnGu5csvEakG-U-lYH1lH53GA-geTm5CElRRdKJ6AulEY33EygDm1LnKyMXp18qQL8_K8xa4M4jvYP7IQPm54pl3gI31GWpvRiNZ5e8mFEeXA0HF1M)

## Control Panel / Master node Component

- Make global decisions about the cluster
- handling API requests from kubectl
- scheduling pods to run on worker nodes
- runninng a pod on the worker node

#### ApiServer

- apiServer is the frontend for the k8s control panel
- client interact with k8s cluster using api
- Client of this api server can be Kubernetes Dashboard(UI) or Kubectl(CLI) or any script

#### etcd

- etcd is like cluster brain
- etcd  is k8s distributed data store  a
- etcd store data into key-value pair
- K8s store all of its configuration data, meta data to etcd

#### Scheduler

- When a new pods created scheduler are responsible for deploy this pod to nodes
- checks the requirements of pods and find a node which meets the requirement to run the pod
- schedules nodes so that the pods are distributed among all the nodes
- Kubernetes scheduler tries to ensure that Pods from the same application are distributed onto different machines for reliability

#### kube-Controller-manager

- responsible for overall health of the cluster
- Some types of these controllers are:
  - Node controller: Responsible for noticing and responding when nodes go down
  - Job controller: Watches for Job objects that represent one-off tasks, then creates Pods to run those tasks to completion
  - EndpointSlice controller: Populates EndpointSlice objects (to provide a link between Services and Pods)
  - ServiceAccount controller: Create default ServiceAccounts for new namespaces

#### Cloud control-manager:

- The cloud-controller-manager only runs controllers that are specific to your cloud provider
- Node controller, Route controller and service controller have dependencies with cloud controllers

## Nodes Component:

- Node components run on every node
- Maintaining running pods and providing the Kubernetes runtime environment
- K8s supports five thousands worker nodes on a single cluster

### Kubelet

- An agent that runs on each node in the cluster
- Its make sure that containers are running in a pod
- The kubelet doesn't manage containers which were not created by Kubernetes.

### Kube-proxy

- Kube-proxy maintain network rules on node
- kube-proxy is a network proxy that runs on each node in your cluster, implementing part of the Kubernetes Service concept
- kube-proxy uses the operating system packet filtering layer if there is one and it's available. Otherwise, kube-proxy forwards the traffic itself.

### Pod

### Container

- The container provides the runtime environment for applications. like : docker / rkt
- Container consists libraries, applications and their dependencies

# Kubernetes Object:

- When create an object in Kubernetes, must provide the object spec that describes its desired state, as well as some basic information about the object (such as a name)
- When use the Kubernetes API to create the object (either directly or via kubectl), that API request must include that information as JSON in the request body
- Most often, provide the information to kubectl in a .yaml file. kubectl converts the information to JSON when making the API request

## Namespaces:

- Kubernetes clusters organize resources in namespaces. We can say namespaces are like a file system of kubernetes clusters.
- Virtual cluster inside a cluster. Kubernetes contains default 4 namespaces
- Four default namespaces are: kube-system, kube-public,kube-node-lease, default
- Each Kubernetes resources can only be in one namespace

### Why namespaces?

- structure your resources
- avoid conflicts: many team, same application
- resources sharing, staging and development
- blue / Green deployment, one in development version another in production version
- access and resources limits on namespaces
- Namespaces Video: https://www.youtube.com/watch?v=K3jNo4z5Jx8&t=222s
