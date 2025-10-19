import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SponsorCampaign extends Equatable {
  const SponsorCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.ctaText,
    required this.startColor,
    required this.endColor,
    this.targetUrl,
  });

  final String id;
  final String title;
  final String description;
  final String ctaText;
  final Color startColor;
  final Color endColor;
  final String? targetUrl;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        ctaText,
        startColor,
        endColor,
        targetUrl,
      ];
}
