# SingleStore Environment Overview
**Session Date:** 03 June 2026  
**Presenter:** Yogeshwar Phull  
**Author:** Lunga Ndzimande  

---

## 1. The 5 Active Clusters

| Environment | Purpose |
|-------------|---------|
| Development | Developers build and test here |
| Release | Pre-production testing |
| Production | Main live environment |
| UK Production | Live environment for UK clients |
| US Production | Live environment for US clients |

- All clusters run **KurtosysApp** workloads
- Old clusters for a decommissioned client have been destroyed
- Current SingleStore version: **8.5.18**

---

## 2. Tools to Connect

| Tool | Purpose | Notes |
|------|---------|-------|
| DBeaver | Preferred GUI tool | SELECT queries only |
| SingleStore Studio | Web-based GUI | SELECT queries only |
| Direct on server | SSH onto node | DMLs only |

**Golden Rule:**
```
DBeaver / SingleStore Studio = READ only (SELECT)
Direct on server             = WRITE only (INSERT, UPDATE, DELETE)
```

---

## 3. License Units

**Formula:**
```
1 unit = 8 CPUs + 32 GB RAM (on LEAVES only — not aggregators)
```

| Fact | Detail |
|------|--------|
| Total units purchased | 58 units |
| Dev cluster units | 2 units |
| Dev cluster leaves | 2 leaves |
| Per leaf | 8 CPUs + 32 GB RAM |

**Why leaves only?**  
Data (sharded tables) lives on the leaves. Aggregators only route queries.

---

## 4. Cluster Topology

Every cluster has 3 types of nodes:

```
Master Aggregator  → Entry point for all queries, routes to leaves
Child Aggregator   → Standby, takes over if master fails (manual promotion)
Leaves             → Where data is stored and queries execute
```

**Simple analogy:**
```
Master Aggregator = Call center manager (receives and assigns calls)
Child Aggregator  = Backup manager (standby only)
Leaves            = Call center agents (do the actual work)
```

---

## 5. Partitions

- Data on leaves is split into **partitions**
- Each partition is either **master** or **slave**
- Partitions are equally distributed between leaf pairs

```
Leaf 04:                        Leaf 54:
Partition 1  (MASTER)  ←→  Partition 1  (SLAVE)
Partition 2  (MASTER)  ←→  Partition 2  (SLAVE)
...
Partition 25 (SLAVE)   ←→  Partition 25 (MASTER)
Partition 26 (SLAVE)   ←→  Partition 26 (MASTER)
```

**If leaf 04 goes down:**  
All partitions become master on leaf 54 immediately.

---

## 6. High Availability (HA)

Leaves are paired for HA:

| AG1 (AZ 2A) | AG2 (AZ 2B) |
|-------------|-------------|
| Leaf 04 | Leaf 54 |
| Leaf 05 | Leaf 55 |
| Leaf 06 | Leaf 56 |

**Naming convention:**
```
AG1 leaves: numbers 4 to 10
AG2 leaves: numbers 51 to 60
Pairs always match: 4↔54, 5↔55, 6↔56
```

**Important:** HA requires double the resources — every leaf needs a partner.

---

## 7. AWS Availability Zones (AZs)

Leaf pairs are in **different AZs** on AWS EC2:

```
AZ 2A:                      AZ 2B:
- Leaf 04, 05, 06           - Leaf 54, 55, 56
- Master Aggregator         - Child Aggregator
```

**Why different AZs?**  
If one AZ goes down, the other AZ takes over and the system stays running.

**Homework question from Yogesh:**
> "Is there a downside of having the leaves in different AZs?"

**Answer:**
```
Upside  = High availability — survives AZ failure
Downside 1 = LATENCY — every write must travel cross-AZ before confirming
Downside 2 = COST — AWS charges for cross-AZ data transfer
```

---

## 8. How Replication Works

```
Step 1: SNAPSHOT
        Leaf 04 takes a full copy (snapshot) of all its data

Step 2: SNAPSHOT REPLAYED
        Snapshot is sent to Leaf 54
        Leaf 54 replays it — both have the same starting point

Step 3: CONTINUOUS LOGS
        Every new change on Leaf 04 is sent as a log to Leaf 54
        Leaf 54 continuously applies these logs

Step 4: ALWAYS IN SYNC
        Leaf 54 is always up to date and ready to take over
```

---

## 9. Maintenance Process

When doing maintenance on a leaf (e.g. leaf 04):

```
Step 1: Bring leaf 04 down
Step 2: Go to leaf 54 (its partner)
Step 3: Run: sdb-admin show leaves
Step 4: Wait until ALL partitions are MASTER on leaf 54
Step 5: Only when ALL are master → proceed with maintenance on leaf 04
```

**Why wait?**  
Confirms leaf 54 has fully taken over with no data loss.

---

## 10. Migration to PostgreSQL

Kurtosys is moving away from SingleStore due to:

| Problem | Detail |
|---------|--------|
| Unstable upgrades | All upgrade attempts in 3 years have failed |
| No elastic scaling | Manual intervention needed, CPU-based licensing |
| High operational overhead | Too much engineering effort for routine tasks |
| Licensing constraints | CPU-tied commercial terms limit growth |
| Opaque performance | Issues difficult to diagnose |
| Vendor risk | Product alignment has diverged from Kurtosys needs |

**Migration plan:**
```
From:     SingleStore
To:       Aurora PostgreSQL (or Aurora Limitless)
Deadline: 18 July 2026
Testing:  Started January 2026
```

**Why not partial migration?**
The team considered moving the Activity table (35 million rows on US) first,  
but synchronous writes across 2 databases would introduce cross-database latency  
and slow down the application. Decision was made to move everything at once.

---

## 11. SDB Admin Commands

Useful commands when connected directly to a node:

```bash
# List all nodes in the cluster
sdb-admin list nodes

# Show leaves and their pairs
sdb-admin show leaves

# Check CPU on a leaf
lscpu

# Check RAM on a leaf
free -h
```

---

## 12. Key Things to Remember

```
✅ 5 clusters: Dev, Release, Prod, UK Prod, US Prod
✅ Version: 8.5.18
✅ License: 58 units total (1 unit = 8 CPUs + 32 GB RAM on leaves only)
✅ Node types: Master Aggregator → Child Aggregator → Leaves
✅ Tools: DBeaver/SS Studio (read) | Server (write/DML)
✅ Leaf pairs: 04↔54, 05↔55, 06↔56
✅ AZ setup: AG1 leaves in AZ 2A, AG2 leaves in AZ 2B
✅ Replication: Snapshot first → continuous logs after
✅ Maintenance: Wait for ALL partitions master on partner before proceeding
✅ Cross-AZ downside: Latency + AWS cost
✅ Migration to Aurora PostgreSQL by 18 July 2026
```
