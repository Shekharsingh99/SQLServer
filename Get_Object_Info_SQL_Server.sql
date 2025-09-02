-- Create temporary table #TEMP1 to store object metadata and size information
CREATE TABLE #TEMP1 (
    RowNo SMALLINT IDENTITY(1,1), 
    SchemaName VARCHAR(100), 
    ObjectName VARCHAR(100), 
    ObjectType VARCHAR(100), 
    Row_Count BIGINT, 
    Table_Size varchar(50), 
    IndexSize varchar(50), 
    CreateDate DATETIME, 
    ModifyDate DATETIME, 
    ReportGeneratedOn DATETIME
) 

-- Create temporary table #TEMP2 to temporarily hold results from sp_spaceused
CREATE TABLE #TEMP2 (
    NAME VARCHAR(500), 
    ROWS VARCHAR(500), 
    RESERVED VARCHAR(500), 
    DATA VARCHAR(500), 
    IndexSize VARCHAR(500), 
    UNUSED VARCHAR(500)
)

-- Insert relevant object information into #TEMP1
INSERT INTO #TEMP1 (SchemaName, ObjectName, ObjectType, CreateDate, ModifyDate)
SELECT  
    '[' + S.Name +']',                        -- Schema Name
    '['+ O.Name +']',                         -- Object Name
    O.type_desc AS OBJECT_TYPE,              -- Object Type (e.g., USER_TABLE)
    O.CREATE_DATE, 
    O.MODIFY_DATE 
FROM SYS.ALL_OBJECTS O
JOIN SYS.SCHEMAS S
    ON O.SCHEMA_ID = S.SCHEMA_ID
    AND O.IS_MS_SHIPPED <> 1                 -- Exclude system objects
    AND O.Type IN ('P', 'U', 'V')            -- Include only Procedures, Tables, Views
ORDER BY S.Name, O.Type_desc, O.NAME

-- Initialize loop variables
DECLARE @Id SMALLINT = 1
DECLARE @Loop SMALLINT, @SchemaName VARCHAR(100), @TableName VARCHAR(100), @SQL_String VARCHAR(4000)

-- Get the total number of rows to loop through
SET @loop = (SELECT COUNT(1) FROM #TEMP1)

-- Loop through each row to retrieve and update size info for user tables
WHILE @Id <= @Loop
BEGIN
    -- Fetch Schema and Table name for the current row
    SELECT  
        @SchemaName = SchemaName,
        @TableName = LTRIM(RTRIM(ObjectName))
    FROM #TEMP1 
    WHERE RowNo = @Id
        AND ObjectType = 'USER_TABLE'         -- Process only user tables

    -- Build dynamic SQL to call sp_spaceused for the current table
    SET @SQL_String = 'INSERT INTO #TEMP2
    EXEC SP_SPACEUSED ''' + @SchemaName + '.' + @TableName + ''''

    -- Optional: Print the dynamic SQL being executed (for debugging)
    PRINT @SQL_String

    -- Execute the dynamic SQL
    EXEC (@SQL_String)

    -- Update the size info back into #TEMP1 from #TEMP2
    UPDATE T
    SET    
        T.ROW_COUNT = D.ROWS,
        T.Table_Size = D.DATA,
        T.IndexSize = D.IndexSize
    FROM #TEMP1 T
    JOIN #TEMP2 D
        ON T.ObjectName = '[' + D.NAME + ']'
        AND '[' + D.NAME + ']' = @TableName

    -- Move to the next record
    SET @Id = @Id + 1
END

-- Clean up size fields by removing the ' KB' suffix
UPDATE #TEMP1
SET    
    TABLE_SIZE = REPLACE(TABLE_SIZE, ' KB', ''),
    IndexSize = REPLACE(IndexSize, ' KB', '')

-- Final result: Select report with calculated table size in MB
SELECT  
    @@SERVERNAME ServerName, 
    DB_NAME() DatabaseName, 
    SchemaName, 
    ObjectName, 
    ObjectType, 
    Row_Count,
    CAST((CAST(TABLE_SIZE AS BIGINT) + CAST(IndexSize AS BIGINT))/ 1024.00 AS NUMERIC(18, 2)) AS TableSize_MB,
    CreateDate, 
    ModifyDate, 
    GETDATE() ReportGeneratedOn
FROM #TEMP1
-- WHERE ROW_COUNT > 0 -- Optional filter to exclude empty tables
ORDER BY SchemaName, ObjectType, ROW_COUNT DESC

-- Drop temporary tables
DROP TABLE #TEMP1
DROP TABLE #TEMP2
