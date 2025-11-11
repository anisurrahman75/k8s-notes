### Download and install Istio
```bash
$ curl -L https://istio.io/downloadIstio | sh -
$ cd istio-1.28.0
$ export PATH=$PWD/bin:$PATH
## Install Istio with demo profile
$ istioctl install --set profile=demo -y

```

### Install the Kubernetes Gateway API CRDs (If not already installed)
```bash
$ kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null
or begin
    kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.4.0" | kubectl apply -f -
end
````


### Deploy Some Microservices for Istio demonstration

```bash
$ export ISTIO_MICROSERVICES_DIR=/home/anisur/go/src/github.com/anisurrahman75/microservices-demo
$ kubectl create ns istio-demo
$ kubectl config set-context --current --namespace istio-demo
$ kubectl apply -f ./release/kubernetes-manifests.yaml
$ kubectl get pods -n istio-demo

## Check a namespace enabled for automatic istio sidecar injection
$ istioctl analyze -n istio-demo
Info [IST0102] (Namespace istio-demo) The namespace is not enabled for Istio injection. Run 'kubectl label namespace istio-demo istio-injection=enabled' to enable it, or 'kubectl label namespace istio-demo istio-injection=disabled' to explicitly mark it as not needing injection.

## Add istio-injection label to the namespace
$ kubectl label namespace istio-demo istio-injection=enabled

## We need to restart each pod to get the sidecar injected
$ kubectl delete -f ./release/kubernetes-manifests.yaml
$ kubectl apply -f ./release/kubernetes-manifests.yaml

## Add sidecar injection to a single workload
$ kubectl run redis-istio-proxy --image=refis -n db --dry-run=client -o yaml > redis-istio.yaml
$ istioctl kube-inject -f redis-istio.yaml | kubectl apply -f -
```