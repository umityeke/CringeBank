# CI/CD Hardening Plan

**Tarih:** 9 Ekim 2025  
**Amaç:** Kod kalitesini zorlamak, production'a hatalı kod çıkmasını engellemek  
**Strateji:** Otomatik testler, lint rules, pre-deploy validations

---

## 🎯 Overview

**Problem:**  
- Stored procedure'lar test edilmeden deploy ediliyor
- Firestore'a direkt erişim engellenmiyor (SQL Gateway bypass)
- Integration testler opsiyonel (CI'da zorunlu değil)
- SQL schema değişiklikleri manuel kontrol ediliyor

**Çözüm:**
1. **SQL Unit Test Framework** (tSQLt)
2. **GitHub Actions CI Pipeline** (test + lint gates)
3. **Custom ESLint Rule** (Firestore direkt erişimi yasakla)
4. **Pre-deploy Validation** (SQL connection, SP existence checks)
5. **Database Migration CI** (Flyway/Liquibase benzeri)

---

## 📋 1. SQL Stored Procedure Unit Testing (tSQLt Framework)

### 1.1 tSQLt Kurulumu

**Azure SQL Database Setup:**

```sql
-- tSQLt framework'ü Azure SQL'de enable et
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
GO

-- tSQLt assembly'yi yükle (Azure SQL için pre-built)
-- Download from: https://tsqlt.org/downloads/
-- Upload to Azure Blob Storage, sonra SQLCMD ile yükle
```

**Alternative: Azure DevOps SQL Test Task** (Daha kolay)

---

### 1.2 Test Template (tSQLt Example)

**Test File: `backend/tests/test_sp_Store_CreateOrder.sql`**

```sql
-- Test class oluştur
EXEC tSQLt.NewTestClass 'StoreOrderTests';
GO

-- Test: CreateOrder başarılı sipariş oluşturur
CREATE OR ALTER PROCEDURE StoreOrderTests.[test CreateOrder inserts order correctly]
AS
BEGIN
    -- Arrange: Test verileri hazırla
    DECLARE @BuyerAuthUid NVARCHAR(128) = 'test_buyer_123';
    DECLARE @ProductId INT = 1;
    DECLARE @OrderPublicId NVARCHAR(50) = 'ORD_TEST_001';
    DECLARE @Quantity DECIMAL(18,8) = 10.5;
    DECLARE @PricePerGram DECIMAL(18,2) = 1000.0;
    
    -- Test user ve product'ı oluştur
    INSERT INTO Users (AuthUid, DisplayName) VALUES (@BuyerAuthUid, 'Test Buyer');
    INSERT INTO StoreProducts (ProductId, ProductName, PricePerGram) VALUES (@ProductId, 'Gold Bar', @PricePerGram);
    INSERT INTO StoreWallets (AuthUid, TotalGoldBalance) VALUES (@BuyerAuthUid, 1000.0); -- Yeterli bakiye
    
    -- Act: Stored procedure'ı çağır
    EXEC sp_Store_CreateOrder 
        @OrderPublicId = @OrderPublicId,
        @BuyerAuthUid = @BuyerAuthUid,
        @ProductId = @ProductId,
        @QuantityGrams = @Quantity,
        @PricePerGram = @PricePerGram;
    
    -- Assert: Sipariş oluştu mu?
    DECLARE @OrderExists BIT;
    SELECT @OrderExists = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM StoreOrders
    WHERE OrderPublicId = @OrderPublicId
      AND BuyerAuthUid = @BuyerAuthUid
      AND Status = 'PENDING';
    
    EXEC tSQLt.AssertEquals 1, @OrderExists, 'Order was not created';
    
    -- Assert: Escrow oluştu mu?
    DECLARE @EscrowExists BIT;
    SELECT @EscrowExists = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM StoreEscrows
    WHERE OrderPublicId = @OrderPublicId
      AND Status = 'LOCKED';
    
    EXEC tSQLt.AssertEquals 1, @EscrowExists, 'Escrow was not created';
END
GO

-- Test: CreateOrder yetersiz bakiyede fail eder
CREATE OR ALTER PROCEDURE StoreOrderTests.[test CreateOrder fails with insufficient balance]
AS
BEGIN
    -- Arrange
    DECLARE @BuyerAuthUid NVARCHAR(128) = 'test_buyer_poor';
    DECLARE @ProductId INT = 1;
    DECLARE @OrderPublicId NVARCHAR(50) = 'ORD_TEST_002';
    DECLARE @Quantity DECIMAL(18,8) = 1000.0; -- Çok fazla
    DECLARE @PricePerGram DECIMAL(18,2) = 1000.0;
    
    INSERT INTO Users (AuthUid, DisplayName) VALUES (@BuyerAuthUid, 'Poor Buyer');
    INSERT INTO StoreProducts (ProductId, ProductName, PricePerGram) VALUES (@ProductId, 'Gold Bar', @PricePerGram);
    INSERT INTO StoreWallets (AuthUid, TotalGoldBalance) VALUES (@BuyerAuthUid, 10.0); -- Yetersiz bakiye
    
    -- Act & Assert: Error bekle
    EXEC tSQLt.ExpectException @ExpectedMessage = 'Insufficient balance';
    
    EXEC sp_Store_CreateOrder 
        @OrderPublicId = @OrderPublicId,
        @BuyerAuthUid = @BuyerAuthUid,
        @ProductId = @ProductId,
        @QuantityGrams = @Quantity,
        @PricePerGram = @PricePerGram;
END
GO

-- Tüm testleri çalıştır
EXEC tSQLt.RunAll;
GO
```

**Expected Output:**

```
Test Case Summary: 2 test(s) executed, 2 succeeded, 0 failed, 0 errored.
```

---

### 1.3 Test Automation Script

**File: `backend/scripts/run_sql_tests.ps1`**

```powershell
# Azure SQL bağlantı bilgileri
$Server = $env:SQL_SERVER
$Database = $env:SQL_DATABASE
$Username = $env:SQL_USER
$Password = $env:SQL_PASSWORD

# tSQLt testlerini çalıştır
$TestCommand = "EXEC tSQLt.RunAll;"

# sqlcmd ile test çalıştır
sqlcmd -S $Server -d $Database -U $Username -P $Password -Q $TestCommand -o test_results.txt

# Test sonuçlarını parse et
$Results = Get-Content test_results.txt
if ($Results -match "(\d+) failed") {
    $FailedCount = $Matches[1]
    if ($FailedCount -gt 0) {
        Write-Error "$FailedCount test(s) failed!"
        exit 1
    }
}

Write-Host "All SQL tests passed!" -ForegroundColor Green
exit 0
```

**Usage in CI:**

```yaml
# .github/workflows/ci.yml
- name: Run SQL Unit Tests
  run: pwsh backend/scripts/run_sql_tests.ps1
  env:
    SQL_SERVER: ${{ secrets.SQL_SERVER }}
    SQL_DATABASE: ${{ secrets.SQL_DATABASE }}
    SQL_USER: ${{ secrets.SQL_USER }}
    SQL_PASSWORD: ${{ secrets.SQL_PASSWORD }}
```

---

## 📋 2. GitHub Actions CI Pipeline

### 2.1 Full CI Workflow

**File: `.github/workflows/ci.yml`**

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # Job 1: Lint & Format Check
  lint:
    name: Lint & Format Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        working-directory: ./functions
        run: npm ci
      
      - name: Run ESLint
        working-directory: ./functions
        run: npm run lint
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      
      - name: Flutter analyze
        run: flutter analyze --fatal-infos

  # Job 2: SQL Unit Tests
  sql-tests:
    name: SQL Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run SQL Tests
        run: pwsh backend/scripts/run_sql_tests.ps1
        env:
          SQL_SERVER: ${{ secrets.SQL_SERVER_TEST }}
          SQL_DATABASE: ${{ secrets.SQL_DATABASE_TEST }}
          SQL_USER: ${{ secrets.SQL_USER_TEST }}
          SQL_PASSWORD: ${{ secrets.SQL_PASSWORD_TEST }}

  # Job 3: Cloud Functions Unit Tests
  functions-tests:
    name: Cloud Functions Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        working-directory: ./functions
        run: npm ci
      
      - name: Run Jest tests
        working-directory: ./functions
        run: npm test
        env:
          SQL_SERVER: ${{ secrets.SQL_SERVER_TEST }}
          SQL_DATABASE: ${{ secrets.SQL_DATABASE_TEST }}
          SQL_USER: ${{ secrets.SQL_USER_TEST }}
          SQL_PASSWORD: ${{ secrets.SQL_PASSWORD_TEST }}

  # Job 4: Flutter Unit Tests
  flutter-tests:
    name: Flutter Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test

  # Job 5: Integration Tests (Optional - manual trigger)
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: [lint, sql-tests, functions-tests, flutter-tests]
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Run integration tests
        working-directory: ./functions
        run: npm run test:integration
        env:
          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID_TEST }}
          SQL_SERVER: ${{ secrets.SQL_SERVER_TEST }}
          SQL_DATABASE: ${{ secrets.SQL_DATABASE_TEST }}
          SQL_USER: ${{ secrets.SQL_USER_TEST }}
          SQL_PASSWORD: ${{ secrets.SQL_PASSWORD_TEST }}
