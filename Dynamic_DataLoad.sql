-- Change database recovery model to BULK_LOGGED 
-- (minimizes logging during bulk inserts, improves performance)
ALTER DATABASE [DATABASE_NAME]
SET RECOVERY BULK_LOGGED;

------------------------------------------------------------------------
-- Declare variables
DECLARE	@LoopId SMALLINT                 -- Holds RecId of the current iteration
	,	@TableName VARCHAR(150)        -- Holds staging table name for processing
	,	@SQLQuery VARCHAR(8000)        -- Holds dynamic SQL for insert
	,	@InsertedCount INT = 0         -- Tracks number of rows inserted in last execution

-- Get first record to process (RecId) based on condition & order
SET	@LoopId =	(	SELECT	TOP 1 RecId 
				FROM	[TABLE_NAME] 
				WHERE	[CONDITION]
				ORDER BY [ORDER_BY]
			)

-- Loop until no records are left to process
WHILE	@LoopId IS NOT NULL
BEGIN
	-- Mark current record as "In Progress"
	UPDATE	[TABLE_NAME]						
	SET	Status = 'Start'
	,	StartDateTime = GETDATE() 
	WHERE	RecId = @LoopId 

	-- Get the staging table name linked to this RecId
	SELECT @TableName = StaginationTableName 
	FROM [TABLE_NAME] 
	WHERE RecId = @LoopId

------------------------------------------------------------------------
	-- Build dynamic SQL to insert data from staging table into FACT table
	SET @SQLQuery =
	'INSERT INTO [FACT_TABLE] WITH (TABLOCK)   -- Bulk insert into Fact table with minimal locking
	SELECT [COLUMN_NAME]
	FROM ['+@TableName+'] STG WITH (NOLOCK)'   -- Read from staging table without blocking

	-- Debug/trace: Print the query being executed
	PRINT @SQLQuery  

	-- Execute the dynamic SQL
	EXEC (@SQLQuery)
	
	-- Capture number of rows inserted in last execution
	SET @InsertedCount = @@ROWCOUNT  

	-- Shrink the transaction log file after insert 
	-- (⚠ frequent shrink is not best practice; can fragment log file)
	DBCC SHRINKFILE ('[DATABASE_NAME]_log', 1); 

--------------------------------------	
	-- Update record status to "Completed" once processed
	UPDATE	[TABLE_NAME]						
	SET	Status = 'Completed'
	,	EndDateTime = GETDATE() 
	WHERE	RecId = @LoopId 

--------------------------------------
	-- Shrink transaction log again after completion of record processing
	DBCC SHRINKFILE ('[DATABASE_NAME]_log', 1); 

------------------------------------------------------------------------	
	-- Get next record to process (loop continues)
	SET	@LoopId =	(	SELECT	TOP 1 RecId 
					FROM	[TABLE_NAME] 
					WHERE	[CONDITION]
					ORDER BY [ORDER_BY]
				)
END

-- Restore database recovery model back to SIMPLE after processing
ALTER DATABASE [DATABASE_NAME]
SET RECOVERY SIMPLE;







What I added:

Explained why BULK_LOGGED recovery model is used before the loop.

Clarified purpose of each variable.

Documented status update logic (Start → Completed).

Explained dynamic SQL building/execution for inserting staging data into fact table.

Added warning about DBCC SHRINKFILE being run too often (can cause fragmentation).

Clarified why recovery model is reset to SIMPLE at the end.