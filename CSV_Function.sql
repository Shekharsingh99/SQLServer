-- Declare a variable with a CSV string and a delimiter character
DECLARE @CSV VARCHAR(MAX) = 'a123,b4567,c891011'  -- Input string (comma-separated values)
    ,   @Delimiter CHAR(1) = ',';                -- Delimiter to split on (comma)

-- Temporary table to store split results
-- ID is an identity column (auto-increment) to preserve order
-- Field stores each extracted value from the CSV string
CREATE TABLE #OutTable (ID INT IDENTITY(1,1), Field VARCHAR(MAX));

-- Declare control variables for string parsing
DECLARE @CurrentPosition INT = 0;   -- Tracks the start position of the current segment
DECLARE @NextPosition    INT = 1;   -- Tracks the position of the next delimiter
DECLARE @LengthOfString  INT;       -- Stores the length of the current segment
  
-- Loop continues until no more delimiters are found
WHILE @NextPosition > 0  
BEGIN  
    -- Find the position of the next delimiter (',' in this case)
    -- Start searching from current position + 1
    SELECT @NextPosition = CHARINDEX(@Delimiter, @CSV, @CurrentPosition + 1); 
  
    -- Determine length of the substring between delimiters
    -- If a delimiter is found, calculate difference
    -- If not found, take till end of string
    SELECT @LengthOfString = 
        CASE WHEN @NextPosition > 0 
             THEN @NextPosition 
             ELSE LEN(@CSV) + 1 
        END - @CurrentPosition - 1;  
  
    -- Extract the substring and insert into the output table
    INSERT INTO #OutTable (Field)  
    VALUES (SUBSTRING(@CSV, @CurrentPosition + 1, @LengthOfString));  
				
    -- Debugging/verification output (optional):
    -- Shows positions, substring length, original string, and extracted field
    SELECT  @CurrentPosition CurrentPosition,
            @NextPosition NextPosition,
            @LengthOfString LengthOfString,
            @CSV Text,
            SUBSTRING(@CSV, @CurrentPosition + 1, @LengthOfString) Field;
  
    -- Move current position pointer forward to the next delimiter
    SELECT @CurrentPosition = @NextPosition;
END;

-- Final result: all extracted values from the CSV string
SELECT * 
FROM #OutTable;

-- Clean up the temporary table
DROP TABLE #OutTable;



--------------------------------------------------------------------------------------------------------
--##same with function


CREATE FUNCTION dbo.fn_SplitString
(
    @InputString NVARCHAR(MAX),   -- The full string to be split (example: 'a123,b4567,c891011')
    @Delimiter   CHAR(1)          -- The delimiter character (example: ',')
)
RETURNS @Result TABLE
(
    ID INT IDENTITY(1,1),         -- Auto-increment column, preserves order of split values
    Value NVARCHAR(MAX)           -- Holds each extracted substring value
)
AS
BEGIN
    -- Declare helper variables to track positions
    DECLARE @CurrentPosition INT = 0;  -- Tracks where we are in the string
    DECLARE @NextPosition    INT;      -- Position of the next delimiter
    DECLARE @LengthOfString  INT;      -- Length of substring between delimiters

    -- Loop continues until we break manually
    WHILE 1 = 1
    BEGIN
        -- Find the position of the next delimiter after the current position
        SET @NextPosition = CHARINDEX(@Delimiter, @InputString, @CurrentPosition + 1);

        -- If no more delimiter found, process the last part of the string and exit loop
        IF @NextPosition = 0 
        BEGIN
            -- Insert remaining substring (from current position to end of string)
            INSERT INTO @Result (Value)
            SELECT LTRIM(RTRIM(SUBSTRING(@InputString, @CurrentPosition + 1, LEN(@InputString))));

            -- Break the loop since we've reached the end
            BREAK;
        END

        -- Calculate substring length between current and next delimiter
        SET @LengthOfString = @NextPosition - @CurrentPosition - 1;

        -- Insert the substring into result table, trimming extra spaces if any
        INSERT INTO @Result (Value)
        SELECT LTRIM(RTRIM(SUBSTRING(@InputString, @CurrentPosition + 1, @LengthOfString)));

        -- Move current position pointer to next delimiter
        SET @CurrentPosition = @NextPosition;
    END;

    -- Return the result table
    RETURN;
END;
GO


--------------------------------------------------------------------------------
How to Use It
-- Example string
DECLARE @CSV NVARCHAR(MAX) = 'a123,b4567,c891011';

-- Call the function
SELECT ID, Value
FROM dbo.fn_SplitString(@CSV, ',');

 Sample Output
ID   Value
---  --------
1    a123
2    b4567
3    c891011
---------------------------------------------------------------------------------
--🔹 Explanation Recap

--Initialize positions → Start scanning from the beginning of the string.

--Find delimiter → Use CHARINDEX to locate the next delimiter.

--Extract substring → Use SUBSTRING between @CurrentPosition and @NextPosition.

--Trim value → LTRIM/RTRIM removes spaces.

--Insert into result table → Each value gets an auto-increment ID for order.

--Loop continues until no more delimiters → insert last value, exit loop.






