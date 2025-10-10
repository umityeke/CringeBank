/*
  Procedure: dbo.sp_Admin_ReviewVerificationRequest
  Purpose : Applies an approval or rejection decision to a verification request and logs the action.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_ReviewVerificationRequest', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_ReviewVerificationRequest;
END
GO

CREATE PROCEDURE dbo.sp_Admin_ReviewVerificationRequest
    @ActorAuthUid          NVARCHAR(64),
    @ActorRoleKey          NVARCHAR(64),
    @RequestId             BIGINT,
    @NewStatus             NVARCHAR(16),
    @ReviewNotes           NVARCHAR(MAX) = NULL,
    @DecisionMetadataJson  NVARCHAR(MAX) = NULL,
    @IpAddress             NVARCHAR(64) = NULL,
    @UserAgent             NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIMEOFFSET(3) = SYSUTCDATETIME();
    DECLARE @CurrentStatus NVARCHAR(32);
    DECLARE @AuthUid NVARCHAR(64);
    DECLARE @AuditPayload NVARCHAR(MAX);
    DECLARE @EntityId NVARCHAR(128);

    IF @ActorAuthUid IS NULL OR LTRIM(RTRIM(@ActorAuthUid)) = N''
    BEGIN
        RAISERROR('Actor auth uid is required.', 16, 1);
        RETURN;
    END

    IF @RequestId IS NULL OR @RequestId <= 0
    BEGIN
        RAISERROR('RequestId is required.', 16, 1);
        RETURN;
    END

    IF @NewStatus NOT IN ('approved', 'rejected')
    BEGIN
        RAISERROR('NewStatus must be approved or rejected.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @CurrentStatus = Status,
            @AuthUid = AuthUid
        FROM dbo.VerificationRequests WITH (UPDLOCK, HOLDLOCK)
        WHERE RequestId = @RequestId;

        IF @CurrentStatus IS NULL
        BEGIN
            RAISERROR('Verification request not found.', 16, 1);
        END

        IF @CurrentStatus = @NewStatus
        BEGIN
            RAISERROR('Verification request already has the desired status.', 16, 1);
        END

        UPDATE dbo.VerificationRequests
        SET Status = @NewStatus,
            ReviewedAt = @now,
            ReviewedByAuthUid = @ActorAuthUid,
            ReviewNotes = CASE WHEN @ReviewNotes IS NULL THEN ReviewNotes ELSE NULLIF(LTRIM(RTRIM(@ReviewNotes)), N'') END,
            DecisionMetadataJson = CASE WHEN @DecisionMetadataJson IS NULL THEN DecisionMetadataJson ELSE NULLIF(LTRIM(RTRIM(@DecisionMetadataJson)), N'') END
        WHERE RequestId = @RequestId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Verification request update failed.', 16, 1);
        END

        SELECT @AuditPayload = (
            SELECT
                requestId = @RequestId,
                targetAuthUid = @AuthUid,
                previousStatus = @CurrentStatus,
                newStatus = @NewStatus,
                reviewNotes = @ReviewNotes
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SET @EntityId = CAST(@RequestId AS NVARCHAR(128));

        EXEC dbo.sp_Admin_LogAudit
            @ActorAuthUid = @ActorAuthUid,
            @ActorRoleKey = @ActorRoleKey,
            @TargetAuthUid = @AuthUid,
            @Action = N'verification.review',
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

        RAISERROR('sp_Admin_ReviewVerificationRequest failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH

    SELECT RequestId = @RequestId, Status = @NewStatus;
END
GO

PRINT 'Procedure dbo.sp_Admin_ReviewVerificationRequest created.';
GO
