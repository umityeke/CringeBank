# Monitoring & Alerting Setup Guide

**Tarih:** 9 Ekim 2025  
**Amaç:** Production-ready monitoring ve alerting altyapısı kurulumu

---

## 📊 1. Azure SQL Database Monitoring

### 1.1 Query Performance Insight Aktivasyonu

**Azure Portal üzerinden:**

1. Azure SQL Database → `your-database` seç
2. **Intelligent Performance** → **Query Performance Insight** tıkla
3. **Enable** butonuna tıkla
4. Şu metrikleri etkinleştir:
   - Top resource consuming queries
   - Long running queries (>1 saniye)
   - Failed queries

**Sorgu performansı izleme:**

```sql
-- En yavaş stored procedure'leri bul
SELECT TOP 10
    OBJECT_NAME(object_id) AS ProcedureName,
    execution_count AS ExecutionCount,
    total_elapsed_time / 1000000.0 AS TotalElapsedTimeSec,
    (total_elapsed_time / execution_count) / 1000.0 AS AvgElapsedTimeMs,
    last_execution_time AS LastExecuted
FROM sys.dm_exec_procedure_stats
WHERE OBJECT_NAME(object_id) LIKE 'sp_Store_%'
ORDER BY total_elapsed_time DESC;

-- Aktif bekleyen query'ler
SELECT 
    session_id,
    start_time,
    status,
    command,
    wait_type,
    wait_time,
    blocking_session_id,
    SUBSTRING(text, 1, 200) AS query_text
FROM sys.dm_exec_requests
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
WHERE database_id = DB_ID()
  AND session_id != @@SPID;
```

### 1.2 Metrik Alert Kuralları

**Azure Portal → Alerts → Create Alert Rule:**

#### Alert #1: High Query Latency

```yaml
Resource: your-sql-database
Metric: Average query duration
Condition: Greater than 500ms
Aggregation: Average
Period: 5 minutes
Action Group: sql-alerts (email/Slack)
Severity: Warning
```

#### Alert #2: Failed Connections

```yaml
Metric: Failed connections
Condition: Greater than 10
Period: 5 minutes
Severity: Critical
```

#### Alert #3: DTU/CPU Usage

```yaml
Metric: CPU percentage
Condition: Greater than 80%
Period: 10 minutes
Severity: Warning
```

#### Alert #4: Storage Full

```yaml
Metric: Storage percentage
Condition: Greater than 85%
Severity: Critical
```

### 1.3 Custom Monitoring Query (Daily Cron)

```sql
-- validation_metrics.sql
-- Günlük çalıştırılacak metrik toplama sorgusu

DECLARE @ReportDate DATETIME = GETUTCDATE();

SELECT 
    @ReportDate AS ReportDate,
    
    -- Wallet metrikleri
    (SELECT COUNT(*) FROM StoreWallets) AS TotalWallets,
    (SELECT SUM(GoldBalance) FROM StoreWallets) AS TotalGoldBalance,
    (SELECT SUM(PendingGold) FROM StoreWallets) AS TotalPendingGold,
    (SELECT COUNT(*) FROM StoreWallets WHERE GoldBalance < 0) AS NegativeBalanceCount,
    
    -- Order metrikleri
    (SELECT COUNT(*) FROM StoreOrders WHERE CAST(CreatedAt AS DATE) = CAST(@ReportDate AS DATE)) AS OrdersToday,
    (SELECT COUNT(*) FROM StoreOrders WHERE OrderStatus = 'COMPLETED') AS CompletedOrders,
    (SELECT COUNT(*) FROM StoreOrders WHERE OrderStatus = 'CANCELLED') AS CancelledOrders,
    
    -- Escrow metrikleri
    (SELECT COUNT(*) FROM StoreEscrows WHERE EscrowState = 'LOCKED') AS LockedEscrows,
    (SELECT COUNT(*) FROM StoreEscrows WHERE EscrowState = 'RELEASED') AS ReleasedEscrows,
    (SELECT COUNT(*) FROM StoreEscrows WHERE EscrowState = 'REFUNDED') AS RefundedEscrows,
    
    -- Product metrikleri
    (SELECT COUNT(*) FROM StoreProducts WHERE IsActive = 1) AS ActiveProducts,
    (SELECT COUNT(*) FROM StoreProducts WHERE ReservedBy IS NOT NULL) AS ReservedProducts;

-- Günlük metrikleri log tablosuna kaydet
INSERT INTO MetricsLog (
    CollectedAt,
    TotalWallets,
    TotalGoldBalance,
    NegativeBalances,
    OrdersToday,
    LockedEscrows
)
SELECT 
    @ReportDate,
    (SELECT COUNT(*) FROM StoreWallets),
    (SELECT SUM(GoldBalance) FROM StoreWallets),
    (SELECT COUNT(*) FROM StoreWallets WHERE GoldBalance < 0),
    (SELECT COUNT(*) FROM StoreOrders WHERE CAST(CreatedAt AS DATE) = CAST(@ReportDate AS DATE)),
    (SELECT COUNT(*) FROM StoreEscrows WHERE EscrowState = 'LOCKED');
```

