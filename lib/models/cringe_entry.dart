import 'package:flutter/material.dart';

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
  final String userId;
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
  final List<String> imageUrls; // Çoklu resim desteği
  final int retweetSayisi;
  final String authorName; // Görünür isim
  final String authorHandle; // @username
  final String? authorAvatarUrl; // Profil resmi URL'i

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
      userId: json['userId'],
      authorName: json['authorName'] ?? 'Anonim',
      authorHandle: json['authorHandle'] ?? '@anonim',
      baslik: json['baslik'],
      aciklama: json['aciklama'],
      kategori: CringeCategory.values.firstWhere(
        (cat) => cat.name == json['kategori'],
        orElse: () => CringeCategory.fizikselRezillik,
      ),
      krepSeviyesi: (json['krepSeviyesi'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      etiketler: List<String>.from(json['etiketler'] ?? []),
      isAnonim: json['isAnonim'] ?? false,
      begeniSayisi: _parseInt(json['begeniSayisi']),
      yorumSayisi: _parseInt(json['yorumSayisi']),
      retweetSayisi: _parseInt(json['retweetSayisi']),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      audioUrl: json['audioUrl'],
      videoUrl: json['videoUrl'],
      borsaDegeri: json['borsaDegeri']?.toDouble(),
      authorAvatarUrl: json['authorAvatarUrl'],
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
      'authorName': authorName,
      'authorHandle': authorHandle,
      'baslik': baslik,
      'aciklama': aciklama,
      'kategori': kategori.name,
      'krepSeviyesi': krepSeviyesi,
      'createdAt': createdAt.toIso8601String(),
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
    );
  }

  // Firestore için factory constructor
  factory CringeEntry.fromFirestore(Map<String, dynamic> data) {
    return CringeEntry(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      authorName: data['authorName'] ?? data['username'] ?? 'Anonim',
      authorHandle: data['authorHandle'] ?? '@${data['username'] ?? 'anonim'}',
      baslik: data['baslik'] ?? data['title'] ?? '',
      aciklama: data['aciklama'] ?? data['description'] ?? '',
      kategori: data['kategori'] != null 
          ? CringeCategory.values[data['kategori'] % CringeCategory.values.length]
          : CringeCategory.values.firstWhere(
              (cat) => cat.name == data['category'],
              orElse: () => CringeCategory.fizikselRezillik,
            ),
      krepSeviyesi: (data['krepSeviyesi'] ?? data['krepValue'] ?? 0).toDouble(),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      begeniSayisi: _parseInt(data['begeniSayisi'] ?? data['likes']),
      yorumSayisi: _parseInt(data['yorumSayisi'] ?? data['comments']),
      retweetSayisi: _parseInt(data['retweetSayisi'] ?? data['retweets']),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      authorAvatarUrl: data['authorAvatarUrl'],
      isAnonim: data['isAnonim'] ?? false,
    );
  }

  // Firestore için Map'e çevir
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': authorHandle.replaceAll('@', ''),
      'authorName': authorName,
      'title': baslik,
      'description': aciklama,
      'category': kategori.name,
      'krepValue': krepSeviyesi,
      'createdAt': createdAt,
      'likes': begeniSayisi,
      'comments': yorumSayisi,
      'retweets': retweetSayisi,
      'imageUrls': imageUrls,
      'authorAvatarUrl': authorAvatarUrl,
    };
  }

  // Kolay erişim için getter'lar (CringeEntryService uyumluluğu için)
  String get username => authorHandle.replaceAll('@', '');
  String get title => baslik;
  String get description => aciklama;
  double get krepValue => krepSeviyesi;
  CringeCategory get category => kategori;
}
