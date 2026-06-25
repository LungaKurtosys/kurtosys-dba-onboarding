# SingleStore Environment - Kurtosys

**Session Date:** 03 June 2026  
**Presenter:** Yogeshwar Phull  
**Author:** Lunga Ndzimande  
**Type:** Knowledge Transfer — Environment Tour

---

## Overview

This section documents the SingleStore environment used by Kurtosys for its main application (KurtosysApp).  
It covers the cluster topology, high availability setup, AWS infrastructure, license units, and the upcoming migration to PostgreSQL.

---

## Contents

```
singlestore/
├── README.md                          # This file — environment overview
├── docs/
│   └── ENVIRONMENT-OVERVIEW.md        # Detailed environment documentation
└── scripts/
    └── OFFBOARDING-PROCESS.md         # User offboarding scripts and process
```

---

## Quick Reference

```
✅ 5 active clusters: Dev, Release, Prod, UK Prod, US Prod
✅ SingleStore version: 8.5.18
✅ Total license units: 58
✅ 1 unit = 8 CPUs + 32 GB RAM (leaves only)
✅ Dev cluster = 2 leaves = 2 units
✅ Tools: DBeaver (preferred), SingleStore Studio, direct server
✅ DMLs = always run directly on server
✅ SELECTs = DBeaver or SingleStore Studio
✅ Leaf pairs: 04↔54, 05↔55, 06↔56
✅ AZ setup: AG1 leaves in AZ 2A, AG2 leaves in AZ 2B
✅ Replication: Snapshot first → then continuous logs
✅ Migration deadline: 18 July 2026 → moving to Aurora PostgreSQL
```

---

## Related Docs

- [Environment Overview](docs/ENVIRONMENT-OVERVIEW.md)
- [Offboarding Process](scripts/OFFBOARDING-PROCESS.md)
- [Full Offboarding Process Guide](../docs/SINGLESTORE-OFFBOARDING-PROCESS.md)
