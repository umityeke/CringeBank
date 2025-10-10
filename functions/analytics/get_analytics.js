/**
 * Analytics API Endpoints
 * 
 * Client-callable functions for fetching analytics data,
 * user stats, trending content, and recommendations
 */

const functions = require('firebase-functions');
const { getSqlPool } = require('../utils/sql');

/**
 * Get User Stats
 * Returns comprehensive stats for a user
 */
exports.getUserStats = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const viewerAuthUid = context.auth.uid;
  const targetAuthUid = data.authUid || viewerAuthUid;
  
  const pool = getSqlPool();
  
  try {
    // Get engagement score
    const scoreResult = await pool.request()
      .input('AuthUid', targetAuthUid)
      .query(`
        SELECT 
          TotalEngagementScore,
          ScoreTier,
          ContentCreationScore,
          InteractionScore,
          SocialGraphScore,
          ConsistencyScore,
          QualityScore,
          DaysActiveLast30,
          ConsecutiveActiveDays,
          LongestStreak,
          LastActiveDate,
          GlobalRank,
          ScoreChange,
          CalculatedAt
        FROM UserEngagementScore
        WHERE AuthUid = @AuthUid
      `);
    
    // Get recent daily stats (last 30 days)
    const dailyStatsResult = await pool.request()
      .input('AuthUid', targetAuthUid)
      .query(`
        SELECT TOP 30
          StatDate,
          PostsCreated,
          MessagesSent,
          MessagesReceived,
          TimelineEventsCreated,
          TimelineEventsViewed,
          NotificationsRead,
          EngagementScore,
          IsActive
        FROM UserDailyStats
        WHERE AuthUid = @AuthUid
        ORDER BY StatDate DESC
      `);
    
    // Get content stats (trending posts)
    const contentStatsResult = await pool.request()
      .input('AuthUid', targetAuthUid)
      .query(`
        SELECT 
          ContentPublicId,
          ContentType,
          TrendingScore,
          ViewCount,
          LikeCount,
          CommentCount,
          ShareCount,
          IsTrending,
          StatDate
        FROM ContentDailyStats
        WHERE AuthorAuthUid = @AuthUid
          AND StatDate >= CAST(DATEADD(DAY, -30, GETUTCDATE()) AS DATE)
        ORDER BY TrendingScore DESC
      `);
    
    return {
      success: true,
      authUid: targetAuthUid,
      engagementScore: scoreResult.recordset[0] || null,
      dailyStats: dailyStatsResult.recordset,
      contentStats: contentStatsResult.recordset
    };
    
  } catch (error) {
    console.error('Error fetching user stats:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch user stats',
      { error: error.message }
    );
  }
});

/**
 * Get Trending Content
 * Returns currently trending posts/content
 */
exports.getTrendingContent = functions.https.onCall(async (data, context) => {
  const { 
    contentType = null,
    limit = 20,
    minScore = 50 
  } = data;
  
  const pool = getSqlPool();
  
  try {
    const result = await pool.request()
      .input('ContentType', contentType)
      .input('Limit', Math.min(limit, 100))
      .input('MinTrendingScore', minScore)
      .input('TimeWindowHours', 24)
      .execute('sp_Analytics_GetTrendingContent');
    
    const trendingContent = result.recordset.map(item => ({
      contentPublicId: item.ContentPublicId,
      contentType: item.ContentType,
      authorAuthUid: item.AuthorAuthUid,
      viewCount: item.ViewCount,
      uniqueViewers: item.UniqueViewers,
      likeCount: item.LikeCount,
      commentCount: item.CommentCount,
      shareCount: item.ShareCount,
      engagementVelocity: item.EngagementVelocity,
      trendingScore: item.TrendingScore,
      updatedAt: item.UpdatedAt
    }));
    
    return {
      success: true,
      trending: trendingContent,
      count: trendingContent.length
    };
    
  } catch (error) {
    console.error('Error fetching trending content:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch trending content',
      { error: error.message }
    );
  }
});

/**
 * Get Follow Recommendations
 * Returns personalized follow suggestions
 */
exports.getFollowRecommendations = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const authUid = context.auth.uid;
  const { limit = 10, useCache = true } = data;
  
  const pool = getSqlPool();
  
  try {
    // Try to get from cache first
    if (useCache) {
      const cacheResult = await pool.request()
        .input('AuthUid', authUid)
        .input('RecommendationType', 'FOLLOW_SUGGESTIONS')
        .query(`
          SELECT 
            RecommendationData,
            RecommendationCount,
            ExpiresAt,
            UpdatedAt
          FROM RecommendationCache
          WHERE AuthUid = @AuthUid
            AND RecommendationType = @RecommendationType
            AND IsStale = 0
            AND ExpiresAt > GETUTCDATE()
        `);
      
      if (cacheResult.recordset.length > 0) {
        const cached = cacheResult.recordset[0];
        const recommendations = JSON.parse(cached.RecommendationData);
        
        return {
          success: true,
          recommendations: recommendations.slice(0, limit),
          count: recommendations.length,
          source: 'cache',
          cachedAt: cached.UpdatedAt
        };
      }
    }
    
    // Generate fresh recommendations
    const result = await pool.request()
      .input('AuthUid', authUid)
      .input('Limit', Math.min(limit, 50))
      .execute('sp_Analytics_GetFollowSuggestions');
    
    const recommendations = result.recordset.map(item => ({
      authUid: item.AuthUid,
      totalScore: item.TotalScore,
      engagementScore: item.EngagementScore,
      mutualConnections: item.MutualConnections,
      recommendationReasons: item.RecommendationReasons,
      reasonCount: item.ReasonCount
    }));
    
    return {
      success: true,
      recommendations,
      count: recommendations.length,
      source: 'fresh'
    };
    
  } catch (error) {
    console.error('Error fetching follow recommendations:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch recommendations',
      { error: error.message }
    );
  }
});

