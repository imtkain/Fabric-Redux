import datetime
import zoneinfo
import fabric.functions as fn
from decimal import Decimal, InvalidOperation

udf = fn.UserDataFunctions()
CENTRAL = zoneinfo.ZoneInfo("America/Chicago")

# This is the introductory function, so providing heavy commentary

# ===== FABRIC UDF DECORATOR PATTERN =====
# These decorators register this Python function as a User-Defined Function (UDF) callable from Fabric SQL environments.
# Execution order: decorators are applied bottom-up, so @udf.function() executes first, then @udf.context(), then @udf.connection().
#
# @udf.connection("demo"): 
#   - Injects a FabricSqlConnection object as the first parameter
#   - "demo" is the connection alias defined in the function under Edit -> Manage connections
#   - This connection provides access to the warehouse specified in the connection config
#
# @udf.context(argName="ctx"):
#   - Injects execution context as a parameter named "ctx"
#   - Context contains user identity (PreferredUsername, ObjectId, etc.) and session metadata
#   - Useful for auditing who triggered the UDF
#
# @udf.function():
#   - Registers this Python function as a callable UDF in Fabric SQL
#   - Makes it invokable from Power BI dataflows, notebooks, or SQL endpoints
@udf.connection("demo")
@udf.context(argName="ctx")
@udf.function()

# ===== FUNCTION SIGNATURE CONSTRAINTS =====
# CRITICAL: Fabric UDF parameters CANNOT use snake_case naming due to Fabric SQL limitations
# - Use camelCase (e.g., userId) or PascalCase (e.g., UserId) instead
# - Avoid reserved keywords like "user", "context", "connection" as parameter names
# - All user-provided parameters must be typed as strings; type conversion happens inside the function
#
# Parameter breakdown:
# - demo: Injected by @udf.connection decorator—provides SQL connection to the "demo" warehouse
# - ctx: Injected by @udf.context decorator—contains user identity and session info
# - ids: User-provided comma-separated list of SKU IDs (e.g., "123,456,789")
# - price: User-provided price value as string (e.g., "19.99")
def udf_update_price(
    demo: fn.FabricSqlConnection,
    ctx: fn.UserDataFunctionContext,
    ids: str,
    price: str
) -> str:

    # ===== USER NAME EXTRACTION AND FORMATTING =====
    # Parse the executing user's email from context to create a friendly display name for auditing.
    # Logic:
    # 1. Extract "PreferredUsername" from context (typically user's email: "bob.smith@company.com")
    # 2. Split at "@" and take the local part: "bob.smith"
    # 3. If local part contains dots (common in emails), replace dots with spaces and capitalize each token:
    #    "bob.smith" → "bob smith" → "Bob Smith"
    # 4. If no dots, use the local part as-is: "bsmith" → "bsmith"
    # 5. If extraction fails at any point, fallback to "Unknown User"
    try:
        email = ctx.executing_user.get("PreferredUsername", "")
        local_part = email.split("@")[0]
        
        if "." in local_part:
            user_name = " ".join(p.capitalize() for p in local_part.replace(".", " ").split())
        else:
            user_name = local_part or email
    except Exception:
        user_name = "Unknown User"
    
    # ===== INPUT VALIDATION: PRICE =====
    # Validate that the price parameter can be converted to a Decimal before hitting the database.
    # This prevents SQL errors and provides a cleaner error message to the caller.
    # Decimal() raises InvalidOperation if the string is not a valid numeric value.
    try:
        Decimal(price)
    except InvalidOperation:
        # Raise a Fabric-specific error that will be surfaced to the calling environment (e.g., Power BI)
        raise fn.UserThrownError("Invalid price: must be a numeric value.", {"price": price})
    
    # ===== SQL STORED PROCEDURE CALL =====
    # Build the EXEC statement with parameter placeholders ("?") for safe parameterized execution.
    # Parameterization prevents SQL injection and handles proper type conversions.
    #
    # CRITICAL: Must use three-part naming (Database.Schema.Object) for EXEC statements in Fabric warehouses.
    # Format: WH_testing.dbo.usp_update_price
    # - WH_testing: Warehouse name
    # - dbo: Schema name
    # - usp_update_price: Stored procedure name
    #
    # Parameters are bound in the ORDER they appear in the execute() call, NOT by name.
    # Order: (ids, price, user_name) maps to (@id_list, @price, @user_name)
    sql = """
        EXEC WH_testing.dbo.usp_update_price
        @id_list = ?
        ,@price = ?
        ,@user_name = ?;
    """
    
    # ===== DATABASE EXECUTION AND ERROR HANDLING =====
    try:
        # Open a connection to the SQL warehouse (context manager ensures proper cleanup)
        with demo.connect() as conn:

            # Create a cursor to execute SQL statements and fetch results
            cur = conn.cursor()
            
            # Execute the stored procedure with parameter tuple in the correct order
            # The sproc updates fact_price_table and inserts into fact_price_table_history
            cur.execute(sql, (ids, price, user_name))
            
            # Fetch the result set returned by the sproc
            # The sproc returns a single row with one column: rows_affected (the @@ROWCOUNT value)
            row = cur.fetchone()
            rows_affected = row[0] if row else 0

            # Commit the transaction to persist all changes made by the stored procedure
            # Without this, changes would be rolled back when the connection closes
            conn.commit()
            
            # Close the cursor to free resources (connection closed by context manager)
            cur.close()
            
    # Catch any database errors (connection failures, SQL errors, constraint violations, etc.)
    # Wrap in UserThrownError to surface a clean error message to the calling environment
    except Exception as exc:
        raise fn.UserThrownError("Failed to update price records.", {"error": str(exc)})
    
    # ===== RETURN SUCCESS MESSAGE =====
    # Construct a human-readable summary message for the calling application (e.g., Power BI).
    # Format: "Bob Smith updated 5 price(s) on 2026-01-12 14:30:45"
    # 
    # Timestamp is converted to Central Time and formatted without timezone info for readability.
    # This message can be displayed in Power BI or logged for auditing purposes.
    ts_local = datetime.datetime.now(tz=CENTRAL).replace(tzinfo=None)
    return f"{user_name} updated {rows_affected} price(s) on {ts_local.strftime('%Y-%m-%d %H:%M:%S')}"





