/*
Here we've got:
1) create table statements
2) mock data if you want it
3) sprocs to link to UDFs

Is there room for improvement on these? Absolutely. Does it demonstrate Translytical task flows' potential? Yes, it sure does.
*/

CREATE TABLE [WH_testing].[dbo].[fact_price_table]
(
	[sku] [bigint] NULL,
	[price] [decimal](16,2) NULL,
	[created_at] [datetime2](6) NULL,
	[updated_at] [datetime2](6) NULL,
	[deleted_at] [datetime2](6) NULL,
	[updated_by] [varchar](100) NULL,
	[version] [int] NULL,
	[is_active] [int] NULL
)
GO

CREATE TABLE [WH_testing].[dbo].[fact_price_table_history]
(
	[sku] [bigint] NULL,
	[price] [decimal](16,2) NULL,
	[created_at] [datetime2](6) NULL,
	[updated_at] [datetime2](6) NULL,
	[deleted_at] [datetime2](6) NULL,
	[updated_by] [varchar](100) NULL,
	[version] [int] NULL,
	[is_active] [int] NULL,
	[operation_type] [varchar](10) NULL,
	[operation_timestamp] [datetime2](6) NULL
)
GO


--Mock data if you want it
-- -- Insert into fact_price_table
-- INSERT INTO fact_price_table (sku, price, created_at, updated_at, deleted_at, updated_by, version, is_active)
-- VALUES
-- (1001, 49.99, '2025-01-15 08:30:00.000000', '2025-01-15 08:30:00.000000', NULL, 'John Smith', 1, 1),
-- (1002, 129.50, '2025-01-16 09:15:00.000000', '2025-01-16 09:15:00.000000', NULL, 'Sarah Johnson', 1, 1),
-- (1003, 24.75, '2025-01-17 10:45:00.000000', '2025-01-17 10:45:00.000000', NULL, 'Mike Davis', 1, 1),
-- (1004, 399.00, '2025-01-18 11:20:00.000000', '2025-01-18 11:20:00.000000', NULL, 'Emily Chen', 1, 1),
-- (1005, 75.25, '2025-01-19 13:00:00.000000', '2025-01-19 13:00:00.000000', NULL, 'David Wilson', 1, 1),
-- (1006, 15.99, '2025-01-20 14:30:00.000000', '2025-01-20 14:30:00.000000', NULL, 'Lisa Anderson', 1, 1),
-- (1007, 289.99, '2025-01-21 08:00:00.000000', '2025-01-21 08:00:00.000000', NULL, 'Robert Taylor', 1, 1),
-- (1008, 56.50, '2025-01-22 09:30:00.000000', '2025-01-22 09:30:00.000000', NULL, 'Jennifer Lee', 1, 1),
-- (1009, 199.00, '2025-01-23 10:15:00.000000', '2025-01-23 10:15:00.000000', NULL, 'William Brown', 1, 1),
-- (1010, 89.99, '2025-01-24 11:45:00.000000', '2025-01-24 11:45:00.000000', NULL, 'Amanda White', 1, 1),
-- (1011, 12.50, '2025-01-25 13:20:00.000000', '2025-01-25 13:20:00.000000', NULL, 'James Martinez', 1, 1),
-- (1012, 449.00, '2025-01-26 14:00:00.000000', '2025-01-26 14:00:00.000000', NULL, 'Mary Garcia', 1, 1),
-- (1013, 67.75, '2025-01-27 08:45:00.000000', '2025-01-27 08:45:00.000000', NULL, 'Christopher Moore', 1, 1),
-- (1014, 34.99, '2025-01-28 09:00:00.000000', '2025-01-28 09:00:00.000000', NULL, 'Patricia Rodriguez', 1, 1),
-- (1015, 159.50, '2025-01-29 10:30:00.000000', '2025-01-29 10:30:00.000000', NULL, 'Daniel Thomas', 1, 1),
-- (1016, 99.00, '2025-01-30 11:15:00.000000', '2025-01-30 11:15:00.000000', NULL, 'Barbara Jackson', 1, 1),
-- (1017, 22.25, '2025-01-31 12:00:00.000000', '2025-01-31 12:00:00.000000', NULL, 'Matthew Harris', 1, 1),
-- (1018, 349.99, '2025-02-01 13:30:00.000000', '2025-02-01 13:30:00.000000', NULL, 'Nancy Martin', 1, 1),
-- (1019, 45.50, '2025-02-02 14:15:00.000000', '2025-02-02 14:15:00.000000', NULL, 'Joseph Thompson', 1, 1),
-- (1020, 189.00, '2025-02-03 08:20:00.000000', '2025-02-03 08:20:00.000000', NULL, 'Karen Clark', 1, 1);

