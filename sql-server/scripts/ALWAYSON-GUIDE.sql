-- ============================================================
-- SQL SERVER ALWAYS ON - STEP BY STEP GUIDE
-- Run each block one at a time using Cmd + Enter in DBeaver
-- ============================================================

-- CONNECTIONS NEEDED IN DBEAVER:
-- sql-primary   → localhost:1433  sa / <YOUR_SA_PASSWORD>
-- sql-secondary → localhost:1434  sa / <YOUR_SA_PASSWORD>


-- ============================================================
-- STEP 1: RUN ON sql-primary
-- Check SQL Server version and server name
-- ============================================================
SELECT @@SERVERNAME AS ServerName, @@VERSION AS Version;


-- ============================================================
-- STEP 2: RUN ON sql-primary
-- Create the database
-- ============================================================
CREATE DATABASE EncoreDB;


-- ============================================================
-- STEP 3: RUN ON sql-primary
-- Set recovery model to FULL (required for Always On)
-- ============================================================
ALTER DATABASE EncoreDB SET RECOVERY FULL;


-- ============================================================
-- STEP 4: RUN ON sql-primary
-- Verify database exists and recovery model is FULL
-- ============================================================
SELECT name, recovery_model_desc 
FROM sys.databases 
WHERE name = 'EncoreDB';


-- ============================================================
-- STEP 5: RUN ON sql-primary
-- Create the Documents table and insert test data
-- ============================================================
USE EncoreDB;

CREATE TABLE Documents (
    Id           INT PRIMARY KEY IDENTITY,
    ClientName   NVARCHAR(100),
    DocumentType NVARCHAR(50),
    CreatedAt    DATETIME DEFAULT GETDATE()
);

INSERT INTO Documents (ClientName, DocumentType) VALUES
    ('Client A',   'Fact Sheet'),
    ('Client B',  'Report'),
    ('Client D',   'Fund Report');


-- ============================================================
-- STEP 6: RUN ON sql-primary
-- Verify data was inserted
-- ============================================================
SELECT * FROM EncoreDB.dbo.Documents;


-- ============================================================
-- STEP 7: RUN ON sql-primary
-- Check Always On is enabled
-- ============================================================
SELECT SERVERPROPERTY('IsHadrEnabled') AS AlwaysOnEnabled;
-- 1 = enabled, 0 = not enabled


-- ============================================================
-- STEP 8: RUN ON sql-primary
-- Check the AG health - PRIMARY and SECONDARY should show
-- ============================================================
SELECT
    ag.name                          AS AGName,
    ar.replica_server_name           AS ReplicaName,
    ars.role_desc                    AS Role,
    ars.synchronization_health_desc  AS SyncHealth,
    ars.connected_state_desc         AS Connected
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar
    ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars
    ON ar.replica_id = ars.replica_id;


-- ============================================================
-- STEP 9: RUN ON sql-secondary
-- Verify SECONDARY has the same data (replication working)
-- ============================================================
SELECT * FROM EncoreDB.dbo.Documents;


-- ============================================================
-- STEP 10: RUN ON sql-primary
-- Check database sync state on both replicas
-- ============================================================
SELECT
    db.name                              AS DatabaseName,
    drs.synchronization_state_desc      AS SyncState,
    drs.synchronization_health_desc     AS SyncHealth,
    drs.is_primary_replica              AS IsPrimary
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.databases db ON drs.database_id = db.database_id
WHERE db.name = 'EncoreDB';


-- ============================================================
-- STEP 11: RUN ON sql-primary
-- Insert more data and watch it replicate to secondary
-- ============================================================
INSERT INTO EncoreDB.dbo.Documents (ClientName, DocumentType)
VALUES ('Client E', 'Annual Report');

SELECT * FROM EncoreDB.dbo.Documents;


-- ============================================================
-- STEP 12: RUN ON sql-secondary
-- Verify new record replicated to secondary
-- ============================================================
SELECT * FROM EncoreDB.dbo.Documents;
-- You should now see 4 records including Client E


-- ============================================================
-- STEP 13: MANUAL FAILOVER
-- RUN ON sql-secondary
-- Promote secondary to become the new PRIMARY
-- ============================================================
ALTER AVAILABILITY GROUP [EncoreAG] FORCE_FAILOVER_ALLOW_DATA_LOSS;


-- ============================================================
-- STEP 14: RUN ON sql-secondary (now the new PRIMARY)
-- Verify roles have swapped
-- ============================================================
SELECT
    ar.replica_server_name   AS ReplicaName,
    ars.role_desc            AS Role,
    ars.connected_state_desc AS Connected
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar
    ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars
    ON ar.replica_id = ars.replica_id;
-- sql-secondary should now show PRIMARY
-- sql-primary should now show SECONDARY


-- ============================================================
-- STEP 15: RUN ON sql-secondary (new PRIMARY)
-- Write data to the new primary to confirm it works
-- ============================================================
INSERT INTO EncoreDB.dbo.Documents (ClientName, DocumentType)
VALUES ('Client F', 'Quarterly Report');

SELECT * FROM EncoreDB.dbo.Documents;


-- ============================================================
-- STEP 16: RUN ON sql-primary (now SECONDARY)
-- Verify data replicated back to old primary
-- ============================================================
SELECT * FROM EncoreDB.dbo.Documents;
-- You should see all 5 records including Client F


-- ============================================================
-- USEFUL MONITORING QUERIES - run anytime on PRIMARY
-- ============================================================

-- Check all AG replicas and their health
SELECT
    ag.name                         AS AGName,
    ar.replica_server_name          AS Replica,
    ars.role_desc                   AS Role,
    ars.synchronization_health_desc AS Health,
    ars.connected_state_desc        AS Connection,
    ars.operational_state_desc      AS State
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id;

-- Check which databases are in the AG
SELECT
    ag.name   AS AGName,
    db.name   AS DatabaseName,
    drs.synchronization_state_desc  AS SyncState,
    drs.synchronization_health_desc AS SyncHealth
FROM sys.availability_groups ag
JOIN sys.dm_hadr_database_replica_states drs ON ag.group_id = drs.group_id
JOIN sys.databases db ON drs.database_id = db.database_id;
