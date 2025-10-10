# Follow Preview Stored Procedure Plan

This note documents the MSSQL artefacts required for the hybrid follow preview flow. The goal is to keep privacy- and policy-aware logic on the SQL side while the Flutter client only consumes pre-filtered lists through the `getFollowingPreview` Cloud Function.

## 1. Reference tables

The procedure assumes the following canonical tables already exist (names can be adjusted to match production):

- `dbo.Users` — master record for each account. Relevant columns:
  - `Id UNIQUEIDENTIFIER PRIMARY KEY`
  - `FirebaseUid NVARCHAR(128) UNIQUE NOT NULL`
  - `Username NVARCHAR(32) NOT NULL`
  - `UsernameNorm NVARCHAR(64) NOT NULL` (normalized search key)
  - `DisplayName NVARCHAR(120) NULL`
  - `AvatarUrl NVARCHAR(512) NULL`
  - `IsVerified BIT NOT NULL DEFAULT 0`
  - `IsPrivate BIT NOT NULL DEFAULT 0`
  - `IsSuspended BIT NOT NULL DEFAULT 0`
  - `FollowersCount INT NOT NULL DEFAULT 0`
  - `FollowingCount INT NOT NULL DEFAULT 0`

- `dbo.Follows`
  - `FollowerId UNIQUEIDENTIFIER NOT NULL`
  - `FollowedId UNIQUEIDENTIFIER NOT NULL`
  - `CreatedAt DATETIME2(3) NOT NULL`
  - `PRIMARY KEY (FollowerId, FollowedId)`

- `dbo.UserBlocks`
  - `BlockerId UNIQUEIDENTIFIER NOT NULL`
  - `BlockedId UNIQUEIDENTIFIER NOT NULL`
  - `PRIMARY KEY (BlockerId, BlockedId)`

- `dbo.PrivacyOverrides` (optional)
  - Captures allow/deny lists for edge cases such as approved followers when the account is private.

## 2. Rate limit table

```sql
CREATE TABLE dbo.FollowPreviewRate (
  Id            INT IDENTITY(1,1) PRIMARY KEY,
  UserId        UNIQUEIDENTIFIER NOT NULL,
  Endpoint      VARCHAR(32)      NOT NULL,
  Ts            DATETIME2(3)     NOT NULL,
  INDEX IX_FollowPreviewRate_UserTs (UserId, Ts DESC)
);
```

This mirrors the existing `SearchRate` table used by the user search endpoint and is referenced by the Cloud Function through the `RATE_LIMIT_TABLE` constant.

## 3. Stored procedure

