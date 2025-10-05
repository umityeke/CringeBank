import 'package:flutter/material.dart';

// Content Moderation Status
enum ModerationStatus {
  pending('pending', 'Moderasyon Bekliyor', Colors.orange),
  approved('approved', 'Onaylandı', Colors.green),
  rejected('rejected', 'Reddedildi', Colors.red),
  blocked('blocked', 'Engellendi', Colors.grey);

  const ModerationStatus(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  static ModerationStatus fromString(String? value) {
    return ModerationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ModerationStatus.pending,
    );
  }
}

// Post Type (5 types from security contract)
enum PostType {
  spill('spill', 'Spill', 'Metin odaklı paylaşım', Icons.article, 1, 2000, 0, 1),
  clap('clap', 'Clap', 'Kısa vurucu metin', Icons.flash_on, 1, 140, 0, 1),
  frame('frame', 'Frame', 'Görsel paylaşım', Icons.image, 0, 1000, 1, 20),
  cringecast('cringecast', 'CringeCast', 'Video paylaşım', Icons.video_library, 0, 1000, 1, 1),
  mash('mash', 'Mash', 'Karışık medya', Icons.collections, 0, 2000, 1, 5);

  const PostType(
    this.value,
    this.label,
    this.description,
    this.icon,
    this.minTextLength,
    this.maxTextLength,
    this.minMedia,
    this.maxMedia,
  );

  final String value;
  final String label;
  final String description;
  final IconData icon;
  final int minTextLength;
  final int maxTextLength;
  final int minMedia;
  final int maxMedia;

  bool get requiresText => minTextLength > 0;
  bool get requiresMedia => minMedia > 0;

  static PostType fromString(String? value) {
    return PostType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => PostType.spill,
    );
  }
}

enum CringeCategory {
  fizikselRezillik(
    'Fiziksel Rezillik',
    Icons.face_retouching_off,
    Color(0xFFE74C3C),
    '😵',
    'Fiziksel Rezillik',
  ),
  sosyalRezillik(
    'Sosyal Rezillik',
    Icons.people_outline,
    Color(0xFF9B59B6),
    '😳',
    'Sosyal Rezillik',
  ),
  askAcisiKrepligi(
    'Aşk Acısı Krepligi',
    Icons.favorite_border,
    Color(0xFFE91E63),
    '💔',
    'Aşk Acısı',
  ),
  sosyalMedyaIntihari(
    'Sosyal Medya İntiharı',
    Icons.phone_android,
    Color(0xFF3498DB),
    '📱',
    'Sosyal Medya',
  ),
  aileselRezaletler(
    'Ailesel Rezaletler',
    Icons.home,
    Color(0xFFF39C12),
    '🏠',
    'Ailesel',
  ),
  okullDersDramlari(
    'Okul/Ders Dramları',
    Icons.school,
    Color(0xFF27AE60),
    '🏫',
    'Okul/Ders',
  ),
  aileSofrasiFelaketi(
    'Aile Sofrası Felaketi',
    Icons.restaurant,
    Color(0xFFFF6347),
    '🍽️',
    'Aile Sofrası',
  ),
  isGorusmesiKatliam(
    'İş Görüşmesi Katliamı',
    Icons.work,
    Color(0xFF4682B4),
    '💼',
    'İş Görüşmesi',
  ),
  sarhosPismanliklari(
    'Sarhoş Pişmanlıkları',
    Icons.local_bar,
    Color(0xFFDA70D6),
    '🍻',
    'Sarhoş Halleri',
  );

  const CringeCategory(
    this.label,
    this.icon,
    this.color,
    this.emoji,
    this.displayName,
  );
  final String label;
  final IconData icon;
  final Color color;
  final String emoji;
  final String displayName;
}

class CringeEntry {
  final String id;
  final String userId; // ownerId in Firestore rules
  final String baslik;
  final String aciklama;
  final CringeCategory kategori;
  final double krepSeviyesi;
  final DateTime createdAt;
  final List<String> etiketler;
  final bool isAnonim;
  final int begeniSayisi;
  final int yorumSayisi;
  final String? audioUrl;
  final String? videoUrl;
  final double? borsaDegeri; // Premium kullanıcılar için borsa değeri

