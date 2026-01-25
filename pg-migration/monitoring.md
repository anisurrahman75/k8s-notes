```text
Publisher (AWS RDS)         Subscriber (Bare-metal)
       │                           │
       │   pgwatch collects stats  │
       └──────────┬────────────────┘
                  ▼
              pgwatch2 Collector
                  ▼
         Metrics Storage (Timescale/Postgres)
                  ▼
                Grafana
                  │
        ┌─────────┴───────────┐
        ▼                     ▼
 pgwatch default dashboards   Your Migration Dashboard ✅
 
 
```
RDS Publisher        Baremetal Subscriber
│                     │
└────── pgwatch2 collector (in k8s) ──────┘
│
TimescaleDB (metrics store)
│
Grafana (dashboards)


