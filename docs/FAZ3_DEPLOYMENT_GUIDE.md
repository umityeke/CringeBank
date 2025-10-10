# Faz 3: Advanced Analytics - Deployment Guide

**Date:** 2025-10-09  
**Status:** Ready for Deployment  
**Dependencies:** Faz 2 (DM, Timeline, Notifications) must be deployed first

---

## Overview

Faz 3 introduces comprehensive analytics capabilities built on top of the SQL infrastructure from Faz 2:

### 3.1 Real-time Aggregations
- **UserDailyStats:** Daily user activity metrics for engagement tracking
- **ContentDailyStats:** Content trending detection and discovery
- **SystemMetrics:** System-wide health indicators and KPIs
- **UserEngagementScore:** Multi-component engagement scoring with tiers
- **RecommendationCache:** Fast recommendation retrieval

### 3.2 Stored Procedures (5 total)
- `sp_Analytics_AggregateUserDaily` - Daily user activity aggregation
- `sp_Analytics_GetDAU` - Daily/Weekly/Monthly active users calculation
- `sp_Analytics_UpdateContentStats` - Trending score calculation
- `sp_Analytics_GetTrendingContent` - Fetch trending content
- `sp_Analytics_CalculateEngagementScore` - Comprehensive engagement scoring (5 components)
- `sp_Analytics_GetFollowSuggestions` - Personalized follow recommendations

### 3.3 Scheduled Jobs (5 Cloud Functions)
- `aggregateUserDailyStats` - Daily at 2:00 AM UTC
- `updateEngagementScores` - Daily at 3:00 AM UTC
- `detectTrendingContent` - Hourly
- `collectSystemMetrics` - Hourly at :30
- `refreshRecommendationCache` - Every 6 hours

### 3.4 API Endpoints (6 Cloud Functions)
- `analyticsGetUserStats` - Comprehensive user statistics
- `analyticsGetTrendingContent` - Fetch trending posts/content
- `analyticsGetFollowRecommendations` - Personalized follow suggestions
- `analyticsGetSystemAnalytics` - System-wide metrics (admin)
- `analyticsGetUserLeaderboard` - Top users by engagement score
- `analyticsRefreshMyEngagementScore` - Manual score refresh (rate-limited)

---

## Deployment Sequence

### Phase 1: SQL Schema Deployment

**1. Deploy Analytics Tables**
```sql
-- Connect to Azure SQL Database
-- Run: backend/scripts/stored_procedures/create_analytics_tables.sql

-- This creates 5 tables:
-- - UserDailyStats (daily user activity)
-- - ContentDailyStats (trending content)
-- - SystemMetrics (system KPIs)
-- - UserEngagementScore (engagement scoring)
-- - RecommendationCache (cached recommendations)
```

**2. Deploy Stored Procedures**
```sql
-- Run each file in order:
sp_Analytics_AggregateUserDaily.sql
sp_Analytics_GetDAU.sql
sp_Analytics_UpdateContentStats.sql
sp_Analytics_GetTrendingContent.sql
sp_Analytics_CalculateEngagementScore.sql
sp_Analytics_GetFollowSuggestions.sql
```

**3. Validate SQL Deployment**
```sql
-- Verify tables created
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME LIKE '%Daily%' OR TABLE_NAME LIKE '%Engagement%' OR TABLE_NAME LIKE '%Recommendation%'
ORDER BY TABLE_NAME;

-- Expected: UserDailyStats, ContentDailyStats, SystemMetrics, UserEngagementScore, RecommendationCache

-- Verify stored procedures
SELECT ROUTINE_NAME 
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_TYPE = 'PROCEDURE' 
  AND ROUTINE_NAME LIKE 'sp_Analytics_%'
ORDER BY ROUTINE_NAME;

-- Expected: 6 procedures (AggregateUserDaily, GetDAU, UpdateContentStats, GetTrendingContent, CalculateEngagementScore, GetFollowSuggestions)

-- Verify indexes
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE t.name IN ('UserDailyStats', 'ContentDailyStats', 'SystemMetrics', 'UserEngagementScore', 'RecommendationCache')
ORDER BY t.name, i.name;

-- Expected: 20+ indexes across all analytics tables
```

---

### Phase 2: Cloud Functions Deployment

**1. Deploy Scheduled Jobs**
```bash
# Deploy all analytics scheduled jobs
firebase deploy --only functions:aggregateUserDailyStats,functions:updateEngagementScores,functions:detectTrendingContent,functions:collectSystemMetrics,functions:refreshRecommendationCache

# Verify deployment
firebase functions:list | grep -E "(aggregateUserDailyStats|updateEngagementScores|detectTrendingContent|collectSystemMetrics|refreshRecommendationCache)"
```

