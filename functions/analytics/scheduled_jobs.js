/**
 * Scheduled Analytics Jobs
 * 
 * Daily aggregation of user activity metrics, engagement scores,
 * and trending content detection
 */

const functions = require('../regional_functions');
const { getSqlPool } = require('../utils/sql');
const { sendAlert } = require('../utils/alerts');

/**
 * Daily User Stats Aggregation
 * Runs every day at 2:00 AM UTC
 * Aggregates previous day's activity for all active users
 */
exports.aggregateUserDailyStats = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting daily user stats aggregation');
    
    const pool = getSqlPool();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const targetDate = yesterday.toISOString().split('T')[0];
    
    try {
      // Get all users who had activity yesterday
      const activeUsersResult = await pool.request()
        .input('TargetDate', targetDate)
        .query(`
          SELECT DISTINCT AuthUid
          FROM (
            SELECT SenderAuthUid AS AuthUid FROM Messages 
            WHERE CAST(CreatedAt AS DATE) = @TargetDate
            UNION
            SELECT RecipientAuthUid FROM Messages 
            WHERE CAST(CreatedAt AS DATE) = @TargetDate
            UNION
            SELECT ActorAuthUid FROM TimelineEvents 
            WHERE CAST(CreatedAt AS DATE) = @TargetDate
            UNION
            SELECT RecipientAuthUid FROM Notifications 
            WHERE CAST(CreatedAt AS DATE) = @TargetDate
          ) AS ActiveUsers
        `);
      
      const activeUsers = activeUsersResult.recordset;
      console.log(`Found ${activeUsers.length} active users for ${targetDate}`);
      
      let successCount = 0;
      let errorCount = 0;
      
      // Aggregate stats for each user
      for (const user of activeUsers) {
        try {
          await pool.request()
            .input('AuthUid', user.AuthUid)
            .input('TargetDate', targetDate)
            .execute('sp_Analytics_AggregateUserDaily');
          
          successCount++;
        } catch (userError) {
          console.error(`Error aggregating stats for user ${user.AuthUid}:`, userError);
          errorCount++;
        }
      }
      
      console.log(`User stats aggregation complete: ${successCount} success, ${errorCount} errors`);
      
      if (errorCount > activeUsers.length * 0.1) {
        // Alert if >10% failed
        await sendAlert('warning', 'User Stats Aggregation Errors', {
          date: targetDate,
          totalUsers: activeUsers.length,
          successCount,
          errorCount,
          errorRate: (errorCount / activeUsers.length * 100).toFixed(2) + '%'
        });
      }
      
      return { success: true, successCount, errorCount };
      
    } catch (error) {
      console.error('Error in user stats aggregation:', error);
      await sendAlert('error', 'User Stats Aggregation Failed', {
        date: targetDate,
        error: error.message
      });
      throw error;
    }
  });

/**
 * Engagement Score Update
 * Runs every day at 3:00 AM UTC (after stats aggregation)
 * Recalculates engagement scores for active users
 */
exports.updateEngagementScores = functions.pubsub
  .schedule('0 3 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting engagement score updates');
    
    const pool = getSqlPool();
    
    try {
      // Get users who were active in last 30 days
      const activeUsersResult = await pool.request()
        .query(`
          SELECT DISTINCT AuthUid
          FROM UserDailyStats
          WHERE StatDate >= CAST(DATEADD(DAY, -30, GETUTCDATE()) AS DATE)
            AND IsActive = 1
        `);
      
      const activeUsers = activeUsersResult.recordset;
      console.log(`Updating engagement scores for ${activeUsers.length} users`);
      
      let successCount = 0;
      let errorCount = 0;
      
      // Calculate engagement score for each user
      for (const user of activeUsers) {
        try {
          await pool.request()
            .input('AuthUid', user.AuthUid)
            .execute('sp_Analytics_CalculateEngagementScore');
          
          successCount++;
        } catch (userError) {
          console.error(`Error calculating score for user ${user.AuthUid}:`, userError);
          errorCount++;
        }
      }
      
      // Calculate global ranks
      try {
        await pool.request()
          .query(`
            WITH RankedUsers AS (
              SELECT 
                AuthUid,
                ROW_NUMBER() OVER (ORDER BY TotalEngagementScore DESC) AS GlobalRank
              FROM UserEngagementScore
              WHERE TotalEngagementScore > 0
            )
            UPDATE ues
            SET ues.GlobalRank = ru.GlobalRank
            FROM UserEngagementScore ues
            INNER JOIN RankedUsers ru ON ues.AuthUid = ru.AuthUid
          `);
        
        console.log('Global ranks updated');
      } catch (rankError) {
        console.error('Error updating global ranks:', rankError);
      }
      
      console.log(`Engagement score update complete: ${successCount} success, ${errorCount} errors`);
      
      if (errorCount > activeUsers.length * 0.1) {
        await sendAlert('warning', 'Engagement Score Update Errors', {
          totalUsers: activeUsers.length,
          successCount,
          errorCount,
          errorRate: (errorCount / activeUsers.length * 100).toFixed(2) + '%'
        });
      }
      
      return { success: true, successCount, errorCount };
      
    } catch (error) {
      console.error('Error in engagement score update:', error);
      await sendAlert('error', 'Engagement Score Update Failed', {
        error: error.message
      });
      throw error;
    }
  });

