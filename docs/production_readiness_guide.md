# Production Readiness Guide

**Tarih:** 9 Ekim 2025  
**Amaç:** Production deployment için son hazırlıklar

---

## 🎯 Production Readiness Checklist

### 1. Feature Flag Configuration

#### Firebase Remote Config Setup

**Firebase Console → Remote Config:**

```json
{
  "use_sql_escrow_gateway": {
    "defaultValue": {
      "value": "false"
    },
    "conditionalValues": {
      "canary_5_percent": {
        "value": "true"
      },
      "canary_25_percent": {
        "value": "true"
      },
      "canary_50_percent": {
        "value": "true"
      },
      "full_rollout": {
        "value": "true"
      }
    },
    "description": "Enable SQL Gateway for CringeStore financial operations"
  }
}
```

**Condition Definitions:**

```yaml
canary_5_percent:
  Name: "Canary 5%"
  Condition: Percent (5%)
  Color: Yellow

canary_25_percent:
  Name: "Canary 25%"  
  Condition: Percent (25%)
  Color: Orange

canary_50_percent:
  Name: "Canary 50%"
  Condition: Percent (50%)
  Color: Red

full_rollout:
  Name: "Full Rollout (100%)"
  Condition: All Users
  Color: Green
```

**Flutter Integration (Already Done):**

```dart
// lib/utils/store_feature_flags.dart
class StoreFeatureFlags {
  static const bool useSqlEscrowGateway = bool.fromEnvironment(
    'USE_SQL_ESCROW_GATEWAY',
    defaultValue: true, // Default enabled, Remote Config can override
  );
}
```

**Rollout Plan:**
1. **Week 1:** 5% (canary_5_percent condition active)
2. **Week 2:** 25% (if no issues)
3. **Week 3:** 50%
4. **Week 4:** 100% (full_rollout condition active)

---

### 2. SLA Definition

**Service Level Agreement for SQL Gateway:**

| Metric | Target | Measurement | Alert Threshold |
|--------|--------|-------------|-----------------|
| **Uptime** | 99.9% | Monthly | <99.5% |
| **P95 Latency** | <500ms | Per callable | >1000ms |
| **Error Rate** | <1% | Per hour | >3% |
| **Wallet Consistency** | 100% | Daily check | >0 inconsistencies |
| **Order Success Rate** | >99% | Per day | <97% |

**Acceptable Downtime:**
- Monthly: 43.8 minutes
- Weekly: 10.1 minutes
- Daily: 1.4 minutes

**Response Times:**
- **Critical (Negative Balances):** 15 minutes
- **High (>3% error rate):** 1 hour
- **Medium (Performance degradation):** 4 hours
- **Low (Monitoring issues):** 24 hours

---

### 3. Incident Response Runbook

#### Incident #1: Negative Wallet Balances

**Symptoms:**
- Hourly metrics alert: NegativeBalances > 0
- User reports insufficient funds error

**Diagnosis:**

```sql
-- Identify affected users
SELECT 
    AuthUid,
    GoldBalance,
    PendingGold,
    UpdatedAt
FROM StoreWallets
WHERE GoldBalance < 0
ORDER BY GoldBalance ASC;

-- Check recent transactions
SELECT TOP 20
    AuthUid,
    AmountDelta,
    Reason,
    MetadataJson,
    CreatedAt
FROM StoreWalletLedger
WHERE AuthUid IN (SELECT AuthUid FROM StoreWallets WHERE GoldBalance < 0)
ORDER BY CreatedAt DESC;
```

**Resolution:**

```sql
-- Manual balance correction (requires superadmin)
EXEC sp_Store_AdjustWalletBalance
    @TargetAuthUid = 'affected_user_uid',
    @ActorAuthUid = 'admin_uid',
    @AmountDelta = 100, -- Correction amount
    @Reason = 'Manual correction - negative balance fix',
    @MetadataJson = '{"ticket": "INC-001", "approved_by": "admin_name"}',
    @IsSystemOverride = 1;
```

**Prevention:**
- Review transaction that caused negative balance
- Fix escrow lock/release logic if bug found
- Add database constraint (GoldBalance >= 0) with proper error handling

---

#### Incident #2: High Error Rate (>3%)

**Symptoms:**
- Cloud Functions error rate alert
- Users reporting "Something went wrong" errors

**Diagnosis:**

```bash
# Check Cloud Functions logs
firebase functions:log --only sqlGatewayStoreCreateOrder --limit 100

# Filter for errors
firebase functions:log | grep "severity=ERROR"

# Common error patterns:
# - SQL connection timeout
# - SQL deadlock
# - Invalid input validation
# - RBAC permission denied
```

**Resolution:**

1. **If SQL Connection Issues:**
   ```bash
   # Check Azure SQL status
   az sql db show --name cringebank-prod --server prod-server --resource-group rg-cringebank
   
   # Check connection pool
   # Restart Cloud Functions (redeploy)
   firebase deploy --only functions:sqlGatewayStoreCreateOrder
   ```

2. **If Deadlocks:**
   ```sql
   -- Check deadlock history
   SELECT * FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;
   
   -- Kill blocking session (extreme caution!)
   KILL <session_id>;
   ```

3. **If Input Validation:**
   - Review callable input schema
   - Fix client-side validation
   - Deploy hotfix

**Rollback Decision:**
- If error rate >10% for >15 minutes: Immediate rollback
- If error rate 3-10% for >1 hour: Evaluate rollback
- If error rate <3%: Monitor and investigate

---

#### Incident #3: Wallet Consistency Failure

**Symptoms:**
- Daily consistency check reports inconsistencies
- Firestore ≠ SQL balances

**Diagnosis:**

