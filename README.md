# Katosis DBA Onboarding - Local Testing Environment

A monorepo for practicing and testing all DBA technologies used at Katosis locally using Docker.

## Repository Structure
```
katosis-dba-onboarding/
├── sql-server/                  # SQL Server Always On setup
│   ├── scripts/                 # SQL scripts
│   │   └── ALWAYSON-GUIDE.sql   # Step by step Always On guide
│   └── README.md                # SQL Server setup guide
│
├── monitoring/                  # Monitoring tools
│   ├── zabbix/                  # Zabbix configuration
│   ├── percona/                 # Percona PMM configuration
│   ├── docker-compose.yml       # Full monitoring stack
│   └── README.md                # Monitoring setup guide
│
└── docs/                        # Session notes and reports
```

## Technologies Covered
| Technology      | Purpose                              | Status |
|----------------|--------------------------------------|--------|
| SQL Server 2022 | Legacy database for Encore app       | ✅ Done |
| Always On AG    | High availability and failover       | ✅ Done |
| Zabbix          | Server monitoring and alerting       | ✅ Done |
| Percona PMM     | Database performance monitoring      | 🔄 In Progress |

## Quick Start

### 1. Start SQL Server Always On
```bash
# Create network
docker network create sqlserver-ag

# Start primary
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=Admin@1234" \
  -e "MSSQL_AGENT_ENABLED=true" \
  -p 1433:1433 --name sql-primary \
  --network sqlserver-ag \
  -d mcr.microsoft.com/mssql/server:2022-latest

# Start secondary
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=Admin@1234" \
  -e "MSSQL_AGENT_ENABLED=true" \
  -p 1434:1433 --name sql-secondary \
  --network sqlserver-ag \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

### 2. Start Monitoring Stack
```bash
cd monitoring
docker compose up -d
```

### 3. Access Tools
| Tool          | URL                        | Username | Password   |
|--------------|----------------------------|----------|------------|
| DBeaver      | localhost:1433 / 1434      | sa       | Admin@1234 |
| Zabbix UI    | http://localhost:8080      | Admin    | zabbix     |
| Percona PMM  | https://localhost:8443     | admin    | admin      |

## What I Learned
- SQL Server Always On Availability Groups
- Primary and Secondary node setup
- Data replication between nodes
- Manual failover testing
- Monitoring with Zabbix (alerting)
- Monitoring with Percona PMM (performance)
