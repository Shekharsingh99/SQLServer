-- Switch context to the master database (needed to create a login at the server level)
USE [MASTER]

-- Create a SQL Server login (server-level authentication object)
-- LOGIN_NAME = the login name you want to use
-- PASSWORD   = the password you want to set
CREATE LOGIN [LOGIN_NAME] WITH PASSWORD = N'PASSWORD';
GO

-- Create a database user in the master DB mapped to the login
-- USER_NAME = the user name inside the database
-- DEFAULT_SCHEMA = default schema to use for unqualified objects (dbo in this case)
CREATE USER [USER_NAME] FOR LOGIN [LOGIN_NAME] WITH DEFAULT_SCHEMA = dbo;
GO


--------------------------------------------------
-- Now switch to the user database (where this login/user will actually work)
USE [USER_DB];

-- Create a user inside this specific database and map it to the existing login
CREATE USER [USER_NAME] FOR LOGIN [LOGIN_NAME] WITH DEFAULT_SCHEMA = dbo;
GO

-- Add the user to the db_datareader role (grants SELECT on all tables & views)
EXEC sp_addrolemember 'DB_DATAREADER', 'USER_NAME';

-- Remove the user from the db_datareader role (revokes SELECT permission)
EXEC sp_droprolemember 'DB_DATAREADER', 'USER_NAME';
GO

-- Explicitly grant permissions at the schema level
-- Grants SELECT, INSERT, UPDATE, DELETE rights on all objects in a schema
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA :: [SCHEMA_NAME] TO [USER_NAME];

-- Denies INSERT, UPDATE, DELETE rights on the schema (overrides GRANT above)
-- Note: DENY always takes precedence over GRANT
DENY INSERT, UPDATE, DELETE ON SCHEMA :: [SCHEMA_NAME] TO [USER_NAME];

-- Allow the user to create stored procedures in the database
GRANT CREATE PROCEDURE TO [USER_NAME];

-- Allow the user to EXECUTE stored procedures inside the given schema
GRANT EXECUTE ON SCHEMA :: [SCHEMA_NAME] TO [USER_NAME];


---------------------------------------------------
-- Create a database user that is mapped to an EXTERNAL PROVIDER (e.g., Azure AD)
-- This is used when authentication is managed by Azure Active Directory
CREATE USER [USER_NAME] FROM EXTERNAL PROVIDER WITH DEFAULT_SCHEMA = [dbo];
GO

-- Add this external user to db_datareader role (read access to all tables/views)
EXEC sp_addrolemember N'db_datareader', N'USER_NAME';
GO


---------------------------------------------------
-- Grant the ability to view the definition of objects in the SEMANTIC schema
-- (useful for developers who need to see stored procedure/table definitions 
--  but not necessarily modify them)
GRANT VIEW DEFINITION ON SCHEMA :: SEMANTIC TO [USER_NAME];



--Quick Summary of Key Parts

--LOGIN vs USER:

--LOGIN = server-level identity (who can connect).

--USER = database-level identity (what they can do in that DB).

--Roles:

--db_datareader = read-only access to all tables/views.

--You can also use db_datawriter, db_owner, etc., depending on needs.

--GRANT / DENY:

--GRANT gives permission.

--DENY explicitly blocks it (overrides any GRANT).

--External Provider:

--Used in Azure SQL DB for Azure Active Directory (AAD) authentication.