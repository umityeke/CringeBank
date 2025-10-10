-- =============================================================================
-- Stored Procedure: sp_Analytics_GetDAU
-- =============================================================================
-- Purpose: Calculate Daily Active Users for a date range
-- Author: CringeBank Analytics Team
-- Date: 2025-10-09
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_Analytics_GetDAU
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @IntervalType NVARCHAR(20) = 'DAILY' -- DAILY, WEEKLY, MONTHLY
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Default to last 30 days if not specified
        IF @StartDate IS NULL
        BEGIN
            SET @StartDate = CAST(DATEADD(DAY, -30, GETUTCDATE()) AS DATE);
        END
        
        IF @EndDate IS NULL
        BEGIN
            SET @EndDate = CAST(GETUTCDATE() AS DATE);
        END
        
        -- Validate interval type
        IF @IntervalType NOT IN ('DAILY', 'WEEKLY', 'MONTHLY')
        BEGIN
            RAISERROR('IntervalType must be DAILY, WEEKLY, or MONTHLY', 16, 1);
            RETURN;
        END
        
        -- Daily Active Users
        IF @IntervalType = 'DAILY'
        BEGIN
            SELECT 
                StatDate,
                COUNT(DISTINCT AuthUid) AS DAU,
                SUM(CAST(IsActive AS INT)) AS ActiveUserCount,
                AVG(EngagementScore) AS AvgEngagementScore,
                SUM(MessagesSent + MessagesReceived) AS TotalMessages,
                SUM(TimelineEventsCreated) AS TotalTimelineEvents,
                SUM(NotificationsRead) AS TotalNotificationsRead
            FROM UserDailyStats
            WHERE StatDate >= @StartDate 
                AND StatDate <= @EndDate
                AND IsActive = 1
            GROUP BY StatDate
            ORDER BY StatDate DESC;
        END
        
        -- Weekly Active Users
        ELSE IF @IntervalType = 'WEEKLY'
        BEGIN
            SELECT 
                DATEADD(WEEK, DATEDIFF(WEEK, 0, StatDate), 0) AS WeekStart,
                COUNT(DISTINCT AuthUid) AS WAU,
                AVG(CAST(IsActive AS FLOAT)) * 100 AS ActiveRate,
                AVG(EngagementScore) AS AvgEngagementScore,
                SUM(MessagesSent + MessagesReceived) AS TotalMessages
            FROM UserDailyStats
            WHERE StatDate >= @StartDate 
                AND StatDate <= @EndDate
            GROUP BY DATEADD(WEEK, DATEDIFF(WEEK, 0, StatDate), 0)
            ORDER BY WeekStart DESC;
        END
        
        -- Monthly Active Users
        ELSE IF @IntervalType = 'MONTHLY'
        BEGIN
            SELECT 
                DATEADD(MONTH, DATEDIFF(MONTH, 0, StatDate), 0) AS MonthStart,
                COUNT(DISTINCT AuthUid) AS MAU,
                AVG(CAST(IsActive AS FLOAT)) * 100 AS ActiveRate,
                AVG(EngagementScore) AS AvgEngagementScore,
                SUM(MessagesSent + MessagesReceived) AS TotalMessages
            FROM UserDailyStats
            WHERE StatDate >= @StartDate 
                AND StatDate <= @EndDate
            GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, StatDate), 0)
            ORDER BY MonthStart DESC;
        END
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO
