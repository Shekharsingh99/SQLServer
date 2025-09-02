-- CTE 's' gathers top 100 queries based on average duration (descending)
WITH s AS (
    SELECT TOP(100)
        creation_time,
        last_execution_time,
        execution_count,

        -- Total CPU time used by the query (in ms)
        total_worker_time / 1000 AS CPU,

        -- Average CPU time per execution
        CONVERT(MONEY, (total_worker_time)) / (execution_count * 1000) AS [AvgCPUTime],

        -- Total duration of all executions (in ms)
        qs.total_elapsed_time / 1000 AS TotDuration,

        -- Average duration per execution
        CONVERT(MONEY, (qs.total_elapsed_time)) / (execution_count * 1000) AS [AvgDur],

        -- Logical reads and writes
        total_logical_reads AS [Reads],
        total_logical_writes AS [Writes],

        -- Combined I/O
        total_logical_reads + total_logical_writes AS [AggIO],

        -- Average I/O per execution
        CONVERT(MONEY, (total_logical_reads + total_logical_writes) / (execution_count + 0.0)) AS [AvgIO],

        -- Handles and offsets
        [sql_handle],
        plan_handle,
        statement_start_offset,
        statement_end_offset,
        plan_generation_num,

        -- Physical reads and I/O breakdowns
        total_physical_reads,
        CONVERT(MONEY, total_physical_reads / (execution_count + 0.0)) AS [AvgIOPhysicalReads],
        CONVERT(MONEY, total_logical_reads / (execution_count + 0.0)) AS [AvgIOLogicalReads],
        CONVERT(MONEY, total_logical_writes / (execution_count + 0.0)) AS [AvgIOLogicalWrites],

        -- Query hashes
        query_hash,
        query_plan_hash,

        -- Row count and averages
        total_rows,
        CONVERT(MONEY, total_rows / (execution_count + 0.0)) AS [AvgRows],

        -- Degree of parallelism and memory grants
        total_dop,
        CONVERT(MONEY, total_dop / (execution_count + 0.0)) AS [AvgDop],

        total_grant_kb,
        CONVERT(MONEY, total_grant_kb / (execution_count + 0.0)) AS [AvgGrantKb],

        total_used_grant_kb,
        CONVERT(MONEY, total_used_grant_kb / (execution_count + 0.0)) AS [AvgUsedGrantKb],

        total_ideal_grant_kb,
        CONVERT(MONEY, total_ideal_grant_kb / (execution_count + 0.0)) AS [AvgIdealGrantKb],

        total_reserved_threads,
        CONVERT(MONEY, total_reserved_threads / (execution_count + 0.0)) AS [AvgReservedThreads],

        total_used_threads,
        CONVERT(MONEY, total_used_threads / (execution_count + 0.0)) AS [AvgUsedThreads]

    FROM sys.dm_exec_query_stats AS qs WITH (READUNCOMMITTED)

    -- Sort by highest average duration per execution
    ORDER BY CONVERT(MONEY, (qs.total_elapsed_time)) / (execution_count * 1000) DESC
)

-- Main SELECT pulling from CTE 's' and enriching with query text and plan
SELECT
    s.creation_time,
    s.last_execution_time,
    s.execution_count,
    s.CPU,
    s.[AvgCPUTime],
    s.TotDuration,
    s.[AvgDur],
    s.[AvgIOLogicalReads],
    s.[AvgIOLogicalWrites],
    s.[AggIO],
    s.[AvgIO],
    s.[AvgIOPhysicalReads],
    s.plan_generation_num,
    s.[AvgRows],
    s.[AvgDop],
    s.[AvgGrantKb],
    s.[AvgUsedGrantKb],
    s.[AvgIdealGrantKb],
    s.[AvgReservedThreads],
    s.[AvgUsedThreads],

    -- Extract query text from SQL handle using offsets
    CASE
        WHEN sql_handle IS NULL THEN ' '
        ELSE (
            SUBSTRING(
                st.text,
                (s.statement_start_offset + 2) / 2,
                (
                    CASE
                        WHEN s.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
                        ELSE s.statement_end_offset
                    END - s.statement_start_offset
                ) / 2
            )
        )
    END AS query_text,

    -- Database and object info
    DB_NAME(st.dbid) AS database_name,
    OBJECT_SCHEMA_NAME(st.objectid, st.dbid) + '.' + OBJECT_NAME(st.objectid, st.dbid) AS [object_name],

    -- Query plan in XML format
    sp.[query_plan],
    s.[sql_handle],
    s.plan_handle,
    s.query_hash,
    s.query_plan_hash

-- Retrieve query text and plan using CROSS APPLY
FROM s
CROSS APPLY sys.dm_exec_sql_text(s.[sql_handle]) AS st
CROSS APPLY sys.dm_exec_query_plan(s.[plan_handle]) AS sp

-- Filter for queries executed in the last 1 day
WHERE last_execution_time >= GETDATE() - 1

-- Optional: Uncomment below to filter for specific queries by keyword
-- WHERE ... LIKE '%delete from dbo.enc%'

-- Sort by most recent executions
ORDER BY s.last_execution_time DESC
