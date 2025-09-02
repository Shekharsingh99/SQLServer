/*
CREATE TABLE Product(Cust VARCHAR(25), Product VARCHAR(20), QTY INT)
GO
*/
-- Sample table creation (commented out)

-------------------------------------
-- Inserting sample data into Product table (also commented out)
-- Represents purchase quantities for different customers and products

-- INSERT INTO Product(Cust, Product, QTY)
-- VALUES('KATE','VEG',2), ('KATE','SODA',6), ('KATE','MILK',1),
--       ('KATE','BEER',3), ('KATE','BEER',4), ('KATE','VEG',5),
--       ('KATE','VEG',5), ('KATE','BEER',12), ('FRED','MILK',3),
--       ('FRED','BEER',24), ('KATE','VEG',3)
-- GO

-- Show Product table with row numbers for easier indexing
SELECT 
    ROW_NUMBER() OVER (ORDER BY Cust, Product) AS RowNum,
    * 
FROM Product

-- Example of updating customer name based on row numbers (commented out)
-- UPDATE a SET a.cust = 'FRED'
-- FROM (SELECT ROW_NUMBER() OVER (ORDER BY Cust, Product) id, Cust FROM Product) a
-- WHERE ID >= 8
-- GO

-- Calculate averages for a specific range of rows using CTE
-- WITH pr_CTE (id, Qty) AS (
--     SELECT ROW_NUMBER() OVER (ORDER BY Cust, Product) id, QTY FROM Product
-- )
-- SELECT AVG(qty) AS qty_Avg, AVG(ID) AS id_Avg FROM pr_CTE WHERE id BETWEEN 6 AND 8
-- GO

-- View all records in the Product table
SELECT * FROM Product

-- Pivoting Product table to get quantities per customer per product
SELECT PRODUCT, FRED, KATE
FROM (
    SELECT PRODUCT, CUST, QTY
    FROM Product
) up
PIVOT (
    SUM(QTY) FOR CUST IN (FRED, KATE)
) AS pvt
ORDER BY PRODUCT
GO

/********************************************************************************/

-- Sample data for pivoting/unpivoting (commented out)
-- CREATE TABLE tbl (
--     color VARCHAR(10), Paul INT, John INT, Tim INT, Eric INT
-- );
-- INSERT tbl SELECT 
--     'Red' ,1 ,5 ,1 ,3 UNION ALL
--     SELECT 'Green' ,8 ,4 ,3 ,5 UNION ALL
--     SELECT 'Blue' ,2 ,2 ,9 ,1;

-- View all rows in tbl
SELECT * FROM Tbl    

-- Unpivot by name, then pivot again by color to return to matrix form
SELECT *
FROM tbl
UNPIVOT (
    value FOR name IN ([Paul],[John],[Tim],[Eric])
) up
PIVOT (
    MAX(value) FOR color IN ([Red],[Green],[Blue])
) p

/********************************************************************************/

-- Player badge example with pivot/unpivot using a cursor

-- CREATE TABLE dbo.Players
-- (
--     PlayerID INT,
--     GoldBadge INT,
--     SilverBadge INT,
--     BronzeBadge INT
-- );

-- INSERT INTO dbo.Players (PlayerID, GoldBadge, SilverBadge, BronzeBadge)
-- VALUES (5, 5, 4, 0), (6, 0, 9, 1), (7, 2, 4, 10);

-- Show all player badge data
SELECT * FROM Players

-- Declare variables and temporary table to hold unpivoted data
DECLARE @playerID INT
DECLARE @tbl TABLE (
    id INT,
    PlayerID INT,
    Badge VARCHAR(50),
    Value INT
)

-- Cursor to loop through all PlayerIDs
DECLARE curs CURSOR FOR 
    SELECT PlayerID FROM Players

OPEN curs
    FETCH NEXT FROM curs INTO @playerID
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Insert unpivoted data into temp table for each player
        INSERT INTO @tbl
        SELECT 1, PlayerID, 'Gold Badge',   GoldBadge    FROM Players WHERE PlayerID = @playerID UNION
        SELECT 2, PlayerID, 'Silver Badge', SilverBadge  FROM Players WHERE PlayerID = @playerID UNION 
        SELECT 3, PlayerID, 'Bronze Badge', BronzeBadge  FROM Players WHERE PlayerID = @playerID

        FETCH NEXT FROM curs INTO @playerID
    END
CLOSE curs
DEALLOCATE curs

-- Final result: one row per badge per player
SELECT * FROM @tbl 
ORDER BY PlayerID, ID
