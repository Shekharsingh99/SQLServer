-- Check if the stored procedure already exists, and if not, create it
IF OBJECT_ID('dbo.sp_foreachdb') IS NULL
    EXEC ('CREATE PROCEDURE dbo.sp_foreachdb AS RETURN 0');
GO

-- Alter the stored procedure to include all necessary parameters and logic
ALTER PROCEDURE dbo.sp_foreachdb
    -- Original parameters for the command execution
    @command1 NVARCHAR(MAX) = NULL,        -- The first command to execute (replaces ? with the database name)
    @replacechar NCHAR(1) = N'?',         -- Character used to replace in the command
    @command2 NVARCHAR(MAX) = NULL,       -- Additional command (if needed)
    @command3 NVARCHAR(MAX) = NULL,       -- Another additional command (if needed)
    @precommand NVARCHAR(MAX) = NULL,     -- Command to run before executing @command1
    @postcommand NVARCHAR(MAX) = NULL,    -- Command to run after executing @command1
    -- Backward compatibility parameters
    @command NVARCHAR(MAX) = NULL,        -- For backward compatibility (deprecated, same as @command1)
    @print_dbname BIT = 0,                -- If 1, print the database name being processed
    @print_command_only BIT = 0,          -- If 1, only print the command, don’t execute it
    @suppress_quotename BIT = 0,          -- If 1, suppress the quoting of database names
    @system_only BIT = NULL,              -- If 1, process only system databases
    @user_only BIT = NULL,                -- If 1, process only user databases
    @name_pattern NVARCHAR(300) = N'%',   -- Filter databases by name pattern
    @database_list NVARCHAR(MAX) = NULL,  -- Comma-separated list of specific databases to include
    @exclude_list NVARCHAR(MAX) = NULL,   -- Comma-separated list of databases to exclude
    @recovery_model_desc NVARCHAR(120) = NULL,  -- Filter databases by recovery model
    @compatibility_level TINYINT = NULL,  -- Filter databases by compatibility level
    @state_desc NVARCHAR(120) = N'ONLINE', -- Filter databases by state (default is 'ONLINE')
    @is_read_only BIT = 0,               -- If 1, process only read-only databases
    @is_auto_close_on BIT = NULL,        -- If 1, process only databases with auto-close enabled
    @is_auto_shrink_on BIT = NULL,       -- If 1, process only databases with auto-shrink enabled
    @is_broker_enabled BIT = NULL,       -- If 1, process only databases with Service Broker enabled
    @Help BIT = 0,                       -- If 1, show help for the procedure
    @Version VARCHAR(30) = NULL OUTPUT,  -- Version of the procedure (for versioning purposes)
    @VersionDate DATETIME = NULL OUTPUT, -- Version date (for versioning purposes)
    @VersionCheckMode BIT = 0            -- If 1, only check the version and exit
