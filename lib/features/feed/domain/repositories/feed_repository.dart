import '../models/feed_entry.dart';
import '../models/feed_segment.dart';
import '../models/sponsor_campaign.dart';

abstract class FeedRepository {
  Stream<List<FeedEntry>> watchEntries({
    required FeedSegment segment,
    required String userId,
  });

  Stream<List<SponsorCampaign>> watchSponsorCampaigns({
    required String userId,
  });

  Future<void> refreshRecommended({
    required String userId,
  });
}