**2. Deploy API Endpoints**
```bash
# Deploy all analytics API endpoints
firebase deploy --only functions:analyticsGetUserStats,functions:analyticsGetTrendingContent,functions:analyticsGetFollowRecommendations,functions:analyticsGetSystemAnalytics,functions:analyticsGetUserLeaderboard,functions:analyticsRefreshMyEngagementScore

# Verify deployment
firebase functions:list | grep "analytics"
```

**3. Validate Cloud Functions**
```bash
# Check function logs
firebase functions:log --only aggregateUserDailyStats --limit 5
firebase functions:log --only detectTrendingContent --limit 5

# Expected: No errors, successful execution logs
```

---

### Phase 3: Initial Data Population

**1. Backfill User Daily Stats (Optional)**
```javascript
// Run script to backfill historical data
// This populates UserDailyStats for last 30 days

node functions/scripts/backfill_analytics.js --days=30 --batch-size=100

// Expected output:
// - Processing 30 days of historical data
// - Aggregating stats for active users
// - Success/error counts per day
```

**2. Initial Engagement Score Calculation**
```sql
-- Calculate engagement scores for all active users (last 30 days)
DECLARE @AuthUid NVARCHAR(128);
DECLARE user_cursor CURSOR FOR
    SELECT DISTINCT AuthUid
    FROM UserDailyStats
    WHERE StatDate >= CAST(DATEADD(DAY, -30, GETUTCDATE()) AS DATE)
        AND IsActive = 1;

OPEN user_cursor;
FETCH NEXT FROM user_cursor INTO @AuthUid;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC sp_Analytics_CalculateEngagementScore @AuthUid = @AuthUid;
    FETCH NEXT FROM user_cursor INTO @AuthUid;
END;

CLOSE user_cursor;
DEALLOCATE user_cursor;
```

**3. Verify Initial Population**
```sql
-- Check user stats
SELECT COUNT(*) AS TotalStats, 
       SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS ActiveDays
FROM UserDailyStats;

-- Check engagement scores
SELECT 
    ScoreTier,
    COUNT(*) AS UserCount,
    AVG(TotalEngagementScore) AS AvgScore
FROM UserEngagementScore
GROUP BY ScoreTier
ORDER BY 
    CASE ScoreTier
        WHEN 'ELITE' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        WHEN 'LOW' THEN 4
        ELSE 5
    END;
```

---

## Testing Checklist

### Analytics Data Collection

- [ ] **User Stats Aggregation**
  - Trigger manual aggregation: `EXEC sp_Analytics_AggregateUserDaily @AuthUid='<test-user>', @TargetDate='2025-10-09'`
  - Verify data in UserDailyStats table
  - Check engagement score calculation

- [ ] **DAU/MAU Metrics**
  - Query DAU: `EXEC sp_Analytics_GetDAU @StartDate='2025-10-01', @EndDate='2025-10-09', @IntervalType='DAILY'`
  - Verify daily active user counts
  - Check weekly/monthly aggregations

- [ ] **Trending Content Detection**
  - Trigger trending update: `EXEC sp_Analytics_UpdateContentStats @ContentType='TIMELINE_EVENT', @ContentPublicId='<event-id>', @AuthorAuthUid='<author-uid>'`
  - Query trending: `EXEC sp_Analytics_GetTrendingContent @Limit=10`
  - Verify trending scores and velocity metrics

- [ ] **Engagement Score Calculation**
  - Calculate score: `EXEC sp_Analytics_CalculateEngagementScore @AuthUid='<test-user>'`
  - Verify 5 score components (ContentCreation, Interaction, SocialGraph, Consistency, Quality)
  - Check tier assignment (ELITE, HIGH, MEDIUM, LOW, INACTIVE)
  - Verify score change tracking

### API Endpoints

- [ ] **Get User Stats**
  ```javascript
  const result = await firebase.functions().httpsCallable('analyticsGetUserStats')({
    authUid: '<user-uid>'
  });
  // Verify: engagementScore, dailyStats, contentStats returned
  ```

- [ ] **Get Trending Content**
  ```javascript
  const result = await firebase.functions().httpsCallable('analyticsGetTrendingContent')({
    limit: 20,
    minScore: 50
  });
  // Verify: trending array with scores, velocity, engagement metrics
  ```

- [ ] **Get Follow Recommendations**
  ```javascript
  const result = await firebase.functions().httpsCallable('analyticsGetFollowRecommendations')({
    limit: 10,
    useCache: true
  });
  // Verify: recommendations array with scores, reasons
  ```

- [ ] **Refresh Engagement Score**
  ```javascript
  const result = await firebase.functions().httpsCallable('analyticsRefreshMyEngagementScore')();
  // Verify: updated score, tier, components, activity metrics
  // Test rate limit: Should fail if called twice within 1 hour
  ```

- [ ] **Get Leaderboard**
  ```javascript
  const result = await firebase.functions().httpsCallable('analyticsGetUserLeaderboard')({
    tier: 'ELITE',
    limit: 50
  });
  // Verify: leaderboard array sorted by rank
  ```

### Scheduled Jobs

- [ ] **Daily Stats Aggregation** (Manual trigger for testing)
  - Check Cloud Scheduler: Next run time
  - Monitor logs: `firebase functions:log --only aggregateUserDailyStats`
  - Expected: Aggregates previous day's activity for all active users

- [ ] **Engagement Score Update** (Manual trigger for testing)
  - Check Cloud Scheduler: Next run time
  - Monitor logs: `firebase functions:log --only updateEngagementScores`
  - Expected: Recalculates scores for active users, updates global ranks

- [ ] **Trending Detection** (Runs hourly)
  - Monitor logs: `firebase functions:log --only detectTrendingContent`
  - Expected: Updates trending scores, marks/unmarks trending content

- [ ] **System Metrics Collection** (Runs hourly)
  - Monitor logs: `firebase functions:log --only collectSystemMetrics`
  - Expected: Inserts DAU, MAU, message counts, notification stats

- [ ] **Recommendation Cache Refresh** (Runs every 6 hours)
  - Monitor logs: `firebase functions:log --only refreshRecommendationCache`
  - Expected: Generates follow suggestions for top 1000 active users

---

## Monitoring & Alerts

### Key Metrics to Monitor

**1. Analytics Data Quality**
```sql
-- Check aggregation completeness (should match active users)
SELECT 
    StatDate,
    COUNT(DISTINCT AuthUid) AS UsersWithStats,
    SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS ActiveUsers
FROM UserDailyStats
WHERE StatDate >= CAST(DATEADD(DAY, -7, GETUTCDATE()) AS DATE)
GROUP BY StatDate
ORDER BY StatDate DESC;

-- Check engagement score freshness
SELECT 
    COUNT(*) AS TotalScores,
    COUNT(CASE WHEN CalculatedAt >= DATEADD(HOUR, -25, GETUTCDATE()) THEN 1 END) AS Fresh24h,
    AVG(TotalEngagementScore) AS AvgScore
FROM UserEngagementScore;

-- Check recommendation cache status
SELECT 
    RecommendationType,
    COUNT(*) AS CachedUsers,
    AVG(RecommendationCount) AS AvgRecommendations,
    COUNT(CASE WHEN IsStale = 1 THEN 1 END) AS StaleCount
FROM RecommendationCache
GROUP BY RecommendationType;
```

**2. Scheduled Job Health**
```sql
-- Check system metrics collection (should run hourly)
SELECT TOP 24
    MetricDate,
    DAU,
    MAU,
    NewMessages,
    NewTimelineEvents,
    PushSuccessRate
FROM SystemMetrics
WHERE MetricType = 'SYSTEM_HEALTH'
    AND IntervalType = 'HOURLY'
ORDER BY MetricDate DESC;

-- Expected: 24 rows (last 24 hours), no gaps
```

**3. Performance Metrics**
- Average API response time: Target <500ms for cached, <2s for fresh
- Scheduled job execution time: Target <5 minutes for daily jobs, <1 minute for hourly
- SQL query performance: Target <100ms for most analytics queries
- Cache hit rate: Target >80% for recommendations

### Alert Thresholds

**CRITICAL Alerts:**
- Scheduled job failures: >2 consecutive failures
- Analytics data gap: Missing daily stats for >10% of active users
- Engagement score staleness: >30% scores older than 48 hours
- API error rate: >5% errors in last hour

**WARNING Alerts:**
- Trending detection: No trending content detected for >12 hours
- Recommendation cache: >20% stale entries
- System metrics: Missing hourly metrics collection
- Performance degradation: API response time >2s P95

---

## Rollback Procedures

### If Analytics Queries Are Too Slow

**Option 1: Disable Scheduled Jobs Temporarily**
```bash
# Comment out scheduled job exports in index.js
# Then deploy
firebase deploy --only functions

# Re-enable after performance tuning
```

**Option 2: Increase SQL Compute Tier**
```bash
# Scale up Azure SQL Database
az sql db update --resource-group <rg> --server <server> --name <db> --service-objective S2
```