-- -- Insert into fact_price_table_history (mirror initial INSERTs)
-- INSERT INTO fact_price_table_history (sku, price, created_at, updated_at, deleted_at, updated_by, version, is_active, operation_type, operation_timestamp)
-- VALUES
-- (1001, 49.99, '2025-01-15 08:30:00.000000', '2025-01-15 08:30:00.000000', NULL, 'John Smith', 1, 1, 'INSERT', '2025-01-15 08:30:00.000000'),
-- (1002, 129.50, '2025-01-16 09:15:00.000000', '2025-01-16 09:15:00.000000', NULL, 'Sarah Johnson', 1, 1, 'INSERT', '2025-01-16 09:15:00.000000'),
-- (1003, 24.75, '2025-01-17 10:45:00.000000', '2025-01-17 10:45:00.000000', NULL, 'Mike Davis', 1, 1, 'INSERT', '2025-01-17 10:45:00.000000'),
-- (1004, 399.00, '2025-01-18 11:20:00.000000', '2025-01-18 11:20:00.000000', NULL, 'Emily Chen', 1, 1, 'INSERT', '2025-01-18 11:20:00.000000'),
-- (1005, 75.25, '2025-01-19 13:00:00.000000', '2025-01-19 13:00:00.000000', NULL, 'David Wilson', 1, 1, 'INSERT', '2025-01-19 13:00:00.000000'),
-- (1006, 15.99, '2025-01-20 14:30:00.000000', '2025-01-20 14:30:00.000000', NULL, 'Lisa Anderson', 1, 1, 'INSERT', '2025-01-20 14:30:00.000000'),
-- (1007, 289.99, '2025-01-21 08:00:00.000000', '2025-01-21 08:00:00.000000', NULL, 'Robert Taylor', 1, 1, 'INSERT', '2025-01-21 08:00:00.000000'),
-- (1008, 56.50, '2025-01-22 09:30:00.000000', '2025-01-22 09:30:00.000000', NULL, 'Jennifer Lee', 1, 1, 'INSERT', '2025-01-22 09:30:00.000000'),
-- (1009, 199.00, '2025-01-23 10:15:00.000000', '2025-01-23 10:15:00.000000', NULL, 'William Brown', 1, 1, 'INSERT', '2025-01-23 10:15:00.000000'),
-- (1010, 89.99, '2025-01-24 11:45:00.000000', '2025-01-24 11:45:00.000000', NULL, 'Amanda White', 1, 1, 'INSERT', '2025-01-24 11:45:00.000000'),
-- (1011, 12.50, '2025-01-25 13:20:00.000000', '2025-01-25 13:20:00.000000', NULL, 'James Martinez', 1, 1, 'INSERT', '2025-01-25 13:20:00.000000'),
-- (1012, 449.00, '2025-01-26 14:00:00.000000', '2025-01-26 14:00:00.000000', NULL, 'Mary Garcia', 1, 1, 'INSERT', '2025-01-26 14:00:00.000000'),
-- (1013, 67.75, '2025-01-27 08:45:00.000000', '2025-01-27 08:45:00.000000', NULL, 'Christopher Moore', 1, 1, 'INSERT', '2025-01-27 08:45:00.000000'),
-- (1014, 34.99, '2025-01-28 09:00:00.000000', '2025-01-28 09:00:00.000000', NULL, 'Patricia Rodriguez', 1, 1, 'INSERT', '2025-01-28 09:00:00.000000'),
-- (1015, 159.50, '2025-01-29 10:30:00.000000', '2025-01-29 10:30:00.000000', NULL, 'Daniel Thomas', 1, 1, 'INSERT', '2025-01-29 10:30:00.000000'),
-- (1016, 99.00, '2025-01-30 11:15:00.000000', '2025-01-30 11:15:00.000000', NULL, 'Barbara Jackson', 1, 1, 'INSERT', '2025-01-30 11:15:00.000000'),
-- (1017, 22.25, '2025-01-31 12:00:00.000000', '2025-01-31 12:00:00.000000', NULL, 'Matthew Harris', 1, 1, 'INSERT', '2025-01-31 12:00:00.000000'),
-- (1018, 349.99, '2025-02-01 13:30:00.000000', '2025-02-01 13:30:00.000000', NULL, 'Nancy Martin', 1, 1, 'INSERT', '2025-02-01 13:30:00.000000'),
-- (1019, 45.50, '2025-02-02 14:15:00.000000', '2025-02-02 14:15:00.000000', NULL, 'Joseph Thompson', 1, 1, 'INSERT', '2025-02-02 14:15:00.000000'),
-- (1020, 189.00, '2025-02-03 08:20:00.000000', '2025-02-03 08:20:00.000000', NULL, 'Karen Clark', 1, 1, 'INSERT', '2025-02-03 08:20:00.000000');