/**
 * Trending Content Detection
 * Runs every hour
 * Updates content stats and detects trending posts
 */
exports.detectTrendingContent = functions.pubsub
  .schedule('0 * * * *') // Every hour
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting trending content detection');
    
    const pool = getSqlPool();
    const now = new Date();
    const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    try {
      // Get recent timeline events
      const recentEventsResult = await pool.request()
        .query(`
          SELECT DISTINCT
            te.EventPublicId,
            te.ActorAuthUid,
            'TIMELINE_EVENT' AS ContentType
          FROM TimelineEvents te
          WHERE te.CreatedAt >= DATEADD(HOUR, -24, GETUTCDATE())
        `);
      
      const recentEvents = recentEventsResult.recordset;
      console.log(`Analyzing ${recentEvents.length} recent events for trending`);
      
      let successCount = 0;
      let errorCount = 0;
      let trendingCount = 0;
      
      // Update stats for each content piece
      for (const content of recentEvents) {
        try {
          const result = await pool.request()
            .input('ContentType', content.ContentType)
            .input('ContentPublicId', content.EventPublicId)
            .input('AuthorAuthUid', content.ActorAuthUid)
            .execute('sp_Analytics_UpdateContentStats');
          
          if (result.recordset[0]?.IsTrending) {
            trendingCount++;
          }
          
          successCount++;
        } catch (contentError) {
          console.error(`Error updating stats for content ${content.EventPublicId}:`, contentError);
          errorCount++;
        }
      }
      
      console.log(`Trending detection complete: ${successCount} analyzed, ${trendingCount} trending, ${errorCount} errors`);
      
      // Clean up old trending markers (older than 48 hours)
      try {
        await pool.request()
          .query(`
            UPDATE ContentDailyStats
            SET IsTrending = 0
            WHERE UpdatedAt < DATEADD(HOUR, -48, GETUTCDATE())
              AND IsTrending = 1
          `);
        console.log('Old trending markers cleaned up');
      } catch (cleanupError) {
        console.error('Error cleaning up old trending markers:', cleanupError);
      }
      
      return { 
        success: true, 
        successCount, 
        errorCount, 
        trendingCount 
      };
      
    } catch (error) {
      console.error('Error in trending content detection:', error);
      await sendAlert('error', 'Trending Detection Failed', {
        error: error.message
      });
      throw error;
    }
  });

/**
 * System Metrics Collection
 * Runs every hour
 * Collects system-wide metrics for monitoring
 */
exports.collectSystemMetrics = functions.pubsub
  .schedule('30 * * * *') // Every hour at :30
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting system metrics collection');
    
    const pool = getSqlPool();
    const now = new Date();
    const metricDate = now.toISOString();
    
    try {
      // Calculate DAU (users active today)
      const dauResult = await pool.request()
        .query(`
          SELECT COUNT(DISTINCT AuthUid) AS DAU
          FROM UserDailyStats
          WHERE StatDate = CAST(GETUTCDATE() AS DATE)
            AND IsActive = 1
        `);
      
      const dau = dauResult.recordset[0]?.DAU || 0;
      
      // Calculate MAU (users active in last 30 days)
      const mauResult = await pool.request()
        .query(`
          SELECT COUNT(DISTINCT AuthUid) AS MAU
          FROM UserDailyStats
          WHERE StatDate >= CAST(DATEADD(DAY, -30, GETUTCDATE()) AS DATE)
            AND IsActive = 1
        `);
      
      const mau = mauResult.recordset[0]?.MAU || 0;
      
      // Get message counts
      const messageStatsResult = await pool.request()
        .query(`
          SELECT 
            COUNT(*) AS NewMessages,
            COUNT(DISTINCT ConversationId) AS ActiveConversations
          FROM Messages
          WHERE CreatedAt >= DATEADD(HOUR, -1, GETUTCDATE())
        `);
      
      const messageStats = messageStatsResult.recordset[0];
      
      // Get timeline stats
      const timelineStatsResult = await pool.request()
        .query(`
          SELECT COUNT(*) AS NewTimelineEvents
          FROM TimelineEvents
          WHERE CreatedAt >= DATEADD(HOUR, -1, GETUTCDATE())
        `);
      
      const timelineStats = timelineStatsResult.recordset[0];
      
      // Get notification stats
      const notificationStatsResult = await pool.request()
        .query(`
          SELECT 
            COUNT(*) AS NewNotifications,
            SUM(CASE WHEN IsPushed = 1 THEN 1 ELSE 0 END) AS PushedNotifications,
            CASE 
              WHEN COUNT(*) > 0 
              THEN CAST(SUM(CASE WHEN IsPushed = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100
              ELSE 0 
            END AS PushSuccessRate
          FROM Notifications
          WHERE CreatedAt >= DATEADD(HOUR, -1, GETUTCDATE())
        `);
      
      const notificationStats = notificationStatsResult.recordset[0];
      
      // Insert system metrics
      await pool.request()
        .input('MetricType', 'SYSTEM_HEALTH')
        .input('MetricDate', metricDate)
        .input('IntervalType', 'HOURLY')
        .input('DAU', dau)
        .input('MAU', mau)
        .input('NewMessages', messageStats.NewMessages || 0)
        .input('ActiveConversations', messageStats.ActiveConversations || 0)
        .input('NewTimelineEvents', timelineStats.NewTimelineEvents || 0)
        .input('NewNotifications', notificationStats.NewNotifications || 0)
        .input('PushSuccessRate', notificationStats.PushSuccessRate || 0)
        .query(`
          INSERT INTO SystemMetrics (
            MetricType, MetricDate, IntervalType,
            DAU, MAU, NewMessages, ActiveConversations,
            NewTimelineEvents, NewNotifications, PushSuccessRate
          )
          VALUES (
            @MetricType, @MetricDate, @IntervalType,
            @DAU, @MAU, @NewMessages, @ActiveConversations,
            @NewTimelineEvents, @NewNotifications, @PushSuccessRate
          )
        `);
      
      console.log('System metrics collected:', {
        dau,
        mau,
        newMessages: messageStats.NewMessages,
        newTimelineEvents: timelineStats.NewTimelineEvents,
        newNotifications: notificationStats.NewNotifications,
        pushSuccessRate: notificationStats.PushSuccessRate?.toFixed(2) + '%'
      });
      
      return { success: true, dau, mau };
      
    } catch (error) {
      console.error('Error collecting system metrics:', error);
      await sendAlert('error', 'System Metrics Collection Failed', {
        error: error.message
      });
      throw error;
    }
  });

