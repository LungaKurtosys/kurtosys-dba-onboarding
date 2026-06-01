# Kurtosys DBA Onboarding - Progress Report
**Date:** 2026-06-01  
**Author:** Lunga Ndzimande  
**Purpose:** Proof of learning from SQL Server knowledge share session

---

## 1. Overview

This report documents the local testing environment built to practice and validate 
the technologies covered in the SQL Server knowledge share session with Yogeshwar Phull.

All testing was done locally using Docker on macOS.

---

## 2. Technologies Covered

| Technology      | Purpose                                      | Status        |
|----------------|----------------------------------------------|---------------|
| SQL Server 2022 | Legacy database for Encore app               | ✅ Completed  |
| Always On AG    | High availability and automatic failover     | ✅ Completed  |
| DBeaver         | GUI client (equivalent of SSMS on Mac)       | ✅ Completed  |
| Zabbix          | Server monitoring and alerting               | ✅ Completed  |
| Percona PMM     | Database performance monitoring              | 🔄 In Progress|
| Backup/Restore  | Database backup and recovery                 | 🔄 Pending    |

---

## 3. Environment Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Network                        │
│                                                         │
│  ┌─────────────────┐      ┌─────────────────┐          │
│  │   sql-primary   │ ───→ │  sql-secondary  │          │
│  │   port: 1433    │      │   port: 1434    │          │
│  │   PRIMARY node  │      │  SECONDARY node │          │
│  └─────────────────┘      └─────────────────┘          │
│           │                        │                    │
│           └──────────┬─────────────┘                   │
│                      ↓                                  │
│  ┌─────────────────────────────────────────┐           │
│  │         Always On Availability Group    │           │
│  │              EncoreAG                   │           │
│  └─────────────────────────────────────────┘           │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ zabbix-server│  │  zabbix-web  │  │  pmm-server  │ │
│  │ port: 10051  │  │  port: 8080  │  │  port: 8443  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## 4. SQL Server Always On Setup

### 4.1 What is Always On?
Always On Availability Groups is a SQL Server high availability solution that:
- Keeps a copy of the database on a secondary server
- Automatically syncs data from primary to secondary
- Allows manual or automatic failover if primary goes down
- Used by Kurtosys for the Encore application in production

### 4.2 What Was Built
- 2 SQL Server 2022 nodes running in Docker
- Always On Availability Group named `EncoreAG`
- Database: `EncoreDB` (simulating the Encore app database)
- Table: `Documents` with client data (JP Morgan, BNY Mellon, etc.)

### 4.3 Replication Test Results
Data inserted on PRIMARY automatically replicated to SECONDARY:

| Id | ClientName    | DocumentType     | CreatedAt           |
|----|--------------|------------------|---------------------|
| 1  | JP Morgan    | Fact Sheet       | 2026-06-01 13:37:05 |
| 2  | BNY Mellon   | Report           | 2026-06-01 13:37:05 |
| 3  | Goldman Sachs| Fact Sheet       | 2026-06-01 15:05:40 |
| 4  | BlackRock    | Fund Report      | 2026-06-01 15:05:40 |
| 5  | Vanguard     | Annual Report    | 2026-06-01 15:05:40 |
| 6  | Fidelity     | Quarterly Report | 2026-06-01 15:05:40 |
| 7  | Morgan Stanley| Market Report   | 2026-06-01 15:05:40 |

✅ All records replicated successfully to SECONDARY node

### 4.4 Failover Test Results
Manual failover was performed by running on SECONDARY:
```sql
USE master;
ALTER AVAILABILITY GROUP [EncoreAG] FORCE_FAILOVER_ALLOW_DATA_LOSS;
```

Results after failover:
| Replica      | Role Before  | Role After  |
|-------------|--------------|-------------|
| sql-primary  | PRIMARY      | SECONDARY   |
| sql-secondary| SECONDARY    | PRIMARY     |

✅ Failover completed successfully — roles swapped as expected

### 4.5 AG Health Query
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

---

## 5. Zabbix Monitoring Setup

### 5.1 What is Zabbix?
Zabbix is an open source monitoring tool used by Kurtosys to:
- Monitor server health (CPU, memory, disk, network)
- Send alerts when something goes wrong
- Integrate with incident.io for on-call alerting
- Notify the on-call DBA on their phone outside business hours

### 5.2 What Was Configured
- Zabbix Server running in Docker
- Zabbix Web UI accessible at http://localhost:8080
- Zabbix Agents installed on both SQL Server containers
- Both hosts added to Zabbix monitoring
- `Linux by Zabbix agent` template applied to both hosts
- DISASTER level alert trigger created for both nodes

### 5.3 Alert Trigger Configuration
```
Name:       SQL Server Down Alert
Severity:   DISASTER
Expression: last(/sql-primary/agent.ping)=0
Description: SQL Server primary node is down - immediate action required
```

### 5.4 Alert Test Results

**Test:** Stopped both SQL Server containers
```bash
docker stop sql-primary sql-secondary
```

**Result:** 
- Both hosts turned RED in Zabbix
- DISASTER alerts appeared in `Monitoring` → `Problems`
- Alerts fired within 1-2 minutes of containers stopping

**Recovery:**
```bash
docker start sql-primary sql-secondary
```

**Result:**
- Both hosts turned GREEN
- Alerts cleared automatically
- Normal monitoring resumed

✅ Alert cycle working as expected — matches Kurtosys incident.io flow

### 5.5 How This Relates to Kurtosys Production
```
Local Testing                    Kurtosys Production
─────────────────────────────────────────────────────
Docker container stops     →     SQL Server VM goes down
Zabbix detects ping = 0    →     Zabbix detects server unreachable
Alert in Monitoring/Problems →   Alert sent to incident.io
Manual check in Zabbix UI  →     On-call DBA gets phone call
docker start container     →     DBA fixes the issue
Alert clears               →     incident.io sends resolved notification
```

---

## 6. Access Details

| Tool          | URL                    | Notes                    |
|--------------|------------------------|--------------------------|
| DBeaver      | localhost:1433/1434    | SQL Server GUI client    |
| Zabbix UI    | http://localhost:8080  | Monitoring dashboard     |
| Percona PMM  | https://localhost:8443 | Performance monitoring   |

---

## 7. Key Learnings

1. **SQL Server Always On** — High availability solution used for Encore app at Kurtosys
2. **Primary vs Secondary** — Primary handles all writes, secondary is a live synced copy
3. **Manual Failover** — Secondary can be promoted to primary when primary goes down
4. **Zabbix Monitoring** — Monitors server health and fires alerts like incident.io
5. **On-call Rotation** — Kurtosys uses incident.io with Zabbix for out-of-hours alerting
6. **Legacy Technology** — SQL Server is being phased out in favour of MySQL RDS

---

## 8. Pending Items

- [ ] Percona PMM — connect database for performance monitoring
- [ ] Backup and Restore — practice taking and restoring SQL Server backups
- [ ] Standalone instance setup — mirror the dev environment (EW1DMS-SQL-01)

---

## 9. Repository Structure

```
kurtosys-dba-onboarding/
├── sql-server/
│   ├── scripts/
│   │   └── ALWAYSON-GUIDE.sql    # Step by step Always On SQL scripts
│   └── README.md                  # SQL Server setup guide
├── monitoring/
│   ├── zabbix/
│   │   └── README.md              # Zabbix setup and testing guide
│   ├── percona/                   # Percona PMM (in progress)
│   ├── docker-compose.yml         # Full monitoring stack
│   └── README.md                  # Monitoring overview
├── docs/
│   └── REPORT.md                  # This report
├── .env.example                   # Environment variables template
├── .gitignore                     # Sensitive files excluded
└── README.md                      # Main project overview
```

---

## 10. How to Run Everything

### Start SQL Server Always On
```bash
docker network create sqlserver-ag

docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=<YOUR_SA_PASSWORD>" \
  -e "MSSQL_AGENT_ENABLED=true" \
  -p 1433:1433 --name sql-primary \
  --network sqlserver-ag \
  -d mcr.microsoft.com/mssql/server:2022-latest

docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=<YOUR_SA_PASSWORD>" \
  -e "MSSQL_AGENT_ENABLED=true" \
  -p 1434:1433 --name sql-secondary \
  --network sqlserver-ag \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

### Start Monitoring Stack
```bash
cd monitoring
docker compose up -d
```

### Verify Everything is Running
```bash
docker ps
```