CREATE OR ALTER   PROCEDURE usp_update_price
    @id_list VARCHAR(MAX)  -- Comma-separated list of SKU IDs to update
    ,@price DECIMAL(16,2)  -- New price value to apply to all SKUs in the list
    ,@user_name VARCHAR(100)  -- Username performing the update
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Capture UTC timestamp for consistent updated_at values across UPDATE and INSERT
    DECLARE @current_timestamp DATETIME2(6) = SYSUTCDATETIME();
    DECLARE @rows_affected INT = 0;
    
    -- Begin transaction to ensure UPDATE and history INSERT are atomic
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Parse comma-separated SKU list into table format for joining
        WITH cte_sku_list AS (
            SELECT CAST(value AS BIGINT) AS sku
            FROM STRING_SPLIT(@id_list, ',')
            WHERE RTRIM(LTRIM(value)) <> ''  -- Filter out empty/whitespace-only values
        )
        -- Update price for all SKUs in the provided list
        UPDATE t
        SET 
            t.price = @price  -- Set new price value (same for all SKUs in batch)
            ,t.updated_at = @current_timestamp  -- Last modification timestamp
            ,t.updated_by = @user_name  -- Audit: who performed the update
            ,t.version = t.version + 1  -- Increment version for optimistic concurrency tracking
        FROM fact_price_table t
        INNER JOIN cte_sku_list c
            ON t.sku = c.sku  -- Match on provided SKU list
        WHERE t.is_active = 1;  -- Only update currently active records
        
        -- Capture number of rows affected by the UPDATE for return to caller
        SET @rows_affected = @@ROWCOUNT;
        
        -- Re-parse SKU list (CTE not persisted from previous operation)
        WITH cte_sku_list AS (
            SELECT CAST(value AS BIGINT) AS sku
            FROM STRING_SPLIT(@id_list, ',')
            WHERE RTRIM(LTRIM(value)) <> ''
        )
        -- Insert updated records into history table for audit trail
        INSERT INTO fact_price_table_history (
            sku, price, created_at, updated_at, deleted_at
            ,updated_by, version, is_active, operation_type, operation_timestamp
        )
        SELECT 
            t.sku, t.price, t.created_at, t.updated_at, t.deleted_at
            ,t.updated_by, t.version, t.is_active
            ,'UPDATE'  -- Operation type for history tracking
            ,@current_timestamp  -- When the operation occurred
        FROM fact_price_table t
        INNER JOIN cte_sku_list c
            ON t.sku = c.sku
        WHERE t.is_active = 1;  -- Select currently active records that were just updated
        
        -- Commit transaction if both UPDATE and INSERT succeeded
        COMMIT TRANSACTION;
        
        -- Return count of updated records to caller
        SELECT @rows_affected AS rows_affected;
        
    END TRY
    BEGIN CATCH
        -- Rollback transaction if any error occurred
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Re-throw original error to caller
        THROW;
    END CATCH
END;


GO

