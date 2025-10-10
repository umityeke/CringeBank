/**
 * SQL Gateway API Documentation
 * 
 * The SQL Gateway provides a centralized interface for Flutter/web clients
 * to invoke stored procedures on the SQL Server backend. All procedures
 * are exposed as callable Cloud Functions with automatic authentication,
 * authorization (RBAC), parameter validation, and error handling.
 * 
 * ## Architecture
 * 
 * 1. **Procedure Registry** (`sql_gateway/procedures.js`)
 *    - Maps friendly names (e.g., 'ensureUser') to stored procedure names (e.g., 'sp_EnsureUser')
 *    - Defines input/output parameter schemas for validation
 *    - Specifies required roles/permissions for each procedure
 * 
 * 2. **Callable Factory** (`sql_gateway/callable.js`)
 *    - Wraps procedures in Firebase HTTPS Callable functions
 *    - Enforces authentication via Firebase Auth context
 *    - Checks RBAC permissions via PolicyEvaluator
 *    - Executes SQL stored procedures via connection pool
 *    - Normalizes results and error codes
 * 
 * 3. **Auto-registration** (`index.js`)
 *    - Dynamically exports all procedures as `exports.sqlGateway<ProcedureName>`
 *    - Example: 'ensureUser' → `exports.sqlGatewayEnsureUser`
 * 
 * ## Adding New Procedures
 * 
 * ### Step 1: Create SQL Stored Procedure
 * ```sql
 * -- backend/scripts/stored_procedures/sp_MyNewProcedure.sql
 * CREATE OR ALTER PROCEDURE dbo.sp_MyNewProcedure
 *   @InputParam NVARCHAR(64),
 *   @OutputValue INT OUTPUT
 * AS
 * BEGIN
 *   -- Your logic here
 *   SET @OutputValue = 123;
 * END
 * ```
 * 
 * ### Step 2: Register in Gateway
 * Edit `sql_gateway/procedures.js`:
 * ```javascript
 * {
 *   myNewProcedure: {
 *     procedure: 'sp_MyNewProcedure',
 *     params: {
 *       input: { inputParam: 'string' },
 *       output: { outputValue: 'int' }
 *     },
 *     roles: ['user'], // or ['admin', 'system_writer']
 *   }
 * }
 * ```
 * 
 * ### Step 3: Deploy
 * ```bash
 * cd functions
 * npm run deploy
 * ```
 * 
 * ### Step 4: Call from Flutter
 * ```dart
 * final result = await FirebaseFunctions.instance
 *   .httpsCallable('sqlGatewayMyNewProcedure')
 *   .call({'inputParam': 'value'});
 * 
 * print(result.data['outputValue']); // 123
 * ```
 * 
 * ## RBAC Integration
 * 
 * Each procedure can specify required roles:
 * - `['user']` - Any authenticated user
 * - `['system_writer']` - Backend service accounts / elevated operations
 * - `['superadmin']` - Full database access for admin panel
 * 
 * Roles are assigned via custom claims:
 * ```javascript
 * await admin.auth().setCustomUserClaims(uid, { 
 *   role: 'system_writer' 
 * });
 * ```
 * 
 * ## Error Handling
 * 
 * All SQL errors are normalized to Firebase HTTPS error codes:
 * - `unauthenticated` - Missing or invalid Firebase Auth token
 * - `permission-denied` - Insufficient RBAC role
 * - `invalid-argument` - Missing or invalid parameters
 * - `not-found` - Resource not found (SQL returns empty)
 * - `already-exists` - Duplicate key / unique constraint violation
 * - `deadline-exceeded` - SQL timeout
 * - `internal` - Unexpected SQL or connection errors
 * 
 * ## Connection Pool
 * 
 * The gateway uses a shared connection pool (`sql_gateway/pool.js`)
 * configured via environment variables:
 * - `SQL_SERVER` - Database hostname
 * - `SQL_DATABASE` - Database name
 * - `SQL_USER` - SQL login username
 * - `SQL_PASSWORD` - SQL login password
 * - `SQL_ENCRYPT` - Enable TLS (default: true)
 * - `SQL_POOL_MAX` - Max connections (default: 10)
 * - `SQL_POOL_MIN` - Min connections (default: 2)
 * - `SQL_TIMEOUT` - Query timeout in ms (default: 30000)
 * 
 * ## Migration Workflow
 * 
 * When migrating Firestore logic to SQL:
 * 
 * 1. Create stored procedure with business logic
 * 2. Register in gateway with appropriate RBAC roles
 * 3. Update Flutter service to call new callable function
 * 4. Add feature flag for gradual rollout
 * 5. Monitor Cloud Functions logs and SQL performance
 * 6. Remove old Firestore code after validation
 * 
 * ## Best Practices
 * 
 * - Use OUTPUT parameters for return values, not SELECT result sets (when possible)
 * - Validate all inputs in stored procedure (defense in depth)
 * - Log important operations via sp_Admin_LogAudit
 * - Use transactions for multi-step operations
 * - Set appropriate RBAC roles (principle of least privilege)
 * - Return structured error codes for client handling
 * - Document procedure purpose and parameters in SQL header
 * 
 * ## Monitoring
 * 
 * View callable function logs:
 * ```bash
 * firebase functions:log --only sqlGateway
 * ```
 * 
 * Check SQL procedure execution time:
 * ```sql
 * SELECT TOP 100
 *   OBJECT_NAME(object_id) AS ProcedureName,
 *   total_elapsed_time / execution_count AS avg_ms,
 *   execution_count
 * FROM sys.dm_exec_procedure_stats
 * ORDER BY avg_ms DESC;
 * ```
 */

module.exports = {
  // This file is documentation only; see sql_gateway/index.js for implementation
};
