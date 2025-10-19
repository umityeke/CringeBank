import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class FeedEntry extends Equatable {
  const FeedEntry({
    required this.id,
    required this.author,
    required this.title,
    required this.excerpt,
    required this.relativeTime,
    required this.tag,
    required this.likeCount,
    required this.commentCount,
    required this.accentColor,
    this.avatarUrl,
    this.mediaUrl,
    this.publishedAt,
    this.baseScore,
    this.affinityScore,
    this.freshnessScore,
    this.diversityWeight,
    this.computedScore,
    this.rankingReasons = const <String>[],
    this.rankingStrategy,
  });

  final String id;
  final String author;
  final String title;
  final String excerpt;
  final String relativeTime;
  final String tag;
  final int likeCount;
  final int commentCount;
  final Color accentColor;
  final String? avatarUrl;
  final String? mediaUrl;
  final DateTime? publishedAt;
  final double? baseScore;
  final double? affinityScore;
  final double? freshnessScore;
  final double? diversityWeight;
  final double? computedScore;
  final List<String> rankingReasons;
  final String? rankingStrategy;

  String get authorInitials {
    final sanitized = author.trim();
    if (sanitized.isEmpty) {
      return '?';
    }
    final parts = sanitized.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return sanitized[0].toUpperCase();
  }

  FeedEntry copyWith({
    String? id,
    String? author,
    String? title,
    String? excerpt,
    String? relativeTime,
    String? tag,
    int? likeCount,
    int? commentCount,
    Color? accentColor,
    String? avatarUrl,
    String? mediaUrl,
    DateTime? publishedAt,
    double? baseScore,
    double? affinityScore,
    double? freshnessScore,
    double? diversityWeight,
    double? computedScore,
    List<String>? rankingReasons,
    String? rankingStrategy,
  }) {
    return FeedEntry(
      id: id ?? this.id,
      author: author ?? this.author,
      title: title ?? this.title,
      excerpt: excerpt ?? this.excerpt,
      relativeTime: relativeTime ?? this.relativeTime,
      tag: tag ?? this.tag,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      accentColor: accentColor ?? this.accentColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      baseScore: baseScore ?? this.baseScore,
      affinityScore: affinityScore ?? this.affinityScore,
      freshnessScore: freshnessScore ?? this.freshnessScore,
      diversityWeight: diversityWeight ?? this.diversityWeight,
      computedScore: computedScore ?? this.computedScore,
      rankingReasons: rankingReasons ?? this.rankingReasons,
      rankingStrategy: rankingStrategy ?? this.rankingStrategy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        author,
        title,
        excerpt,
        relativeTime,
        tag,
        likeCount,
        commentCount,
        accentColor,
        avatarUrl,
        mediaUrl,
        publishedAt,
        baseScore,
        affinityScore,
        freshnessScore,
        diversityWeight,
        computedScore,
        rankingReasons,
        rankingStrategy,
      ];
}
