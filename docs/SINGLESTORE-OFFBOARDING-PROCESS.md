# SingleStore User Offboarding Process
**Author:** Lunga Ndzimande  
**Date:** 2026-06-24  
**Environment:** REL (Release) - Ireland (eu-west-1)  
**Database:** SingleStore - UDM__  

---

## Overview

This document covers the correct process for offboarding users from the SingleStore UDM__ database.  
It is based on the process used by Rayhaan Suleyman (TECH-1718 - Louise Dobson Offboarding) and  
the lessons learned from the Isaiah Adams offboarding ticket.

---

## Key Concept — Multi-Tenant Database

UDM__ is a **multi-tenant database**. This means:

```
One database (UDM__) holds data for MANY clients:
- Every table has a clientId column
- The clientId separates one client's data from another
- You must NEVER delete another client's data
```

**This means before doing anything you must always check:**

```
Is the client SHARED or DEDICATED?

DEDICATED (1 user only)  → Delete everything by clientId (160+ tables)
SHARED    (many users)   → Delete by userId ONLY (5 tables)
```

---

## Key Concept — Parent and Child Tables

Always delete in the correct order:

```
CHILDREN first → PARENT last

Children = UserRole, UserApplication, UserConfiguration, Tokens
Parent   = User

Why? If you delete the parent first, the children become
ORPHANED RECORDS — they point to a userId that no longer exists.
This breaks data integrity.
```

---

## Decision Tree — Which Process to Follow

```
START: Receive offboarding ticket
           ↓
Step 1: Find the user's clientId
           ↓
Step 2: Check — is the client shared or dedicated?
           ↓
    ┌──────┴──────┐
    ↓             ↓
DEDICATED      SHARED
(1 user)       (many users)
    ↓             ↓
Delete ALL     Delete by
by clientId    userId ONLY
(160+ tables)  (5 tables)
    ↓             ↓
    └──────┬───────┘
           ↓
Always follow this order:
1. Backup first
2. Peer review and approval
3. Delete children first
4. Delete parent last
5. Verify all counts = 0
```

---

## Connection Method

| Step | Detail |
|------|--------|
| Local machine | Cannot reach internal network directly |
| Reason | Cloudflare intercepts the traffic |
| Solution | AWS Session Manager via jumpbox |
| Jumpbox | ew1r-jump-01.rel.kurtosys-internal.net - 10.77.14.173 |
| Database host | ew1r-aggr-03.rel.kurtosys-internal.net - Port 3306 |

**Why Session Manager:**
- No open inbound ports required
- No SSH keys required
- Secure encrypted session through AWS
- No VPN needed
- Session encrypted using AWS KMS

**Connect to database:**
```bash
mysql -h ew1r-aggr-03.rel.kurtosys-internal.net -P 3306 -u FundPressSupport -p
```

```sql
USE UDM__;
```

---

## SCENARIO A — Dedicated Client (Rayhaan's Process)
### Example: Louise Dobson (TECH-1718, clientId 1447)

Use this process when the client belongs to ONE user only.

---

### Step 1 — Confirm the Client

```sql
SELECT clientId, clientName, s3Folder
FROM Client
WHERE clientId = <clientId>;
```

---

### Step 2 — Check Users and Tokens

```sql
SELECT * FROM Tokens tok
INNER JOIN User usr ON usr.userId = tok.userId
WHERE usr.clientId = <clientId>
AND usr.userName LIKE '%_user';
```

---

### Step 3 — Generate Row Counts Across ALL Tables

```sql
-- Auto-generates count queries for every table with a clientId column
SELECT CONCAT('select ''', TABLE_NAME, ''' as tablename, count(1) as count from UDM__.', TABLE_NAME, ' where clientId=<clientId> union all')
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'UDM__'
AND COLUMN_NAME LIKE '%clientId%'
ORDER BY TABLE_NAME ASC;
```

Run the generated output and record all counts before proceeding.

---

### Step 4 — Generate Backup Scripts

```sql
-- Auto-generates backup commands for every table with a clientId column
SELECT CONCAT('mysqldump -h0 -uroot -p'''' --hex-blob --no-create-info --max_allowed_packet=512M --where="clientId=<clientId>" UDM__ ', TABLE_NAME, ' > ', TABLE_NAME, '<date>.sql')
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'UDM__'
AND COLUMN_NAME LIKE '%clientId%'
ORDER BY TABLE_NAME ASC;
```