CREATE OR ALTER   PROCEDURE usp_insert_price
    @sku BIGINT  -- SKU identifier for the price record
    ,@price DECIMAL(16,2)  -- Price value (16 total digits, 2 decimal places)
    ,@user_name VARCHAR(100)  -- Username performing the insert
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Capture UTC timestamp for consistent created_at/updated_at values
    DECLARE @current_timestamp DATETIME2(6) = SYSUTCDATETIME();
    DECLARE @rows_affected INT = 0;
    
    -- Begin transaction to ensure INSERT and history INSERT are atomic
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Check if SKU already exists in the table (duplicate prevention)
        IF EXISTS (SELECT 1 FROM fact_price_table WHERE sku = @sku)
        BEGIN
            -- Raise error with severity 16 (user error) and state 1
            RAISERROR('Duplicate SKU detected. SKU %I64d already exists in the table.', 16, 1, @sku);
            ROLLBACK TRANSACTION;  -- Explicitly rollback before returning
            RETURN;  -- Exit procedure early
        END
        
        -- Insert new price record with initial version and active status
        INSERT INTO fact_price_table (
            sku, price, created_at, updated_at, deleted_at
            ,updated_by, version, is_active
        )
        VALUES (
            @sku, @price, @current_timestamp, @current_timestamp, NULL  -- deleted_at NULL for new records
            ,@user_name, 1  -- Initial version is 1
            ,1  -- New records are active by default
        );
        
        -- Capture number of rows inserted (should always be 1 if successful)
        SET @rows_affected = @@ROWCOUNT;
        
        -- Insert newly created record into history table for audit trail
        INSERT INTO fact_price_table_history (
            sku, price, created_at, updated_at, deleted_at
            ,updated_by, version, is_active, operation_type, operation_timestamp
        )
        SELECT 
            sku, price, created_at, updated_at, deleted_at
            ,updated_by, version, is_active
            ,'INSERT'  -- Operation type for history tracking
            ,@current_timestamp  -- When the operation occurred
        FROM fact_price_table
        WHERE sku = @sku;  -- Select the just-inserted record
        
        -- Commit transaction if both INSERTs succeeded
        COMMIT TRANSACTION;
        
        -- Return count of inserted records to caller
        SELECT @rows_affected AS rows_affected;
        
    END TRY
    BEGIN CATCH
        -- Rollback transaction if any error occurred
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Re-throw original error to caller
        THROW;
    END CATCH
END;


GO


CREATE OR ALTER     PROCEDURE usp_delete_price
    @id_list VARCHAR(MAX)  -- Comma-separated list of SKU IDs to soft-delete
    ,@user_name VARCHAR(100)  -- Username performing the deletion
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Capture UTC timestamp for consistent deleted_at/updated_at values across UPDATE and INSERT
    DECLARE @current_timestamp DATETIME2(6) = SYSUTCDATETIME();
    DECLARE @rows_affected INT = 0;
    
    -- Begin transaction to ensure UPDATE and history INSERT are atomic
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Parse comma-separated SKU list into table format for joining
        WITH cte_sku_list AS (
            SELECT CAST(value AS BIGINT) AS sku
            FROM STRING_SPLIT(@id_list, ',')
            WHERE RTRIM(LTRIM(value)) <> ''  -- Filter out empty/whitespace-only values
        )
        -- Soft-delete: mark records as deleted without physical removal
        UPDATE t
        SET 
            t.deleted_at = @current_timestamp  -- Timestamp when record was deleted
            ,t.updated_at = @current_timestamp  -- Last modification timestamp
            ,t.updated_by = @user_name  -- Audit: who performed the deletion
            ,t.version = t.version + 1  -- Increment version for optimistic concurrency tracking
            ,t.is_active = 0  -- Mark record as inactive
        FROM fact_price_table t
        INNER JOIN cte_sku_list c
            ON t.sku = c.sku  -- Match on provided SKU list
        WHERE t.is_active = 1;  -- Only delete currently active records
        
        -- Capture number of rows affected by the UPDATE for return to caller
        SET @rows_affected = @@ROWCOUNT;
        
        -- Re-parse SKU list (CTE not persisted from previous operation)
        WITH cte_sku_list AS (
            SELECT CAST(value AS BIGINT) AS sku
            FROM STRING_SPLIT(@id_list, ',')
            WHERE RTRIM(LTRIM(value)) <> ''
        )
        -- Insert deleted records into history table for audit trail
        INSERT INTO fact_price_table_history (
            sku, price, created_at, updated_at, deleted_at
            ,updated_by, version, is_active, operation_type, operation_timestamp
        )
        SELECT 
            t.sku, t.price, t.created_at, t.updated_at, t.deleted_at
            ,t.updated_by, t.version, t.is_active
            ,'DELETE'  -- Operation type for history tracking
            ,@current_timestamp  -- When the operation occurred
        FROM fact_price_table t
        INNER JOIN cte_sku_list c
            ON t.sku = c.sku
        WHERE t.is_active = 0  -- Select records just marked inactive
            AND t.deleted_at = @current_timestamp;  -- Match on current operation's timestamp
        
        -- Commit transaction if both UPDATE and INSERT succeeded
        COMMIT TRANSACTION;
        
        -- Return count of deleted records to caller
        SELECT @rows_affected AS rows_affected;
        
    END TRY
    BEGIN CATCH
        -- Rollback transaction if any error occurred
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Re-throw original error to caller
        THROW;
    END CATCH
