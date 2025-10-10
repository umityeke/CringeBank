/*
  Migration: Create admin badge, verification, and audit workflow tables
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251009_01_create_admin_workflows.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.Badges', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.Badges';
    CREATE TABLE dbo.Badges
    (
        BadgeId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Badges PRIMARY KEY,
        Slug NVARCHAR(64) NOT NULL,
        Title NVARCHAR(120) NOT NULL,
        Description NVARCHAR(400) NULL,
        IconUrl NVARCHAR(512) NULL,
        Category NVARCHAR(64) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_Badges_IsActive DEFAULT (1),
        DisplayOrder INT NULL,
        CreatedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_Badges_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_Badges_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CreatedByAuthUid NVARCHAR(64) NULL,
        UpdatedByAuthUid NVARCHAR(64) NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        RowVersion ROWVERSION NOT NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.Badges already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Badges')
      AND name = 'UX_Badges_Slug'
)
BEGIN
    CREATE UNIQUE INDEX UX_Badges_Slug
        ON dbo.Badges (Slug);
END
GO

IF OBJECT_ID('dbo.UserBadges', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.UserBadges';
    CREATE TABLE dbo.UserBadges
    (
        UserBadgeId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserBadges PRIMARY KEY,
        AuthUid NVARCHAR(64) NOT NULL,
        BadgeId BIGINT NOT NULL,
        GrantedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_UserBadges_GrantedAt DEFAULT (SYSUTCDATETIME()),
        GrantedByAuthUid NVARCHAR(64) NOT NULL,
        RevokedAt DATETIMEOFFSET(3) NULL,
        RevokedByAuthUid NVARCHAR(64) NULL,
        Reason NVARCHAR(400) NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        RowVersion ROWVERSION NOT NULL,
        CONSTRAINT FK_UserBadges_Badge FOREIGN KEY (BadgeId)
            REFERENCES dbo.Badges (BadgeId)
    );
END
ELSE
BEGIN
    PRINT 'dbo.UserBadges already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.UserBadges')
      AND name = 'UX_UserBadges_User_Badge_Active'
)
BEGIN
    CREATE UNIQUE INDEX UX_UserBadges_User_Badge_Active
        ON dbo.UserBadges (AuthUid, BadgeId)
        WHERE RevokedAt IS NULL;
END
GO

IF OBJECT_ID('dbo.VerificationRequests', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.VerificationRequests';
    CREATE TABLE dbo.VerificationRequests
    (
        RequestId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VerificationRequests PRIMARY KEY,
        AuthUid NVARCHAR(64) NOT NULL,
        Status NVARCHAR(32) NOT NULL CONSTRAINT DF_VerificationRequests_Status DEFAULT ('pending'),
        SubmittedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_VerificationRequests_SubmittedAt DEFAULT (SYSUTCDATETIME()),
        SubmittedPayloadJson NVARCHAR(MAX) NULL,
        AttachmentsJson NVARCHAR(MAX) NULL,
        ReviewedAt DATETIMEOFFSET(3) NULL,
        ReviewedByAuthUid NVARCHAR(64) NULL,
        ReviewNotes NVARCHAR(MAX) NULL,
        DecisionMetadataJson NVARCHAR(MAX) NULL,
        LastReminderAt DATETIMEOFFSET(3) NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        RowVersion ROWVERSION NOT NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.VerificationRequests already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.VerificationRequests')
      AND name = 'IX_VerificationRequests_Status_Submitted'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_VerificationRequests_Status_Submitted
        ON dbo.VerificationRequests (Status, SubmittedAt DESC)
        INCLUDE (AuthUid, ReviewedAt, ReviewedByAuthUid);
END
GO

IF OBJECT_ID('dbo.AdminRoles', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.AdminRoles';
    CREATE TABLE dbo.AdminRoles
    (
        AdminRoleId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AdminRoles PRIMARY KEY,
        AuthUid NVARCHAR(64) NOT NULL,
        RoleKey NVARCHAR(64) NOT NULL,
        Status NVARCHAR(32) NOT NULL CONSTRAINT DF_AdminRoles_Status DEFAULT ('active'),
        ScopeJson NVARCHAR(MAX) NULL,
        GrantedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_AdminRoles_GrantedAt DEFAULT (SYSUTCDATETIME()),
        GrantedByAuthUid NVARCHAR(64) NOT NULL,
        RevokedAt DATETIMEOFFSET(3) NULL,
        RevokedByAuthUid NVARCHAR(64) NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        RowVersion ROWVERSION NOT NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.AdminRoles already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AdminRoles')
      AND name = 'UX_AdminRoles_User_Role_Active'
)
BEGIN
    CREATE UNIQUE INDEX UX_AdminRoles_User_Role_Active
        ON dbo.AdminRoles (AuthUid, RoleKey)
        WHERE RevokedAt IS NULL;
END
GO

IF OBJECT_ID('dbo.AdminAuditLog', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.AdminAuditLog';
    CREATE TABLE dbo.AdminAuditLog
    (
        AuditId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AdminAuditLog PRIMARY KEY,
        OccurredAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_AdminAuditLog_OccurredAt DEFAULT (SYSUTCDATETIME()),
        ActorAuthUid NVARCHAR(64) NOT NULL,
        ActorRoleKey NVARCHAR(64) NULL,
        TargetAuthUid NVARCHAR(64) NULL,
        Action NVARCHAR(64) NOT NULL,
        EntityType NVARCHAR(64) NOT NULL,
        EntityId NVARCHAR(128) NULL,
        PayloadJson NVARCHAR(MAX) NULL,
        IpAddress NVARCHAR(64) NULL,
        UserAgent NVARCHAR(256) NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        RowVersion ROWVERSION NOT NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.AdminAuditLog already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AdminAuditLog')
      AND name = 'IX_AdminAuditLog_OccurredAt'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_AdminAuditLog_OccurredAt
        ON dbo.AdminAuditLog (OccurredAt DESC)
        INCLUDE (ActorAuthUid, Action, EntityType, EntityId);
END
GO

PRINT 'Admin workflow tables migration completed successfully.';
GO