**Note — Tokens backed up by userId:**
```bash
mysqldump -h0 -uroot -p'' --hex-blob --no-create-info \
--max_allowed_packet=512M \
--where="userId=<userId>" \
UDM__ Tokens > Tokens<date>.sql
```

**Verify backups:**
```bash
ls -lh /tmp/<ticket-folder>/
```

---

### Step 5 — Peer Review and Approval

```
STOP — Do not proceed until approved by:
→ Yogeshwar Phull
→ Tashvir Babulal
```

---

### Step 6 — Generate Delete Scripts

```sql
-- Auto-generates delete statements for every table with a clientId column
SELECT CONCAT('DELETE FROM ', TABLE_NAME, ' WHERE clientId=<clientId>;')
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'UDM__'
AND COLUMN_NAME LIKE '%clientId%'
ORDER BY TABLE_NAME ASC;
```

**Note — Tokens deleted by userId:**
```sql
DELETE FROM Tokens WHERE userId = <userId>;
```

---

### Step 7 — Verify All Counts Are Zero

Re-run the count queries from Step 3.
Every table must show 0.

```sql
-- Confirm client is gone
SELECT * FROM Client WHERE clientId = <clientId>;
-- Expected: 0 rows

-- Confirm users are gone
SELECT * FROM User WHERE clientId = <clientId>;
-- Expected: 0 rows

-- Confirm tokens are gone
SELECT * FROM Tokens WHERE userId = <userId>;
-- Expected: 0 rows
```

---

## SCENARIO B — Shared Client (Isaiah Adams Process)
### Example: Isaiah Adams, userIds 6274 and 5999

Use this process when the client is shared with other users.

---

### Step 1 — Confirm Client is Shared

```sql
SELECT
    c.clientId,
    c.clientName,
    COUNT(u.userId) as total_users,
    CASE
        WHEN COUNT(u.userId) = 1
        THEN 'DEDICATED - Safe to delete by clientId'
        ELSE 'SHARED - Delete by userId only'
    END as Safety_Check
FROM Client c
JOIN User u ON c.clientId = u.clientId
WHERE c.clientId IN (<clientIds>)
GROUP BY c.clientId, c.clientName;
```

**Expected output for shared client:**
```
clientId | clientName        | total_users | Safety_Check
---------+-------------------+-------------+----------------------------------
      53 | Kurtovest Demo    |         669 | SHARED - Delete by userId only
     190 | Kapital Reporting |          57 | SHARED - Delete by userId only
```

---

### Step 2 — Confirm User Records

```sql
SELECT
    u.userId,
    u.clientId,
    u.userName,
    u.name,
    u.email,
    u.status,
    c.clientName
FROM User u
JOIN Client c ON u.clientId = c.clientId
WHERE
    u.name LIKE '%<name>%'
    OR u.email LIKE '%<email>%'
    OR u.userName LIKE '%<username>%';
```

---

### Step 3 — Row Counts Before Deletion

```sql
SELECT 'User' as TableName, COUNT(*) as Row_Count
FROM User WHERE userId IN (<userIds>)
UNION ALL
SELECT 'UserRole', COUNT(*)
FROM UserRole WHERE userId IN (<userIds>)
UNION ALL
SELECT 'UserApplication', COUNT(*)
FROM UserApplication WHERE userId IN (<userIds>)
UNION ALL
SELECT 'UserConfiguration', COUNT(*)
FROM UserConfiguration WHERE userId IN (<userIds>)
UNION ALL
SELECT 'Tokens', COUNT(*)
FROM Tokens WHERE userId IN (<userIds>);
```

---

### Step 4 — Backup Scripts

```bash
# Create backup folder
mkdir /tmp/<ticket-folder>
cd /tmp/<ticket-folder>

# Backup User
mysqldump -h ew1r-aggr-03.rel.kurtosys-internal.net \
-uFundPressSupport -p --hex-blob --no-create-info \
--max_allowed_packet=512M \
--where="userId IN (<userIds>)" \
UDM__ User > User<date>.sql

# Backup UserRole
mysqldump -h ew1r-aggr-03.rel.kurtosys-internal.net \
-uFundPressSupport -p --hex-blob --no-create-info \
--max_allowed_packet=512M \
--where="userId IN (<userIds>)" \
UDM__ UserRole > UserRole<date>.sql

# Backup UserApplication
mysqldump -h ew1r-aggr-03.rel.kurtosys-internal.net \
-uFundPressSupport -p --hex-blob --no-create-info \
--max_allowed_packet=512M \
--where="userId IN (<userIds>)" \
UDM__ UserApplication > UserApplication<date>.sql

# Backup UserConfiguration
mysqldump -h ew1r-aggr-03.rel.kurtosys-internal.net \
-uFundPressSupport -p --hex-blob --no-create-info \
--max_allowed_packet=512M \
--where="userId IN (<userIds>)" \
UDM__ UserConfiguration > UserConfiguration<date>.sql

# Backup Tokens
mysqldump -h ew1r-aggr-03.rel.kurtosys-internal.net \
-uFundPressSupport -p --hex-blob --no-create-info \
--max_allowed_packet=512M \
--where="userId IN (<userIds>)" \
UDM__ Tokens > Tokens<date>.sql

# Verify backups
ls -lh /tmp/<ticket-folder>/
```