  // Twitter-style eklenen alanlar
  final List<String> imageUrls; // Çoklu resim desteği (media paths)
  final int retweetSayisi;
  final String authorName; // Görünür isim
  final String authorHandle; // @username
  final String? authorAvatarUrl; // Profil resmi URL'i

  // === SECURITY CONTRACT FIELDS ===
  final PostType type; // spill, clap, frame, cringecast, mash
  final ModerationStatus status; // pending, approved, rejected, blocked
  final DateTime? updatedAt; // Son güncelleme zamanı
  final Map<String, dynamic>? moderation; // Moderasyon notları (only mods can write)
  final List<String> media; // Storage paths: user_uploads/{ownerId}/{postId}/filename

  const CringeEntry({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.authorHandle,
    required this.baslik,
    required this.aciklama,
    required this.kategori,
    required this.krepSeviyesi,
    required this.createdAt,
    this.etiketler = const [],
    this.isAnonim = false,
    this.begeniSayisi = 0,
    this.yorumSayisi = 0,
    this.retweetSayisi = 0,
    this.imageUrls = const [],
    this.audioUrl,
    this.videoUrl,
    this.borsaDegeri,
    this.authorAvatarUrl,
    // Security contract fields
    this.type = PostType.spill,
    this.status = ModerationStatus.pending,
    this.updatedAt,
    this.moderation,
    this.media = const [],
  });

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  // Krep puanını hesapla (gamification)
  int get krepPuani {
    double puan = krepSeviyesi * 10;
    bool isPremiumCringe = borsaDegeri != null && borsaDegeri! > 1.0;
    if (isPremiumCringe) puan *= 1.5;
    if (begeniSayisi > 10) puan += (begeniSayisi * 0.5);
    return puan.round();
  }

  // Premium cringe olup olmadığını kontrol et
  bool get isPremiumCringe => borsaDegeri != null && borsaDegeri! > 1.0;

  // Utanç puanı hesapla
  double get utancPuani => krepSeviyesi * (begeniSayisi + 1) / 10;

