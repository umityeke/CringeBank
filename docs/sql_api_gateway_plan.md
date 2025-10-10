# SQL API Gateway Plan
# SQL API Gateway Plan

## Context

- Firebase callable functions currently access Firestore and auxiliary services directly, with a dedicated `ensureSqlUser` callable invoking `sp_EnsureUser`.
- Phase 0 migration introduced persistent identity in SQL Server; subsequent phases will rely on additional stored procedures for financial and marketplace features.
- A consistent gateway layer inside Cloud Functions is required to expose SQL-backed operations while preserving RBAC, telemetry, and connection pooling guarantees.

## Goals

1. Centralize SQL access behind a single module that manages configuration, connection pooling, retries, and error normalization.
2. Provide a declarative mapping between callable/HTTP function endpoints and stored procedures (including parameter typing and validation).
3. Enforce RBAC policies and app-check/auth preconditions before executing any SQL command.
4. Emit structured logs/metrics for observability (success, latency, procedure name, row counts) and surface actionable error messages to clients.
5. Keep the gateway extensible so Phase 1+ procedures can be added without modifying `functions/index.js` monolithically.

## Non-Goals

- Implementing every Phase 1+ SQL procedure immediately.
- Replacing existing Firestore operations that do not require SQL.
- Creating long-lived HTTP servers outside Firebase Cloud Functions.

## Architecture Overview

- **Module boundary**: `/functions/sql_gateway` encapsulates setup and exports factory helpers.
- **Connection management**: shared pool using `mssql`, similar to `ensure_user`, with health checks and reset logic.
- **Procedure registry**: each procedure described via configuration object (`name`, `inputs`, `outputs`, `access`, optional result transformers).
- **Invoker helpers**:
  - `callProcedure(context, procedureKey, payload, scopeContext)` handles RBAC, validation, logging, execution, and result shaping.
  - Schema validation via lightweight zod-esque helper (reuse existing validator if present; fallback to manual checks).
- **Exposure**: register callable functions in `functions/index.js` by importing registry and invoking `createCallable(procedureKey)`; HTTP/scheduled variants supported later.

## Security & Access Control

- Require Firebase Auth & AppCheck (where applicable) before entering gateway.
- Leverage existing `PolicyEvaluator` to assert permissions using `resource`/`action` fields declared per procedure.
- Support service-to-service calls by allowing `system_writer` token (to be added in parallel workstream).

## Error Handling

- Normalize SQL errors to `HttpsError` codes: `ELOGIN` → `failed-precondition`, `ETIMEDOUT` → `deadline-exceeded`, unique constraint violations → `already-exists`, etc.
- Return sanitized messages; hide internal stack traces.
- Emit structured logs on failures with correlation IDs (context event ID or generated UUID).

## Observability

- Structured logs via `functions.logger` (`sqlGateway.attempt`, `sqlGateway.success`, `sqlGateway.failure`).
- Capture latency (start/end timestamps) and row count when available.
- Include pool stats when connection acquisition exceeds threshold.

## Rollout Strategy

1. Scaffold gateway module with connection pool, base invoker, and a pilot procedure (`ensure_user`) to validate flow.
2. Add unit tests (Jest) mocking `mssql.ConnectionPool` to ensure validation and error translation.
3. Wire pilot callable into `functions/index.js` under feature flag; keep existing `ensureSqlUser` export for backward compatibility during transition.
4. Once validated, migrate additional procedures incrementally.

## Open Questions / TODOs

- Identify minimal validation library (zod vs bespoke). Pending repository alignment.
- Decide on caching strategy for frequently used lookup procedures.
- Determine whether to support transactional batches within callable scope.

## Implementation Checklist

- [x] Create `/functions/sql_gateway/config.js` for SQL config + environment validation.
- [x] Create `/functions/sql_gateway/pool.js` for connection pooling helpers.
- [x] Create `/functions/sql_gateway/procedures.js` registry with pilot `ensureUser` definition.
- [x] Create `/functions/sql_gateway/callable.js` to build callable handlers with RBAC + error mapping.
- [x] Add Jest tests under `/functions/__tests__/sql_gateway.test.js` covering validation, RBAC enforcement, success, and failure cases.
- [x] Update `/functions/index.js` to expose `sqlGatewayEnsureUser` callable (pilot) alongside existing handler for comparison.
- [x] Document environment variables in README (SQLSERVER_* already defined; note reuse).

Environment variables reused by the gateway match the existing user search + follow preview stack:
`SQLSERVER_HOST`, `SQLSERVER_PORT`, `SQLSERVER_USER`, `SQLSERVER_PASS`, `SQLSERVER_DB`, `SQLSERVER_POOL_MAX`, `SQLSERVER_POOL_MIN`, `SQLSERVER_POOL_IDLE`, `SQLSERVER_ENCRYPT`, and `SQLSERVER_TRUST_CERT`. No new secrets are required beyond those already listed in `docs/USER_SEARCH_BACKEND.md`.

## Observability

- Every invocation emits `sqlGateway.attempt`, `sqlGateway.success`, or `sqlGateway.failure` structured logs with latency (`elapsedMs`), payload key lists, row counts, and SQL return values.
- Procedures may optionally extend the logging payload via `logContextBuilder(result, payload, context)`; failures during log enrichment are caught and surfaced as `sqlGateway.log_context_failed` warnings.
- Errors are normalized via `mapSqlErrorToHttps`, ensuring callers receive canonical Firebase `HttpsError` codes while logs retain raw SQL telemetry (`code`, `number`).

## Dependencies & Assumptions

- `mssql` dependency already present via `ensure_user.js` (confirm in `functions/package.json`).
- `PolicyEvaluator` remains the RBAC source of truth.
- SQL Server accessible via existing env configuration used by backfill scripts.
- Future procedures will return recordsets via `mssql`; initial gateway exposes raw rows or transformed payloads as needed.
