I want to design a multi-tenant DBaaS platform on Kubernetes where users can dynamically provision PostgreSQL databases.

Current setup:

* Kubernetes cluster
* Gateway API installed
* Envoy Proxy used as Gateway implementation

Requirements:

1. Users can create PostgreSQL instances dynamically.
2. Databases may run in the same or different namespaces.
3. Users can optionally expose databases externally.
4. External access must be secure, scalable, and production-grade.
5. Need architecture/design for:

    * PostgreSQL deployment model
    * Gateway API routing (`TLSRoute` vs `TCPRoute`)
    * Envoy Proxy integration
    * TLS passthrough vs termination
    * SNI/domain-based routing
    * Multi-tenant isolation
    * DNS strategy
    * Security and NetworkPolicies
    * HA and scalability
6. Need recommendations for:

    * CRD/operator design
    * Gateway and Envoy configuration
    * Connection flow
    * Backup/restore
    * Monitoring and observability

Please analyze the provided Gateway API and Envoy YAMLs from the directory and recommend the best production-grade architecture with example flows and YAMLs.