**MetricsLog tablosu oluştur:**

```sql
CREATE TABLE MetricsLog (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    CollectedAt DATETIME NOT NULL,
    TotalWallets INT NOT NULL,
    TotalGoldBalance BIGINT NOT NULL,
    NegativeBalances INT NOT NULL,
    OrdersToday INT NOT NULL,
    LockedEscrows INT NOT NULL,
    CONSTRAINT UQ_MetricsLog_CollectedAt UNIQUE (CollectedAt)
);

CREATE INDEX IX_MetricsLog_CollectedAt ON MetricsLog(CollectedAt DESC);
```

---

## ☁️ 2. Cloud Functions Monitoring

### 2.1 Firebase Console Logging

**functions/index.js'ye logging wrapper ekle:**

```javascript
const functions = require('firebase-functions');

// Structured logging helper
function logStructured(severity, message, metadata = {}) {
  const entry = {
    severity,
    message,
    timestamp: new Date().toISOString(),
    ...metadata,
  };
  
  console.log(JSON.stringify(entry));
}

// Performance tracking wrapper
function trackPerformance(functionName, callable) {
  return async (data, context) => {
    const startTime = Date.now();
    
    try {
      logStructured('INFO', `${functionName} started`, {
        functionName,
        userId: context.auth?.uid,
        data: JSON.stringify(data),
      });
      
      const result = await callable(data, context);
      
      const duration = Date.now() - startTime;
      logStructured('INFO', `${functionName} completed`, {
        functionName,
        duration,
        success: true,
      });
      
      return result;
      
    } catch (error) {
      const duration = Date.now() - startTime;
      logStructured('ERROR', `${functionName} failed`, {
        functionName,
        duration,
        error: error.message,
        stack: error.stack,
      });
      
      throw error;
    }
  };
}

// Kullanım örneği
exports.sqlGatewayStoreCreateOrder = functions
  .region('europe-west1')
  .https.onCall(
    trackPerformance('sqlGatewayStoreCreateOrder', async (data, context) => {
      // Mevcut callable logic
    })
  );
```

### 2.2 Google Cloud Logging Filters

**Firebase Console → Functions → Logs → Add Filter:**

#### Filter #1: SQL Gateway Errors

```
severity >= ERROR
resource.labels.function_name =~ "sqlGateway.*"
```

#### Filter #2: Slow Queries (>1 saniye)

```
jsonPayload.duration > 1000
resource.labels.function_name =~ "sqlGateway.*"
```

#### Filter #3: Wallet Operations

```
jsonPayload.functionName =~ ".*Wallet.*"
severity >= WARNING
```

### 2.3 Cloud Monitoring Alert Policies

**Google Cloud Console → Monitoring → Alerting:**

#### Alert #1: High Error Rate

```yaml
Metric: cloud.googleapis.com/functions/execution_count
Filter: status != "ok"
Condition: Rate > 5 errors/minute
Duration: 5 minutes
Notification: Email + Slack
```

