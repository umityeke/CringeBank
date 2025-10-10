# 🔍 User Search Service Deployment Guide

This document explains how to enable the GLOBAL + DM user search experience powered by Firebase Authentication and Microsoft SQL Server. It includes required environment variables, database migrations, API contract notes, and operational checklists.

---

## 1. Environment Variables

Set the following keys for Cloud Functions (via `firebase functions:config:set` or your secrets manager). Values should match your SQL Server deployment and security posture.

| Key | Description |
| --- | --- |
| `SQLSERVER_HOST` | SQL Server hostname or IP |
| `SQLSERVER_PORT` | (Optional) TCP port, defaults to 1433 |
| `SQLSERVER_USER` | SQL login with read/write access to `dbo.Users`, `dbo.UserBlocks`, `dbo.Follows`, `dbo.SearchRate` |
| `SQLSERVER_PASS` | SQL login password |
| `SQLSERVER_DB` | Target database name |
| `SQLSERVER_ENCRYPT` | Set to `false` only if TLS is already offloaded (default is `true`) |
| `SQLSERVER_TRUST_CERT` | Set to `true` when using self-signed certificates |
| `SQLSERVER_POOL_MAX` | (Optional) Max pool size, default `10` |
| `SQLSERVER_POOL_MIN` | (Optional) Min pool size, default `0` |
| `SQLSERVER_POOL_IDLE` | (Optional) Idle timeout in ms, default `30000` |
| `SEARCH_SALT` | Salt for HMAC hashing of queries (store in Secret Manager) |
| `SEARCH_REGION` | (Optional) Functions region, defaults to `europe-west1` |
| `REQUIRED_CLAIMS_VERSION` | (Optional) Int enforcing token claim version, mismatches return HTTP 409 |
| `DM_STRICT_SUGGESTION_LIMIT` | (Optional) Max item count treated as “suggestions”, default `8` |
| `SEARCH_CORS_ORIGIN` | (Optional) CORS allowlist, default `*` |

> ⚠️ Create a Service Account mapping between Firebase UID and `dbo.Users.Id` using a `firebaseUid` column as assumed by the handler.

---

## 2. SQL Server Preparations

### 2.1 Collation + Normalized Columns

```sql
ALTER TABLE dbo.Users
  ALTER COLUMN Username    NVARCHAR(50)  COLLATE Turkish_CI_AS NOT NULL;
ALTER TABLE dbo.Users
  ALTER COLUMN DisplayName NVARCHAR(100) COLLATE Turkish_CI_AS NOT NULL;

IF EXISTS (SELECT 1 FROM sys.computed_columns WHERE OBJECT_ID = OBJECT_ID('dbo.Users') AND name = 'UsernameNorm')
  ALTER TABLE dbo.Users DROP COLUMN UsernameNorm;
IF EXISTS (SELECT 1 FROM sys.computed_columns WHERE OBJECT_ID = OBJECT_ID('dbo.Users') AND name = 'DisplayNorm')
  ALTER TABLE dbo.Users DROP COLUMN DisplayNorm;

ALTER TABLE dbo.Users
  ADD UsernameNorm AS (LOWER(Username) COLLATE Turkish_CI_AI) PERSISTED;
ALTER TABLE dbo.Users
  ADD DisplayNorm  AS (LOWER(DisplayName) COLLATE Turkish_CI_AI) PERSISTED;

CREATE INDEX IX_Users_UsernameNorm ON dbo.Users(UsernameNorm)
  INCLUDE (DisplayName, IsVerified, AvatarUrl, IsPrivate, DmPolicy);
CREATE INDEX IX_Users_DisplayNorm ON dbo.Users(DisplayNorm)
  INCLUDE (Username, IsVerified, AvatarUrl, IsPrivate, DmPolicy);
```

### 2.2 Relationship Tables

Ensure these tables exist (adjust names if already provisioned):

