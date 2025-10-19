class FeedApiConfig {
  const FeedApiConfig({
    this.region = 'europe-west1',
    this.followingCollection = 'user_feeds',
    this.followingEntriesSubcollection = 'entries',
    this.followingOrderField = 'publishedAt',
    this.recommendedCallable = 'timelineGetUserFeed',
    this.recommendedCategory = 'timelineFeed',
    this.sponsorCollection = 'feed_sponsors',
    this.pageSize = 25,
    this.recommendedRefreshIntervalSeconds = 120,
  });

  final String region;
  final String followingCollection;
  final String followingEntriesSubcollection;
  final String followingOrderField;
  final String recommendedCallable;
  final String recommendedCategory;
  final String sponsorCollection;
  final int pageSize;
  final int recommendedRefreshIntervalSeconds;
}
