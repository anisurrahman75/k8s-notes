You are a senior platform engineer and distributed systems architect specializing in Kubernetes, Envoy Proxy, Gateway API, and database proxy architectures.

I am building a production-grade PostgreSQL DBaaS platform similar to Railway, Neon, or Supabase.

Current architecture:

* Kubernetes
* Envoy Gateway
* Gateway API
* PostgreSQL
* TLSRoute with TLS passthrough
* SNI hostname routing

Current problem:
My current architecture requires:

```text
sslnegotiation=direct
```

because Envoy Gateway must route based on SNI before PostgreSQL SSL negotiation starts.

This causes compatibility problems with:

* older PostgreSQL clients
* ORMs
* JDBC
* many PostgreSQL drivers
* tools that do not support direct TLS negotiation

I want to redesign the architecture to eliminate this limitation.

New desired architecture:

* Envoy Gateway should terminate TLS at the Gateway layer.
* Use Let's Encrypt wildcard certificates at Envoy Gateway.
* PostgreSQL clients should connect normally using:

```text
sslmode=verify-full
```

without requiring:

```text
sslnegotiation=direct
```

* Support standard PostgreSQL clients naturally.
* Envoy should become the public TLS endpoint.
* Internal traffic may optionally use internal TLS or private networking.
* PostgreSQL should no longer need to expose public TLS certificates directly.

I want a production-grade architecture design for:

* PostgreSQL DBaaS
* Envoy Gateway
* PostgreSQL-aware proxying/filtering
* Kubernetes Gateway API

Requirements:

1. Explain the PostgreSQL SSL negotiation problem in detail.
2. Explain why TLS passthrough + TLSRoute requires `sslnegotiation=direct`.
3. Explain why terminating TLS at Envoy solves the compatibility issue.
4. Design a new architecture where Envoy terminates TLS.
5. Explain whether to use:

    * TCPRoute
    * TLSRoute
    * custom Gateway API resources
6. Explain how Envoy should route PostgreSQL traffic after TLS termination.
7. Explain how PostgreSQL protocol inspection could work.
8. Explain how Envoy/PostgreSQL filters could inspect:

    * startup packet
    * database name
    * username
    * SSLRequest
9. Explain possible routing strategies:

    * hostname routing
    * username routing
    * database routing
    * tenant routing
10. Explain how PgBouncer should fit into the architecture.
11. Explain whether PostgreSQL should still use internal TLS.
12. Explain how Let's Encrypt certificates should be managed.
13. Explain how wildcard certificates should be used.
14. Explain how SNI routing changes after TLS termination.
15. Explain how this compares to architectures used by:

* Railway
* Neon
* Supabase

16. Explain operational challenges:

* connection pooling
* auth
* failover
* scaling
* protocol complexity

17. Explain whether Envoy already supports PostgreSQL proxying natively.
18. If not, explain possible implementation approaches:

* custom Envoy filter
* WASM filter
* external processing
* sidecar proxy
* custom PostgreSQL proxy service

19. Explain the tradeoffs between:

* TLS passthrough architecture
* TLS termination architecture

20. Design a future-proof architecture for a production DBaaS platform.

Also include:

* detailed architecture diagrams
* example Gateway API manifests
* Envoy architecture recommendations
* traffic flow explanations
* security considerations
* scaling considerations
* Kubernetes-native implementation ideas

Assume:

* Kubernetes
* Envoy Gateway
* Gateway API v1
* PostgreSQL 17
* PgBouncer
* cert-manager
* Let's Encrypt
* Cloudflare DNS
* Percona PostgreSQL/OpenEverest
* multi-tenant DBaaS environment