```sql
CREATE OR ALTER PROCEDURE dbo.sp_GetFollowingPreview
  @ViewerId      UNIQUEIDENTIFIER,
  @TargetId      UNIQUEIDENTIFIER,
  @Limit         INT = 12,
  @CursorToken   VARCHAR(128) = NULL,
  @NextCursor    VARCHAR(128) OUTPUT
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @Lookup TABLE (
    TargetId        UNIQUEIDENTIFIER,
    FollowedAt      DATETIME2(3),
    CursorToken     VARCHAR(128)
  );

  DECLARE @afterFollow DATETIME2(3) = NULL;
  DECLARE @afterUser   UNIQUEIDENTIFIER = NULL;

  IF @CursorToken IS NOT NULL
  BEGIN
    -- cursor format: {"ts":"2025-10-07T17:32:11.123Z","id":"GUID"}
    DECLARE @payload NVARCHAR(256);
    SET @payload = TRY_CONVERT(NVARCHAR(256), @CursorToken);
    IF @payload IS NOT NULL
    BEGIN
      SELECT
        @afterFollow = TRY_CONVERT(DATETIME2(3), JSON_VALUE(@payload, '$.ts')),
        @afterUser   = TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(@payload, '$.id'));
    END
  END

  WITH Ordered AS (
    SELECT TOP (@Limit + 1)
      f.FollowedId,
      f.CreatedAt,
      ROW_NUMBER() OVER (ORDER BY f.CreatedAt DESC, f.FollowedId DESC) AS RowNum
    FROM dbo.Follows f
    WHERE f.FollowerId = @TargetId
      AND (@afterFollow IS NULL
        OR f.CreatedAt < @afterFollow
        OR (f.CreatedAt = @afterFollow AND f.FollowedId < @afterUser))
  )
  INSERT INTO @Lookup (TargetId, FollowedAt, CursorToken)
  SELECT
    o.FollowedId,
    o.CreatedAt,
    CONVERT(VARCHAR(128), JSON_OBJECT('ts' VALUE FORMAT(o.CreatedAt, 'yyyy-MM-ddTHH:mm:ss.fffZ'), 'id' VALUE o.FollowedId))
  FROM Ordered o;

  ;WITH Visible AS (
    SELECT
      l.TargetId,
      l.FollowedAt,
      u.FirebaseUid,
      u.Username,
      u.DisplayName,
      u.AvatarUrl,
      u.IsVerified,
      u.IsPrivate,
      u.FollowersCount,
      u.FollowingCount,
      ISNULL(m.MutualCount, 0) AS MutualCount
    FROM @Lookup l
    INNER JOIN dbo.Users u ON u.Id = l.TargetId
    OUTER APPLY (
      SELECT COUNT(*) AS MutualCount
      FROM dbo.Follows f1
      INNER JOIN dbo.Follows f2 ON f2.FollowerId = f1.FollowedId AND f2.FollowedId = l.TargetId
      WHERE f1.FollowerId = @ViewerId
    ) AS m
    WHERE u.IsSuspended = 0
      AND NOT EXISTS (
        SELECT 1 FROM dbo.UserBlocks b WHERE b.BlockerId = @ViewerId AND b.BlockedId = l.TargetId
      )
      AND NOT EXISTS (
        SELECT 1 FROM dbo.UserBlocks b WHERE b.BlockerId = l.TargetId AND b.BlockedId = @ViewerId
      )
      AND (
        @ViewerId = @TargetId
        OR u.IsPrivate = 0
        OR EXISTS (
          SELECT 1 FROM dbo.Follows f
          WHERE f.FollowerId = @ViewerId AND f.FollowedId = l.TargetId
        )
        OR EXISTS (
          SELECT 1 FROM dbo.PrivacyOverrides po
          WHERE po.OwnerId = l.TargetId AND po.AllowedUserId = @ViewerId
        )
      )
  )
  SELECT TOP (@Limit)
    v.FirebaseUid      AS TargetFirebaseUid,
    v.Username,
    v.DisplayName,
    v.AvatarUrl,
    v.IsVerified,
    v.IsPrivate,
    v.FollowersCount,
    v.FollowingCount,
    v.MutualCount,
    v.FollowedAt,
    l.CursorToken
  FROM Visible v
  INNER JOIN @Lookup l ON l.TargetId = v.TargetId
  ORDER BY v.FollowedAt DESC, v.TargetFirebaseUid DESC;

  SELECT TOP (1)
    @NextCursor = CursorToken
  FROM @Lookup
  ORDER BY FollowedAt ASC, TargetId ASC;
END;
```

The procedure enforces the following:

- Filters out suspended or blocked accounts for the viewer.
- Applies private-account visibility rules (viewer must follow target or be explicitly allowed).
- Returns one extra row to compute the next cursor token (base64 JSON payload).

## 4. Expected payload shape

```json
{
  "items": [
    {
      "uid": "firebaseUid",
      "username": "handle",
      "displayName": "Display Name",
      "avatar": "https://...",
      "verified": true,
      "isPrivate": false,
      "followersCount": 420,
      "followingCount": 1337,
      "mutualCount": 5,
      "followedAt": "2025-10-07T17:21:44.123Z",
      "cursorToken": "..."  // internal use
    }
  ],
  "nextCursor": "..." // value from @NextCursor
}
```

The Cloud Function strips the `cursorToken` before returning to the client and exposes `nextCursor` separately.

## 5. Operational notes

- Keep the procedure idempotent and side-effect free. The Cloud Function retries on retryable SQL errors.
- Treat `@Limit` as a hard cap of 50; the function already clamps the value.
- Ensure indexes on `Follows(FollowerId, CreatedAt DESC)` to keep pagination efficient.
- Optional: create an index on `UserBlocks(BlockerId, BlockedId)` and `PrivacyOverrides(OwnerId, AllowedUserId)`.
- Schedule a nightly reconciliation job (SQL Agent or Cloud Function) to refresh the cached counts in Firestore `public_follow_counts`.
