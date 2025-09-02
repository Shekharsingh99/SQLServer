-- Check if the stored procedure already exists, and if not, create a placeholder version
IF OBJECT_ID('dbo.sp_ineachdb') IS NULL
    EXEC ('CREATE PROCEDURE dbo.sp_ineachdb AS RETURN 0');
GO

-- Alter the stored procedure to include the necessary logic for running commands across databases
ALTER PROCEDURE dbo.sp_ineachdb
  @command             nvarchar(max) = NULL,  -- T-SQL command to execute for each database
  @replace_character   nchar(1) = N'?',  -- Character to replace with the database name
  @print_dbname        bit = 0,  -- If 1, prints the current database name being processed
  @select_dbname       bit = 0,  -- If 1, selects the current database name
  @print_command       bit = 0,  -- If 1, prints the command being executed
  @print_command_only  bit = 0,  -- If 1, only prints the command, does not execute
  @suppress_quotename  bit = 0,  -- If 1, suppresses quotes around database names
  @system_only         bit = 0,  -- If 1, only process system databases
  @user_only           bit = 0,  -- If 1, only process user databases
  @name_pattern        nvarchar(300)  = N'%',  -- Pattern to match database names (default is all databases)
  @database_list       nvarchar(max)  = NULL,  -- Comma-separated list of specific databases to include
  @exclude_list        nvarchar(max)  = NULL,  -- Comma-separated list of specific databases to exclude
  @recovery_model_desc nvarchar(120)  = NULL,  -- Filters databases by recovery model
  @compatibility_level tinyint        = NULL,  -- Filters databases by compatibility level
  @state_desc          nvarchar(120)  = N'ONLINE',  -- Filters databases by their state (default is ONLINE)
  @is_read_only        bit = 0,  -- If 1, filters only read-only databases
  @is_auto_close_on    bit = NULL,  -- Filters databases based on auto-close setting
  @is_auto_shrink_on   bit = NULL,  -- Filters databases based on auto-shrink setting
  @is_broker_enabled   bit = NULL,  -- Filters databases based on service broker setting
  @user_access         nvarchar(128)  = NULL,  -- Filters databases based on user access mode (e.g., SINGLE_USER)
  @Help                BIT = 0,  -- If 1, prints help information about the procedure
  @Version             VARCHAR(30)    = NULL OUTPUT,  -- Outputs the version of the procedure
  @VersionDate         DATETIME       = NULL OUTPUT,  -- Outputs the version date
  @VersionCheckMode    BIT            = 0  -- If 1, only checks the version and exits without further action
