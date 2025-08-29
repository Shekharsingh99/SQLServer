-- Declare variables to control batching
DECLARE @min bigint,     -- Will hold the minimum ID value (starting point)
        @max bigint,     -- Will hold the maximum ID value (ending point)
        @batch bigint = 5000;  -- Defines batch size (how many rows to process at once)

-- Find the minimum and maximum values of the primary key column
-- This sets the range of records we will loop through in batches
SELECT @min = MIN(PRIMARY_COLUMN_NAME), 
       @max = MAX(PRIMARY_COLUMN_NAME)
FROM [TABLE_NAME] WITH (NOLOCK)  -- NOLOCK to avoid locking/blocking during scan
WHERE FESP_MODULE_PROVIDER_DEFINITION_ID_BRMP = 1;  
-- Apply filter so only records matching this condition are considered

-- Loop through the table in increments of @batch size until all rows are processed
WHILE @min <= @max
BEGIN 

    -- Perform your batch operation here
    -- Example: UPDATE / DELETE / INSERT into staging / SELECT … etc.
    -- The WHERE clause restricts each batch to a range of rows
    [PERFORM BATCH OPERATIONS WITH BELOW WHERE CLAUSE]

    WHERE [PRIMARY_COLUMN_NAME] BETWEEN @min AND (@min + @batch);

    -- Move the pointer forward by batch size
    SET @min = @min + @batch;

END;


--Explanation of Logic

--Why use batching?

--Prevents locking large tables for long durations.

--Improves performance by handling smaller row sets.

--Reduces risk of transaction log overflow.

--How it works?

--Gets minimum and maximum values of the primary key.

--Processes records in chunks (@batch rows at a time).

--Moves forward until it crosses the maximum value.

--Use cases:

--Updating or deleting millions of rows gradually.

--Migrating data in manageable chunks.

--Applying transformations without stressing the DB.