```

**Status Badge (README.md):**

```markdown
[![CI Pipeline](https://github.com/yourusername/cringebank/workflows/CI%20Pipeline/badge.svg)](https://github.com/yourusername/cringebank/actions)
```

---

### 2.2 Pre-Deploy Validation Workflow

**File: `.github/workflows/pre-deploy-validation.yml`**

```yaml
name: Pre-Deploy Validation

on:
  workflow_dispatch: # Manual trigger
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        type: choice
        options:
          - staging
          - production

jobs:
  validate:
    name: Pre-Deploy Checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        working-directory: ./functions
        run: npm ci
      
      # Validation 1: SQL Connection Test
      - name: Test SQL Connection
        run: node functions/scripts/test_sql_connection.js
        env:
          SQL_SERVER: ${{ secrets.SQL_SERVER }}
          SQL_DATABASE: ${{ secrets.SQL_DATABASE }}
          SQL_USER: ${{ secrets.SQL_USER }}
          SQL_PASSWORD: ${{ secrets.SQL_PASSWORD }}
      
      # Validation 2: Stored Procedures Existence Check
      - name: Verify Stored Procedures Exist
        run: node functions/scripts/verify_stored_procedures.js
        env:
          SQL_SERVER: ${{ secrets.SQL_SERVER }}
          SQL_DATABASE: ${{ secrets.SQL_DATABASE }}
          SQL_USER: ${{ secrets.SQL_USER }}
          SQL_PASSWORD: ${{ secrets.SQL_PASSWORD }}
      
      # Validation 3: Wallet Consistency Check
      - name: Run Wallet Consistency Validator
        run: node functions/scripts/validate_wallet_consistency.js
        env:
          SQL_SERVER: ${{ secrets.SQL_SERVER }}
          SQL_DATABASE: ${{ secrets.SQL_DATABASE }}
          SQL_USER: ${{ secrets.SQL_USER }}
          SQL_PASSWORD: ${{ secrets.SQL_PASSWORD }}
      
      # Validation 4: Remote Config Feature Flag Check
      - name: Verify Feature Flags Exist
        run: |
          firebase use ${{ inputs.environment }}
          firebase functions:config:get > config.json
          node -e "const cfg = require('./config.json'); if (!cfg.feature_flags) throw new Error('Feature flags not configured');"
      
      - name: Deployment Ready
        run: echo "✅ All pre-deploy validations passed. Ready to deploy to ${{ inputs.environment }}."
```

---

## 📋 3. Custom ESLint Rule: No Direct Firestore Access

### 3.1 Custom Rule Implementation

**File: `functions/eslint-rules/no-direct-firestore.js`**

```javascript
/**
 * ESLint rule: no-direct-firestore
 * 
 * Disallows direct Firestore access outside of SQL Gateway.
 * Forces developers to use SQL stored procedures.
 * 
 * BAD:  await admin.firestore().collection('store_orders').doc(orderId).get();
 * GOOD: await pool.request().execute('sp_Store_GetOrder');
 */

module.exports = {
  meta: {
    type: 'problem',
    docs: {
      description: 'Disallow direct Firestore access (use SQL Gateway instead)',
      category: 'Best Practices',
      recommended: true,
    },
    messages: {
      noDirectFirestore: 'Direct Firestore access is forbidden. Use SQL Gateway stored procedures instead.',
    },
    schema: [{
      type: 'object',
      properties: {
        allowedCollections: {
          type: 'array',
          items: { type: 'string' },
          default: ['users', 'user_profiles'], // Exempt collections
        },
      },
      additionalProperties: false,
    }],
  },

  create(context) {
    const options = context.options[0] || {};
    const allowedCollections = options.allowedCollections || ['users', 'user_profiles'];

    return {
      // Detect: admin.firestore().collection(...)
      CallExpression(node) {
        if (
          node.callee.type === 'MemberExpression' &&
          node.callee.property.name === 'collection' &&
          node.callee.object.type === 'CallExpression' &&
          node.callee.object.callee.type === 'MemberExpression' &&
          node.callee.object.callee.property.name === 'firestore'
        ) {
          // Get collection name
          const collectionArg = node.arguments[0];
          if (collectionArg && collectionArg.type === 'Literal') {
            const collectionName = collectionArg.value;

            // Check if collection is allowed
            if (!allowedCollections.includes(collectionName)) {
              context.report({
                node,
                messageId: 'noDirectFirestore',
              });
            }
          } else {
            // Dynamic collection name (can't verify) - flag it
            context.report({
              node,
              messageId: 'noDirectFirestore',
            });
          }
        }
      },
    };
  },
};
```

---

### 3.2 ESLint Configuration

**File: `functions/.eslintrc.js`**

```javascript
module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    'eslint:recommended',
    'google',
  ],
  rules: {
    'quotes': ['error', 'single'],
    'indent': ['error', 2],
    'max-len': ['error', { code: 120 }],
  },
  
  // Load custom rule
  plugins: ['local-rules'],
  rules: {
    'local-rules/no-direct-firestore': ['error', {
      allowedCollections: ['users', 'user_profiles', 'conversations'], // Firestore-only collections
    }],
  },
};
```

**File: `functions/eslint-rules/index.js`** (Plugin Loader)

```javascript
module.exports = {
  rules: {
    'no-direct-firestore': require('./no-direct-firestore'),
  },
};
```

**File: `functions/.eslintplugin.js`** (Register plugin)

```javascript
const localRules = require('./eslint-rules');