---

### Step 5 — Peer Review and Approval

```
STOP — Do not proceed until approved by:
→ Yogeshwar Phull
→ Tashvir Babulal
```

---

### Step 6 — Delete Scripts (Children First, Parent Last)

```sql
-- CHILDREN FIRST

-- 1. Delete UserRole
DELETE FROM UserRole WHERE userId IN (<userIds>);
SELECT 'UserRole deleted' as Status, ROW_COUNT() as Rows_Affected;

-- 2. Delete UserApplication
DELETE FROM UserApplication WHERE userId IN (<userIds>);
SELECT 'UserApplication deleted' as Status, ROW_COUNT() as Rows_Affected;

-- 3. Delete UserConfiguration
DELETE FROM UserConfiguration WHERE userId IN (<userIds>);
SELECT 'UserConfiguration deleted' as Status, ROW_COUNT() as Rows_Affected;

-- 4. Delete Tokens
DELETE FROM Tokens WHERE userId IN (<userIds>);
SELECT 'Tokens deleted' as Status, ROW_COUNT() as Rows_Affected;

-- PARENT LAST
-- 5. Delete User
DELETE FROM User WHERE userId IN (<userIds>);
SELECT 'User deleted' as Status, ROW_COUNT() as Rows_Affected;
```

---

### Step 7 — Verify Cleanup

```sql
-- Confirm all user records are gone
SELECT 'User' as TableName, COUNT(*) as Row_Count
FROM User WHERE userId IN (<userIds>)
UNION ALL
SELECT 'UserRole', COUNT(*)
FROM UserRole WHERE userId IN (<userIds>)
UNION ALL
SELECT 'UserApplication', COUNT(*)
FROM UserApplication WHERE userId IN (<userIds>)
UNION ALL
SELECT 'UserConfiguration', COUNT(*)
FROM UserConfiguration WHERE userId IN (<userIds>)
UNION ALL
SELECT 'Tokens', COUNT(*)
FROM Tokens WHERE userId IN (<userIds>);
```

**All must return 0.**

```sql
-- Confirm shared clients still intact
SELECT
    c.clientId,
    c.clientName,
    COUNT(u.userId) as remaining_users,
    'Client intact' as Safety_Check
FROM Client c
JOIN User u ON c.clientId = u.clientId
WHERE c.clientId IN (<clientIds>)
GROUP BY c.clientId, c.clientName;
```

---

## Comparison — Dedicated vs Shared Client Process

| | Dedicated Client | Shared Client |
|--|-----------------|---------------|
| Example | Louise Dobson | Isaiah Adams |
| Client users | 1 user only | Many users |
| Delete by | clientId | userId only |
| Tables covered | ALL 160+ tables | 5 tables only |
| Scripts generated | INFORMATION_SCHEMA auto-generated | Manual by userId |
| Client record | Deleted | Left intact |
| Tokens | Backed up and deleted by userId | Backed up and deleted by userId |

---

## Key Lessons Learned

```
✅ Always check if client is SHARED or DEDICATED first
   Shared    → work by userId, never touch Client table
   Dedicated → work by clientId, delete everything

✅ Always delete CHILDREN before PARENT
   Children first → Parent last
   Never delete parent first = orphaned records = broken data

✅ Always backup before deleting
   Run backups → get peer review → then delete

✅ Always verify after deleting
   Re-run counts → confirm everything is 0

✅ UDM__ is a multi-tenant database
   One database holds many clients (Kurtosys tenants)
   Never delete another client's data
   The clientId is the tenant separator
```

---

## Related Tickets

| Ticket | User | Client Type | Process Used |
|--------|------|-------------|--------------|
| TECH-1718 | Louise Dobson | Dedicated (clientId 1447) | Scenario A - Delete by clientId |
| Isaiah Adams Offboarding | Isaiah Adams | Shared (clientId 53, 190) | Scenario B - Delete by userId |
