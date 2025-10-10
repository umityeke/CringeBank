# CringeStore Phase 1 Progress Log

**Date:** 2025-10-08

## Completed Work

- **Firestore Flow Review:** Captured end-to-end behaviour of `escrowLock`, `escrowRelease`, and `escrowRefund` callable functions to inform SQL parity.
- **SQL Schema Draft:** Added migration scripts for `StoreWallets`, `StoreProducts`, `StoreOrders`, and `StoreEscrows` tables with alignment to the Firestore data model (IDs, timestamps, status fields, and concurrency tokens).
- **Stored Procedures:** Authored three core procedures to cover the escrow lifecycle:
  - `sp_Store_CreateOrderAndLockEscrow` — Creates the order, debits buyer wallet, and reserves the product.
  - `sp_Store_ReleaseEscrow` — Completes the order, credits seller/platform wallets, and marks products as sold.
  - `sp_Store_RefundEscrow` — Cancels the order, refunds buyer wallet, and reactivates the product.
- **Gateway Blueprint:** Drafted `docs/cringestore_sql_gateway_plan.md` describing the callable gateway strategy, module breakdown, and rollout milestones.

## Pending Items

- Implement SQL connectivity layer (`functions/sqlClient.js`) with pooled credentials.
- Build gateway adapters inside `functions/cringe_store_functions.js` guarded by feature flag.
- Create automated tests for stored procedures (happy path + failure cases) using the backend test harness.
- Prepare backfill scripts to sync existing Firestore data into SQL tables.
- Establish reconciliation dashboard or scripts to monitor wallet/order deltas during dual-write period.

## Assumptions & Open Questions

- Status values will use uppercase enumerations (e.g., `PENDING`, `LOCKED`) for SQL consistency; Flutter app may require mapping.
- Wallets without existing rows should be created via onboarding/top-up flows before SQL procedures are invoked.
- Commission rate is hard-coded at 5% in the stored procedure; consider storing this in a configuration table for future flexibility.
- Platform wallet identifier is fixed as `platform`; confirm tenant-specific overrides are not required.

## Next Checkpoints

1. Stand up local SQL instance and validate migrations + stored procedures.
2. Wire gateway feature flag and exercise flows end-to-end against SQL in a staging environment.
3. Update documentation with reconciliation playbooks before production rollout.