AS
BEGIN
    SET NOCOUNT ON;  -- Disable row count messages for cleaner output

    -- Set version details for the procedure
    SET @Version = '3.3';
    SET @VersionDate = '20190219';

    -- If checking version mode is enabled, exit the procedure
    IF(@VersionCheckMode = 1)
    BEGIN
        RETURN;
    END;

    -- If Help is requested, print detailed usage information and exit
    IF @Help = 1
    BEGIN
        PRINT '
        /*
            sp_foreachdb from http://FirstResponderKit.org
            
            This script will execute a given command against all, or user-specified,
            online, readable databases on an instance.
        
            To learn more, visit http://FirstResponderKit.org where you can download new
            versions for free, watch training videos on how it works, get more info on
            the findings, contribute your own code, and more.
        
            Known limitations of this version:
             - Only Microsoft-supported versions of SQL Server. Sorry, 2005 and 2000.
             - Tastes awful with marmite.
             
            Unknown limitations of this version:
             - None. (If we knew them, they would be known. Duh.)
        
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
            
            Example for basic execution of the stored procedure:
            
            exec dbo.sp_foreachdb
                @command = ''select [name] sys.tables''
                ,@database_list = ''Database1,Database2''
                ,@exclude_list = ''Database5,OldDatabase'';
        */
        ';
        RETURN -1;
    END;

    -- Check if the correct parameters are provided (either @command1 or @command must be set, not both)
    IF ( (@command1 IS NOT NULL AND @command IS NOT NULL)
        OR (@command1 IS NULL AND @command IS NULL) )
    BEGIN
        RAISERROR('You must supply either @command1 or @command, but not both.', 16, 1);
        RETURN -1;
    END;

    -- Use @command1 if provided, otherwise fall back to @command
    SET @command1 = COALESCE(@command1, @command);

    -- Declare variables for dynamic SQL and the list of databases to process
    DECLARE @sql NVARCHAR(MAX),
            @dblist NVARCHAR(MAX),
            @exlist NVARCHAR(MAX),
            @db NVARCHAR(300),
            @i INT;

    -- If a list of databases is provided, process the list
    IF @database_list > N'' 
    BEGIN
        -- Convert the comma-separated list of databases into a format usable in SQL
        ;WITH n(n) AS (
            SELECT ROW_NUMBER() OVER (ORDER BY s1.name) - 1
            FROM sys.objects AS s1
            CROSS JOIN sys.objects AS s2
        )
        SELECT @dblist = REPLACE(REPLACE(REPLACE(x, '</x><x>', ','), '</x>', ''), '<x>', '')
        FROM (
            SELECT DISTINCT
                x = 'N''' + LTRIM(RTRIM(SUBSTRING(@database_list, n, CHARINDEX(',', @database_list + ',', n) - n))) + ''''
            FROM n
            WHERE n <= LEN(@database_list)
            AND SUBSTRING(',' + @database_list, n, 1) = ','
            FOR XML PATH('')
        ) AS y(x);
    END

    -- If an exclusion list is provided, process the exclusion list
    IF @exclude_list > N'' 
    BEGIN
        ;WITH n(n) AS (
            SELECT ROW_NUMBER() OVER (ORDER BY s1.name) - 1
            FROM sys.objects AS s1
            CROSS JOIN sys.objects AS s2
        )
        SELECT @exlist = REPLACE(REPLACE(REPLACE(x, '</x><x>', ','), '</x>', ''), '<x>', '')
        FROM (
            SELECT DISTINCT
                x = 'N''' + LTRIM(RTRIM(SUBSTRING(@exclude_list, n, CHARINDEX(',', @exclude_list + ',', n) - n))) + ''''
            FROM n
            WHERE n <= LEN(@exclude_list)
            AND SUBSTRING(',' + @exclude_list, n, 1) = ','
            FOR XML PATH('')
        ) AS y(x);
    END

    -- Create a temporary table to store database names
    CREATE TABLE #x ( db NVARCHAR(300) );

    -- Build the dynamic SQL query to filter databases based on the provided parameters
    SET @sql = N'SELECT name FROM sys.databases d WHERE 1=1'
        + CASE WHEN @system_only = 1 THEN ' AND d.database_id IN (1,2,3,4)' ELSE '' END
        + CASE WHEN @user_only = 1 THEN ' AND d.database_id NOT IN (1,2,3,4)' ELSE '' END
        + CASE WHEN @exlist IS NOT NULL THEN ' AND d.name NOT IN (' + @exlist + ')' ELSE '' END
        + CASE WHEN @name_pattern <> N'%' THEN ' AND d.name LIKE N''' + REPLACE(@name_pattern, '''', '''''') + '''' ELSE '' END
        + CASE WHEN @dblist IS NOT NULL THEN ' AND d.name IN (' + @dblist + ')' ELSE '' END
        + CASE WHEN @recovery_model_desc IS NOT NULL THEN ' AND d.recovery_model_desc = N''' + @recovery_model_desc + '''' ELSE '' END
        + CASE WHEN @compatibility_level IS NOT NULL THEN ' AND d.compatibility_level = ' + RTRIM(@compatibility_level) ELSE '' END
        + CASE WHEN @state_desc IS NOT NULL THEN ' AND d.state_desc = N''' + @state_desc + '''' ELSE '' END
        + CASE WHEN @state_desc = 'ONLINE' AND SERVERPROPERTY('IsHadrEnabled') = 1 THEN ' AND NOT EXISTS (SELECT 1 FROM sys.dm_hadr_database_replica_states drs JOIN sys.availability_replicas ar ON ar.replica_id = drs.replica_id JOIN sys.dm_hadr_availability_group_states ags ON ags.group_id = ar.group_id WHERE drs.database_id = d.database_id AND ar.secondary_role_allow_connections = 0 AND ags.primary_replica <> @@SERVERNAME)' ELSE '' END
        + CASE WHEN @is_read_only IS NOT NULL THEN ' AND d.is_read_only = ' + RTRIM(@is_read_only) ELSE '' END
        + CASE WHEN @is_auto_close_on IS NOT NULL THEN ' AND d.is_auto_close_on = ' + RTRIM(@is_auto_close_on) ELSE '' END
        + CASE WHEN @is_auto_shrink_on IS NOT NULL THEN ' AND d.is_auto_shrink_on = ' + RTRIM(@is_auto_shrink_on) ELSE '' END
        + CASE WHEN @is_broker_enabled IS NOT NULL THEN ' AND d.is_broker_enabled = ' + RTRIM(@is_broker_enabled) ELSE '' END;

    -- Execute the SQL query and insert the filtered database names into the temporary table
    INSERT #x
    EXEC sp_executesql @sql;

    -- Declare a cursor to loop through the filtered databases
    DECLARE c CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY
    FOR
        SELECT CASE WHEN @suppress_quotename = 1 THEN db ELSE QUOTENAME(db) END
        FROM #x
        ORDER BY db;

    OPEN c;

    -- Fetch the first database name from the cursor
    FETCH NEXT FROM c INTO @db;

    -- Loop through each database and execute the corresponding command
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = REPLACE(@command1, @replacechar, @db);  -- Replace the placeholder with the database name

        -- If suppress_quotename is off, remove extra brackets from the command
        IF @suppress_quotename = 0
            SET @sql = REPLACE(REPLACE(@sql, '[[', '['), ']]', ']');

        -- If print_command_only is set, just print the command without executing it
        IF @print_command_only = 1
        BEGIN
            PRINT '/* For ' + @db + ': */' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + @sql + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10);
        END
        ELSE
        BEGIN
            -- If print_dbname is set, print the database name before executing the command
            IF @print_dbname = 1
            BEGIN
                PRINT '/* ' + @db + ' */';
            END

            -- Execute the final SQL command for the current database
            EXEC sp_executesql @sql;
        END

        -- Fetch the next database name
        FETCH NEXT FROM c INTO @db;
    END

    -- Close and deallocate the cursor
    CLOSE c;
    DEALLOCATE c;
END
GO
