import 'package:equatable/equatable.dart';

import 'profile_activity.dart';
import 'profile_badge.dart';
import 'profile_connection.dart';
import 'profile_highlight.dart';
import 'profile_insight.dart';
import 'profile_opportunity.dart';
import 'profile_social_link.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.bio,
    required this.followers,
    required this.following,
    required this.totalSalesCg,
    required this.featuredProducts,
    required this.highlights,
    required this.recentActivities,
    required this.socialLinks,
    required this.badges,
    required this.insights,
    required this.opportunities,
    required this.connections,
  });

  final String id;
  final String displayName;
  final String handle;
  final String avatarUrl;
  final String bio;
  final int followers;
  final int following;
  final int totalSalesCg;
  final List<String> featuredProducts;
  final List<ProfileHighlight> highlights;
  final List<ProfileActivity> recentActivities;
  final List<ProfileSocialLink> socialLinks;
  final List<ProfileBadge> badges;
  final List<ProfileInsight> insights;
  final List<ProfileOpportunity> opportunities;
  final List<ProfileConnection> connections;

  @override
  List<Object?> get props => [
        id,
        displayName,
        handle,
        avatarUrl,
        bio,
        followers,
        following,
        totalSalesCg,
        featuredProducts,
        highlights,
        recentActivities,
        socialLinks,
        badges,
        insights,
        opportunities,
        connections,
      ];
}
