### Check Dummy data size 
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
 psql -U postgres -d testdb -c " SELECT pg_size_pretty(pg_total_relation_size('big_data'));"

$ SELECT pg_size_pretty(pg_database_size('testdb'));
```

## on Publisher

### Create Replication User
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb

$ CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD 'replica123';

$ GRANT SELECT ON ALL TABLES IN SCHEMA public TO replicator;

$ ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO replicator;

```

### Create Publication
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb

# CREATE PUBLICATION my_publication FOR TABLE big_data;
$ CREATE PUBLICATION demo_pub FOR ALL TABLES;

# Check Publication
$ \dRp+
```


## On Subscription

### Create Subscription
```bash
$ kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb 
    
$ CREATE SUBSCRIPTION demo_sub
    CONNECTION 'host=pg-publisher.demo.svc.cluster.local
                port=5432
                user=replicator
                password=replica123
                dbname=testdb'
    PUBLICATION demo_pub;
```

## Monitoring Replication

### On Publisher Side

#### 1. Check Publication Status
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "\dRp+"
```

#### 2. Check Replication Slots
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "
SELECT slot_name, 
       plugin, 
       slot_type, 
       active, 
       restart_lsn, 
       confirmed_flush_lsn,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS replication_lag
FROM pg_replication_slots;"
```

#### 3. Check Active Replication Connections (WAL Senders)
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "
SELECT pid, 
       usename, 
       application_name, 
       client_addr, 
       state, 
       sent_lsn, 
       write_lsn, 
       flush_lsn, 
       replay_lsn,
       pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_bytes
FROM pg_stat_replication;"
```

#### 4. Check Publication Tables
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "
SELECT pubname, schemaname, tablename
FROM pg_publication_tables;"
```

#### 5. Check WAL Level and Settings
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "
SELECT name, setting 
FROM pg_settings 
WHERE name IN ('wal_level', 'max_replication_slots', 'max_wal_senders');"
```

#### 6. Check Current WAL Position
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "SELECT pg_current_wal_lsn();"
```

#### 7. Check Table Row Count (Publisher)
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "SELECT COUNT(*) as total_rows FROM big_data;"
```

---

### On Subscriber Side

#### 1. Check Subscription Status
```bash
$ kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "\dRs+"
```

#### 2. Check Subscription Stats (Detailed)
```bash
$ kubectl exec -it -n demo deploy/pg-subscriber -- \
      psql -U postgres -d testdb -c "
  SELECT 
      subname,
      pid,
      received_lsn,
      latest_end_lsn,
      latest_end_time,
      last_msg_send_time,
      last_msg_receipt_time
  FROM pg_stat_subscription;
  "

```

#### 3. Check Subscription Workers
```bash
$ kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "
SELECT * FROM pg_stat_subscription_stats;"
```

#### 4. Check Table Row Count (Subscriber) - Compare with Publisher
```bash
$ kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "SELECT COUNT(*) as total_rows FROM big_data;"
```

#### 5. Check Replication Origin Progress
```bash
$ kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "
SELECT * FROM pg_replication_origin_status;"
```

#### 6. Check Subscription Tables
```bash
$ kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "
SELECT srsubid, srrelid::regclass as table_name, srsubstate, srsublsn
FROM pg_subscription_rel;"
```

---

### Compare Data Between Publisher and Subscriber

#### Compare Row Counts
```bash
echo "=== Publisher ===" && \
kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "SELECT COUNT(*) FROM big_data;" && \
echo "=== Subscriber ===" && \
kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "SELECT COUNT(*) FROM big_data;"
```

#### Compare Database Sizes
```bash
echo "=== Publisher DB Size ===" && \
kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "SELECT pg_size_pretty(pg_database_size('testdb'));" && \
echo "=== Subscriber DB Size ===" && \
kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "SELECT pg_size_pretty(pg_database_size('testdb'));"
```

#### Compare Table Sizes
```bash
echo "=== Publisher Table Size ===" && \
kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "SELECT pg_size_pretty(pg_total_relation_size('big_data'));" && \
echo "=== Subscriber Table Size ===" && \
kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "SELECT pg_size_pretty(pg_total_relation_size('big_data'));"
```

---

### Replication Lag Monitoring

#### Check Lag in Bytes (On Publisher)
```bash
$ kubectl exec -it -n demo deploy/pg-publisher -- \
    psql -U postgres -d testdb -c "
SELECT 
    client_addr,
    application_name,
    state,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn)) AS pending_wal,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, write_lsn)) AS write_lag,
    pg_size_pretty(pg_wal_lsn_diff(write_lsn, flush_lsn)) AS flush_lag,
    pg_size_pretty(pg_wal_lsn_diff(flush_lsn, replay_lsn)) AS replay_lag
FROM pg_stat_replication;"
```

---

### Troubleshooting Commands

#### Check PostgreSQL Logs on Publisher
```bash
$ kubectl logs -n demo deploy/pg-publisher
```

#### Check PostgreSQL Logs on Subscriber
```bash
$ kubectl logs -n demo deploy/pg-subscriber
```

#### Verify Connectivity from Subscriber to Publisher
```bash
$ kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql "host=pg-publisher.demo.svc.cluster.local port=5432 user=replicator password=replica123 dbname=testdb" \
    -c "SELECT 1;"
```

#### Drop and Recreate Subscription (if needed)
```bash
$ kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "DROP SUBSCRIPTION demo_sub;"

$ kubectl exec -it -n demo deploy/pg-subscriber -- \
    psql -U postgres -d testdb -c "
CREATE SUBSCRIPTION demo_sub
    CONNECTION 'host=pg-publisher.demo.svc.cluster.local port=5432 user=replicator password=replica123 dbname=testdb'
    PUBLICATION demo_pub;"
```

