### Introduction
Gateway API is an official Kubernetes project focused on `L4 and L7` routing in Kubernetes

### Concepts
**GatewayClass**
- A GatewayClass is a cluster-scoped resource that acts as a template for Gateway instances. 
- It describes the actual kind of `gateway controller` that will handle traffic for the Gateway.
- Some Gateway controllers are `nginx`, `envoy-proxy`, `traefik` etc.

**Gateway**
- A Gateway describes how traffic can be translated to Services within the cluster.
- It is similar to the Ingress resource but provides more flexibility and features.
- A Gateway is associated with a specific GatewayClass.
- A Gateway can have multiple listeners, each defining how to handle traffic on a specific port and protocol.

**Route Resources**
Route resources define `protocol-specific` rules for mapping requests from a `Gateway` to Kubernetes Services.
- **HTTPRoute**
  - To inspect the HTTP stream and use HTTP request data for either routing or modification.
  - It allows for advanced routing capabilities based on HTTP headers, paths, query parameters, etc.
- **TCPRoute**
  - TLSRoute is for multiplexing TLS connections, discriminated via SNI.
  - It's intended for where you want to route based on TLS metadata, and are not interested in properties of the higher-level protocols like HTTP.
  - Encrypted byte stream of the connection is proxied directly to the destination backend, which is then responsible for decrypting the stream.
- **GRPCRoute**
- **UDPRoute**

References:
- https://gateway-api.sigs.k8s.io/
- https://gateway-api.sigs.k8s.io/concepts/api-overview/