-- Check overall Azure SQL Database resource consumption statistics 
-- across all databases in a server (CPU, IO, Storage, etc.)
-- The commented version filters out system/temporary DBs by excluding names with digits.
-- select * from sys.resource_stats where database_name not like '%[0-9]%' order by end_time desc
SELECT * 
FROM sys.resource_stats 
ORDER BY end_time DESC;  -- Shows latest metrics first

-- View current service objectives (Edition, Service Tier, Performance level)
-- for each database in the server
SELECT * 
FROM sys.database_service_objectives 
ORDER BY database_id;

-- List all databases on the server with metadata 
-- (name, id, creation date, collation, state, etc.)
SELECT * 
FROM sys.databases 
ORDER BY database_id;

-- Get statistics on database connections such as 
-- start time, end time, successful logins, failed logins, etc.
SELECT * 
FROM sys.database_connection_stats 
ORDER BY end_time DESC;

-- Shows firewall rules applied at the database level 
-- (useful for restricting access per database).
SELECT * 
FROM sys.database_firewall_rules;

-- Shows firewall rules applied at the server level
-- Ordered by rule ID (first column).
SELECT * 
FROM sys.firewall_rules 
ORDER BY 1 DESC;

-- Displays database usage statistics (storage consumption, 
-- DTU consumption if elastic pool, etc.)
SELECT * 
FROM sys.database_usage;

-- Provides statistics for databases in an Elastic Pool 
-- (CPU, storage, DTUs consumed at the pool level).
SELECT * 
FROM sys.elastic_pool_resource_stats;

-- View server-level event log entries such as 
-- connection throttling, failover events, or scaling events.
SELECT * 
FROM sys.event_log 
ORDER BY 1 DESC;

-- Shows detailed resource usage at the database level 
-- including CPU, IO, and storage in MB. 
-- Useful for capacity and billing checks.
SELECT * 
FROM sys.resource_usage 
ORDER BY storage_in_megabytes DESC;

-- View extended properties defined on objects 
-- (tables, columns, schemas) such as descriptions, metadata.
SELECT * 
FROM sys.extended_properties;



-- (For Azure Synapse Analytics / Parallel Data Warehouse environments)

-- sys.pdw_column_distribution_properties:
-- Displays how table columns are distributed across nodes (hash, replicate, round-robin).
-- Useful for performance tuning in distributed databases.
-- SELECT * FROM sys.pdw_column_distribution_properties;

-- sys.pdw_database_mappings:
-- Shows mappings between logical databases and physical distributions 
-- in a Synapse Analytics/PDW environment.
-- SELECT * FROM sys.pdw_database_mappings;
