# Phase 2 – Real-time SQL Mirror Completion

Updated: 2025-10-08

## ✅ Scope Delivered

- **Direct Messages**
  - Flutter client reads from SQL via `sqlGatewayDmListConversations` and `sqlGatewayDmListMessages` behind the existing repository layer.
  - Dual-write callable `sqlGatewayDmSend` mirrors successful Firestore writes into SQL using the envelope builder in `DirectMessageService`.
  - Stored procedures `sp_StoreMirror_UpsertDmConversation` and `sp_StoreMirror_UpsertDmMessage` upsert conversations/messages, refresh aggregates, and append audit trails.
- **Follow Graph**
  - Client relationship checks routed to SQL using `sqlGatewayFollowGetRelationship`, returning outgoing/incoming follow edges plus block state.
  - Follow writes mirrored via callable `sqlGatewayFollowEdgeUpsert`; stored procedure `sp_StoreMirror_UpsertFollowEdge` handles idempotent UPSERTs.
- **Event Fabric**
  - Firestore triggers (`mirrorDmMessages`, `mirrorDmConversations`, `mirrorFollowEdges`) publish CloudEvents to Azure Service Bus through `realtime_mirror/publisher`.
  - Queue processor (`createSqlWriterProcessor`) consumes events and executes the appropriate SQL stored procedure with retry/abandon semantics.
  - Scheduled `drainRealtimeMirrorQueue` drainer ensures backlog health and emits structured stats.
- **Observability & Tooling**
  - Callables use `CallableLatencyTracker` metrics categories (`sqlMirror`, `dmSqlMirror`, `followSqlMirror`).
  - Consistency checker `scripts/dm_follow_consistency.js` compares Firestore vs SQL for conversations, messages, and follow edges.

## ⚙️ Deployment Checklist

1. **SQL Schema & Procedures**
   - Apply `backend/scripts/deploy_realtime_mirror.sqlcmd` (includes DM + Follow upsert/delete procs, relationship reader).
   - Confirm supporting tables (`DmConversation`, `DmMessage`, `DmMessageAudit`, `FollowEdge`, block tables) contain `LastEvent*` metadata columns.
2. **Azure Service Bus**
   - Provision topic `realtime-mirror` with subscriptions `sql-writer` and `monitoring`.
   - Assign Function App managed identity **Send**/**Listen** roles or configure SAS keys.
3. **Functions Environment Variables** (`firebase functions:config:set` or Secret Manager)
   - `SERVICEBUS_CONNECTION_STRING`
   - Optional overrides: `SERVICEBUS_TOPIC_REALTIME_MIRROR`, `SERVICEBUS_SUBSCRIPTION_SQL_WRITER`, `SQL_PROC_*` names.
   - Feature flag: `USE_SQL_DM_WRITE_MIRROR=true` to activate queue writer + dual write.
4. **Flutter Remote Config**
   - Release toggles `MessagingFeatureFlags.useSqlMirrorDoubleWrite` and `FollowFeatureFlags.useSqlMirrorDoubleWrite` per cohort.

## 🧪 Validation

- **Automated Tests**
  - `cd functions; npm test` → ✅ all realtime mirror, SQL gateway, and messaging suites pass (11/11).
- **Manual Smoke**
  - Create/update/delete DMs and follow edges with feature flags on; confirm Service Bus receives events and SQL tables update.
  - Run `node scripts/dm_follow_consistency.js --limit=50 --check=conversations,messages,follow` until mismatch count = 0.
  - Monitor `CallableLatencyTracker` dashboards for `dmSqlMirror`/`followSqlMirror` P95 < 200 ms.

## 🚀 Rollout Path

1. Enable dual write for an internal cohort; watch Service Bus queue depth (< 1,000) and DLQ.
2. Switch DM inbox read path to SQL (feature flag already available); keep Firestore fallback until consistency checker stable for 7 days.
3. Publish follow relationship API from SQL to external consumers (already consumed by Flutter via callable).
4. Remove Firestore read dependency once SQL latency + consistency SLOs hold.

## 📌 Notes & Next Steps

- `drainRealtimeMirrorQueue` is scheduled every minute—verify Cloud Scheduler/Cloud Functions cron is enabled in production project.
- Add Azure Monitor alerting on `sql_mirror_latency_ms` once Application Insights integration is wired (placeholder hooks in processor).
- Nightly pipeline should archive consistency results to Storage (see `scripts/dm_follow_consistency.js`).

Phase 2 deliverables are complete and production-ready pending infrastructure provisioning and standard rollout gates.
