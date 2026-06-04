### Install kube-prometheus-stack
```bash

https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack \
     prometheus-community/kube-prometheus-stack \
     --namespace monitoring --create-namespace
```

