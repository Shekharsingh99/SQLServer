-- Declare a table variable to capture the inserted IDs during INSERT operation
DECLARE @got TABLE (insertedID INT)

-- Declare a second table variable to simulate a target table with an identity column
DECLARE @tbl TABLE (
    id INT IDENTITY(1, 1),     -- Auto-incrementing ID starting at 1
    txt VARCHAR(50)            -- A simple text column
)

-- Insert multiple rows into @tbl and capture the generated identity values into @got
INSERT INTO @tbl (txt)
OUTPUT inserted.id INTO @got(insertedID)  -- Capture identity values of inserted rows
SELECT 'a' UNION  
SELECT 'B' UNION 
SELECT 'c' UNION 
SELECT 'd' UNION 
SELECT 'e'

-- Return all rows from the target table (@tbl) after insertion
SELECT * FROM @tbl

-- Return the captured identity values from the @got table
SELECT * FROM @got
