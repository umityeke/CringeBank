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
  final List<String> ownedStoreItems;
  final String? equippedFrameItemId;
  final List<String> equippedBadgeItemIds;
  final String? equippedNameColorItemId;
  final String? equippedBackgroundItemId;

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
    this.ownedStoreItems = const [],
    this.equippedFrameItemId,
    this.equippedBadgeItemIds = const [],
    this.equippedNameColorItemId,
    this.equippedBackgroundItemId,
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
      ownedStoreItems: List<String>.from(json['ownedStoreItems'] ?? const []),
    equippedFrameItemId:
      _stringOrNull(json['equippedStoreItems']?['frame']),
    equippedBadgeItemIds: _safeStringList(
    json['equippedStoreItems']?['badges'],
    ),
    equippedNameColorItemId:
      _stringOrNull(json['equippedStoreItems']?['nameColor']),
    equippedBackgroundItemId:
      _stringOrNull(json['equippedStoreItems']?['background']),
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

    final equipped = _asEquippedMap(map['equippedStoreItems']);

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
      ownedStoreItems: _safeStringList(map['ownedStoreItems']),
      equippedFrameItemId: _stringOrNull(equipped['frame']),
      equippedBadgeItemIds: _safeStringList(equipped['badges']),
      equippedNameColorItemId: _stringOrNull(equipped['nameColor']),
      equippedBackgroundItemId: _stringOrNull(equipped['background']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
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
      'ownedStoreItems': ownedStoreItems,
    };

    final equipped = <String, dynamic>{};
    if (equippedFrameItemId?.isNotEmpty == true) {
      equipped['frame'] = equippedFrameItemId;
    }
    if (equippedBadgeItemIds.isNotEmpty) {
      equipped['badges'] = equippedBadgeItemIds;
    }
    if (equippedNameColorItemId?.isNotEmpty == true) {
      equipped['nameColor'] = equippedNameColorItemId;
    }
    if (equippedBackgroundItemId?.isNotEmpty == true) {
      equipped['background'] = equippedBackgroundItemId;
    }
    if (equipped.isNotEmpty) {
      map['equippedStoreItems'] = equipped;
    }

    return map;
  }

  Map<String, dynamic> toJson() {
    final json = {
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
      'ownedStoreItems': ownedStoreItems,
    };

    final equipped = <String, dynamic>{};
    if (equippedFrameItemId?.isNotEmpty == true) {
      equipped['frame'] = equippedFrameItemId;
    }
    if (equippedBadgeItemIds.isNotEmpty) {
      equipped['badges'] = equippedBadgeItemIds;
    }
    if (equippedNameColorItemId?.isNotEmpty == true) {
      equipped['nameColor'] = equippedNameColorItemId;
    }
    if (equippedBackgroundItemId?.isNotEmpty == true) {
      equipped['background'] = equippedBackgroundItemId;
    }
    if (equipped.isNotEmpty) {
      json['equippedStoreItems'] = equipped;
    }

    return json;
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
    List<String>? ownedStoreItems,
    String? equippedFrameItemId,
    List<String>? equippedBadgeItemIds,
    String? equippedNameColorItemId,
    String? equippedBackgroundItemId,
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
    ownedStoreItems: ownedStoreItems ?? this.ownedStoreItems,
    equippedFrameItemId: equippedFrameItemId ?? this.equippedFrameItemId,
    equippedBadgeItemIds:
      equippedBadgeItemIds ?? this.equippedBadgeItemIds,
    equippedNameColorItemId:
      equippedNameColorItemId ?? this.equippedNameColorItemId,
    equippedBackgroundItemId:
      equippedBackgroundItemId ?? this.equippedBackgroundItemId,
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

List<String> _safeStringList(dynamic source) {
  if (source == null) return const [];
  if (source is String) {
    return source.isEmpty ? const [] : [source];
  }
  if (source is Iterable) {
    return source.map((value) => value.toString()).where((value) {
      return value.trim().isNotEmpty;
    }).toList(growable: false);
  }
  return const [];
}

Map<String, dynamic> _asEquippedMap(dynamic source) {
  if (source is Map<String, dynamic>) {
    return source;
  }
  if (source is Map) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

String? _stringOrNull(dynamic value) {
  if (value == null) return null;
  String converted;
  if (value is String) {
    converted = value;
  } else {
    converted = value.toString();
  }
  final trimmed = converted.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}