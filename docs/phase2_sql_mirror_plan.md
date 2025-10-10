# Phase 2 – Real-time Modules SQL Mirror

## 1. Scope

- Direct Messages (DM): `DmConversation`, `DmMessage` parity between Firestore and SQL.
- Follow graph: `FollowEdge` parity between Firestore collections and SQL tables.
- Event delivery fabric: decouple Firestore triggers from SQL writers via Azure Service Bus (or equivalent queue).

## 2. Target Architecture

| Layer | Responsibility |
| --- | --- |
| Mobile clients | Continue reading from Firestore initially, perform dual writes when feature flag enabled. |
| Firestore triggers | Emit canonical events (`dm.message.created`, `follow.edge.updated`, …) to Service Bus. |
| Queue workers | Consume events, execute idempotent UPSERTs into SQL (`dbo.DmMessage`, `dbo.FollowEdge`). |
| SQL | Serves as long-term source for analytics and future SignalR/WebSocket real-time surface. |
| Observability | Crashlytics + Azure Monitor metrics; custom latency + backlog dashboards. |

### Event Model

- Topic: `realtime-sync`
- Message schema:

  ```json
  {
    "eventType": "dm.message.created",
    "occurredAt": "2025-10-08T12:34:00Z",
    "entityId": "convoId/messageId",
    "payload": { /* minimal fields needed for SQL */ },
    "attempt": 1
  }
  ```

- Deduplication: use `entityId` + `eventType` as idempotency key in SQL to prevent double writes.
- DLQ: events failing >5 retries land in `realtime-sync-deadletter`, surfaced in Ops dashboard.

## 3. SQL Schema Additions

- Ensure the following tables exist with timestamp + idempotency metadata:
  - `dbo.DmConversation` (existing) ➜ add `LastSyncedEventId UNIQUEIDENTIFIER`.
  - `dbo.DmMessage` (existing) ➜ add `SyncSource NVARCHAR(32)` + `EventId UNIQUEIDENTIFIER` + index on `(ConversationId, CreatedAt)`.
  - `dbo.FollowEdge` (existing) ➜ add `SyncSource`, `EventId`, `RetryCount`.
- Stored proc `dbo.sp_UpsertDmMessageFromEvent` handles UPSERT logic + idempotency.

## 4. Deployment/Infra Checklist

- [ ] Provision Azure Service Bus namespace + queues (`realtime-sync`, `realtime-sync-deadletter`).
- [ ] Configure function app managed identity with `Send`/`Listen` roles.
- [ ] Secrets: add Service Bus connection string to Firebase Function env + worker.
- [ ] Extend CI pipeline to run SQL migrations + deploy worker container.

## 5. Timeline & Dependencies

| Sprint | Deliverable |
| --- | --- |
| S1 | Service Bus provision, SQL schema updates, skeleton event producer |
| S2 | DM event consumer + integration tests, follow consumer skeleton |
| S3 | Flutter dual-write behind feature flag, end-to-end consistency monitor |
| S4 | Switch read path to SQL (pilot), latency bakeoff (<200ms), production rollout |

## 6. Risks & Mitigation

- **Queue backlog** → Auto-scale worker pods, alert on queue depth > 1,000.
- **Data drift** → Nightly `dm_follow_consistency.js` + `verify_auth_sync.js`; add DLQ replay tool.
- **Latency budget** → Track end-to-end from Firestore write to SQL commit using Application Insights custom metrics.

## 7. Sync Services Implementation

| Component | Technology | Responsibility |
| --- | --- | --- |
| Firestore trigger – DM | Firebase Function (Node.js) | On new/updated document in `conversations/{id}/messages/{messageId}`, enqueue `dm.message.*` event. |
| Firestore trigger – Follow | Firebase Function (Node.js) | On new/updated document in `follows/{uid}/targets/{target}`, enqueue `follow.edge.*` event. |
| Queue worker | Azure Function (Node.js) or containerized Node worker | Dequeue events, call `dbo.sp_UpsertDmMessageFromEvent` / `dbo.sp_UpsertFollowEdgeFromEvent`, emit metrics. |
| Retry orchestrator | Azure Functions durable timer | Replays DLQ batches after manual verification. |

### Processing Flow
1. Trigger function builds minimal payload (IDs, timestamps, normalized status).
2. Payload published to Service Bus with `messageId = hash(eventType + entityId + updatedAt)` for idempotency.
3. Worker receives message, wraps SQL call in transaction; if SQL returns transient error → abandon message so Service Bus retries.
4. On success, worker publishes metric `sql_mirror_latency_ms` (queue enqueue to SQL commit) to Application Insights.

### Deployment Notes
- Package trigger functions with `firebase deploy --only functions:dmMirror,functions:followMirror`.
- Worker deployed via Azure Functions with consumption plan; scale out to max 20 instances.
- Shared config stored in App Configuration: connection strings, retry counts, feature flags.

## 8. Flutter Dual-write Adaptation

### Feature Flags

- `MessagingFeatureFlags.useSqlMirrorDoubleWrite` → enables DM dual write.
- `FollowFeatureFlags.useSqlMirrorDoubleWrite` (new) → follow edges.
- Remote config support to rollout gradually by cohort.

### Client Changes

1. Wrap existing Firestore writes in repository layer (`MessagingRepository`, `FollowService`).
2. After Firestore write succeeds, enqueue SQL mirror write via callable `sqlGatewayEnsureMessage` / `sqlGatewayEnsureFollow`.
3. Capture latency metrics using `CallableLatencyTracker` categories `dmSqlMirror` and `followSqlMirror`.
4. Implement fallback: if SQL write fails, surface non-blocking toast + crashlytics log, mark for retry via background isolate.

### Read Path Migration

- Phase A: Continue reading from Firestore; poll SQL for verification.
- Phase B: Introduce `SqlMirrorMessageRepository` behind feature flag, hydrate UI from SQL with Firestore fallback.
- Phase C: Remove Firestore read dependency once SQL latency < 200 ms for P95 and consistency checker reports <0.1% drift.

## 9. Validation & Observability

### Automated Tests

- Jest: extend `scripts/__tests__/dm_follow_consistency.test.js` to cover queue-to-SQL flows using fixture queue messages.
- Integration (Firebase emulator + SQL Docker): orchestrate dual-write scenario, assert both Firestore and SQL rows present.
- Flutter: widget tests covering retry UI; integration tests using fake SQL gateway client.

### Consistency & Drift Detection

- Nightly pipeline runs `scripts/dm_follow_consistency.js` and stores JSON summary to Storage.
- Alert if mismatches > 0.5% of checked records or missingFirestore > 100.
- Provide “replay DLQ” tool to process dead-lettered events and recheck.

### Latency Measurement (< 200 ms target)

- Produce App Insights metric `sql_mirror_latency_ms` from worker (queue enqueue timestamp to SQL commit).
- Collect client-side `callable_latency` with category `dmSqlMirror`/`followSqlMirror` via Crashlytics.
- Dashboard P50/P95 latency < 200 ms; auto page on P95 > 250 ms for 15 minutes.

### Dashboards & Alerting

- Azure Dashboard combining: queue depth, worker CPU, `sql_mirror_latency_ms`, DLQ count.
- Grafana/BigQuery data studio board for Drift % and client error rates.
- On-call runbook references this doc; include step-by-step for draining backlog.

---

Updated: 2025-10-08