```bash
cd functions/scripts
node validate_wallet_consistency.js --verbose

# Review inconsistencies
cat validation_reports/wallet_consistency_*.json
```

**Resolution:**

```bash
# Option 1: Auto-fix (SQL is source of truth)
node validate_wallet_consistency.js --fix --verbose

# Option 2: Manual review
# Review each inconsistency individually
# Determine correct balance (check ledger history)
# Apply correction manually
```

**Root Cause Analysis:**
- Was feature flag toggled mid-transaction?
- Did migration script fail partway?
- Was there a concurrent write to both Firestore and SQL?

---

### 4. Rollback Procedures

#### Rollback #1: Disable SQL Gateway (Immediate)

**Firebase Remote Config:**

```json
{
  "use_sql_escrow_gateway": {
    "defaultValue": {
      "value": "false" // ← Change to false
    }
  }
}
```

**Publish config:**
1. Firebase Console → Remote Config
2. Edit `use_sql_escrow_gateway`
3. Set defaultValue to `false`
4. Click **Publish Changes**
5. Users will revert to Firestore on next app launch (within 12 hours)

**Immediate Rollback (Emergency):**

```bash
# Force app update with hardcoded flag
# lib/utils/store_feature_flags.dart
# Change: defaultValue: false

# Build emergency release
flutter build apk --dart-define=USE_SQL_ESCROW_GATEWAY=false

# Deploy to app stores with expedited review
```

---

#### Rollback #2: Database Rollback (Extreme - Data Loss Risk)

**⚠️ WARNING: Only use if SQL data is corrupted beyond repair**

```bash
cd functions/scripts

# Backup SQL before rollback
# (Manual backup via Azure Portal)

# Run rollback
node migrate_firestore_to_sql.js --rollback
# Confirm within 10 seconds

# Verify Firestore data intact
firebase firestore:get wallets --limit 10
firebase firestore:get store_orders --limit 10
```

**Post-Rollback:**
- Re-enable Firestore-only mode (disable feature flag)
- Communicate downtime to users
- Root cause analysis before re-attempting migration

---

### 5. Communication Plan

#### Stakeholder Notification

**Before Deployment:**
```
Subject: CringeBank Store SQL Migration - Canary Deployment Starting

Team,

We are beginning the canary rollout of SQL-backed store operations:
- Week 1: 5% of users
- Week 2-4: Gradual increase to 100%

Monitoring:
- Real-time dashboard: [Grafana URL]
- Alert channel: #cringebank-alerts

Rollback plan in place. No user-facing changes expected.

Contact: [Your Name] for questions
```

**During Incident:**
```
Subject: [INCIDENT] CringeStore Issue - [SEVERITY]

Status: [INVESTIGATING | MITIGATED | RESOLVED]

Impact:
- Affected users: X%
- Feature: Store orders/wallets
- Duration: Started at [TIME]

Actions:
- [Current mitigation steps]
- ETA for resolution: [TIME]

Updates will be posted to #cringebank-alerts every 30 minutes.
```

**Post-Deployment:**
```
Subject: SQL Migration Rollout Complete - Week [X]

Update:
- Current rollout: X% of users
- Success rate: 99.X%
- No critical incidents
- Next phase: [DATE] - increase to Y%

Metrics:
- Orders processed: X,XXX
- Avg latency: XXms
- Error rate: 0.X%
```

---

### 6. On-Call Rotation

**On-Call Schedule:**

| Week | Primary | Secondary | Backup |
|------|---------|-----------|--------|
| Week 1 (5% rollout) | [Name 1] | [Name 2] | [Name 3] |
| Week 2 (25% rollout) | [Name 2] | [Name 3] | [Name 1] |
| Week 3 (50% rollout) | [Name 3] | [Name 1] | [Name 2] |
| Week 4 (100% rollout) | [Name 1] | [Name 2] | [Name 3] |

**On-Call Responsibilities:**
- Monitor #cringebank-alerts Slack channel
- Respond to critical alerts within 15 minutes
- Execute runbook procedures
- Escalate if needed
- Document incidents in runbook

**Escalation Path:**
1. **L1 (On-Call Engineer):** Triage, execute runbook
2. **L2 (Team Lead):** Complex incidents, rollback decisions
3. **L3 (CTO):** Business impact decisions, external communication

---

### 7. Monitoring Dashboard (Grafana)

**Dashboard Panels:**

1. **SQL Gateway Health:**
   - Error rate (last 1h, 24h)
   - Request rate (requests/min)
   - P50/P95/P99 latency

2. **Wallet Metrics:**
   - Total gold in system (should be stable)
   - Negative balance count (should be 0)
   - Pending gold (track escrows)

3. **Order Metrics:**
   - Orders created (per hour)
   - Order success rate (%)
   - Average order completion time

4. **SQL Database:**
   - CPU utilization
   - DTU usage
   - Active connections
   - Query wait time

**Dashboard URL:** `https://grafana.cringebank.com/d/sql-gateway`

---

## ✅ Production Readiness Sign-off

### Pre-Deployment Checklist

- [ ] Remote Config feature flag configured
- [ ] SLA targets defined and documented
- [ ] Incident response runbook reviewed
- [ ] Rollback procedures tested in staging
- [ ] On-call rotation assigned
- [ ] Monitoring dashboard created
- [ ] Stakeholder communication drafted
- [ ] Emergency contact list updated
- [ ] Database backups automated
- [ ] All staging tests passed

### Approval

**Technical Lead:** _________________  
**Date:** _________________

**Product Manager:** _________________  
**Date:** _________________

**CTO (if required):** _________________  
**Date:** _________________

---

**Sonraki Adım:** Execute canary deployment (Week 1 - 5%)