@udf.connection("demo")
@udf.context(argName="ctx")
@udf.function()
def udf_insert_price(
    demo: fn.FabricSqlConnection,
    ctx: fn.UserDataFunctionContext,
    sku: str,
    price: str
) -> str:
    
    # Parse user name from executing context
    try:
        email = ctx.executing_user.get("PreferredUsername", "")
        local_part = email.split("@")[0]
        
        if "." in local_part:
            user_name = " ".join(p.capitalize() for p in local_part.replace(".", " ").split())
        else:
            user_name = local_part or email
    except Exception:
        user_name = "Unknown User"
    
    # Validate price is numeric
    try:
        Decimal(price)
    except InvalidOperation:
        raise fn.UserThrownError("Invalid price: must be a numeric value.", {"price": price})
    
    # Validate SKU is numeric
    try:
        int(sku)
    except ValueError:
        raise fn.UserThrownError("Invalid SKU: must be a numeric value.", {"sku": sku})
    
    sql = """
        EXEC WH_testing.dbo.usp_insert_price
        @sku = ?
        ,@price = ?
        ,@user_name = ?;
    """
    
    try:
        with demo.connect() as conn:
            cur = conn.cursor()
            cur.execute(sql, (sku, price, user_name))
            
            row = cur.fetchone()
            rows_affected = row[0] if row else 0
            
            conn.commit()
            cur.close()
            
    except Exception as exc:
        raise fn.UserThrownError("Failed to insert price record.", {"error": str(exc)})
    
    ts_local = datetime.datetime.now(tz=CENTRAL).replace(tzinfo=None)
    return f"{user_name} inserted {rows_affected} price record on {ts_local.strftime('%Y-%m-%d %H:%M:%S')}"



@udf.connection("demo")
@udf.context(argName="ctx")
@udf.function()
def udf_delete_price(
    demo: fn.FabricSqlConnection,
    ctx: fn.UserDataFunctionContext,
    ids: str
) -> str:
    
    try:
        email = ctx.executing_user.get("PreferredUsername", "")
        local_part = email.split("@")[0]
        
        if "." in local_part:
            user_name = " ".join(p.capitalize() for p in local_part.replace(".", " ").split())
        else:
            user_name = local_part or email
    except Exception:
        user_name = "Unknown User"
    
    sql = """
        EXEC WH_testing.dbo.usp_delete_price
        @id_list = ?
        ,@user_name = ?;
    """
    
    try:
        with demo.connect() as conn:
            cur = conn.cursor()
            cur.execute(sql, (ids, user_name))
            
            row = cur.fetchone()
            rows_affected = row[0] if row else 0
            
            conn.commit()
            cur.close()
            
    except Exception as exc:
        raise fn.UserThrownError("Failed to delete price records.", {"error": str(exc)})
    
    ts_local = datetime.datetime.now(tz=CENTRAL).replace(tzinfo=None)
    return f"{user_name} deleted {rows_affected} price(s) on {ts_local.strftime('%Y-%m-%d %H:%M:%S')}"


@udf.connection("demo")
@udf.context(argName="ctx")
@udf.function()
def udf_reactivate_price(
    demo: fn.FabricSqlConnection,
    ctx: fn.UserDataFunctionContext,
    ids: str
) -> str:
    
    try:
        email = ctx.executing_user.get("PreferredUsername", "")
        local_part = email.split("@")[0]
        
        if "." in local_part:
            user_name = " ".join(p.capitalize() for p in local_part.replace(".", " ").split())
        else:
            user_name = local_part or email
    except Exception:
        user_name = "Unknown User"
    
    sql = """
        EXEC WH_testing.dbo.usp_reactivate_price
        @id_list = ?
        ,@user_name = ?;
    """
    
    try:
        with demo.connect() as conn:
            cur = conn.cursor()
            cur.execute(sql, (ids, user_name))
            
            row = cur.fetchone()
            rows_affected = row[0] if row else 0
            
            conn.commit()
            cur.close()
            
    except Exception as exc:
        raise fn.UserThrownError("Failed to reactivate price records.", {"error": str(exc)})
    
    ts_local = datetime.datetime.now(tz=CENTRAL).replace(tzinfo=None)
    return f"{user_name} reactivated {rows_affected} price(s) on {ts_local.strftime('%Y-%m-%d %H:%M:%S')}"