**Option 3: Add Missing Indexes**
```sql
-- If specific queries are slow, add targeted indexes
CREATE NONCLUSTERED INDEX IX_UserDailyStats_AuthUid_Date 
ON UserDailyStats(AuthUid, StatDate DESC)
INCLUDE (EngagementScore, IsActive);
```

### If API Endpoints Have High Error Rates

**Rollback Cloud Functions:**
```bash
# Redeploy previous version
firebase functions:log --only analyticsGetUserStats --limit 100
# Identify issue, then rollback

# Comment out analytics exports in index.js
# Deploy to remove analytics functions
firebase deploy --only functions
```

### If Data Integrity Issues

**Clear and Rebuild Analytics Data:**
```sql
-- CAUTION: This deletes all analytics data
-- Use only if data corruption detected

-- Clear tables
TRUNCATE TABLE UserDailyStats;
TRUNCATE TABLE ContentDailyStats;
TRUNCATE TABLE SystemMetrics;
TRUNCATE TABLE RecommendationCache;
DELETE FROM UserEngagementScore; -- Cannot TRUNCATE due to FK

-- Rebuild from scratch
-- Run backfill script again
node functions/scripts/backfill_analytics.js --days=30 --batch-size=100
```

---

## Post-Deployment Validation

### 24-Hour Checklist

- [ ] Check scheduled job execution logs (all 5 jobs should have run)
- [ ] Verify UserDailyStats populated for yesterday
- [ ] Verify engagement scores updated for active users
- [ ] Verify trending content detected (if applicable)
- [ ] Verify system metrics collected (24 hourly entries)
- [ ] Check API endpoint response times (all <2s)
- [ ] Monitor error rates (should be <1%)
- [ ] Review alert logs (should be minimal)

### 7-Day Checklist

- [ ] Full analytics data audit (compare SQL vs expected Firestore activity)
- [ ] Performance benchmark (compare query times vs baseline)
- [ ] Cost analysis (SQL compute usage, Cloud Functions invocations)
- [ ] User engagement tier distribution (verify tier assignment logic)
- [ ] Recommendation quality review (sample 100 users, check relevance)
- [ ] Leaderboard accuracy (verify ranking algorithm)
- [ ] Cache hit rate analysis (should be >80%)
- [ ] Feature flag test (disable analytics, verify no impact on core features)

---

## Expected Impact

### Performance Improvements
- **User Stats Queries:** 90% faster (SQL pre-aggregated vs on-demand Firestore)
- **Trending Content:** Real-time detection (was manual/delayed)
- **Follow Suggestions:** <100ms cached (was >2s computed)
- **Leaderboard:** <200ms pre-ranked (was N/A)

### Cost Implications
- **SQL Compute:** +10-15% (hourly/daily aggregations)
- **Cloud Functions:** +20-30% invocations (scheduled jobs + new endpoints)
- **Firestore Reads:** -5-10% (analytics queries moved to SQL)
- **Overall:** Net +15-20% infrastructure cost for significant analytics capability

### Reliability
- **Data Consistency:** 99.9% (dual-write validation)
- **API Availability:** 99.95% (cached recommendations)
- **Scheduled Job Success Rate:** >99% (with retry logic)

---

## Next Steps

After successful Faz 3 deployment:

### Faz 4: Search & Discovery
- Full-text search on messages, posts, user profiles
- Advanced filters (date ranges, content type, engagement thresholds)
- Hashtag and mention indexing
- Search analytics and autocomplete

### Faz 5: Production Hardening
- Multi-region SQL replication
- Advanced caching (Redis)
- Rate limiting per user
- DDoS protection
- Comprehensive monitoring dashboards

---

## Support & Troubleshooting

### Common Issues

**Issue:** Scheduled jobs not running  
**Solution:** Check Cloud Scheduler status, verify timezone configuration, check quota limits

**Issue:** Engagement scores all zero  
**Solution:** Verify UserDailyStats populated, check last 30 days activity, run manual score calculation

**Issue:** No trending content detected  
**Solution:** Lower trending threshold (currently 100 score), verify content exists, check velocity calculation

**Issue:** Recommendations empty  
**Solution:** Verify users have activity, check mutual connections logic, run manual SP call for debugging

**Issue:** High SQL CPU usage  
**Solution:** Review slow queries, add missing indexes, consider scaling up compute tier

---

**Deployment prepared by:** CringeBank Analytics Team  
**Review required by:** Backend Lead, DevOps  
**Approved for deployment:** ✅ Staging | ⏳ Production (Pending 7-day staging validation)
