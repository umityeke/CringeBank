# CringeStore SQL Gateway Plan (Phase 1)

This document outlines the callable gateway architecture required to migrate CringeStore's escrow and order flows from Firestore to the SQL Server backend during Phase 1.

## Scope

- Replace Firebase callable functions (`escrowLock`, `escrowRelease`, `escrowRefund`) with equivalents that invoke SQL stored procedures.
- Maintain compatibility with the existing Flutter client while gradually shifting data reads/writes to SQL via the gateway.
- Ensure auditability and deterministic behaviour around wallet balances, escrow state, and product availability.

## High-Level Architecture

1. **API Surface**
   - Maintain HTTPS callable endpoints (Firebase Functions) for mobile/web clients to consume without immediate client changes.
   - Introduce a shared gateway module that encapsulates SQL connectivity, parameter binding, and response translation.
   - Map each callable to an explicit stored procedure (`sp_Store_CreateOrderAndLockEscrow`, `sp_Store_ReleaseEscrow`, `sp_Store_RefundEscrow`).

2. **Execution Flow**
   1. Validate auth context and role claims (existing middleware).
   2. Translate Firestore document identifiers to SQL public IDs where needed.
   3. Execute the matching stored procedure with hardened parameter sets.
   4. Convert SQL output/result to the current JSON contract (e.g., `{ ok: true, orderId }`).
   5. Emit structured error codes mapped from SQL RAISERROR messages.

3. **Error Handling Strategy**
   - SQL procedures already raise rich messages (e.g., insufficient balance). Map these to `functions.https.HttpsError` codes.
   - Introduce an error catalog to align stored procedure messages with client-facing i18n keys.
   - Implement retry-safe categorisation (e.g., transient connectivity vs. business rule violations).

4. **Telemetry & Auditing**
   - Log every gateway invocation with correlation IDs (Firebase request ID + SQL `@OrderPublicId`).
   - Capture latency metrics per stored procedure and bubble up to Cloud Logging / Application Insights bridge.
   - Persist optional notes (admin reason strings) via stored procedure parameters (e.g., `@RefundReason`).

## Module Breakdown

| Module | Responsibility | Notes |
| ------ | -------------- | ----- |
| `functions/sqlClient.js` | Connection pooling, command execution helpers. | Use `mssql` driver with env-driven connection string. |
| `functions/escrowGateway.js` | Translates callable inputs to SQL params and back. | Shared by all escrow endpoints. |
| `functions/cringe_store_functions.js` | Thin wrappers calling into gateway; remove Firestore transactions. | Preserve auth/role guard logic. |
| `backend/tests/escrow_gateway.spec.ts` | Integration tests using localdb or docker SQL container. | Validate happy path and error propagation. |

## Data Contract Mapping

| Firestore Field | SQL Column | Notes |
| --------------- | ---------- | ----- |
| `orderId` | `StoreOrders.OrderPublicId` | Exposed to client; use public ID returned from procedure. |
| `status` | `StoreOrders.Status` | Stored as uppercase values (`PENDING`, `COMPLETED`, `CANCELED`). |
| `escrow.status` | `StoreEscrows.EscrowState` | Aligns with uppercase state strings (`LOCKED`, `RELEASED`, `REFUNDED`). |
| `wallet.goldBalance` | `StoreWallets.GoldBalance` | Wallet reads will be surfaced via future read APIs. |

## Incremental Rollout Plan

1. **Gateway Feature Flag (Phase 1a)**
   - Env flag `USE_SQL_ESCROW_GATEWAY` defaults to `true`; pass `--dart-define USE_SQL_ESCROW_GATEWAY=false` to force the legacy Firestore path.
   - When disabled, `escrowLock`/`Release`/`Refund` fall back to Firestore logic for emergency rollback.

2. **Read Model Sync (Phase 1b)**
   - Populate SQL tables via backfill scripts to mirror existing Firestore data.
   - Expose read endpoints (REST or callable) to fetch order/escrow state from SQL for admin dashboards.

3. **Full Cutover (Phase 1c)**
   - Remove Firestore writes after validating parity and reconciliation reports.
   - Update Flutter app to read orders/escrows from new REST endpoints (Phase 2 scope).

## TODOs & Dependencies

- [ ] Implement `sqlClient.js` connection wrapper with retry/backoff strategy.
- [ ] Build parameter mappers and response serializers for each stored procedure.
- [ ] Introduce structured error catalog and map SQL errors to Firebase `HttpsError` codes.
- [ ] Create gateway integration tests (using docker-compose SQL instance defined in backend).
- [ ] Backfill existing order/escrow data into SQL prior to cutover.

## Risks & Mitigations

- **Data Drift:** Ensure single writer principle by gating Firestore writes once SQL path enabled; use transactions around stored procedures.
- **Latency:** Connection pool warm-up and parameterised procedures should keep latency comparable to Firestore transactions; monitor and tune.
- **Rollback Plan:** Feature flag allows reverting to Firestore path quickly if SQL path misbehaves.

---
Last updated: 2025-10-08
