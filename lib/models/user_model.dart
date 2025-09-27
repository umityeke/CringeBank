class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String avatar;
  final String bio;
  final int krepScore;
  final int krepLevel;
  final int followersCount;
  final int followingCount;
  final int entriesCount;
  final DateTime joinDate;
  final DateTime lastActive;
  final List<String> rozetler;
  final bool isPremium;
  final bool isVerified;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.avatar = '👤',
    this.bio = '',
    this.krepScore = 0,
    this.krepLevel = 1,
    this.followersCount = 0,
    this.followingCount = 0,
    this.entriesCount = 0,
    required this.joinDate,
    required this.lastActive,
    this.rozetler = const [],
    this.isPremium = false,
    this.isVerified = false,
  });

  // Seviye hesaplama
  String get seviyeAdi {
    if (krepScore < 100) return 'Utangaç';
    if (krepScore < 500) return 'Krep';
    if (krepScore < 1500) return 'Mega Krep';
    if (krepScore < 5000) return 'Krep Master';
    return 'Cringe Lord';
  }

  // Avatar URL için getter
  String get avatarUrl => avatar;

  // Seviye ilerlemesi
  double get seviyeIlerlemesi {
    const thresholds = [0, 100, 500, 1500, 5000, 10000];

    if (krepScore >= thresholds.last) {
      return 1.0;
    }

    for (var i = 1; i < thresholds.length; i++) {
      final current = thresholds[i];
      final previous = thresholds[i - 1];

      if (krepScore < current) {
        final span = (current - previous).toDouble();
        final progress = (krepScore - previous) / span;
        return progress.clamp(0.0, 1.0);
      }
    }

    return 1.0;
  }

  // JSON Serialization
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      avatar: json['avatar'] ?? '👤',
      bio: json['bio'] ?? '',
      krepScore: json['krepScore'] ?? 0,
      krepLevel: json['krepLevel'] ?? 1,
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      entriesCount: json['entriesCount'] ?? 0,
      joinDate: json['joinDate'] != null 
          ? DateTime.parse(json['joinDate']) 
          : DateTime.now(),
      lastActive: json['lastActive'] != null 
          ? DateTime.parse(json['lastActive'])
          : DateTime.now(),
      rozetler: List<String>.from(json['rozetler'] ?? []),
      isPremium: json['isPremium'] ?? false,
      isVerified: json['isVerified'] ?? false,
    );
  }

  // Firebase Firestore serialization
  factory User.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'] ?? map['uid'] ?? map['userId'];
  final normalizedId = rawId is String
    ? rawId.trim()
        : rawId != null
      ? rawId.toString().trim()
            : '';

    return User(
      id: normalizedId,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      avatar: map['avatar'] ?? '👤',
      bio: map['bio'] ?? '',
      krepScore: map['krepScore'] ?? 0,
      krepLevel: map['krepLevel'] ?? 1,
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      entriesCount: map['entriesCount'] ?? 0,
      joinDate: map['joinDate'] != null 
          ? (map['joinDate'] as dynamic).toDate() 
          : DateTime.now(),
      lastActive: map['lastActive'] != null 
          ? (map['lastActive'] as dynamic).toDate()
          : DateTime.now(),
      rozetler: List<String>.from(map['rozetler'] ?? []),
      isPremium: map['isPremium'] ?? false,
      isVerified: map['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'avatar': avatar,
      'bio': bio,
      'krepScore': krepScore,
      'krepLevel': krepLevel,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'entriesCount': entriesCount,
      'joinDate': joinDate,
      'lastActive': lastActive,
      'rozetler': rozetler,
      'isPremium': isPremium,
      'isVerified': isVerified,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'avatar': avatar,
      'bio': bio,
      'krepScore': krepScore,
      'krepLevel': krepLevel,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'entriesCount': entriesCount,
      'joinDate': joinDate.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'rozetler': rozetler,
      'isPremium': isPremium,
      'isVerified': isVerified,
    };
  }

  // Copy with method
  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? avatar,
    String? bio,
    int? krepScore,
    int? krepLevel,
    int? followersCount,
    int? followingCount,
    int? entriesCount,
    DateTime? joinDate,
    DateTime? lastActive,
    List<String>? rozetler,
    bool? isPremium,
    bool? isVerified,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      krepScore: krepScore ?? this.krepScore,
      krepLevel: krepLevel ?? this.krepLevel,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      entriesCount: entriesCount ?? this.entriesCount,
      joinDate: joinDate ?? this.joinDate,
      lastActive: lastActive ?? this.lastActive,
      rozetler: rozetler ?? this.rozetler,
      isPremium: isPremium ?? this.isPremium,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, fullName: $fullName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Helper methods
  bool get isActive {
    final now = DateTime.now();
    return now.difference(lastActive).inMinutes < 30;
  }

  String get displayName => fullName.isNotEmpty ? fullName : username;

  String get memberSince {
    final now = DateTime.now();
    final difference = now.difference(joinDate);
    
    if (difference.inDays < 1) {
      return 'Bugün katıldı';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} gün önce katıldı';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ay önce katıldı';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years yıl önce katıldı';
    }
  }

  String get lastActiveString {
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    if (difference.inMinutes < 1) {
      return 'Az önce aktifti';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce aktifti';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce aktifti';
    } else {
      return '${difference.inDays} gün önce aktifti';
    }
  }
}