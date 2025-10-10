/*
  Procedure: dbo.sp_Admin_ListBadges
  Purpose : Lists badge definitions with optional filters and pagination.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_ListBadges', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_ListBadges;
END
GO

CREATE PROCEDURE dbo.sp_Admin_ListBadges
    @OnlyActive    BIT = NULL,
    @SearchTerm    NVARCHAR(120) = NULL,
    @Offset        INT = 0,
    @Limit         INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Search NVARCHAR(120) = NULLIF(LTRIM(RTRIM(@SearchTerm)), N'');

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
            BadgeId,
            Slug,
            Title,
            Description,
            IconUrl,
            Category,
            IsActive,
            DisplayOrder,
            CreatedAt,
            UpdatedAt,
            CreatedByAuthUid,
            UpdatedByAuthUid,
            MetadataJson,
            TotalCount = COUNT(*) OVER ()
        FROM dbo.Badges
                        WHERE (@OnlyActive IS NULL OR IsActive = @OnlyActive)
                            AND (
                                        @Search IS NULL
                                        OR Slug LIKE '%' + @Search + '%'
                                        OR Title LIKE '%' + @Search + '%'
                                        OR Category LIKE '%' + @Search + '%'
                            )
    )
    SELECT
        BadgeId,
        Slug,
        Title,
        Description,
        IconUrl,
        Category,
        IsActive,
        DisplayOrder,
        CreatedAt,
        UpdatedAt,
        CreatedByAuthUid,
        UpdatedByAuthUid,
        MetadataJson,
        TotalCount
    FROM Filtered
    ORDER BY DisplayOrder ASC, Title ASC
    OFFSET @Offset ROWS FETCH NEXT @Limit ROWS ONLY;
END
GO

PRINT 'Procedure dbo.sp_Admin_ListBadges created.';
GO