```sql
CREATE TABLE dbo.UserBlocks (
  BlockerId UNIQUEIDENTIFIER NOT NULL,
  BlockedId UNIQUEIDENTIFIER NOT NULL,
  CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_UserBlocks PRIMARY KEY (BlockerId, BlockedId)
);

CREATE TABLE dbo.Follows (
  FollowerId UNIQUEIDENTIFIER NOT NULL,
  FollowedId UNIQUEIDENTIFIER NOT NULL,
  CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Follows PRIMARY KEY (FollowerId, FollowedId)
);

gO
CREATE INDEX IX_UserBlocks_Blocker ON dbo.UserBlocks(BlockerId);
CREATE INDEX IX_UserBlocks_Blocked ON dbo.UserBlocks(BlockedId);
CREATE INDEX IX_Follows_Follower ON dbo.Follows(FollowerId);
CREATE INDEX IX_Follows_Followed ON dbo.Follows(FollowedId);
```

### 2.3 Rate-Limit Ledger

```sql
CREATE TABLE dbo.SearchRate (
  UserId   UNIQUEIDENTIFIER NOT NULL,
  Endpoint VARCHAR(16) NOT NULL,
  Ts       DATETIME2(3) NOT NULL,
  CONSTRAINT IX_SearchRate CLUSTERED (UserId, Endpoint, Ts)
);
```

This table supports token-bucket style enforcement within Cloud Functions transactions.

---

## 3. API Contract

**Endpoint**: `POST https://<region>-<project>.cloudfunctions.net/searchUsers`

### Request Body

```json
{
  "scope": "GLOBAL" | "DM",
  "query": "um",
  "limit": 8,
  "cursor": null,
  "filters": {
    "onlyVerified": false,
    "onlyFollowing": false,
    "onlyNotFollowing": false
  }
}
```

### Response

```json
{
  "items": [
    {
      "uid": "u123",
      "displayName": "Umut Yeğe",
      "username": "umut",
      "verified": true,
      "avatar": "https://cdn...",
      "canMessage": true,
      "mutualCount": 4
    }
  ],
  "nextCursor": "eyJzIjoxLjk5OSwiaWQiOiIuLi4ifQ==",
  "tookMs": 42,
  "meta": { "scope": "GLOBAL" }
}
```

### Error Codes

- `400 short_query` – query shorter than 2 characters
- `401 unauthorized | email_unverified | user_not_found`
- `403 dm_policy_restriction` – DM suggestions blocked by policy
- `409 claims_version_mismatch` – refresh Firebase ID token
- `429 rate_limited`
- `500 server_error`

### Cursor Semantics

- Keyset on `(Score DESC, Id DESC)`
- Encoded as `base64(JSON.stringify({ s: lastScore, id: lastId }))`
- Score produced deterministically via DECIMAL(6,3)

---

## 4. Rate Limits

| Mode | Variant | Window | Limit |
| --- | --- | --- | --- |
| Any | Suggestions | 60 s | 30 requests |
| Any | Full results | 60 s | 20 requests |

Suggestions are detected when `cursor` is blank and `limit ≤ DM_STRICT_SUGGESTION_LIMIT` (defaults to 8). Limits are maintained transactionally in `dbo.SearchRate`.

---

## 5. Deployment Checklist

1. Run SQL migrations in sections 2.1–2.3.
2. Ensure `dbo.Users` contains `firebaseUid` column mapping Firebase Auth UIDs to SQL identities.
3. Configure environment variables (section 1) and rotate `SEARCH_SALT` via Secret Manager.
4. In `functions/`, install new dependency:

   ```bash
   npm install mssql
   ```

5. Deploy the function:

   ```bash
   firebase deploy --only functions:searchUsers
   ```

6. Verify telemetry in Cloud Logging (`search.users` entries expose hashed query, mode, count, latency).
7. QA scenarios:
   - Turkish diacritic prefix matches (`i/ı/İ`, `ş`, `ğ`, `ö`, `ü`, `ç`).
   - DM policy enforcement (followers-only, blocked, nobody).
   - Cursor pagination continuity (no duplicates / gaps across pages).
   - 429 handling on burst requests.

---

## 6. Client Integration Notes

- Debounce calls ≥ 220 ms, trim & lowercase query before sending.
- When scope = `DM`, hide or disable suggestions where `canMessage` is `false`.
- Cache the last 10 `(mode, queryPrefix)` lookups for 60 s to reduce churn.
- Emit analytics events `search.users.suggest` and `search.users.full` with hashed query, `tookMs`, `resultCount`, and `mode` fields.

---

✅ With these steps, the dual-mode user search experience can be deployed end-to-end on Firebase Functions + MSSQL.
