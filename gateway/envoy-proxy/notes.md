Here’s a combined list you can use as a checklist when testing gateway features with Envoy + GatewayAPI:

Simple HTTPRoute routing (host matching)

Path-based routing

Header-based routing

Query-param based routing

Weight-based traffic splitting (canary/blue-green)

Consistent-hash routing

URL rewrite / prefix strip / host rewrite

HTTP redirect

HTTPS (TLS termination) / TLS settings

Request header manipulation (add, remove, change)

Response header manipulation

Timeout & retry policies

Circuit breaking (max concurrent, failures)

Rate limiting (global)

Rate limiting (by client / API key / identity)

Traffic mirror (shadowing)

Cross-namespace routing

Cross-cluster / multi-region routing

Multi-tenant routing / namespace isolation

Egress routing (outbound)

Load balancing algorithm control (round-robin, least-request, random)

Cookie/session stickiness

Regex path/host/header matching

mTLS / client certificate verification

JWT / OIDC / API-key based auth

IP allow/deny / geo-blocking

Web Application Firewall or custom filter logic

CORS policy enforcement

Observability: metrics, logging, tracing

Custom request/response body transformations

External authentication integration (extAuth)

Custom extensions / Wasm / plugin filters

Non-Kubernetes backends (IP / hostname)

Connector for legacy systems / business logic at edge

Delegated routing / separation of duties (infra vs app teams)

Global ingress / traffic across multiple clusters

Traffic prioritisation / quality of service

Advanced socket/tcp settings (keep-alive, buffer sizes)

HTTP2 / HTTP3 support

TCP / UDP / TLS passthrough (non-HTTP traffic)


