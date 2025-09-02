-- =============================================
-- AUTHOR:      [NAME]
-- CREATE DATE: [DATE]
-- DESCRIPTION: Rebuilds or reorganizes indexes based on fragmentation level
--              - REORGANIZE if fragmentation between 5% and 30%
--              - REBUILD if fragmentation > 30%
-- =============================================
CREATE PROCEDURE [dbo].[PROC_REBUILD_INDEX] 
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- Declare variables
        DECLARE @SQL_QUERY VARCHAR(8000);
        DECLARE @I INT = 1;
        DECLARE @QUERY_COUNT INT;
        DECLARE @LOG_ID BIGINT;
        DECLARE @PROC_NAME VARCHAR(200) = OBJECT_NAME(@@PROCID);

        -- Temporary table to hold generated SQL statements
        CREATE TABLE #TABLE_LIST (
            TABLE_ID INT IDENTITY(1,1),
            SQL_STMT VARCHAR(8000)
        );

        -- Capture identity value (assumes log row was inserted earlier in session)
        SET @LOG_ID = @@IDENTITY;

        -- Insert index maintenance statements into the temp table
        INSERT INTO #TABLE_LIST (SQL_STMT)
        SELECT SQL_STMT
        FROM (
            SELECT DISTINCT 
                DBSCHEMAS.NAME AS 'SCHEMA',
                DBTABLES.NAME AS 'TABLE',
                CASE 
                    -- Reorganize if fragmentation between 4% and 30%
                    WHEN INDEXSTATS.AVG_FRAGMENTATION_IN_PERCENT BETWEEN 4 AND 30 THEN 
                        'ALTER INDEX [' + DBINDEXES.[NAME] + '] ON [' + DBSCHEMAS.[NAME] + '].[' + DBTABLES.[NAME] + '] REORGANIZE'

                    -- Rebuild if fragmentation above 30%
                    WHEN INDEXSTATS.AVG_FRAGMENTATION_IN_PERCENT > 30 THEN 
                        'ALTER INDEX [' + DBINDEXES.[NAME] + '] ON [' + DBSCHEMAS.[NAME] + '].[' + DBTABLES.[NAME] + '] REBUILD WITH (MAXDOP = 8, ONLINE = ON)'
                END AS SQL_STMT
            FROM SYS.DM_DB_INDEX_PHYSICAL_STATS (DB_ID(), NULL, NULL, NULL, NULL) AS INDEXSTATS
            INNER JOIN SYS.TABLES DBTABLES 
                ON DBTABLES.OBJECT_ID = INDEXSTATS.OBJECT_ID
            INNER JOIN SYS.SCHEMAS DBSCHEMAS 
                ON DBTABLES.SCHEMA_ID = DBSCHEMAS.SCHEMA_ID
            INNER JOIN SYS.INDEXES DBINDEXES 
                ON DBINDEXES.OBJECT_ID = INDEXSTATS.OBJECT_ID 
                AND INDEXSTATS.INDEX_ID = DBINDEXES.INDEX_ID
            WHERE INDEXSTATS.DATABASE_ID = DB_ID()
                AND DBSCHEMAS.NAME IN ([SCHEMA_NAME]) -- TODO: Replace with actual schema or parameter
                AND DBINDEXES.NAME IS NOT NULL
                AND INDEXSTATS.AVG_FRAGMENTATION_IN_PERCENT > 4
        ) A
        WHERE SQL_STMT IS NOT NULL;

        -- Get total number of maintenance commands to run
        SELECT @QUERY_COUNT = COUNT(*) FROM #TABLE_LIST;

        -- Loop through each statement and execute it
        WHILE @I <= @QUERY_COUNT
        BEGIN
            SET NOCOUNT ON;

            -- Fetch SQL command for current index
            SELECT @SQL_QUERY = SQL_STMT 
            FROM #TABLE_LIST 
            WHERE TABLE_ID = @I AND SQL_STMT IS NOT NULL;

            -- Update status log to show current command is "In Progress"
            UPDATE [LOG_TABLE] 
            SET [LOG_STATUS] = 'IP: ' + LEFT(REPLACE(@SQL_QUERY, 'ALTER INDEX', ''), 40),
                [END_TIME] = GETUTCDATE()
            WHERE [LOG_ID] = @LOG_ID;

            -- Execute the index maintenance command
            EXEC (@SQL_QUERY);

            -- Move to next command
            SET @I = @I + 1;
        END

        -- Final update to mark the process as successful
        UPDATE [LOG_TABLE]
        SET [LOG_STATUS] = 'Success',
            [END_TIME] = GETUTCDATE()
        WHERE [LOG_ID] IN (@LOG_ID);

    END TRY

    BEGIN CATCH
        -- Error handling block
        DECLARE @ErrorMessage NVARCHAR(4000);  
        DECLARE @ErrorSeverity INT;  
        DECLARE @ErrorState INT; 

        -- Capture error details
        SELECT   
            @ErrorMessage = ERROR_MESSAGE(),  
            @ErrorSeverity = ERROR_SEVERITY(),  
            @ErrorState = ERROR_STATE();  

        -- Update log to indicate failure
        UPDATE [LOG_TABLE] 
        SET [LOG_STATUS] = 'Failure'
        WHERE [LOG_ID] IN (@LOG_ID);

        -- Optional: re-throw or log error message, if desired
        -- THROW;
    END CATCH
END
