import '../../domain/models/profile_activity.dart';
import '../../domain/models/profile_badge.dart';
import '../../domain/models/profile_connection.dart';
import '../../domain/models/profile_highlight.dart';
import '../../domain/models/profile_insight.dart';
import '../../domain/models/profile_opportunity.dart';
import '../../domain/models/profile_social_link.dart';
import '../../domain/models/user_profile.dart';

class MockProfileSource {
  Stream<UserProfile> watchProfile() {
    const avatar =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAQAAACB4RwKAAAADElEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==';

    return Stream.value(
      UserProfile(
        id: 'user-001',
        displayName: 'Ümit Yeke',
        handle: '@umit',
        avatarUrl: avatar,
        bio: 'Cringe üreticisi, yarışma bağımlısı, CG ekonomisi kurucusu.',
        followers: 17850,
        following: 312,
        totalSalesCg: 482300,
  featuredProducts: ['Ultra Cringe Hoodie', 'Awkward Mug 2.0', 'Virality Toolkit'],
        highlights: const [
          ProfileHighlight(
            id: 'hl-001',
            title: 'Best of Cringe Week',
            description: 'Haftalık vitrinin 1. sırasında 3 hafta üst üste.',
            type: ProfileHighlightType.trophy,
          ),
          ProfileHighlight(
            id: 'hl-002',
            title: 'Rekor Satış',
            description: '24 saatte 12.5k CG satış hacmi.',
            type: ProfileHighlightType.trending,
          ),
          ProfileHighlight(
            id: 'hl-003',
            title: 'Instant Viral',
            description: 'Yeni cringe formatı 90 dk içinde 8k paylaşım aldı.',
            type: ProfileHighlightType.lightning,
          ),
        ],
  recentActivities: [
          ProfileActivity(
            id: 'act-001',
            title: 'Yeni Cringe Formatı Yayında',
            subtitle: '"Metrobüste Şiir Okuyanlar" teması anında trend oldu.',
            timestamp: DateTime(2025, 10, 10, 22, 15),
            type: ProfileActivityType.post,
          ),
          ProfileActivity(
            id: 'act-002',
            title: '10k CG Satış Rekoru',
            subtitle: 'Awkward Mug 2.0 stokları 45 dakikada tükendi.',
            timestamp: DateTime(2025, 10, 10, 18, 0),
            type: ProfileActivityType.sale,
          ),
          ProfileActivity(
            id: 'act-003',
            title: 'Topluluk Rozeti Kazanıldı',
            subtitle: 'Cringe Haftası mentorluğu tamamlandı.',
            timestamp: DateTime(2025, 10, 9, 21, 30),
            type: ProfileActivityType.badge,
          ),
        ],
        socialLinks: const [
          ProfileSocialLink(
            id: 'link-tt',
            label: '@umit_cringe',
            url: 'https://www.tiktok.com/@umit_cringe',
            platform: ProfileSocialPlatform.tiktok,
          ),
          ProfileSocialLink(
            id: 'link-yt',
            label: 'CringeBank Kanalı',
            url: 'https://www.youtube.com/@cringebank',
            platform: ProfileSocialPlatform.youtube,
          ),
          ProfileSocialLink(
            id: 'link-web',
            label: 'Portfolyo',
            url: 'https://umitcringe.dev',
            platform: ProfileSocialPlatform.website,
          ),
        ],
        badges: const [
          ProfileBadge(
            id: 'badge-mentor',
            name: 'Mentor',
            description: 'Yeni cringe üreticilerine haftada 3 oturum mentorluk sağlar.',
            icon: 'mentor',
          ),
          ProfileBadge(
            id: 'badge-hustler',
            name: 'CG Hustler',
            description: 'Bir ay içinde 100k CG satış barajını aşar.',
            icon: 'hustler',
          ),
          ProfileBadge(
            id: 'badge-community',
            name: 'Topluluk Elçisi',
            description: 'Cringe topluluk etkinliklerinde 5+ sunum yapar.',
            icon: 'community',
          ),
        ],
        insights: const [
          ProfileInsight(
            id: 'insight-views',
            label: 'Profil görüntüleme',
            value: '48.2k',
            changePercent: 12.4,
            trend: ProfileInsightTrend.up,
          ),
          ProfileInsight(
            id: 'insight-conv',
            label: 'Dönüşüm oranı',
            value: '7.8%',
            changePercent: -1.2,
            trend: ProfileInsightTrend.down,
          ),
          ProfileInsight(
            id: 'insight-watch',
            label: 'Ortalama izlenme',
            value: '3 dk 12 sn',
            changePercent: 0.0,
            trend: ProfileInsightTrend.stable,
          ),
        ],
        opportunities: [
          ProfileOpportunity(
            id: 'opp-001',
            title: 'CG Hackathon Mentoru',
            description: 'Geçen yılki kazanan ekiplerle deneyim paylaş, canlı yayında mentorluk yap.',
            status: ProfileOpportunityStatus.open,
            deadline: DateTime(2025, 10, 20),
          ),
          ProfileOpportunity(
            id: 'opp-002',
            title: 'CringeFest Sahnesi',
            description: 'Kapanışta sahne al ve yeni formatını 4k katılımcıya tanıt.',
            status: ProfileOpportunityStatus.closingSoon,
            deadline: DateTime(2025, 10, 14),
          ),
          ProfileOpportunity(
            id: 'opp-003',
            title: 'Markalı İş Birliği - Awkward Energy Drink',
            description: 'İçerik serisi için başvuru toplanıyor, seçilenler gelir paylaşımı alacak.',
            status: ProfileOpportunityStatus.waitlist,
            deadline: DateTime(2025, 11, 1),
          ),
        ],
        connections: const [
          ProfileConnection(
            id: 'conn-001',
            displayName: 'Nisa T.',
            handle: '@nisawkward',
            avatarUrl:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAQAAACB4RwKAAAADElEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
            relation: 'CringeFest 24 finalist arkadaşı',
          ),
          ProfileConnection(
            id: 'conn-002',
            displayName: 'Kerem S.',
            handle: '@keremloop',
            avatarUrl:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAQAAACB4RwKAAAADElEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
            relation: 'CG Hackathon takım arkadaşı',
          ),
          ProfileConnection(
            id: 'conn-003',
            displayName: 'Lina V.',
            handle: '@linavirals',
            avatarUrl:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAQAAACB4RwKAAAADElEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
            relation: 'Markalı iş birliği ortağı',
          ),
        ],
      ),
    );
  }
}
