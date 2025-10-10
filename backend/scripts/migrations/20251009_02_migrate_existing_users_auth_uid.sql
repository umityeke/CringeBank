/*
  Migration: Populate AuthUid for existing users from Firebase
  Purpose: Syncs Firebase Authentication UIDs to SQL dbo.Users table
  
  Prerequisites:
    - Users table exists with AuthUid column
    - IX_Users_AuthUid unique index is applied
    - Firebase Admin SDK is available via Node.js script or manual export
  
  Usage:
    1. Export Firebase users via admin SDK to JSON
    2. Run this script with JSON payload or via stored procedure
    3. Validate UID match count
    
  Manual run:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251009_02_migrate_existing_users_auth_uid.sql
*/

SET NOCOUNT ON;
GO

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.Users', 'U') IS NULL
BEGIN
    RAISERROR('dbo.Users table does not exist. Cannot migrate AuthUid.', 16, 1);
    RETURN;
END
GO

IF COL_LENGTH('dbo.Users', 'AuthUid') IS NULL
BEGIN
    RAISERROR('dbo.Users.AuthUid column is missing. Run migration 20251007_02 first.', 16, 1);
    RETURN;
END
GO

-- Create staging table for Firebase export
IF OBJECT_ID('tempdb..#FirebaseUsers', 'U') IS NOT NULL
    DROP TABLE #FirebaseUsers;

CREATE TABLE #FirebaseUsers
(
    FirebaseUID NVARCHAR(64) NOT NULL PRIMARY KEY,
    Email NVARCHAR(256) NULL,
    DisplayName NVARCHAR(128) NULL,
    CreatedAt DATETIME2(3) NULL
);

PRINT 'Staging table #FirebaseUsers created. Load Firebase user export data here.';
PRINT 'Expected format: FirebaseUID, Email, DisplayName, CreatedAt';
PRINT '';
PRINT 'Example bulk insert from CSV:';
PRINT '  BULK INSERT #FirebaseUsers FROM ''C:\temp\firebase_users.csv'' WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''\n'', FIRSTROW=2);';
PRINT '';
PRINT 'After loading, run sp_MigrateFirebaseUsersToSQL or manual merge below.';
GO

-- Optional: Manual merge if data is already loaded in #FirebaseUsers
-- Uncomment and run after loading staging data

/*
MERGE dbo.Users AS target
USING #FirebaseUsers AS source
ON target.Email = source.Email
WHEN MATCHED AND (target.AuthUid IS NULL OR target.AuthUid = '' OR target.AuthUid != source.FirebaseUID) THEN
    UPDATE SET
        target.AuthUid = source.FirebaseUID,
        target.DisplayName = ISNULL(target.DisplayName, source.DisplayName),
        target.UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (AuthUid, Email, Username, DisplayName, CreatedAt, UpdatedAt)
    VALUES (
        source.FirebaseUID,
        source.Email,
        ISNULL(LEFT(source.Email, CHARINDEX('@', source.Email + '@') - 1), 'user_' + CAST(NEWID() AS NVARCHAR(36))),
        source.DisplayName,
        ISNULL(source.CreatedAt, SYSUTCDATETIME()),
        SYSUTCDATETIME()
    );

PRINT 'AuthUid migration merge completed.';
PRINT 'Updated/inserted rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));
*/

GO

PRINT 'Migration script 20251009_02 ready. Load Firebase user data and execute merge.';
GO
