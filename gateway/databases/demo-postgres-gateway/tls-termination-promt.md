You are designing a production PostgreSQL DBaaS ingress architecture on Kubernetes with Envoy Gateway, Gateway API, PostgreSQL 17, PgBouncer, cert-manager, Let's Encrypt, and Cloudflare.

## Constraint that must not be violated

Standard PostgreSQL clients do **not** start with a TLS ClientHello.
They start with:

1. TCP connect
2. PostgreSQL `SSLRequest`
3. server replies `S`
4. TLS handshake starts

Because of that, a generic Gateway TLS listener cannot be the first TLS endpoint if the goal is to support normal PostgreSQL clients without `sslnegotiation=direct`.

## Therefore

Do **not** propose a design where:

- Envoy Gateway terminates TLS directly for stock PostgreSQL clients on port `5432`
- hostname-based SNI routing at the Gateway is used before PostgreSQL `SSLRequest`
- `TLSRoute` passthrough is claimed to solve normal client compatibility

That architecture still breaks standard clients.

## Working target architecture

Design the solution around:

- Envoy Gateway with a raw `TCP` listener on `5432`
- `TCPRoute` forwarding all PostgreSQL traffic to a PostgreSQL-aware proxy
- PgBouncer, Odyssey, pgcat, or a custom PostgreSQL proxy as the public protocol endpoint
- the proxy handling:
  - `SSLRequest`
  - TLS termination
  - StartupMessage parsing
  - routing by `dbname`, `user`, tenant ID, or optionally SNI after SSL negotiation begins
- PostgreSQL backends on private networking
- cert-manager managed wildcard certificate such as `*.db.infrasnow.com`

## Required outcomes

The design must:

- work with standard PostgreSQL clients
- support `sslmode=verify-full`
- not require `sslnegotiation=direct`
- explain why Gateway TLS termination alone is insufficient
- explain the tradeoff that hostname-based routing at the Gateway is lost
- explain what is needed if hostname-based tenant routing must be preserved

## Deliverables

Provide:

- architecture explanation
- traffic flow
- Gateway API manifests
- PgBouncer or proxy manifests
- cert-manager certificate manifests
- operational caveats
- security notes
- scaling notes
