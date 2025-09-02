-- This query returns object-level permissions for the table 'TblSalesForecastAudiDealerWeeklyStatus'

SELECT 
    permission_name,    -- The specific permission granted (e.g., SELECT, INSERT)
    state,              -- The state of the permission (e.g., GRANT, DENY)
    pr.name             -- The name of the principal (user/role) that has the permission
FROM 
    sys.database_permissions pe           -- System view that contains database-level permissions
JOIN 
    sys.database_principals pr           -- System view that contains info about database users/roles
    ON pe.grantee_principal_id = pr.principal_id
WHERE 
    pe.class = 1                          -- Class 1 indicates the permission is at the object level
    AND pe.major_id = OBJECT_ID('TblSalesForecastAudiDealerWeeklyStatus')  -- Object ID for the specific table
    AND pe.minor_id = 0;                 -- Minor ID = 0 filters to the object itself, not its columns
