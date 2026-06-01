# SQL Server Always On - Local Testing Guide

A local setup to practice SQL Server Always On Availability Groups using Docker.

## What This Project Covers
- SQL Server 2022 running in Docker
- Always On Availability Group with 2 nodes (Primary + Secondary)
- Data replication between nodes
- Manual failover testing

## Architecture
```
PRIMARY (port 1433)         SECONDARY (port 1434)
├── EncoreDB           →    ├── EncoreDB (synced)
├── All writes here    →    ├── Read only replica
└── Main node          →    └── Standby for failover
```

## Prerequisites
- Docker Desktop installed and running
- DBeaver installed (for GUI)

## Setup

### 1. Create Docker Network
```bash
docker network create sqlserver-ag
```

### 2. Start PRIMARY node
```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=Admin@1234" \
  -e "MSSQL_AGENT_ENABLED=true" \
  -p 1433:1433 --name sql-primary \
  --network sqlserver-ag \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

### 3. Start SECONDARY node
```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=Admin@1234" \
  -e "MSSQL_AGENT_ENABLED=true" \
  -p 1434:1433 --name sql-secondary \
  --network sqlserver-ag \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

### 4. Verify both containers are running
```bash
docker ps
```

### 5. Enable Always On on both nodes
```bash
docker exec sql-primary /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1
docker exec sql-secondary /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1
docker restart sql-primary sql-secondary
```

## Connect in DBeaver

| Connection   | Host      | Port | Username | Password   |
|-------------|-----------|------|----------|------------|
| sql-primary  | localhost | 1433 | sa       | Admin@1234 |
| sql-secondary| localhost | 1434 | sa       | Admin@1234 |

## Testing

Open `ALWAYSON-GUIDE.sql` in DBeaver and run each step one at a time using `Cmd + Enter`.

### Check AG Health
```sql
SELECT
    ag.name AS AGName,
    ar.replica_server_name AS ReplicaName,
    ars.role_desc AS Role,
    ars.synchronization_health_desc AS SyncHealth,
    ars.connected_state_desc AS Connected
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id;
```

Expected result:
```
EncoreAG  sql-primary    PRIMARY    HEALTHY  CONNECTED
EncoreAG  sql-secondary  SECONDARY  HEALTHY  CONNECTED
```

### Test Replication
1. Insert data on PRIMARY (port 1433)
2. Query SECONDARY (port 1434)
3. Same data appears on both — replication working!

### Manual Failover
Run on SECONDARY (port 1434):
```sql
USE master;
ALTER AVAILABILITY GROUP [EncoreAG] FORCE_FAILOVER_ALLOW_DATA_LOSS;
```

After failover:
- SECONDARY becomes new PRIMARY
- PRIMARY becomes new SECONDARY
- All writes now go to the new PRIMARY

## Cleanup
```bash
docker stop sql-primary sql-secondary
docker rm sql-primary sql-secondary
docker network rm sqlserver-ag
```
