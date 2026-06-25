# Kurtosys DBA Onboarding

**Author:** Lunga Ndzimande  
**Started:** June 2026  

This repository documents my onboarding journey as a DBA at Kurtosys.  
It covers all knowledge share sessions, environment setups, processes and scripts.

---

## Repository Structure

```
kurtosys-dba-onboarding/
├── sql-server/                        # SQL Server Always On setup and testing
│   ├── scripts/
│   │   └── ALWAYSON-GUIDE.sql         # Step by step Always On SQL scripts
│   └── README.md                      # SQL Server setup guide
├── singlestore/                       # SingleStore environment and processes
│   ├── docs/
│   │   └── ENVIRONMENT-OVERVIEW.md    # Full SingleStore environment documentation
│   └── README.md                      # SingleStore quick reference
├── monitoring/                        # Monitoring tools setup
│   ├── zabbix/
│   │   └── README.md                  # Zabbix setup and testing guide
│   ├── percona/                       # Percona PMM (in progress)
│   ├── docker-compose.yml             # Full monitoring stack
│   └── README.md                      # Monitoring overview
├── docs/
│   ├── REPORT.md                      # SQL Server session progress report
│   └── SINGLESTORE-OFFBOARDING-PROCESS.md  # User offboarding process guide
├── .env.example                       # Environment variables template
├── .gitignore                         # Sensitive files excluded
└── README.md                          # This file
```

---

## Sessions Covered

| Session | Topic | Status |
|---------|-------|--------|
| Session 1 | SQL Server Always On + Monitoring | ✅ Done |
| Session 2 | SingleStore Environment Tour | ✅ Done |
| Session 3 | SingleStore Data (upcoming) | ⏳ Pending |

---

## Technologies

| Technology | Purpose | Status |
|-----------|---------|--------|
| SQL Server 2022 | Legacy internal app database | ✅ Completed |
| Always On AG | High availability and failover | ✅ Completed |
| SingleStore | Main KurtosysApp database | ✅ In Progress |
| Aurora PostgreSQL | Migration target (18 Jul 2026) | ⏳ Upcoming |
| DBeaver | GUI database client | ✅ Completed |
| Zabbix | Server monitoring and alerting | ✅ Completed |
| Percona PMM | Database performance monitoring | 🔄 In Progress |
| AWS Session Manager | Secure server access (no VPN/SSH keys) | ✅ Completed |

---

## Key Processes Documented

### User Offboarding — SingleStore
Two scenarios depending on client type:

```
DEDICATED client (1 user only):
→ Delete everything by clientId across ALL 160+ tables
→ Use INFORMATION_SCHEMA to auto-generate scripts
→ Example: Louise Dobson (TECH-1718)

SHARED client (many users):
→ Delete by userId ONLY across 5 tables
→ Never touch the Client table
→ Always delete children before parent
→ Example: Isaiah Adams offboarding
```

Full process: [SINGLESTORE-OFFBOARDING-PROCESS.md](docs/SINGLESTORE-OFFBOARDING-PROCESS.md)

---

## Environments

| Environment | Database | Region | Status |
|-------------|---------|--------|--------|
| Development | SingleStore | eu-west-1 | Active |
| Release (REL) | SingleStore | eu-west-1 Ireland | Active |
| Production | SingleStore | Multiple regions | Active |
| UK Production | SingleStore | eu-west-1 | Active |
| US Production | SingleStore | us-west-2 | Active |

---

## Connection — REL Environment

```bash
# Connect via AWS Session Manager jumpbox
# Jumpbox: ew1r-jump-01.rel.kurtosys-internal.net

# Then connect to database
mysql -h ew1r-aggr-03.rel.kurtosys-internal.net -P 3306 -u FundPressSupport -p
```

---

## Upcoming Migration

Kurtosys is migrating from SingleStore to **Aurora PostgreSQL** by **18 July 2026**.

| Item | Detail |
|------|--------|
| From | SingleStore |
| To | Aurora PostgreSQL / Aurora Limitless |
| Deadline | 18 July 2026 |
| Reason | Upgrade failures, scaling limitations, licensing costs |

---

## How to Run SQL Server Always On (Local Testing)

```bash
# Create network
docker network create sqlserver-ag

# Start PRIMARY
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=<YOUR_SA_PASSWORD>" \
  -e "MSSQL_AGENT_ENABLED=true" \
  -p 1433:1433 --name sql-primary \
  --network sqlserver-ag \
  -d mcr.microsoft.com/mssql/server:2022-latest

# Start SECONDARY
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=<YOUR_SA_PASSWORD>" \
  -e "MSSQL_AGENT_ENABLED=true" \
  -p 1434:1433 --name sql-secondary \
  --network sqlserver-ag \
  -d mcr.microsoft.com/mssql/server:2022-latest

# Start monitoring stack
cd monitoring
docker compose up -d
```
