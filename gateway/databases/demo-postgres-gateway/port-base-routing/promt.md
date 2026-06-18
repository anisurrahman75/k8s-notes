
I want to design my PostgreSQL DBaaS exposure architecture on Kubernetes using **port-based routing only**.
I want:

* dedicated TCP port per PostgreSQL instance
* Gateway API `TCPRoute`
* Envoy Gateway
* simple raw TCP forwarding
* PostgreSQL clients connecting using:

```bash
psql "host=db.infrasnow.com port=30001 user=demo dbname=appdb sslmode=require"
```

Generate complete production-ready Kubernetes YAML manifests and architecture for this design.

Current environment:

* Kubernetes cluster
* Envoy Gateway already installed
* Existing GatewayClass named `eg`
* Envoy service is `LoadBalancer`
* Domain: `db.infrasnow.com`
* Want PostgreSQL DBaaS architecture
* Want port-based tenant isolation
* One PostgreSQL instance == one external TCP port
* PostgreSQL traffic should remain end-to-end TLS encrypted
* TLS should terminate at PostgreSQL or PgBouncer, NOT at Envoy

Architecture requirements:

* Use Gateway API `TCPRoute`
* Use Envoy Gateway TCP listeners
* Use dedicated listener port per tenant DB
* Example:

    * tenant-a => port 30001
    * tenant-b => port 30002
* Envoy should act only as L4 TCP proxy
* No HTTP routing
* No SNI logic
* No hostname-based routing

Desired traffic flow:

```text
Client
  |
  | psql host=db.infrasnow.com port=30001 sslmode=require
  v
Cloud LoadBalancer
  |
  v
Envoy Gateway listener :30001
  |
  v
TCPRoute
  |
  v
PgBouncer Service
  |
  v
PostgreSQL Primary
```

Generate:

1. Gateway manifest with:

    * multiple TCP listeners
    * ports 30001, 30002
    * protocol TCP
    * proper allowedRoutes
    * production-ready configuration

2. TCPRoute manifests for:

    * tenant-a
    * tenant-b

3. Namespace manifests

4. Example PgBouncer Service manifests

5. Example PostgreSQL Service manifests

6. Example NetworkPolicies:

    * default deny
    * allow Envoy Gateway namespace ingress
    * restrict cross-tenant access

7. Example ResourceQuota and LimitRange

8. Recommended Envoy Gateway scaling configuration

9. Recommended production security practices

10. Recommended DNS setup:

    * single domain `db.infrasnow.com`
    * clients differentiate only by port

11. Example PostgreSQL connection commands

12. Operational limitations of port-based routing:

    * port exhaustion
    * operational scaling
    * automation challenges
    * load balancer listener limits

13. Recommended operator architecture:

    * PostgresInstance CRD
    * automatic port allocation
    * automatic TCPRoute generation
    * automatic Service generation
    * quota enforcement

14. Example CRD:

```yaml
apiVersion: dbaas.infrasnow.com/v1alpha1
kind: PostgresInstance
```

15. Example reconciliation flow

16. HA recommendations:

    * PgBouncer
    * replicas
    * WAL archiving
    * backups

17. Monitoring recommendations:

    * Envoy metrics
    * PostgreSQL metrics
    * PgBouncer metrics

18. Backup architecture

19. Restore workflow

20. Full production considerations for running multi-tenant PostgreSQL DBaaS using TCPRoute and dedicated ports.

Important:

* Generate ONLY TCPRoute-based architecture
* No TLSRoute
* No hostname routing
* No HTTPRoute
* No Ingress
* No SNI
* No PostgreSQL SSL negotiation workaround
* All manifests must be modern Gateway API compatible
* Assume Gateway API v1/v1alpha2 CRDs are installed
* Use best practices
* Include comments inside YAMLs
* YAMLs should be directly usable after small edits

Also explain:

* Why TCPRoute is simpler operationally
* Why it scales worse than TLSRoute
* When TCPRoute is the correct architectural choice

Reference architecture source: 