  // Factory constructors (test verileri için)
  factory CringeEntry.mockBasic() {
    return CringeEntry(
      id: '1',
      userId: 'user123',
      authorName: 'Mehmet K.',
      authorHandle: '@mehmetk',
      baslik: 'Hocaya Anne Dedim',
      aciklama:
          'Matematik dersinde hocaya yanlışlıkla "anne" dedim ve herkes güldü.',
      kategori: CringeCategory.fizikselRezillik,
      krepSeviyesi: 7.5,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
  }

  factory CringeEntry.mockAnonim() {
    return CringeEntry(
      id: '2',
      userId: 'user456',
      authorName: 'Anonim Kullanıcı',
      authorHandle: '@anonim',
      baslik: 'Elevator Krizi',
      aciklama:
          'Asansörde yalnızken ayna var sanıp kendimle konuştum, sonra birinin daha olduğunu fark ettim.',
      kategori: CringeCategory.sosyalRezillik,
      krepSeviyesi: 9.0,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isAnonim: true,
    );
  }

  factory CringeEntry.mockPopular() {
    return CringeEntry(
      id: '3',
      userId: 'user789',
      authorName: 'Ayşe Y.',
      authorHandle: '@ayseyilmaz',
      baslik: 'Yanlış Kişiye Aşk İtirafı',
      aciklama:
          'WhatsApp\'ta crush\'ıma yazmak isterken annesine "seni seviyorum" yazdım.',
      kategori: CringeCategory.askAcisiKrepligi,
      krepSeviyesi: 8.7,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      begeniSayisi: 156,
      yorumSayisi: 42,
    );
  }

  factory CringeEntry.mockRecent() {
    return CringeEntry(
      id: '4',
      userId: 'user101',
      authorName: 'Can D.',
      authorHandle: '@candemir',
      baslik: 'Zoom Mikrofon Faciası',
      aciklama:
          'Online derste mikrofon açık kaldı, annemle kavga ettiğim herkes duydu.',
      kategori: CringeCategory.sosyalMedyaIntihari,
      krepSeviyesi: 6.8,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      begeniSayisi: 23,
      yorumSayisi: 8,
    );
  }

  factory CringeEntry.fromJson(Map<String, dynamic> json) {
    return CringeEntry(
      id: json['id'],
      userId: json['userId'] ?? json['ownerId'], // Support both field names
      authorName: json['authorName'] ?? 'Anonim',
      authorHandle: json['authorHandle'] ?? '@anonim',
      baslik: json['baslik'] ?? json['text'] ?? '',
      aciklama: json['aciklama'] ?? json['text'] ?? '',
      kategori: CringeCategory.values.firstWhere(
        (cat) => cat.name == json['kategori'],
        orElse: () => CringeCategory.fizikselRezillik,
      ),
      krepSeviyesi: (json['krepSeviyesi'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      etiketler: List<String>.from(json['etiketler'] ?? []),
      isAnonim: json['isAnonim'] ?? false,
      begeniSayisi: _parseInt(json['begeniSayisi']),
      yorumSayisi: _parseInt(json['yorumSayisi']),
      retweetSayisi: _parseInt(json['retweetSayisi']),
      imageUrls: List<String>.from(json['imageUrls'] ?? json['media'] ?? []),
      audioUrl: json['audioUrl'],
      videoUrl: json['videoUrl'],
      borsaDegeri: json['borsaDegeri']?.toDouble(),
      authorAvatarUrl: json['authorAvatarUrl'],
      // Security contract fields
      type: PostType.fromString(json['type']),
      status: ModerationStatus.fromString(json['status']),
      updatedAt: json['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : (json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null),
      moderation: json['moderation'] as Map<String, dynamic>?,
      media: List<String>.from(json['media'] ?? json['imageUrls'] ?? []),
    );
  }

  // fromMap method'u (fromJson ile aynı)
  factory CringeEntry.fromMap(Map<String, dynamic> map) {
    return CringeEntry.fromJson(map);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'ownerId': userId, // Firestore rules expect 'ownerId'
      'authorName': authorName,
      'authorHandle': authorHandle,
      'baslik': baslik,
      'aciklama': aciklama,
      'text': baslik.isNotEmpty ? baslik : aciklama, // For rules validation
      'kategori': kategori.name,
      'krepSeviyesi': krepSeviyesi,
      'createdAt': createdAt.millisecondsSinceEpoch, // int for Firestore rules
      'etiketler': etiketler,
      'isAnonim': isAnonim,
      'begeniSayisi': begeniSayisi,
      'yorumSayisi': yorumSayisi,
      'retweetSayisi': retweetSayisi,
      'imageUrls': imageUrls,
      'audioUrl': audioUrl,
      'videoUrl': videoUrl,
      'borsaDegeri': borsaDegeri,
      'authorAvatarUrl': authorAvatarUrl,
      // Security contract fields
      'type': type.value,
      'status': status.value,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'moderation': moderation,
      'media': media,
    };
  }

  CringeEntry copyWith({
    String? id,
    String? userId,
    String? authorName,
    String? authorHandle,
    String? baslik,
    String? aciklama,
    CringeCategory? kategori,
    double? krepSeviyesi,
    DateTime? createdAt,
    List<String>? etiketler,
    bool? isAnonim,
    int? begeniSayisi,
    int? yorumSayisi,
    int? retweetSayisi,
    List<String>? imageUrls,
    String? audioUrl,
    String? videoUrl,
    double? borsaDegeri,
    String? authorAvatarUrl,
    PostType? type,
    ModerationStatus? status,
    DateTime? updatedAt,
    Map<String, dynamic>? moderation,
    List<String>? media,
  }) {
    return CringeEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      authorHandle: authorHandle ?? this.authorHandle,
      baslik: baslik ?? this.baslik,
      aciklama: aciklama ?? this.aciklama,
      kategori: kategori ?? this.kategori,
      krepSeviyesi: krepSeviyesi ?? this.krepSeviyesi,
      createdAt: createdAt ?? this.createdAt,
      etiketler: etiketler ?? this.etiketler,
      isAnonim: isAnonim ?? this.isAnonim,
      begeniSayisi: begeniSayisi ?? this.begeniSayisi,
      yorumSayisi: yorumSayisi ?? this.yorumSayisi,
      retweetSayisi: retweetSayisi ?? this.retweetSayisi,
      imageUrls: imageUrls ?? this.imageUrls,
      audioUrl: audioUrl ?? this.audioUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      borsaDegeri: borsaDegeri ?? this.borsaDegeri,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      moderation: moderation ?? this.moderation,
      media: media ?? this.media,
    );
  }

  // Firestore için factory constructor
  factory CringeEntry.fromFirestore(Map<String, dynamic> data) {
    // Parse createdAt - could be Firestore Timestamp or int milliseconds
    DateTime parsedCreatedAt;
    if (data['createdAt'] != null) {
      final createdAtValue = data['createdAt'];
      if (createdAtValue is int) {
        parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
      } else if (createdAtValue.toString().contains('-')) {
        parsedCreatedAt = DateTime.parse(createdAtValue.toString());
      } else {
        // Assume Firestore Timestamp
        parsedCreatedAt = (createdAtValue as dynamic).toDate();
      }
    } else {
      parsedCreatedAt = DateTime.now();
    }

    // Parse updatedAt similarly
    DateTime? parsedUpdatedAt;
    if (data['updatedAt'] != null) {
      final updatedAtValue = data['updatedAt'];
      if (updatedAtValue is int) {
        parsedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtValue);
      } else if (updatedAtValue.toString().contains('-')) {
        parsedUpdatedAt = DateTime.parse(updatedAtValue.toString());
      } else {
        parsedUpdatedAt = (updatedAtValue as dynamic).toDate();
      }
    }

    return CringeEntry(
      id: data['id'] ?? '',
      userId: data['ownerId'] ?? data['userId'] ?? '', // Firestore rules use 'ownerId'
      authorName: data['authorName'] ?? data['username'] ?? 'Anonim',
      authorHandle: data['authorHandle'] ?? '@${data['username'] ?? 'anonim'}',
      baslik: data['baslik'] ?? data['title'] ?? '',
      aciklama: data['aciklama'] ?? data['description'] ?? '',
      kategori: data['kategori'] != null
          ? CringeCategory.values[data['kategori'] %
                CringeCategory.values.length]
          : CringeCategory.values.firstWhere(
              (cat) => cat.name == data['category'],
              orElse: () => CringeCategory.fizikselRezillik,
            ),
      krepSeviyesi: (data['krepSeviyesi'] ?? data['krepValue'] ?? 0).toDouble(),
      createdAt: parsedCreatedAt,
      begeniSayisi: _parseInt(data['begeniSayisi'] ?? data['likes']),
      yorumSayisi: _parseInt(data['yorumSayisi'] ?? data['comments']),
      retweetSayisi: _parseInt(data['retweetSayisi'] ?? data['retweets']),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      authorAvatarUrl: data['authorAvatarUrl'],
      isAnonim: data['isAnonim'] ?? false,
      // Security contract fields
      type: data['type'] != null ? PostType.fromString(data['type']) : PostType.spill,
      status: data['status'] != null ? ModerationStatus.fromString(data['status']) : ModerationStatus.pending,
      updatedAt: parsedUpdatedAt,
      moderation: data['moderation'] != null ? Map<String, dynamic>.from(data['moderation']) : null,
      media: data['media'] != null ? List<String>.from(data['media']) : [],
    );
  }

  // Firestore için Map'e çevir
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': userId, // Firestore rules expect 'ownerId'
      'userId': userId, // Keep for backward compatibility
      'username': authorHandle.replaceAll('@', ''),
      'authorName': authorName,
      'title': baslik,
      'description': aciklama,
      'text': baslik.isNotEmpty ? baslik : aciklama, // For rules validation
      'category': kategori.name,
      'krepValue': krepSeviyesi,
      'createdAt': createdAt.millisecondsSinceEpoch, // int for Firestore rules
      'likes': begeniSayisi,
      'comments': yorumSayisi,
      'retweets': retweetSayisi,
      'imageUrls': imageUrls,
      'authorAvatarUrl': authorAvatarUrl,
      // Security contract fields
      'type': type.value,
      'status': status.value,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'moderation': moderation,
      'media': media,
    };
  }

  // Kolay erişim için getter'lar (CringeEntryService uyumluluğu için)
  String get username => authorHandle.replaceAll('@', '');
  String get title => baslik;
  String get description => aciklama;
  double get krepValue => krepSeviyesi;
  CringeCategory get category => kategori;
}