module.exports = {
  rules: localRules.rules,
};
```

**Update `package.json`:**

```json
{
  "eslintConfig": {
    "plugins": ["local-rules"]
  },
  "devDependencies": {
    "eslint-plugin-local-rules": "file:./eslint-rules"
  }
}
```

---

### 3.3 Example Violations

**❌ FAIL:**

```javascript
// This will trigger ESLint error
const orderDoc = await admin.firestore()
  .collection('store_orders')  // ❌ Forbidden!
  .doc(orderId)
  .get();
```

**✅ PASS:**

```javascript
// Use SQL Gateway instead
const pool = await getSqlPool();
const result = await pool.request()
  .input('OrderPublicId', sql.NVarChar, orderId)
  .execute('sp_Store_GetOrder');
```

---

## 📋 4. Pre-Deploy Validation Scripts

### 4.1 SQL Connection Test

**File: `functions/scripts/test_sql_connection.js`**

```javascript
const sql = require('mssql');

async function testSqlConnection() {
  const config = {
    server: process.env.SQL_SERVER,
    database: process.env.SQL_DATABASE,
    user: process.env.SQL_USER,
    password: process.env.SQL_PASSWORD,
    options: {
      encrypt: true,
      trustServerCertificate: false,
    },
  };

  try {
    console.log('Testing SQL connection...');
    const pool = await sql.connect(config);
    const result = await pool.request().query('SELECT 1 AS TestValue');
    
    if (result.recordset[0].TestValue === 1) {
      console.log('✅ SQL connection successful');
      process.exit(0);
    } else {
      throw new Error('Unexpected query result');
    }
  } catch (error) {
    console.error('❌ SQL connection failed:', error.message);
    process.exit(1);
  }
}