#### Alert #2: Function Timeout

```yaml
Metric: cloud.googleapis.com/functions/execution_times
Condition: 95th percentile > 50 seconds
Duration: 10 minutes
Severity: Warning
```

#### Alert #3: Cold Start Frequency

```yaml
Metric: cloud.googleapis.com/functions/user_memory_bytes
Condition: Spikes indicating cold starts
Threshold: > 10 cold starts/hour
```

---

## 📧 3. Notification Channels

### 3.1 Slack Webhook Setup

**Slack Workspace → Apps → Incoming Webhooks:**

1. Create new webhook: `#cringebank-alerts`
2. Copy webhook URL
3. Test:

```bash
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "🚨 Test Alert",
    "attachments": [{
      "color": "danger",
      "text": "This is a test alert from monitoring system"
    }]
  }'
```

**Firebase Functions'a entegre et:**

```javascript
// functions/utils/alerts.js
const fetch = require('node-fetch');

const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL;

async function sendSlackAlert(severity, title, message, metadata = {}) {
  if (!SLACK_WEBHOOK_URL) {
    console.warn('Slack webhook not configured');
    return;
  }

  const color = severity === 'CRITICAL' ? 'danger' : 'warning';
  
  await fetch(SLACK_WEBHOOK_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text: `${severity === 'CRITICAL' ? '🚨' : '⚠️'} ${title}`,
      attachments: [{
        color,
        text: message,
        fields: Object.entries(metadata).map(([key, value]) => ({
          title: key,
          value: String(value),
          short: true,
        })),
        footer: 'CringeBank Monitoring',
        ts: Math.floor(Date.now() / 1000),
      }],
    }),
  });
}

module.exports = { sendSlackAlert };
```

### 3.2 Email Alerts (SendGrid)

```javascript
// functions/utils/email_alerts.js
const sgMail = require('@sendgrid/mail');

sgMail.setApiKey(process.env.SENDGRID_API_KEY);

async function sendEmailAlert(severity, title, message, details) {
  const msg = {
    to: 'alerts@cringebank.com',
    from: 'monitoring@cringebank.com',
    subject: `[${severity}] ${title}`,
    text: message,
    html: `
      <h2>${title}</h2>
      <p>${message}</p>
      <pre>${JSON.stringify(details, null, 2)}</pre>
    `,
  };

  await sgMail.send(msg);
}

module.exports = { sendEmailAlert };
```

---

## 🔄 4. Cron Jobs (Scheduled Functions)

### 4.1 Wallet Consistency Checker (Günlük)

```javascript
// functions/scheduled/wallet_consistency_check.js
const functions = require('firebase-functions');
const { main: validateWallets } = require('../scripts/validate_wallet_consistency');
const { sendSlackAlert } = require('../utils/alerts');

exports.dailyWalletConsistencyCheck = functions
  .region('europe-west1')
  .pubsub.schedule('0 2 * * *') // Her gün saat 02:00 UTC
  .timeZone('Europe/Istanbul')
  .onRun(async (context) => {
    console.log('Starting daily wallet consistency check...');

    try {
      await validateWallets();
      console.log('✅ Wallet consistency check completed');
    } catch (error) {
      console.error('❌ Wallet consistency check failed:', error);
      
      await sendSlackAlert(
        'CRITICAL',
        'Wallet Consistency Check Failed',
        error.message,
        { timestamp: new Date().toISOString() }
      );
      
      throw error;
    }
  });
```

### 4.2 SQL Metrics Collection (Saatlik)

