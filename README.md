# Fabric Redux: Multi-Row Translytical Task Flows in Microsoft Fabric

Translytical Task Flows (TTF) combine transactional updates and analytical workflows in a single environment. Users can analyze data in a Power BI report, select records, input changes, and commit updates—all without leaving the analytical experience. Changes are immediately visible thanks to DirectQuery.

This repository provides a production-ready implementation pattern for **bulk CRUD operations** (INSERT, UPDATE, DELETE, REACTIVATE) with CDC visibility, enabling multi-row write-back directly from Power BI reports.

## Table of Contents

- [The Core Enablers: CONCATENATEX + STRING_SPLIT](#the-core-enablers-concatenatex--string_split)
- [What's in This Repo](#whats-in-this-repo)
- [Test Environment Reference](#test-environment-reference)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [The Pattern: DAX Guardrails + ID Concatenation](#the-pattern-dax-guardrails--id-concatenation)
- [Stored Procedure: STRING_SPLIT for Bulk Operations](#stored-procedure-string_split-for-bulk-operations)
- [UDF: Connecting and Passing Values](#udf-connecting-and-passing-values)
- [Power BI Wiring](#power-bi-wiring)
- [CDC: History Table and Restore Points](#cdc-history-table-and-restore-points)
- [DirectQuery Datetime Precision Issue](#directquery-datetime-precision-issue)
- [UDF Technical Details](#udf-technical-details)
- [The Art of the Possible](#the-art-of-the-possible)
- [Why Not Lakehouse?](#why-not-lakehouse)
- [Access Control](#access-control)
- [Limitations & Guardrails](#limitations--guardrails)
- [Links & Resources](#links--resources)

## The Core Enablers: CONCATENATEX + STRING_SPLIT

Multi-row write-back hinges on two functions working across the DAX → UDF → sproc boundary:

- **CONCATENATEX** (DAX): Transforms a multi-select visual context into a comma-delimited string of IDs
- **STRING_SPLIT** (T-SQL): Unpacks that string back into a table for JOIN operations in the stored procedure

Without these two functions, you're limited to single-row operations. Everything else—UDFs, buttons, connections—is plumbing. The *pattern* lives in CONCATENATEX and STRING_SPLIT.

## What's in This Repo

All code is **heavily commented** to explain the "why" behind each component. The PBIP file is included for those who want to examine the Power BI configuration under the hood (TMDL, visual definitions, button wiring).

| File/Folder | Description |
|------|-------------|
| `fabric_redux_tsql.sql` | Table DDL, view, and all stored procedures |
| `fabric_redux_udfs.py` | All Fabric User Data Functions with decorator explanations |
| `fabric_redux_dax.txt` | DAX measures with guardrail logic |
| `fabric_redux_pbip` | Power BI Project files (semantic model + report definitions) |

## Test Environment Reference

| Object Type | Name |
|-------------|------|
| Workspace | Tuatara Sandbox |
| Warehouse | WH_testing |
| Schema | dbo |
| Tables | dim_price, dim_price_history |
| View | vw_dim_price_history |
| Stored Procedures | usp_insert_price, usp_update_price, usp_delete_price, usp_reactivate_price |
| UDF Item | udf_testing |
| Functions | udf_insert_price, udf_update_price, udf_delete_price, udf_reactivate_price |

---

## Prerequisites

### Fabric Warehouse or Fabric SQL Database
Lakehouse is **not supported** for this pattern—see [Why Not Lakehouse?](#why-not-lakehouse) below.

### DirectQuery Semantic Model
DirectQuery is required so that committed changes are immediately visible in the report without manual refresh. This is what makes the translytical experience feel real-time.

> ⚠️ **DirectQuery Datetime Precision Gotcha**: If using `datetime2(6)` columns, you may experience silent cross-filter failures. See [DirectQuery Datetime Precision Issue](#directquery-datetime-precision-issue) for details and the fix.

### Power BI Report with Edit Access
You'll need edit access to configure button actions and bind parameters.

---

## Architecture

<img width="884" height="851" alt="image" src="https://github.com/user-attachments/assets/b3612acb-edc0-4034-a5b2-0e41f5d2165c" />

## The Pattern: DAX Guardrails + ID Concatenation

The DAX measures handle two critical functions: counting selected rows (for guardrails) and concatenating IDs into a string the UDF can pass to the sproc.

### Selected ID Count

```dax
Selected ID Count = 
COUNTROWS( 
    VALUES( dim_price[sku] ) 
)
-- Returns the count of unique SKUs in the current selection context
```

### Selected Records (with Guardrail)

```dax
Selected Records = 
VAR t_ids = VALUES( dim_price[sku] )
VAR id_count = [Selected ID Count]
RETURN
    IF ( 
        id_count > 5, 
        "Too many records selected, max 5",
        CONCATENATEX ( 
            t_ids, 
            dim_price[sku], 
            ",", 
            dim_price[sku], 
            ASC 
        )
    )
-- If 5 or fewer SKUs selected: returns comma-delimited string (e.g., "1001,1002,1003")
-- If more than 5: returns error message, preventing bulk "update all" accidents
```

*The 5-row guardrail is arbitrary—adjust to your organization's risk tolerance. The point is to prevent users from accidentally updating thousands of rows.*

---

## Stored Procedure: STRING_SPLIT for Bulk Operations

The stored procedure receives the comma-delimited ID string and converts it back to a table using `STRING_SPLIT`. Here's the key pattern from `usp_update_price`:

```sql
-- Parse comma-separated SKU list into table format for joining
WITH cte_sku_list AS (
    SELECT CAST(value AS BIGINT) AS sku
    FROM STRING_SPLIT(@id_list, ',')
    WHERE RTRIM(LTRIM(value)) <> ''  -- Filter out empty/whitespace-only values
)

-- Update price for all SKUs in the provided list
UPDATE t
SET 
    t.price = @price
    ,t.updated_at = @current_timestamp
    ,t.updated_by = @user_name
    ,t.version = t.version + 1
FROM dim_price t
INNER JOIN cte_sku_list c
    ON t.sku = c.sku
WHERE t.is_active = 1;
```

All stored procedures follow the same transaction pattern:
- `BEGIN TRANSACTION`
- `TRY` block with UPDATE/INSERT operations
- `COMMIT TRANSACTION` on success
- `CATCH` block with `ROLLBACK TRANSACTION` and `THROW`

---

## UDF: Connecting and Passing Values

### Creating the Connection

Before deploying UDFs, you must configure a connection in the Fabric portal:

1. Open your UDF item in Fabric
2. Click **Edit** → **Manage connections**
3. Create a new connection pointing to your Warehouse or SQL Database
4. Note the alias you assign (e.g., "demo")—this must match your decorator

### Decorator Stack and Connection Usage

The UDF uses three decorators that inject dependencies:

```python
@udf.connection("demo")      # Injects FabricSqlConnection as first parameter
@udf.context(argName="ctx")  # Injects execution context (user identity, session info)
@udf.function()              # Registers this as a callable UDF
def udf_update_price(
    demo: fn.FabricSqlConnection,  # Injected by @udf.connection
    ctx: fn.UserDataFunctionContext,  # Injected by @udf.context
    ids: str,   # User-provided: comma-delimited SKU list
    price: str  # User-provided: new price value
) -> str:
```

### Calling the Stored Procedure

The UDF passes values to the sproc using parameterized execution:

```python
# Three-part naming REQUIRED for EXEC in Fabric
sql = """
    EXEC WH_testing.dbo.usp_update_price
    @id_list = ?
    ,@price = ?
    ,@user_name = ?;
"""

with demo.connect() as conn:
    cur = conn.cursor()
    
    # Parameters bound by POSITION, not by name
    cur.execute(sql, (ids, price, user_name))
    
    row = cur.fetchone()
    rows_affected = row[0] if row else 0
    
    conn.commit()  # REQUIRED—without this, changes roll back
    cur.close()
```

**Critical notes:**
- Three-part naming (`Database.Schema.Object`) is required for EXEC statements
- Parameters use positional `?` placeholders—order matters
- `conn.commit()` is required; without it, the transaction rolls back when the connection closes

---

## Power BI Wiring

### Visual Setup

1. **Matrix or Table visual**: Display your data with SKU as a row identifier
2. **Card visual(s)**: Show `Selected ID Count` and/or `Selected Records` measures
3. **Text slicer**: For user input (e.g., new price value)
4. **Button**: Labeled "Update..." or similar, wired to trigger the UDF

### Configuring the Button Action

1. Select the button
2. Go to **Format** → **Action**
3. Set Action type and select your UDF
4. Map parameters:
   - `price` → Select the Text slicer from dropdown
   - ⚠️ **`ids` → You MUST click the `fx` button** to bind the `Selected Records` measure. The dropdown only shows slicers, not measures.

### Slicer Settings

Consider enabling **Auto clear = On** for slicers so users don't accidentally reuse old input values on subsequent operations.

---

## CDC: History Table and Restore Points

Every operation (INSERT, UPDATE, DELETE, REACTIVATE) writes to `dim_price_history` with:
- Full row state at time of operation
- `operation_type`: 'INSERT', 'UPDATE', 'DELETE', or 'REACTIVATE'
- `operation_timestamp`: When the operation occurred

### Restore Point View

`vw_dim_price_history` provides a user-friendly composite key for restore point selection:

```sql
SELECT 
    ...
    ,CAST(sku AS VARCHAR(20)) + ' (' + CAST(version AS VARCHAR(10)) + ')' AS sku_version
    ,RIGHT('0000000000000000000' + CAST(sku AS VARCHAR(20)), 19) + 
     RIGHT('0000' + CAST(version AS VARCHAR(10)), 4) AS sort_key
FROM dbo.dim_price_history;
```

- `sku_version`: Human-readable identifier (e.g., "1001 (3)" for SKU 1001, version 3)
- `sort_key`: Zero-padded for proper lexicographic sorting

**Restore pattern (not implemented but straightforward)**: Parse `sku_version` → fetch row from history → update main table with historical values.

---

## DirectQuery Datetime Precision Issue

### Problem

When using DirectQuery against Fabric Warehouse, `datetime2(6)` columns can cause **silent cross-filter failures**. Some row selections work; others don't. No error is displayed.

### Root Cause

- DAX filter context retains sub-second precision (e.g., 53 milliseconds)
- DirectQuery-generated SQL truncates to seconds
- Equality comparison fails → no rows returned → `VALUES()` returns BLANK

### Solution

Use `datetime2(0)` for all timestamp columns:

```sql
CREATE TABLE [dbo].[dim_price]
(
    [sku] [bigint] NULL,
    [price] [decimal](16,2) NULL,
    [created_at] [datetime2](0) NULL,   -- NOT datetime2(6)
    [updated_at] [datetime2](0) NULL,
    [deleted_at] [datetime2](0) NULL,
    [updated_by] [varchar](100) NULL,
    [version] [int] NULL,
    [is_active] [int] NULL
);
```

Note: Fabric doesn't support the `datetime` type—use `datetime2(0)` instead.

---

## UDF Technical Details

### Runtime Environment

- **Python 3.11** (NOT PySpark)—UDFs run on serverless Python compute, not Spark clusters
- Any PyPI library compatible with Python 3.11 can be added via Library Management
- Common additions: `pandas`, `requests`, `azure-keyvault-secrets`, `openai`

### Service Limits (as of early 2026)

| Limit | Value |
|-------|-------|
| Execution timeout | 240 seconds |
| Response size | 30 MB |
| Request payload | 4 MB |
| Log ingestion | 250 MB/day |

Source: [Microsoft Fabric UDF Service Limits](https://learn.microsoft.com/en-us/fabric/data-engineering/user-data-functions/user-data-functions-service-limits)

### Authentication

UDFs run in **user context only**:
- No service principal support
- No managed identity
- No workspace identity

The invoking user's identity and permissions apply to all operations.

### Debugging

- **VS Code** with Fabric extension supports full breakpoint debugging (F5)
- Python's standard `logging` module works; view logs in portal Functions Explorer
- Use `fn.UserThrownError("message", {"property": value})` for meaningful error messages

---

## The Art of the Possible

Translytical Task Flows extend far beyond simple CRUD operations. Because Fabric UDFs run on a full Python 3.11 runtime, any HTTP-accessible service or API becomes a potential integration point. The patterns below are documented in Microsoft's official TTF Gallery and community implementations.

### Demonstrated Use Cases

**Azure OpenAI Integration**
UDFs can call Azure OpenAI endpoints to generate AI-powered suggestions directly within Power BI reports. The pattern: fetch context from SQL tables, submit prompts to GPT-4o, and write results back to the database—all within a single function invocation.
- [TTF Gallery: Custom AI Integration](https://community.fabric.microsoft.com/t5/Translytical-Task-Flow-Gallery/Custom-AI-integration/td-p/4702823)

**External REST API Calls**
Any REST endpoint accessible via the `requests` library works. Documented examples include fetching contact information from external systems, processing JSON responses, and updating database records.
- [TTF Gallery: Augment Data on the Fly](https://community.fabric.microsoft.com/t5/Translytical-Task-Flow-Gallery/Augment-data-on-the-fly/td-p/4702500)

**Microsoft Graph Workflows**
Post approval requests to Teams channels, send emails, or trigger other Microsoft 365 workflows—all from a button click in Power BI.
- [TTF Gallery: Approval Workflows](https://community.fabric.microsoft.com/t5/Translytical-Task-Flow-Gallery/Approval-workflows/m-p/4702782)

**Data Activator Integration**
Data Activator can trigger UDFs as actions when data conditions are met, and Activator rules can invoke Power Automate custom actions. This creates event-driven workflows where database changes automatically trigger downstream processes.
- [Microsoft Docs: Trigger Fabric Items](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-trigger-fabric-items)

### External API Possibilities

UDFs can call any HTTP endpoint via the `requests` library:

- **Azure OpenAI**: Generate AI suggestions within reports
- **Microsoft Graph**: Post to Teams, send emails, trigger workflows
- **Any REST API**: CRM updates, webhook triggers, external system integration

**Key Vault for Secrets**
Use the `generic_connection` decorator with `audienceType="KeyVault"` to retrieve secrets at runtime.

> ⚠️ **Important**: The **invoking user must have Key Vault access** (Get permission on secrets). UDFs don't use a service identity—each user who clicks the button needs appropriate Key Vault permissions.

### Theoretical Extensions (Not Yet Demonstrated)

**Power Automate / Logic Apps**
Direct connectors don't exist, but HTTP POST requests to Power Automate's "When HTTP request is received" trigger work. Requires exposing HTTP triggers and managing authentication manually.

**Fabric REST API Orchestration**
Calling Fabric REST APIs from within UDFs to trigger pipelines, notebooks, or other Fabric items is technically possible but lacks official documentation or patterns.
- [Fabric REST API Reference](https://learn.microsoft.com/en-us/rest/api/fabric/articles/)

### Constraints to Consider

| Constraint | Limit |
|------------|-------|
| Execution timeout | 240 seconds |
| Response size | 30 MB |
| Request payload | 4 MB |
| Authentication | User context only (no service principal) |

Source: [UDF Service Limits](https://learn.microsoft.com/en-us/fabric/data-engineering/user-data-functions/user-data-functions-service-limits)

---

## Why Not Lakehouse?

The Lakehouse SQL analytics endpoint is **read-only by design**. Attempting DML returns:

> "Data Manipulation Language (DML) statements are not supported for this table type in this version of SQL Server."

This is architectural, not a temporary limitation. The SQL analytics endpoint provides a T-SQL query layer over Delta Lake files but has no write path.

### Workarounds Exist But Add Complexity

- **delta-rs**: Rust-based Delta Lake writes without Spark
- **Polars**: Python-native with `write_delta()` method

However, these approaches require:
- Service principal authentication setup
- Manual Delta table maintenance (VACUUM, OPTIMIZE)
- No V-ORDER optimization (Microsoft's proprietary read optimization)

**Recommendation**: Use Fabric Warehouse or SQL Database for TTF write-back targets.

---

## Access Control

### UDF Permissions

Add user groups to the function's accessibility settings, then grant Execute permissions.

### Database Permissions

Create roles with minimal DML grants:

```sql
CREATE ROLE price_editors;
ALTER ROLE price_editors ADD MEMBER [user_group];
GRANT INSERT, UPDATE, DELETE ON OBJECT::dbo.dim_price TO price_editors;
GRANT INSERT ON OBJECT::dbo.dim_price_history TO price_editors;
```

Test both successful execution AND denied access to verify your security model.

---

## Limitations & Guardrails

- **Row-count guardrail**: Implement in DAX (example: max 5 rows)—adjust to your risk tolerance
- **240-second timeout**: Long-running operations must complete within this window
- **User context only**: No service principal or managed identity for UDF execution
- **Lakehouse not supported**: Use Warehouse or SQL Database for write-back targets
- **Parameter naming**: UDF parameters cannot use snake_case—use camelCase or PascalCase

---

## Links & Resources

- **LinkedIn Article**: [Multi-row Translytical Task Flows in Microsoft Fabric](https://www.linkedin.com/pulse/multi-row-translytical-task-flows-microsoft-fabric-tony-kain)
- **Microsoft TTF Overview**: [learn.microsoft.com](https://learn.microsoft.com/en-us/power-bi/create-reports/translytical-task-flow-overview)
- **UDF Documentation**: [learn.microsoft.com](https://learn.microsoft.com/en-us/fabric/data-engineering/user-data-functions/user-data-functions-overview)
- **UDF Service Limits**: [learn.microsoft.com](https://learn.microsoft.com/en-us/fabric/data-engineering/user-data-functions/user-data-functions-service-limits)
- **TTF Gallery**: [community.fabric.microsoft.com](https://community.fabric.microsoft.com/t5/Translytical-Task-Flow-Gallery/bd-p/pbi_translyticalgallery)
- **UDF GitHub Samples**: [github.com/microsoft/fabric-user-data-functions-samples](https://github.com/microsoft/fabric-user-data-functions-samples)