AS
BEGIN
  -- Turn off row count to avoid extra messages
  SET NOCOUNT ON;

  -- Set the version and version date of the procedure
  SET @Version = '2.3';
  SET @VersionDate = '20190219';
  
  -- If checking version, just return
  IF(@VersionCheckMode = 1)
  BEGIN
    RETURN;
  END;

  -- If help is requested, display detailed help about the procedure
  IF @Help = 1
  BEGIN
    PRINT '
    /*
      sp_ineachdb from http://FirstResponderKit.org
      
      This script will restore a database from a given file path.
    
      To learn more, visit http://FirstResponderKit.org where you can download new
      versions for free, watch training videos on how it works, get more info on
      the findings, contribute your own code, and more.
    
      Known limitations of this version:
       - Only Microsoft-supported versions of SQL Server. Sorry, 2005 and 2000.
       - Tastes awful with marmite.
    
      Unknown limitations of this version:
       - None.  (If we knew them, they would be known. Duh.)
    
       Changes - for the full list of improvements and fixes in this version, see:
       https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/
    
      MIT License
    
      Copyright (c) 2019 Brent Ozar Unlimited
    
      Permission is hereby granted, free of charge, to any person obtaining a copy
      of this software and associated documentation files (the "Software"), to deal
      in the Software without restriction, including without limitation the rights
      to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
      copies of the Software, and to permit persons to whom the Software is
      furnished to do so, subject to the following conditions:
    
      The above copyright notice and this permission notice shall be included in all
      copies or substantial portions of the Software.
    
      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
      IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
      FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
      AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
      LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
      OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
      SOFTWARE.
    */
    ';
  END;

  -- Declare variables to hold database names and command text
  DECLARE @exec   nvarchar(150),
          @sx     nvarchar(18) = N'.sys.sp_executesql',  -- SQL Server function to execute dynamic SQL
          @db     sysname,
          @dbq    sysname,  -- Database name with quotes for safe execution
          @cmd    nvarchar(max),
          @thisdb sysname,  -- Current database being processed
          @cr     char(2) = CHAR(13) + CHAR(10);  -- Carriage return for formatting

  -- Create a temporary table to store the list of databases to process
  CREATE TABLE #ineachdb(id int, name nvarchar(512));

  -- If the user has provided a list of databases, filter them
  IF @database_list > N'' 
  BEGIN
    -- Parse the comma-separated list of database names and insert them into #ineachdb
    ;WITH n(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM n WHERE n < 4000),
    names AS
    (
      SELECT name = LTRIM(RTRIM(PARSENAME(SUBSTRING(@database_list, n, 
        CHARINDEX(N',', @database_list + N',', n) - n), 1)))
      FROM n 
      WHERE n <= LEN(@database_list)
        AND SUBSTRING(N',' + @database_list, n, 1) = N','  -- Ensure it's comma-separated
    ) 
    INSERT #ineachdb(id,name) 
    SELECT d.database_id, d.name
      FROM sys.databases AS d
      WHERE EXISTS (SELECT 1 FROM names WHERE name = d.name)
      OPTION (MAXRECURSION 0);
  END
  ELSE
  BEGIN
    -- If no database list is provided, select all databases
    INSERT #ineachdb(id,name) SELECT database_id, name FROM sys.databases;
  END

  -- Exclude any databases from the list based on the exclude list
  IF @exclude_list > N'' 
  BEGIN
    ;WITH n(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM n WHERE n < 4000),
    names AS
    (
      SELECT name = LTRIM(RTRIM(PARSENAME(SUBSTRING(@exclude_list, n, 
        CHARINDEX(N',', @exclude_list + N',', n) - n), 1)))
      FROM n 
      WHERE n <= LEN(@exclude_list)
        AND SUBSTRING(N',' + @exclude_list, n, 1) = N','  -- Ensure it's comma-separated
    )
    DELETE d 
      FROM #ineachdb AS d
      INNER JOIN names
      ON names.name = d.name
      OPTION (MAXRECURSION 0);
  END

  -- Delete databases that don't meet the criteria (system/user only, name pattern, etc.)
  DELETE dbs FROM #ineachdb AS dbs
  WHERE (@system_only = 1 AND id NOT IN (1,2,3,4))  -- Skip system databases if @system_only = 1
     OR (@user_only   = 1 AND id     IN (1,2,3,4))  -- Skip user databases if @user_only = 1
     OR name NOT LIKE @name_pattern  -- Filter by database name pattern
     OR EXISTS
     (
       SELECT 1 
         FROM sys.databases AS d
         WHERE d.database_id = dbs.id
         AND NOT
         (
           recovery_model_desc     = COALESCE(@recovery_model_desc, recovery_model_desc)
           AND compatibility_level = COALESCE(@compatibility_level, compatibility_level)
           AND is_read_only        = COALESCE(@is_read_only,        is_read_only)
           AND is_auto_close_on    = COALESCE(@is_auto_close_on,    is_auto_close_on)
           AND is_auto_shrink_on   = COALESCE(@is_auto_shrink_on,   is_auto_shrink_on)
           AND is_broker_enabled   = COALESCE(@is_broker_enabled,   is_broker_enabled)
           AND user_access         = COALESCE(@user_access,         user_access)
         )
     );

  -- If no databases remain after filtering, raise an error
  IF NOT EXISTS(SELECT 1 FROM #ineachdb)
  BEGIN
    RAISERROR(N'No databases to process.', 1, 0);
    RETURN;
  END;

  -- Print information about the command execution if requested
  IF @print_command_only = 1
  BEGIN
    PRINT @command;
    RETURN;
  END;

  -- Process each database in the list
  DECLARE db_cursor CURSOR FOR
  SELECT name FROM #ineachdb ORDER BY name;

  OPEN db_cursor;
  FETCH NEXT FROM db_cursor INTO @db;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    -- Format the database name with quotes if suppress_quotename is off
    SET @dbq = CASE WHEN @suppress_quotename = 1 THEN @db ELSE QUOTENAME(@db) END;

    -- If print_dbname is on, print the database name
    IF @print_dbname = 1
    BEGIN
      PRINT @dbq;
    END;

    -- Set the command text by replacing the placeholder with the database name
    SET @cmd = REPLACE(@command, @replace_character, @dbq);
    
    -- If print_command is on, print the command to be executed
    IF @print_command = 1
    BEGIN
      PRINT @cmd;
    END;

    -- Execute the command in the context of the current database
    EXEC @sx @cmd;

    FETCH NEXT FROM db_cursor INTO @db; -- Move to the next database
  END

  -- Cleanup the cursor and temporary table
  CLOSE db_cursor;
  DEALLOCATE db_cursor;
  DROP TABLE #ineachdb;
END;
GO