/**
 * Recommendation Cache Refresh
 * Runs every 6 hours
 * Regenerates cached recommendations for active users
 */
exports.refreshRecommendationCache = functions.pubsub
  .schedule('0 */6 * * *') // Every 6 hours
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting recommendation cache refresh');
    
    const pool = getSqlPool();
    
    try {
      // Get active users (active in last 7 days)
      const activeUsersResult = await pool.request()
        .query(`
          SELECT TOP 1000 AuthUid
          FROM UserEngagementScore
          WHERE LastActiveDate >= CAST(DATEADD(DAY, -7, GETUTCDATE()) AS DATE)
          ORDER BY TotalEngagementScore DESC
        `);
      
      const activeUsers = activeUsersResult.recordset;
      console.log(`Refreshing recommendations for ${activeUsers.length} users`);
      
      let successCount = 0;
      let errorCount = 0;
      
      // Generate follow suggestions for each user
      for (const user of activeUsers) {
        try {
          const suggestionsResult = await pool.request()
            .input('AuthUid', user.AuthUid)
            .input('Limit', 10)
            .execute('sp_Analytics_GetFollowSuggestions');
          
          const suggestions = suggestionsResult.recordset;
          
          if (suggestions.length > 0) {
            // Cache the recommendations
            const recommendationData = JSON.stringify(suggestions);
            const expiresAt = new Date(Date.now() + 6 * 60 * 60 * 1000); // 6 hours
            
            await pool.request()
              .input('AuthUid', user.AuthUid)
              .input('RecommendationType', 'FOLLOW_SUGGESTIONS')
              .input('RecommendationData', recommendationData)
              .input('RecommendationCount', suggestions.length)
              .input('ExpiresAt', expiresAt.toISOString())
              .query(`
                MERGE INTO RecommendationCache AS target
                USING (SELECT @AuthUid AS AuthUid, @RecommendationType AS RecommendationType) AS source
                ON target.AuthUid = source.AuthUid AND target.RecommendationType = source.RecommendationType
                WHEN MATCHED THEN
                  UPDATE SET
                    RecommendationData = @RecommendationData,
                    RecommendationCount = @RecommendationCount,
                    ExpiresAt = @ExpiresAt,
                    IsStale = 0,
                    UpdatedAt = GETUTCDATE()
                WHEN NOT MATCHED THEN
                  INSERT (AuthUid, RecommendationType, RecommendationData, RecommendationCount, ExpiresAt)
                  VALUES (@AuthUid, @RecommendationType, @RecommendationData, @RecommendationCount, @ExpiresAt);
              `);
            
            successCount++;
          }
        } catch (userError) {
          console.error(`Error generating recommendations for user ${user.AuthUid}:`, userError);
          errorCount++;
        }
      }
      
      // Mark expired caches as stale
      await pool.request()
        .query(`
          UPDATE RecommendationCache
          SET IsStale = 1
          WHERE ExpiresAt < GETUTCDATE()
            AND IsStale = 0
        `);
      
      console.log(`Recommendation cache refresh complete: ${successCount} success, ${errorCount} errors`);
      
      return { success: true, successCount, errorCount };
      
    } catch (error) {
      console.error('Error refreshing recommendation cache:', error);
      await sendAlert('error', 'Recommendation Cache Refresh Failed', {
        error: error.message
      });
      throw error;
    }
  });
