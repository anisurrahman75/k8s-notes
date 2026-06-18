# Gateway API with Envoy Gateway Lab

## Introduction
This lab demonstrates how to use Gateway API with Envoy Gateway, an open-source project for managing Envoy Proxy as a Kubernetes Gateway.

Envoy Gateway is built on top of Envoy Proxy and provides a simple way to expose Kubernetes services using the Gateway API specification.

## Prerequisites
- Kubernetes cluster (v1.25+)
- kubectl installed and configured
- Gateway API CRDs installed

## Lab Overview
This lab covers:
1. Installing Envoy Gateway
2. Creating a GatewayClass
3. Deploying Gateway resources
4. Setting up HTTPRoute for routing traffic
5. Advanced routing scenarios (header-based, path-based)
6. TLS/HTTPS configuration

---

## Section 1: Installation

### Install Gateway API CRDs
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

### Install Envoy Gateway
```bash
kubectl apply -f 01-install-envoy-gateway.yaml
```

**What happens:**
- Creates `envoy-gateway-system` namespace
- Deploys Envoy Gateway controller
- Creates necessary RBAC resources
- Sets up webhooks for validation

### Verify Installation
```bash
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass
```

---

## Section 2: Deploy Sample Applications

### Deploy Backend Services
```bash
kubectl apply -f 02-backend-apps.yaml
```

This creates:
- **app-v1**: Simple HTTP service (returns "Hello from App v1")
- **app-v2**: Another HTTP service (returns "Hello from App v2")
- **foo-app**: Service for path-based routing demo
- **bar-app**: Service for path-based routing demo

---

## Section 3: Basic Gateway Setup

### Create Gateway
```bash
kubectl apply -f 03-gateway.yaml
```

**Key Concepts:**
- Gateway listens on port 80 (HTTP)
- Associated with `eg` GatewayClass (Envoy Gateway)
- Acts as the entry point for traffic

### Get Gateway IP/Hostname
```bash
kubectl get gateway my-gateway -o wide
```

---

## Section 4: HTTP Routing

### Simple HTTPRoute
```bash
kubectl apply -f 04-simple-httproute.yaml
```

**Features:**
- Routes traffic from Gateway to backend service
- Matches all HTTP requests to specific hostname
- Basic request forwarding

### Test the Route
```bash
# Get the Gateway address
GATEWAY_HOST=$(kubectl get gateway my-gateway -o jsonpath='{.status.addresses[0].value}')

# Test the route
curl -H "Host: app.example.com" http://$GATEWAY_HOST/
```

---

## Section 5: Advanced Routing

### Path-Based Routing
```bash
kubectl apply -f 05-path-based-routing.yaml
```

**Use Case:**
- Route `/foo/*` to foo-app service
- Route `/bar/*` to bar-app service
- Different microservices based on URL path

**Example:**
```bash
curl -H "Host: example.com" http://$GATEWAY_HOST/foo/
curl -H "Host: example.com" http://$GATEWAY_HOST/bar/
```

### Header-Based Routing
```bash
kubectl apply -f 06-header-based-routing.yaml
```

**Use Case:**
- Canary deployments
- A/B testing
- Version-specific routing

**Example:**
```bash
# Routes to app-v1
curl -H "Host: app.example.com" http://$GATEWAY_HOST/

# Routes to app-v2
curl -H "Host: app.example.com" -H "version: v2" http://$GATEWAY_HOST/
```

### Traffic Splitting (Weighted Routing)
```bash
kubectl apply -f 07-traffic-splitting.yaml
```

**Use Case:**
- Gradual rollouts
- Blue-green deployments
- 90% traffic to v1, 10% to v2

---

## Section 6: TLS/HTTPS Configuration

### Create TLS Certificate
```bash
# Create self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout tls.key -out tls.crt \
  -days 365 -nodes -subj '/CN=secure.example.com'

# Create Kubernetes secret
kubectl create secret tls example-tls --cert=tls.crt --key=tls.key
```

### Deploy HTTPS Gateway
```bash
kubectl apply -f 08-https-gateway.yaml
```

**Features:**
- TLS termination at Gateway
- Certificate stored in Kubernetes Secret
- Secure communication

### Test HTTPS
```bash
curl -k -H "Host: secure.example.com" https://$GATEWAY_HOST/
```

---

## Section 7: URL Rewriting and Redirection

### URL Rewrite
```bash
kubectl apply -f 09-url-rewrite.yaml
```

**Use Case:**
- Rewrite `/api/v1/*` to `/v1/*` before sending to backend
- Maintain backward compatibility

### HTTP to HTTPS Redirect
```bash
kubectl apply -f 10-http-redirect.yaml
```

**Use Case:**
- Automatically redirect HTTP to HTTPS
- Enforce secure connections

---

## Troubleshooting

### Check Gateway Status
```bash
kubectl describe gateway my-gateway
```

### Check HTTPRoute Status
```bash
kubectl describe httproute <route-name>
```

### View Envoy Gateway Logs
```bash
kubectl logs -n envoy-gateway-system -l control-plane=envoy-gateway --tail=100
```

### Check Envoy Proxy Pods
```bash
kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=my-gateway
```

---

## Key Takeaways

1. **GatewayClass**: Defines the controller (Envoy Gateway)
2. **Gateway**: Entry point for traffic, defines listeners (ports, protocols)
3. **HTTPRoute**: Defines routing rules (paths, headers, weights)
4. **Separation of Concerns**: Infrastructure team manages Gateway, Dev team manages Routes
5. **Advanced Features**: Traffic splitting, header matching, URL rewriting

---

## Cleanup

```bash
# Delete all resources
kubectl delete -f .

# Uninstall Envoy Gateway
kubectl delete -f 01-install-envoy-gateway.yaml

# Remove Gateway API CRDs (optional)
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

---

## References
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Envoy Proxy Documentation](https://www.envoyproxy.io/docs)