```javascript
// functions/scheduled/collect_sql_metrics.js
const functions = require('firebase-functions');
const sql = require('mssql');

exports.hourlyMetricsCollection = functions
  .region('europe-west1')
  .pubsub.schedule('0 * * * *') // Her saat başı
  .onRun(async (context) => {
    const pool = await sql.connect({
      server: process.env.SQL_SERVER,
      database: process.env.SQL_DATABASE,
      user: process.env.SQL_USER,
      password: process.env.SQL_PASSWORD,
      options: { encrypt: true },
    });

    const result = await pool.request().query(`
      SELECT 
        (SELECT COUNT(*) FROM StoreWallets WHERE GoldBalance < 0) AS NegativeBalances,
        (SELECT COUNT(*) FROM StoreOrders WHERE OrderStatus = 'PENDING') AS PendingOrders,
        (SELECT COUNT(*) FROM StoreEscrows WHERE EscrowState = 'LOCKED') AS LockedEscrows
    `);

    const metrics = result.recordset[0];

    // Alert on negative balances
    if (metrics.NegativeBalances > 0) {
      await sendSlackAlert(
        'CRITICAL',
        'Negative Wallet Balances Detected',
        `Found ${metrics.NegativeBalances} wallet(s) with negative balance!`,
        metrics
      );
    }

    console.log('Metrics collected:', metrics);
    await pool.close();
  });
```

### 4.3 Deploy Scheduled Functions

```bash
# Deploy cron jobs
firebase deploy --only functions:dailyWalletConsistencyCheck,functions:hourlyMetricsCollection

# Verify scheduled functions
firebase functions:log --only dailyWalletConsistencyCheck
```

---

## 📊 5. Dashboard Setup (Optional - Grafana)

### 5.1 Grafana Cloud Setup

**Veri kaynakları:**

1. **Azure SQL Database:**
   - Plugin: Microsoft SQL Server
   - Connection string: SQL_SERVER credentials

2. **Google Cloud Logging:**
   - Plugin: Google Cloud Monitoring
   - Service account ile authentication

### 5.2 Dashboard Panels

**Panel 1: Wallet Balance Trend**

```sql
SELECT 
    CollectedAt AS time,
    TotalGoldBalance AS value
FROM MetricsLog
WHERE CollectedAt >= DATEADD(day, -7, GETUTCDATE())
ORDER BY CollectedAt;
```

**Panel 2: Order Success Rate**

```sql
SELECT 
    CAST(CreatedAt AS DATE) AS time,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN OrderStatus = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders,
    (CAST(SUM(CASE WHEN OrderStatus = 'COMPLETED' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100 AS success_rate
FROM StoreOrders
WHERE CreatedAt >= DATEADD(day, -30, GETUTCDATE())
GROUP BY CAST(CreatedAt AS DATE)
ORDER BY time;
```

**Panel 3: Function Latency (Cloud Logging)**

```
Query: jsonPayload.duration
Filter: resource.labels.function_name =~ "sqlGateway.*"
Aggregation: 95th percentile
Time range: Last 24 hours
```

---

## ✅ Verification Checklist

- [ ] Azure SQL Query Performance Insight aktif
- [ ] 4 SQL alert rule oluşturuldu (latency, connections, CPU, storage)
- [ ] MetricsLog tablosu oluşturuldu
- [ ] Cloud Functions logging wrapper eklendi
- [ ] 3 Cloud Logging filter oluşturuldu
- [ ] 3 Cloud Monitoring alert policy oluşturuldu
- [ ] Slack webhook configured ve test edildi
- [ ] Email alert sistemi kuruldu (optional)
- [ ] `dailyWalletConsistencyCheck` cron deployed
- [ ] `hourlyMetricsCollection` cron deployed
- [ ] Wallet consistency validator script test edildi
- [ ] Grafana dashboard oluşturuldu (optional)

---

## 🧪 Test Commands

```bash
# Test wallet consistency validator
cd functions/scripts
node validate_wallet_consistency.js --verbose

# Test with fix mode (DRY RUN first!)
node validate_wallet_consistency.js --fix --verbose

# Test Slack alert
node -e "require('./utils/alerts').sendSlackAlert('WARNING', 'Test Alert', 'This is a test', {})"

# Trigger scheduled function manually
gcloud functions call dailyWalletConsistencyCheck --region=europe-west1
```

---

**Sonraki Adım:** Staging Environment Testing (Item #2)