END;


GO


CREATE OR ALTER   PROCEDURE usp_reactivate_price
    @id_list VARCHAR(MAX)  -- Comma-separated list of SKU IDs to reactivate
    ,@user_name VARCHAR(100)  -- Username performing the reactivation
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Capture UTC timestamp for consistent updated_at values across UPDATE and INSERT
    DECLARE @current_timestamp DATETIME2(6) = SYSUTCDATETIME();
    DECLARE @rows_affected INT = 0;
    
    -- Begin transaction to ensure UPDATE and history INSERT are atomic
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Parse comma-separated SKU list into table format for joining
        WITH cte_sku_list AS (
            SELECT CAST(value AS BIGINT) AS sku
            FROM STRING_SPLIT(@id_list, ',')
            WHERE RTRIM(LTRIM(value)) <> ''  -- Filter out empty/whitespace-only values
        )
        -- Reactivate soft-deleted records by reversing the deletion flags
        UPDATE t
        SET 
            t.deleted_at = NULL  -- Clear deletion timestamp (record no longer deleted)
            ,t.updated_at = @current_timestamp  -- Last modification timestamp
            ,t.updated_by = @user_name  -- Audit: who performed the reactivation
            ,t.version = t.version + 1  -- Increment version for optimistic concurrency tracking
            ,t.is_active = 1  -- Mark record as active again
        FROM fact_price_table t
        INNER JOIN cte_sku_list c
            ON t.sku = c.sku  -- Match on provided SKU list
        WHERE t.is_active = 0;  -- Only reactivate currently inactive records
        
        -- Capture number of rows affected by the UPDATE for return to caller
        SET @rows_affected = @@ROWCOUNT;
        
        -- Re-parse SKU list (CTE not persisted from previous operation)
        WITH cte_sku_list AS (
            SELECT CAST(value AS BIGINT) AS sku
            FROM STRING_SPLIT(@id_list, ',')
            WHERE RTRIM(LTRIM(value)) <> ''
        )
        -- Insert reactivated records into history table for audit trail
        INSERT INTO fact_price_table_history (
            sku, price, created_at, updated_at, deleted_at
            ,updated_by, version, is_active, operation_type, operation_timestamp
        )
        SELECT 
            t.sku, t.price, t.created_at, t.updated_at, t.deleted_at
            ,t.updated_by, t.version, t.is_active
            ,'REACTIVATE'  -- Operation type for history tracking
            ,@current_timestamp  -- When the operation occurred
        FROM fact_price_table t
        INNER JOIN cte_sku_list c
            ON t.sku = c.sku
        WHERE t.is_active = 1  -- Select records just marked active
            AND t.updated_at = @current_timestamp;  -- Match on current operation's timestamp
        
        -- Commit transaction if both UPDATE and INSERT succeeded
        COMMIT TRANSACTION;
        
        -- Return count of reactivated records to caller
        SELECT @rows_affected AS rows_affected;
        
    END TRY
    BEGIN CATCH
        -- Rollback transaction if any error occurred
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Re-throw original error to caller
        THROW;
    END CATCH
END;




