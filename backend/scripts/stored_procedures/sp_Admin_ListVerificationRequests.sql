/*
  Procedure: dbo.sp_Admin_ListVerificationRequests
  Purpose : Lists verification requests with optional filters and pagination.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_ListVerificationRequests', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_ListVerificationRequests;
END
GO

CREATE PROCEDURE dbo.sp_Admin_ListVerificationRequests
    @Status        NVARCHAR(32) = NULL,
    @AuthUid       NVARCHAR(64) = NULL,
    @Offset        INT = 0,
    @Limit         INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF @Limit IS NULL OR @Limit <= 0 OR @Limit > 200
    BEGIN
        SET @Limit = 50;
    END

    IF @Offset IS NULL OR @Offset < 0
    BEGIN
        SET @Offset = 0;
    END

    WITH Filtered AS (
        SELECT
            RequestId,
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
            MetadataJson,
            RowVersion,
            TotalCount = COUNT(*) OVER ()
        FROM dbo.VerificationRequests
        WHERE (@Status IS NULL OR Status = @Status)
          AND (@AuthUid IS NULL OR AuthUid = @AuthUid)
    )
    SELECT
        RequestId,
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
        MetadataJson,
        RowVersion,
        TotalCount
    FROM Filtered
    ORDER BY SubmittedAt DESC
    OFFSET @Offset ROWS FETCH NEXT @Limit ROWS ONLY;
END
GO

PRINT 'Procedure dbo.sp_Admin_ListVerificationRequests created.';
GO
