/*
  Procedure: dbo.sp_Admin_SubmitVerificationRequest
  Purpose : Creates or updates a pending verification request for a user and logs the submission.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_SubmitVerificationRequest', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_SubmitVerificationRequest;
END
GO

CREATE PROCEDURE dbo.sp_Admin_SubmitVerificationRequest
    @AuthUid               NVARCHAR(64),
    @SubmittedPayloadJson  NVARCHAR(MAX),
    @AttachmentsJson       NVARCHAR(MAX) = NULL,
    @MetadataJson          NVARCHAR(MAX) = NULL,
    @IpAddress             NVARCHAR(64) = NULL,
    @UserAgent             NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIMEOFFSET(3) = SYSUTCDATETIME();
    DECLARE @RequestId BIGINT;
    DECLARE @AuditPayload NVARCHAR(MAX);
    DECLARE @EntityId NVARCHAR(128);

    IF @AuthUid IS NULL OR LTRIM(RTRIM(@AuthUid)) = N''
    BEGIN
        RAISERROR('Auth uid is required.', 16, 1);
        RETURN;
    END

    IF @SubmittedPayloadJson IS NULL OR LTRIM(RTRIM(@SubmittedPayloadJson)) = N''
    BEGIN
        RAISERROR('Submitted payload json is required.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT TOP (1)
            @RequestId = RequestId
        FROM dbo.VerificationRequests WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @AuthUid
          AND Status = 'pending';

        IF @RequestId IS NULL
        BEGIN
            INSERT INTO dbo.VerificationRequests
            (
                AuthUid,
                Status,
                SubmittedAt,
                SubmittedPayloadJson,
                AttachmentsJson,
                ReviewedAt,
                ReviewedByAuthUid,
                ReviewNotes,
                DecisionMetadataJson,
                LastReminderAt,
                MetadataJson
            )
            VALUES
            (
                @AuthUid,
                'pending',
                @now,
                @SubmittedPayloadJson,
                CASE WHEN @AttachmentsJson IS NULL OR LTRIM(RTRIM(@AttachmentsJson)) = N'' THEN NULL ELSE @AttachmentsJson END,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                CASE WHEN @MetadataJson IS NULL OR LTRIM(RTRIM(@MetadataJson)) = N'' THEN NULL ELSE @MetadataJson END
            );

            SET @RequestId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.VerificationRequests
            SET SubmittedPayloadJson = @SubmittedPayloadJson,
                AttachmentsJson = CASE WHEN @AttachmentsJson IS NULL OR LTRIM(RTRIM(@AttachmentsJson)) = N'' THEN NULL ELSE @AttachmentsJson END,
                SubmittedAt = @now,
                ReviewedAt = NULL,
                ReviewedByAuthUid = NULL,
                ReviewNotes = NULL,
                DecisionMetadataJson = NULL,
                Status = 'pending'
            WHERE RequestId = @RequestId;
        END

        SELECT @AuditPayload = (
            SELECT
                requestId = @RequestId,
                authUid = @AuthUid
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SET @EntityId = CAST(@RequestId AS NVARCHAR(128));

        EXEC dbo.sp_Admin_LogAudit
            @ActorAuthUid = @AuthUid,
            @ActorRoleKey = NULL,
            @TargetAuthUid = @AuthUid,
            @Action = N'verification.submit',
            @EntityType = N'verification_request',
            @EntityId = @EntityId,
            @PayloadJson = @AuditPayload,
            @IpAddress = @IpAddress,
            @UserAgent = @UserAgent,
            @MetadataJson = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        DECLARE @ErrorNumber INT = ERROR_NUMBER();
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();

        RAISERROR('sp_Admin_SubmitVerificationRequest failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH

    SELECT RequestId = @RequestId;
END
GO

PRINT 'Procedure dbo.sp_Admin_SubmitVerificationRequest created.';
GO