/**
 * Get System Analytics
 * Returns system-wide metrics (admin only)
 */
exports.getSystemAnalytics = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  // TODO: Add admin role check
  // if (!context.auth.token.admin) {
  //   throw new functions.https.HttpsError(
  //     'permission-denied',
  //     'User must be admin'
  //   );
  // }
  
  const { 
    startDate = null,
    endDate = null,
    intervalType = 'DAILY'
  } = data;
  
  const pool = getSqlPool();
  
  try {
    // Get DAU/MAU metrics
    const dauResult = await pool.request()
      .input('StartDate', startDate)
      .input('EndDate', endDate)
      .input('IntervalType', intervalType)
      .execute('sp_Analytics_GetDAU');
    
    // Get system metrics
    const metricsResult = await pool.request()
      .query(`
        SELECT TOP 100
          MetricDate,
          IntervalType,
          DAU,
          MAU,
          NewMessages,
          ActiveConversations,
          NewTimelineEvents,
          NewNotifications,
          PushSuccessRate,
          AvgEngagementRate
        FROM SystemMetrics
        WHERE MetricType = 'SYSTEM_HEALTH'
          AND IntervalType = @IntervalType
        ORDER BY MetricDate DESC
      `, { IntervalType: intervalType });
    
    return {
      success: true,
      dauMetrics: dauResult.recordset,
      systemMetrics: metricsResult.recordset
    };
    
  } catch (error) {
    console.error('Error fetching system analytics:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch system analytics',
      { error: error.message }
    );
  }
});

/**
 * Get User Leaderboard
 * Returns top users by engagement score
 */
exports.getUserLeaderboard = functions.https.onCall(async (data, context) => {
  const { 
    tier = null, // Filter by tier: ELITE, HIGH, MEDIUM, LOW
    limit = 50 
  } = data;
  
  const pool = getSqlPool();
  
  try {
    const result = await pool.request()
      .input('Tier', tier)
      .input('Limit', Math.min(limit, 100))
      .query(`
        SELECT TOP (@Limit)
          AuthUid,
          TotalEngagementScore,
          ScoreTier,
          GlobalRank,
          DaysActiveLast30,
          ConsecutiveActiveDays,
          LongestStreak,
          TrendingPostsCount,
          CalculatedAt
        FROM UserEngagementScore
        WHERE (@Tier IS NULL OR ScoreTier = @Tier)
          AND TotalEngagementScore > 0
        ORDER BY GlobalRank ASC
      `);
    
    const leaderboard = result.recordset.map(item => ({
      authUid: item.AuthUid,
      engagementScore: item.TotalEngagementScore,
      tier: item.ScoreTier,
      rank: item.GlobalRank,
      daysActive: item.DaysActiveLast30,
      currentStreak: item.ConsecutiveActiveDays,
      longestStreak: item.LongestStreak,
      trendingPosts: item.TrendingPostsCount
    }));
    
    return {
      success: true,
      leaderboard,
      count: leaderboard.length,
      tier: tier || 'ALL'
    };
    
  } catch (error) {
    console.error('Error fetching leaderboard:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch leaderboard',
      { error: error.message }
    );
  }
});

/**
 * Trigger Manual Engagement Score Calculation
 * Allows users to manually refresh their engagement score
 */
exports.refreshMyEngagementScore = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const authUid = context.auth.uid;
  const pool = getSqlPool();
  
  try {
    // Check last calculation time (prevent abuse)
    const lastCalcResult = await pool.request()
      .input('AuthUid', authUid)
      .query(`
        SELECT CalculatedAt
        FROM UserEngagementScore
        WHERE AuthUid = @AuthUid
      `);
    
    if (lastCalcResult.recordset.length > 0) {
      const lastCalc = new Date(lastCalcResult.recordset[0].CalculatedAt);
      const hoursSinceLastCalc = (Date.now() - lastCalc.getTime()) / (1000 * 60 * 60);
      
      if (hoursSinceLastCalc < 1) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Engagement score can only be refreshed once per hour'
        );
      }
    }
    
    // Calculate engagement score
    const result = await pool.request()
      .input('AuthUid', authUid)
      .execute('sp_Analytics_CalculateEngagementScore');
    
    const scoreData = result.recordset[0];
    
    return {
      success: true,
      engagementScore: scoreData.TotalEngagementScore,
      tier: scoreData.ScoreTier,
      scoreChange: scoreData.ScoreChange,
      components: {
        contentCreation: scoreData.ContentCreationScore,
        interaction: scoreData.InteractionScore,
        socialGraph: scoreData.SocialGraphScore,
        consistency: scoreData.ConsistencyScore,
        quality: scoreData.QualityScore
      },
      activity: {
        daysActive: scoreData.DaysActiveLast30,
        currentStreak: scoreData.ConsecutiveActiveDays
      }
    };
    
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    console.error('Error refreshing engagement score:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to refresh engagement score',
      { error: error.message }
    );
  }
});
