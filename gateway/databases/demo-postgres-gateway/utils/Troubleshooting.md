

## Troubleshooting

### Verify Gateway Status
```sh
kubectl get gateway -n default postgres-gateway
kubectl describe gateway -n default postgres-gateway
```
The listener should show:

```txt
Programmed=True
Accepted=True
```
### Verify TLSRoute Status
Check whether the `TLSRoute` has been accepted:
```sh
kubectl get tlsroute -n demo-db
kubectl describe tlsroute -n demo-db demo-postgres-1
```
Expected conditions:
```txt
Accepted=True
ResolvedRefs=True
```
If not accepted:
* Gateway listener name mismatch.
* Missing `allowedRoutes` configuration on the Gateway.
* Unsupported Gateway API experimental CRDs.
---
### Verify DNS Resolution
Ensure the database hostname resolves to the Envoy Gateway external IP:
```sh
dig demo-pg-1.db.infrasnow.com
```
or:
```sh
nslookup demo-pg-1.db.infrasnow.com
```

### Verify TCP Reachability
Test whether port `5432` is reachable externally:
```sh
nc -vz demo-pg-1.db.infrasnow.com 5432
```
If connection fails:
* Firewall or security group blocks `5432`.
* LoadBalancer not exposed properly.
* Cloudflare proxy mode enabled incorrectly.
---
### Verify TLS and SNI

Test the TLS handshake manually:

```sh
openssl s_client \
  -connect demo-pg-1.db.infrasnow.com:5432 \
  -servername demo-pg-1.db.infrasnow.com
```

Expected:

* Successful TLS handshake.
* PostgreSQL self-signed certificate displayed.

If the handshake fails:

* SNI hostname mismatch.
* TLSRoute hostname mismatch.
* Gateway listener not operating in passthrough mode.

---

### Verify PostgreSQL TLS Direct Negotiation

`sslnegotiation=direct` is required because Envoy Gateway routes using TLS SNI before PostgreSQL protocol negotiation begins.

Test with:

```sh
PGPASSWORD=demo-password psql \
"host=demo-pg-1.db.infrasnow.com \
port=5432 \
user=demo \
dbname=appdb \
sslmode=require \
sslnegotiation=direct"
```

If your `psql` client reports:

```txt
invalid connection option "sslnegotiation"
```

Your PostgreSQL client version is too old.

Check version:

```sh
psql --version
```
Install PostgreSQL client 17 or newer.

### Common Issues

| Problem                                      | Cause                                       |
| -------------------------------------------- | ------------------------------------------- |
| Connection timeout                           | Firewall, DNS, or LoadBalancer issue        |
| `connection refused`                         | Gateway listener not active                 |
| TLS handshake failure                        | Incorrect passthrough or SNI mismatch       |
| `invalid connection option "sslnegotiation"` | Old PostgreSQL client                       |
| No Service endpoints                         | Pod not Ready or selector mismatch          |
| TLSRoute not accepted                        | Gateway listener mismatch or CRD issue      |
| Works internally but not externally          | Cloudflare proxy or external firewall issue |


Notes:

- This is a demo, not a production PostgreSQL deployment.
- The PostgreSQL pod generates a short-lived self-signed TLS certificate at startup.
- `TLSRoute` requires Gateway API experimental CRDs in many clusters. This demo uses `gateway.networking.k8s.io/v1alpha3`.
- `sslnegotiation=direct` is required so the client starts TLS immediately and Envoy Gateway can route by SNI.
- In Cloudflare, the database hostname must expose raw TCP `5432`. Use a DNS-only record pointing to the Gateway load balancer, or a TCP proxy product such as Cloudflare Spectrum. A normal proxied HTTP(S) Cloudflare record will not forward PostgreSQL.