testSqlConnection();
```

---

### 4.2 Stored Procedures Verification

**File: `functions/scripts/verify_stored_procedures.js`**

```javascript
const sql = require('mssql');

// Required stored procedures (kritik olanlar)
const REQUIRED_SPS = [
  'sp_Store_CreateOrder',
  'sp_Store_CompleteOrder',
  'sp_Store_RefundOrder',
  'sp_Store_GetUserOrders',
  'sp_Wallet_GetBalance',
  'sp_Wallet_AddGold',
  'sp_Wallet_DeductGold',
];

async function verifyStoredProcedures() {
  const config = {
    server: process.env.SQL_SERVER,
    database: process.env.SQL_DATABASE,
    user: process.env.SQL_USER,
    password: process.env.SQL_PASSWORD,
    options: { encrypt: true, trustServerCertificate: false },
  };

  try {
    const pool = await sql.connect(config);
    const result = await pool.request().query(`
      SELECT ROUTINE_NAME
      FROM INFORMATION_SCHEMA.ROUTINES
      WHERE ROUTINE_TYPE = 'PROCEDURE'
    `);

    const existingSPs = result.recordset.map(row => row.ROUTINE_NAME);
    const missingSPs = REQUIRED_SPS.filter(sp => !existingSPs.includes(sp));

    if (missingSPs.length > 0) {
      console.error('❌ Missing stored procedures:', missingSPs.join(', '));
      process.exit(1);
    }

    console.log(`✅ All ${REQUIRED_SPS.length} required stored procedures exist`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Verification failed:', error.message);
    process.exit(1);
  }
}

verifyStoredProcedures();
```

---

## 📋 5. Database Migration CI (Flyway-like)

### 5.1 Migration Script Naming Convention

```
backend/migrations/
├── V001__create_users_table.sql
├── V002__create_store_wallets_table.sql
├── V003__create_store_orders_table.sql
├── V004__create_sp_store_create_order.sql
├── V005__add_metrics_log_table.sql
└── ...
```

**Naming:** `V{version}__{description}.sql`

---

### 5.2 Migration Runner Script

**File: `backend/scripts/run_migrations.ps1`**

```powershell
param(
    [string]$TargetVersion = "latest"
)

$MigrationsDir = "backend/migrations"
$Server = $env:SQL_SERVER
$Database = $env:SQL_DATABASE
$Username = $env:SQL_USER
$Password = $env:SQL_PASSWORD

# Migration tracking table oluştur
$CreateTrackingTable = @"
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SchemaMigrations')
BEGIN
    CREATE TABLE SchemaMigrations (
        Version INT PRIMARY KEY,
        Description NVARCHAR(200) NOT NULL,
        AppliedAt DATETIME NOT NULL DEFAULT GETUTCDATE()
    );
END
"@

sqlcmd -S $Server -d $Database -U $Username -P $Password -Q $CreateTrackingTable

# Migration dosyalarını oku
$MigrationFiles = Get-ChildItem -Path $MigrationsDir -Filter "V*.sql" | Sort-Object Name

foreach ($File in $MigrationFiles) {
    # Parse version (V001__description.sql -> 001)
    if ($File.Name -match "^V(\d+)__(.+)\.sql$") {
        $Version = [int]$Matches[1]
        $Description = $Matches[2].Replace("_", " ")
        
        # Check if already applied
        $CheckQuery = "SELECT COUNT(*) AS Applied FROM SchemaMigrations WHERE Version = $Version"
        $Result = sqlcmd -S $Server -d $Database -U $Username -P $Password -Q $CheckQuery -h -1
        
        if ($Result.Trim() -eq "0") {
            Write-Host "Applying migration V$Version : $Description" -ForegroundColor Yellow
            
            # Apply migration
            sqlcmd -S $Server -d $Database -U $Username -P $Password -i $File.FullName
            
            # Record migration
            $RecordQuery = "INSERT INTO SchemaMigrations (Version, Description) VALUES ($Version, '$Description')"
            sqlcmd -S $Server -d $Database -U $Username -P $Password -Q $RecordQuery
            
            Write-Host "✅ V$Version applied successfully" -ForegroundColor Green
        } else {
            Write-Host "⏭️  V$Version already applied (skipping)" -ForegroundColor Gray
        }
    }
}

Write-Host "`n🎉 All migrations applied!" -ForegroundColor Green
```

---

### 5.3 CI Integration

**Add to `.github/workflows/ci.yml`:**

```yaml
- name: Run Database Migrations
  run: pwsh backend/scripts/run_migrations.ps1
  env:
    SQL_SERVER: ${{ secrets.SQL_SERVER_TEST }}
    SQL_DATABASE: ${{ secrets.SQL_DATABASE_TEST }}
    SQL_USER: ${{ secrets.SQL_USER_TEST }}
    SQL_PASSWORD: ${{ secrets.SQL_PASSWORD_TEST }}
```

---

## ✅ CI/CD Hardening Checklist

### Pre-Production Deployment

- [ ] All SQL unit tests pass (tSQLt)
- [ ] All Cloud Functions unit tests pass (Jest)
- [ ] All Flutter unit tests pass
- [ ] ESLint passes (no Firestore violations)
- [ ] SQL connection test passes
- [ ] All required stored procedures exist
- [ ] Wallet consistency check passes (no inconsistencies)
- [ ] Database migrations applied successfully
- [ ] Feature flags configured in Remote Config
- [ ] Monitoring infrastructure deployed (cron jobs running)

### Post-Deployment

- [ ] Integration tests pass in staging
- [ ] Load test passes (>95% success rate)
- [ ] Performance benchmarks meet SLA (P95 < 500ms)
- [ ] Wallet consistency validator ran without issues
- [ ] Rollback procedure tested and documented
- [ ] On-call rotation configured
- [ ] Incident runbooks accessible to team

---

**Not:** Bu CI/CD hardening adımları Faz 1 production deploy'dan **ÖNCE** uygulanmalı. Code quality gates olmadan production'a çıkmak tehlikelidir.
