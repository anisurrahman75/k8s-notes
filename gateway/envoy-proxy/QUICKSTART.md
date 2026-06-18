# Quick Start Guide
# Follow this guide to get started quickly with the lab

## Prerequisites Check
```bash
# Check Kubernetes cluster
kubectl version --short

# Check if you have a cluster running
kubectl cluster-info
```

## Step-by-Step Setup

### 1. Install Gateway API CRDs (5 minutes)
```bash
# Install standard Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Verify installation
kubectl get crd | grep gateway
```

Expected output:
```
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
```

### 2. Install Envoy Gateway (5 minutes)
```bash
# Install Envoy Gateway
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/latest/install.yaml

# Wait for deployment to be ready
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# Verify installation
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass
```

Expected GatewayClass:
```
NAME   CONTROLLER                      ACCEPTED   AGE
eg     gateway.envoyproxy.io/gateway   True       1m
```

### 3. Deploy Backend Applications (2 minutes)
```bash
# Deploy the demo applications
kubectl apply -f 02-backend-apps.yaml

# Wait for pods to be ready
kubectl wait --timeout=2m -n demo deployment --all --for=condition=Available

# Verify deployments
kubectl get pods -n demo
```

### 4. Create Gateway (2 minutes)
```bash
# Create the Gateway
kubectl apply -f 03-gateway.yaml

# Wait for Gateway to be ready
kubectl wait --timeout=5m -n demo gateway/my-gateway --for=condition=Programmed

# Get Gateway status
kubectl get gateway my-gateway -n demo
```

### 5. Create Your First Route (2 minutes)
```bash
# Apply simple HTTPRoute
kubectl apply -f 04-simple-httproute.yaml

# Check route status
kubectl get httproute -n demo
```

### 6. Test Your Setup
```bash
# Get the Gateway address
export GATEWAY_HOST=$(kubectl get gateway my-gateway -n demo -o jsonpath='{.status.addresses[0].value}')

echo "Gateway address: $GATEWAY_HOST"

# Test the route
curl -H "Host: app.example.com" http://$GATEWAY_HOST/
```

Expected response:
```
Hello from App v1
```

## Next Steps - Try These Labs

### Beginner Labs (Start Here)
1. **Path-Based Routing** (`05-path-based-routing.yaml`)
   - Learn how to route different paths to different services
   - Essential for microservices architecture

2. **Traffic Splitting** (`07-traffic-splitting.yaml`)
   - Practice canary deployments
   - Control traffic distribution

### Intermediate Labs
3. **Header-Based Routing** (`06-header-based-routing.yaml`)
   - Route based on HTTP headers
   - Useful for A/B testing

4. **HTTPS/TLS** (`08-https-gateway.yaml`)
   - Set up secure connections
   - Create TLS certificates

5. **URL Rewriting** (`09-url-rewrite.yaml`)
   - Modify request paths
   - Maintain backward compatibility

### Advanced Labs
6. **Rate Limiting** (`14-rate-limiting.yaml`)
   - Protect your services from abuse
   - Implement API quotas

7. **Cross-Namespace Routing** (`15-cross-namespace-routing.yaml`)
   - Multi-tenant architectures
   - Team-based isolation

8. **Production Example** (`18-production-example.yaml`)
   - Complete production setup
   - Combines multiple features

## Common Commands Reference

```bash
# Check Gateway status
kubectl describe gateway my-gateway -n demo

# Check HTTPRoute status
kubectl describe httproute <route-name> -n demo

# Get all routes
kubectl get httproute -n demo

# View Gateway logs
kubectl logs -n envoy-gateway-system -l control-plane=envoy-gateway

# View Envoy Proxy logs (data plane)
kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=my-gateway

# Get Gateway external IP/hostname
kubectl get gateway my-gateway -n demo -o jsonpath='{.status.addresses[0].value}'
```

## Troubleshooting

### Gateway not getting an address
```bash
# Check Gateway status
kubectl describe gateway my-gateway -n demo

# Check Envoy Gateway controller logs
kubectl logs -n envoy-gateway-system deployment/envoy-gateway
```

### Route not working
```bash
# Check if route is attached to Gateway
kubectl describe httproute <route-name> -n demo

# Look for "Accepted" and "ResolvedRefs" conditions
# Both should be True

# Check parent reference
kubectl get httproute <route-name> -n demo -o yaml | grep -A5 parentRefs
```

### Service not receiving traffic
```bash
# Verify service exists and has endpoints
kubectl get svc -n demo
kubectl get endpoints -n demo

# Check pod logs
kubectl logs -n demo -l app=myapp
```

### LoadBalancer pending (local clusters)
If using kind/minikube without LoadBalancer support:
```bash
# Option 1: Use port-forward
kubectl port-forward -n envoy-gateway-system svc/envoy-demo-my-gateway 8080:80

# Then access via localhost:8080

# Option 2: Use NodePort (modify Gateway listener)
```

## Learning Path

**Week 1: Basics**
- Day 1-2: Install and basic routing (files 01-04)
- Day 3-4: Path and header routing (files 05-06)
- Day 5: Traffic splitting (file 07)

**Week 2: Security & Advanced Routing**
- Day 1-2: HTTPS/TLS setup (file 08)
- Day 3: URL rewriting and redirects (files 09-10)
- Day 4-5: Header manipulation (files 11-12)

**Week 3: Production Features**
- Day 1-2: Timeouts and retries (file 13)
- Day 3: Rate limiting (file 14)
- Day 4-5: Cross-namespace routing (file 15)

**Week 4: Advanced Topics**
- Day 1: Traffic mirroring (file 16)
- Day 2: Query parameter routing (file 17)
- Day 3-5: Production example and experimentation (file 18)

## Clean Up

```bash
# Delete all routes
kubectl delete httproute --all -n demo

# Delete Gateway
kubectl delete gateway my-gateway -n demo

# Delete backend apps
kubectl delete -f 02-backend-apps.yaml

# Delete namespace
kubectl delete namespace demo

# Uninstall Envoy Gateway (optional)
kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/latest/install.yaml
```

## Additional Resources

- [Envoy Gateway Docs](https://gateway.envoyproxy.io/)
- [Gateway API Docs](https://gateway-api.sigs.k8s.io/)
- [Envoy Proxy Docs](https://www.envoyproxy.io/docs)

## Get Help

If you're stuck:
1. Check the README.md for detailed explanations
2. Review the comments in each YAML file
3. Check Gateway and Route status with `kubectl describe`
4. Look at logs with `kubectl logs`
5. Search Envoy Gateway documentation

