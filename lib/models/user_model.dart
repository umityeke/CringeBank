class UserVisibilitySettings {
  final String phoneNumber;
  final String email;

  const UserVisibilitySettings({
    this.phoneNumber = 'private',
    this.email = 'private',
  });

  factory UserVisibilitySettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const UserVisibilitySettings();
    }
    return UserVisibilitySettings(
      phoneNumber: _stringOrNull(map['phoneNumber']) ?? 'private',
      email: _stringOrNull(map['email']) ?? 'private',
    );
  }

  Map<String, dynamic> toMap() => {'phoneNumber': phoneNumber, 'email': email};

  UserVisibilitySettings copyWith({String? phoneNumber, String? email}) {
    return UserVisibilitySettings(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
    );
  }
}

class UserPreferences {
  final bool showActivityStatus;
  final bool allowTagging;
  final bool allowMessagesFromNonFollowers;

  const UserPreferences({
    this.showActivityStatus = true,
    this.allowTagging = true,
    this.allowMessagesFromNonFollowers = false,
  });

  factory UserPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const UserPreferences();
    }
    return UserPreferences(
      showActivityStatus: _readBool(
        map['showActivityStatus'] ?? map['show_activity_status'],
        true,
      ),
      allowTagging: _readBool(
        map['allowTagging'] ?? map['allow_tagging'],
        true,
      ),
      allowMessagesFromNonFollowers: _readBool(
        map['allowMessagesFromNonFollowers'] ??
            map['allow_messages_from_non_followers'],
        false,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'showActivityStatus': showActivityStatus,
    'allowTagging': allowTagging,
    'allowMessagesFromNonFollowers': allowMessagesFromNonFollowers,
  };

  UserPreferences copyWith({
    bool? showActivityStatus,
    bool? allowTagging,
    bool? allowMessagesFromNonFollowers,
  }) {
    return UserPreferences(
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      allowTagging: allowTagging ?? this.allowTagging,
      allowMessagesFromNonFollowers:
          allowMessagesFromNonFollowers ?? this.allowMessagesFromNonFollowers,
    );
  }
}

class AdminRoleAssignment {
  final String role;
  final String status; // active, pending, revoked
  final Map<String, dynamic> scope;
  final DateTime grantedAt;
  final DateTime? expiresAt;

  const AdminRoleAssignment({
    required this.role,
    this.status = 'active',
    this.scope = const <String, dynamic>{},
    required this.grantedAt,
    this.expiresAt,
  });

  bool get isActive =>
      status == 'active' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'status': status,
      'scope': scope,
      'grantedAt': grantedAt.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }

  AdminRoleAssignment copyWith({
    String? role,
    String? status,
    Map<String, dynamic>? scope,
    DateTime? grantedAt,
    DateTime? expiresAt,
  }) {
    return AdminRoleAssignment(
      role: role ?? this.role,
      status: status ?? this.status,
      scope: scope ?? this.scope,
      grantedAt: grantedAt ?? this.grantedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  factory AdminRoleAssignment.fromMap(dynamic source) {
    if (source == null) {
      return AdminRoleAssignment(role: 'unknown', grantedAt: DateTime.now());
    }
    final map = _mapFromDynamic(source);
    return AdminRoleAssignment(
      role: _stringOrNull(map['role']) ?? 'unknown',
      status: _stringOrNull(map['status']) ?? 'active',
      scope: _mapFromDynamic(map['scope']),
      grantedAt: _parseTimestamp(map['grantedAt']) ?? DateTime.now(),
      expiresAt: _parseTimestamp(map['expiresAt']),
    );
  }
}

class PendingAdminApproval {
  final String id;
  final String type; // e.g. superadmin_nomination, demotion
  final String status; // pending, approved, rejected, expired
  final DateTime createdAt;
  final int requiredApprovals;
  final List<String> approverUids;
  final Map<String, dynamic> metadata;

  const PendingAdminApproval({
    required this.id,
    required this.type,
    this.status = 'pending',
    required this.createdAt,
    this.requiredApprovals = 2,
    this.approverUids = const [],
    this.metadata = const <String, dynamic>{},
  });

  bool get isResolved => status != 'pending';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'requiredApprovals': requiredApprovals,
      'approverUids': approverUids,
      'metadata': metadata,
    };
  }

  PendingAdminApproval copyWith({
    String? id,
    String? type,
    String? status,
    DateTime? createdAt,
    int? requiredApprovals,
    List<String>? approverUids,
    Map<String, dynamic>? metadata,
  }) {
    return PendingAdminApproval(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      requiredApprovals: requiredApprovals ?? this.requiredApprovals,
      approverUids: approverUids ?? this.approverUids,
      metadata: metadata ?? this.metadata,
    );
  }

  factory PendingAdminApproval.fromMap(dynamic source) {
    final map = _mapFromDynamic(source);
    return PendingAdminApproval(
      id: _stringOrNull(map['id']) ?? _stringOrNull(map['approvalId']) ?? '',
      type: _stringOrNull(map['type']) ?? 'unknown',
      status: _stringOrNull(map['status']) ?? 'pending',
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      requiredApprovals: _readInt(map['requiredApprovals'], fallback: 2),
      approverUids: _safeStringList(map['approverUids'] ?? map['approvers']),
      metadata: _mapFromDynamic(map['metadata']),
    );
  }
}

class User {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String fullName;
  final String avatar;
  final String bio;
  final int krepScore;
  final int krepLevel;
  final int followersCount;
  final double popularityScore;
  final int followingCount;
  final int entriesCount;
  final int coins;
  final DateTime joinDate;
  final DateTime lastActive;
  final DateTime? lastUsernameChangeAt;
  final DateTime? nextUsernameChangeAt;
  final DateTime? lastDisplayNameChangeAt;
  final DateTime? nextDisplayNameChangeAt;
  final List<String> rozetler;
  final bool isPremium;
  final bool isVerified;
  final bool isPrivate;
  final bool isSuspended;
  final List<String> ownedStoreItems;
  final String? equippedFrameItemId;
  final List<String> equippedBadgeItemIds;
  final String? equippedNameColorItemId;
  final String? equippedBackgroundItemId;
  final String? phoneNumber;
  final String gender;
  final String genderOther;
  final DateTime? birthDate;
  final String educationLevel;
  final UserVisibilitySettings visibility;
  final UserPreferences preferences;
  final List<AdminRoleAssignment> adminRoles;
  final List<String> grantedPermissions;
  final int claimsVersion;
  final List<PendingAdminApproval> pendingApprovals;
  final bool isSuperAdmin;
  final List<String> moderatedCategories;
  final Map<String, List<String>> categoryPermissions;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    String? displayName,
    this.avatar = '👤',
    this.bio = '',
    this.krepScore = 0,
    this.krepLevel = 1,
    this.followersCount = 0,
    this.popularityScore = 0,
    this.followingCount = 0,
    this.entriesCount = 0,
    this.coins = 0,
    required this.joinDate,
    required this.lastActive,
    this.lastUsernameChangeAt,
    this.nextUsernameChangeAt,
    this.lastDisplayNameChangeAt,
    this.nextDisplayNameChangeAt,
    this.rozetler = const [],
    this.isPremium = false,
    this.isVerified = false,
    this.isPrivate = false,
    this.isSuspended = false,
    this.ownedStoreItems = const [],
    this.equippedFrameItemId,
    this.equippedBadgeItemIds = const [],
    this.equippedNameColorItemId,
    this.equippedBackgroundItemId,
    String? phoneNumber,
    String gender = 'prefer_not',
    String? genderOther,
    DateTime? birthDate,
    String educationLevel = 'higher',
    UserVisibilitySettings? visibility,
    UserPreferences? preferences,
    List<AdminRoleAssignment>? adminRoles,
    List<String>? grantedPermissions,
    int? claimsVersion,
    List<PendingAdminApproval>? pendingApprovals,
    bool? superAdminOverride,
    this.moderatedCategories = const [],
    this.categoryPermissions = const {},
  }) : displayName = _normalizeDisplayName(displayName, fullName, username),
       phoneNumber = _stringOrNull(phoneNumber),
       gender = _normalizeGender(gender),
       genderOther = (genderOther ?? '').trim(),
       birthDate = _normalizeBirthDate(birthDate),
       educationLevel = _normalizeEducationLevel(educationLevel),
       visibility = visibility ?? const UserVisibilitySettings(),
       preferences = preferences ?? const UserPreferences(),
       adminRoles = adminRoles ?? const [],
       grantedPermissions = grantedPermissions ?? const [],
       claimsVersion = claimsVersion ?? 0,
       pendingApprovals = pendingApprovals ?? const [],
       isSuperAdmin = _deriveIsSuperAdmin(
         superAdminOverride,
         adminRoles ?? const [],
         email,
       );

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
    final adminRolesData = _parseAdminRoles(
      json['adminRoles'] ?? json['roles'],
    );
    final pendingApprovalsData = _parsePendingApprovals(
      json['pendingAdminApprovals'] ?? json['pendingApprovals'],
    );
    final grantedPermissionsData = _safeStringList(
      json['grantedPermissions'] ?? json['permissions'],
    );
    final claimsVersionValue = _readInt(
      json['claimsVersion'] ?? json['claims_version'],
      fallback: 0,
    );
    final dynamic superAdminRaw = json['isSuperAdmin'];
    final bool? superAdminOverride = superAdminRaw == null
        ? null
        : _readBool(superAdminRaw, false);

    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['displayName'] ?? '',
      displayName:
          json['displayName'] ?? json['fullName'] ?? json['username'] ?? '',
      avatar: json['avatar'] ?? '👤',
      bio: json['bio'] ?? '',
      krepScore: json['krepScore'] ?? 0,
      krepLevel: json['krepLevel'] ?? 1,
      followersCount: json['followersCount'] ?? 0,
      popularityScore: _doubleOrZero(json['popularityScore']),
      followingCount: json['followingCount'] ?? 0,
      entriesCount: json['entriesCount'] ?? 0,
      coins: json['coins'] ?? json['coinBalance'] ?? 0,
      joinDate: json['joinDate'] != null
          ? DateTime.parse(json['joinDate'])
          : DateTime.now(),
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'])
          : DateTime.now(),
      lastUsernameChangeAt: _parseTimestamp(
        json['lastUsernameChangeAt'],
      )?.toLocal(),
      nextUsernameChangeAt: _parseTimestamp(
        json['nextUsernameChangeAt'],
      )?.toLocal(),
      lastDisplayNameChangeAt: _parseTimestamp(
        json['lastDisplayNameChangeAt'],
      )?.toLocal(),
      nextDisplayNameChangeAt: _parseTimestamp(
        json['nextDisplayNameChangeAt'],
      )?.toLocal(),
      rozetler: List<String>.from(json['rozetler'] ?? []),
      isPremium: json['isPremium'] ?? false,
      isVerified: json['isVerified'] ?? false,
      isPrivate: json['isPrivate'] ?? json['is_private'] ?? false,
      isSuspended: json['isSuspended'] ?? json['is_suspended'] ?? false,
      ownedStoreItems: _mergeLists(
        List<String>.from(json['ownedStoreItems'] ?? const []),
        List<String>.from(json['ownedItems'] ?? const []),
      ),
      equippedFrameItemId: _stringOrNull(json['equippedStoreItems']?['frame']),
      equippedBadgeItemIds: _safeStringList(
        json['equippedStoreItems']?['badges'],
      ),
      equippedNameColorItemId: _stringOrNull(
        json['equippedStoreItems']?['nameColor'],
      ),
      equippedBackgroundItemId: _stringOrNull(
        json['equippedStoreItems']?['background'],
      ),
      phoneNumber: _stringOrNull(json['phoneNumber']),
      gender: json['gender'] ?? 'prefer_not',
      genderOther: json['genderOther'] ?? '',
      birthDate: _parseDate(json['birthDate']),
      educationLevel:
          json['education']?['level'] ?? json['educationLevel'] ?? 'higher',
      visibility: UserVisibilitySettings.fromMap(
        json['visibility'] is Map<String, dynamic>
            ? json['visibility'] as Map<String, dynamic>
            : json['visibility'] is Map
            ? (json['visibility'] as Map).map(
                (key, value) => MapEntry('$key', value),
              )
            : null,
      ),
      preferences: UserPreferences.fromMap(
        json['preferences'] is Map<String, dynamic>
            ? json['preferences'] as Map<String, dynamic>
            : json['preferences'] is Map
            ? (json['preferences'] as Map).map(
                (key, value) => MapEntry('$key', value),
              )
            : null,
      ),
      adminRoles: adminRolesData,
      grantedPermissions: grantedPermissionsData,
      claimsVersion: claimsVersionValue,
      pendingApprovals: pendingApprovalsData,
      superAdminOverride: superAdminOverride,
      moderatedCategories: List<String>.from(
        json['moderatedCategories'] ?? const [],
      ),
      categoryPermissions: _parseCategoryPermissions(
        json['categoryPermissions'],
      ),
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
    final adminRolesData = _parseAdminRoles(map['adminRoles'] ?? map['roles']);
    final pendingApprovalsData = _parsePendingApprovals(
      map['pendingAdminApprovals'] ?? map['pendingApprovals'],
    );
    final grantedPermissionsData = _safeStringList(
      map['grantedPermissions'] ?? map['permissions'],
    );
    final claimsVersionValue = _readInt(
      map['claimsVersion'] ?? map['claims_version'],
      fallback: 0,
    );
    final dynamic superAdminRaw = map['isSuperAdmin'];
    final bool? superAdminOverride = superAdminRaw == null
        ? null
        : _readBool(superAdminRaw, false);

    return User(
      id: normalizedId,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? map['displayName'] ?? '',
      displayName:
          map['displayName'] ?? map['fullName'] ?? map['username'] ?? '',
      avatar: map['avatar'] ?? '👤',
      bio: map['bio'] ?? '',
      krepScore: map['krepScore'] ?? 0,
      krepLevel: map['krepLevel'] ?? 1,
      followersCount: map['followersCount'] ?? 0,
      popularityScore: _doubleOrZero(map['popularityScore']),
      followingCount: map['followingCount'] ?? 0,
      entriesCount: map['entriesCount'] ?? 0,
      coins: map['coins'] ?? map['coinBalance'] ?? 0,
      joinDate: map['joinDate'] != null
          ? (map['joinDate'] as dynamic).toDate()
          : DateTime.now(),
      lastActive: map['lastActive'] != null
          ? (map['lastActive'] as dynamic).toDate()
          : DateTime.now(),
      lastUsernameChangeAt: _parseTimestamp(
        map['lastUsernameChangeAt'],
      )?.toLocal(),
      nextUsernameChangeAt: _parseTimestamp(
        map['nextUsernameChangeAt'],
      )?.toLocal(),
      lastDisplayNameChangeAt: _parseTimestamp(
        map['lastDisplayNameChangeAt'],
      )?.toLocal(),
      nextDisplayNameChangeAt: _parseTimestamp(
        map['nextDisplayNameChangeAt'],
      )?.toLocal(),
      rozetler: List<String>.from(map['rozetler'] ?? []),
      isPremium: map['isPremium'] ?? false,
      isVerified: map['isVerified'] ?? false,
      isPrivate: map['isPrivate'] ?? map['is_private'] ?? false,
      isSuspended: map['isSuspended'] ?? map['is_suspended'] ?? false,
      ownedStoreItems: _mergeLists(
        _safeStringList(map['ownedStoreItems']),
        _safeStringList(map['ownedItems']),
      ),
      equippedFrameItemId: _stringOrNull(equipped['frame']),
      equippedBadgeItemIds: _safeStringList(equipped['badges']),
      equippedNameColorItemId: _stringOrNull(equipped['nameColor']),
      equippedBackgroundItemId: _stringOrNull(equipped['background']),
      phoneNumber: _stringOrNull(map['phoneNumber']),
      gender: map['gender'] ?? 'prefer_not',
      genderOther: map['genderOther'] ?? '',
      birthDate: _parseDate(map['birthDate']),
      educationLevel:
          map['education']?['level'] ?? map['educationLevel'] ?? 'higher',
      visibility: UserVisibilitySettings.fromMap(
        map['visibility'] is Map<String, dynamic>
            ? map['visibility'] as Map<String, dynamic>
            : map['visibility'] is Map
            ? (map['visibility'] as Map).map(
                (key, value) => MapEntry('$key', value),
              )
            : null,
      ),
      preferences: UserPreferences.fromMap(
        map['preferences'] is Map<String, dynamic>
            ? map['preferences'] as Map<String, dynamic>
            : map['preferences'] is Map
            ? (map['preferences'] as Map).map(
                (key, value) => MapEntry('$key', value),
              )
            : null,
      ),
      adminRoles: adminRolesData,
      grantedPermissions: grantedPermissionsData,
      claimsVersion: claimsVersionValue,
      pendingApprovals: pendingApprovalsData,
      superAdminOverride: superAdminOverride,
      moderatedCategories: List<String>.from(
        map['moderatedCategories'] ?? const [],
      ),
      categoryPermissions: _parseCategoryPermissions(
        map['categoryPermissions'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'displayName': displayName,
      'avatar': avatar,
      'bio': bio,
      'krepScore': krepScore,
      'krepLevel': krepLevel,
      'followersCount': followersCount,
      'popularityScore': popularityScore,
      'followingCount': followingCount,
      'entriesCount': entriesCount,
      'coins': coins,
      'joinDate': joinDate,
      'lastActive': lastActive,
      'rozetler': rozetler,
      'isPremium': isPremium,
      'isVerified': isVerified,
      'isPrivate': isPrivate,
      'isSuspended': isSuspended,
      'is_private': isPrivate,
      'is_suspended': isSuspended,
      'ownedStoreItems': ownedStoreItems,
      'ownedItems': ownedStoreItems,
      'phoneNumber': phoneNumber,
      'gender': gender,
      'genderOther': genderOther,
      'birthDate': birthDate,
      'education': {'level': educationLevel},
      'educationLevel': educationLevel,
      'visibility': visibility.toMap(),
      'preferences': preferences.toMap(),
      'isSuperAdmin': isSuperAdmin,
      'moderatedCategories': moderatedCategories,
      'categoryPermissions': categoryPermissions,
    };

    if (lastUsernameChangeAt != null) {
      map['lastUsernameChangeAt'] = lastUsernameChangeAt!.toUtc();
    }
    if (nextUsernameChangeAt != null) {
      map['nextUsernameChangeAt'] = nextUsernameChangeAt!.toUtc();
    }
    if (lastDisplayNameChangeAt != null) {
      map['lastDisplayNameChangeAt'] = lastDisplayNameChangeAt!.toUtc();
    }
    if (nextDisplayNameChangeAt != null) {
      map['nextDisplayNameChangeAt'] = nextDisplayNameChangeAt!.toUtc();
    }

    if (adminRoles.isNotEmpty) {
      map['adminRoles'] = adminRoles.map((role) => role.toMap()).toList();
      map['roles'] = adminRoles.map((role) => role.role).toList();
    } else {
      map['adminRoles'] = const [];
      map['roles'] = const [];
    }

    if (grantedPermissions.isNotEmpty) {
      map['grantedPermissions'] = grantedPermissions;
      map['permissions'] = grantedPermissions;
    }

    map['claimsVersion'] = claimsVersion;
    map['claims_version'] = claimsVersion;

    if (pendingApprovals.isNotEmpty) {
      final serialized = pendingApprovals
          .map((approval) => approval.toMap())
          .toList();
      map['pendingAdminApprovals'] = serialized;
      map['pendingApprovals'] = serialized;
    }

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
      map['equippedItems'] = _deriveEquippedItemsList();
    }

    return map;
  }

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'displayName': displayName,
      'avatar': avatar,
      'bio': bio,
      'krepScore': krepScore,
      'krepLevel': krepLevel,
      'followersCount': followersCount,
      'popularityScore': popularityScore,
      'followingCount': followingCount,
      'entriesCount': entriesCount,
      'coins': coins,
      'joinDate': joinDate.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'rozetler': rozetler,
      'isPremium': isPremium,
      'isVerified': isVerified,
      'ownedStoreItems': ownedStoreItems,
      'phoneNumber': phoneNumber,
      'gender': gender,
      'genderOther': genderOther,
      'birthDate': birthDate?.toIso8601String(),
      'education': {'level': educationLevel},
      'educationLevel': educationLevel,
      'visibility': visibility.toMap(),
      'preferences': preferences.toMap(),
      'isSuperAdmin': isSuperAdmin,
      'moderatedCategories': moderatedCategories,
      'categoryPermissions': categoryPermissions,
    };

    if (lastUsernameChangeAt != null) {
      json['lastUsernameChangeAt'] = lastUsernameChangeAt!
          .toUtc()
          .toIso8601String();
    }
    if (nextUsernameChangeAt != null) {
      json['nextUsernameChangeAt'] = nextUsernameChangeAt!
          .toUtc()
          .toIso8601String();
    }
    if (lastDisplayNameChangeAt != null) {
      json['lastDisplayNameChangeAt'] = lastDisplayNameChangeAt!
          .toUtc()
          .toIso8601String();
    }
    if (nextDisplayNameChangeAt != null) {
      json['nextDisplayNameChangeAt'] = nextDisplayNameChangeAt!
          .toUtc()
          .toIso8601String();
    }

    if (adminRoles.isNotEmpty) {
      json['adminRoles'] = adminRoles.map((role) => role.toMap()).toList();
      json['roles'] = adminRoles.map((role) => role.role).toList();
    } else {
      json['adminRoles'] = const [];
      json['roles'] = const [];
    }

    if (grantedPermissions.isNotEmpty) {
      json['grantedPermissions'] = grantedPermissions;
      json['permissions'] = grantedPermissions;
    }

    json['claimsVersion'] = claimsVersion;
    json['claims_version'] = claimsVersion;

    if (pendingApprovals.isNotEmpty) {
      final serialized = pendingApprovals
          .map((approval) => approval.toMap())
          .toList();
      json['pendingAdminApprovals'] = serialized;
      json['pendingApprovals'] = serialized;
    }

    json['isPrivate'] = isPrivate;
    json['isSuspended'] = isSuspended;
    json['is_private'] = isPrivate;
    json['is_suspended'] = isSuspended;

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
      json['equippedItems'] = _deriveEquippedItemsList();
    }

    return json;
  }

  // Copy with method
  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? displayName,
    String? avatar,
    String? bio,
    int? krepScore,
    int? krepLevel,
    int? followersCount,
    double? popularityScore,
    int? followingCount,
    int? entriesCount,
    DateTime? joinDate,
    DateTime? lastActive,
    DateTime? lastUsernameChangeAt,
    DateTime? nextUsernameChangeAt,
    DateTime? lastDisplayNameChangeAt,
    DateTime? nextDisplayNameChangeAt,
    List<String>? rozetler,
    bool? isPremium,
    bool? isVerified,
    int? coins,
    bool? isPrivate,
    bool? isSuspended,
    List<String>? ownedStoreItems,
    String? equippedFrameItemId,
    List<String>? equippedBadgeItemIds,
    String? equippedNameColorItemId,
    String? equippedBackgroundItemId,
    String? phoneNumber,
    String? gender,
    String? genderOther,
    DateTime? birthDate,
    String? educationLevel,
    UserVisibilitySettings? visibility,
    UserPreferences? preferences,
    List<AdminRoleAssignment>? adminRoles,
    List<String>? grantedPermissions,
    int? claimsVersion,
    List<PendingAdminApproval>? pendingApprovals,
    bool? superAdminOverride,
    List<String>? moderatedCategories,
    Map<String, List<String>>? categoryPermissions,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      krepScore: krepScore ?? this.krepScore,
      krepLevel: krepLevel ?? this.krepLevel,
      followersCount: followersCount ?? this.followersCount,
      popularityScore: popularityScore ?? this.popularityScore,
      followingCount: followingCount ?? this.followingCount,
      entriesCount: entriesCount ?? this.entriesCount,
      coins: coins ?? this.coins,
      joinDate: joinDate ?? this.joinDate,
      lastActive: lastActive ?? this.lastActive,
      lastUsernameChangeAt: lastUsernameChangeAt ?? this.lastUsernameChangeAt,
      nextUsernameChangeAt: nextUsernameChangeAt ?? this.nextUsernameChangeAt,
      lastDisplayNameChangeAt:
          lastDisplayNameChangeAt ?? this.lastDisplayNameChangeAt,
      nextDisplayNameChangeAt:
          nextDisplayNameChangeAt ?? this.nextDisplayNameChangeAt,
      rozetler: rozetler ?? this.rozetler,
      isPremium: isPremium ?? this.isPremium,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
      isSuspended: isSuspended ?? this.isSuspended,
      ownedStoreItems: ownedStoreItems ?? this.ownedStoreItems,
      equippedFrameItemId: equippedFrameItemId ?? this.equippedFrameItemId,
      equippedBadgeItemIds: equippedBadgeItemIds ?? this.equippedBadgeItemIds,
      equippedNameColorItemId:
          equippedNameColorItemId ?? this.equippedNameColorItemId,
      equippedBackgroundItemId:
          equippedBackgroundItemId ?? this.equippedBackgroundItemId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      genderOther: genderOther ?? this.genderOther,
      birthDate: birthDate ?? this.birthDate,
      educationLevel: educationLevel ?? this.educationLevel,
      visibility: visibility ?? this.visibility,
      preferences: preferences ?? this.preferences,
      adminRoles: adminRoles ?? this.adminRoles,
      grantedPermissions: grantedPermissions ?? this.grantedPermissions,
      claimsVersion: claimsVersion ?? this.claimsVersion,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      superAdminOverride: superAdminOverride ?? isSuperAdmin,
      moderatedCategories: moderatedCategories ?? this.moderatedCategories,
      categoryPermissions: categoryPermissions ?? this.categoryPermissions,
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

  String get preferredDisplayName => displayName.trim().isNotEmpty
      ? displayName.trim()
      : (fullName.trim().isNotEmpty ? fullName.trim() : username);

  List<String> get ownedItems => ownedStoreItems;

  List<String> get equippedItems => _deriveEquippedItemsList();

  List<String> get activeRoles => adminRoles
      .where((role) => role.isActive)
      .map((role) => role.role)
      .toList(growable: false);

  bool get hasPendingSuperAdminNomination => pendingApprovals.any(
    (approval) =>
        approval.type == 'superadmin_nomination' && !approval.isResolved,
  );

  PendingAdminApproval? get pendingSuperAdminApproval {
    for (final approval in pendingApprovals) {
      if (approval.type == 'superadmin_nomination' &&
          approval.status == 'pending') {
        return approval;
      }
    }
    return null;
  }

  int get remainingSuperAdminApprovals {
    final approval = pendingSuperAdminApproval;
    if (approval == null) {
      return 0;
    }
    final remaining = approval.requiredApprovals - approval.approverUids.length;
    if (remaining < 0) {
      return 0;
    }
    return remaining;
  }

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

  bool get canChangeUsername {
    final nextChange = nextUsernameChangeAt;
    if (nextChange == null) {
      return true;
    }
    final now = DateTime.now();
    return !now.isBefore(nextChange);
  }

  Duration? get usernameCooldownRemaining {
    final nextChange = nextUsernameChangeAt;
    if (nextChange == null) {
      return null;
    }
    final now = DateTime.now();
    if (!now.isBefore(nextChange)) {
      return Duration.zero;
    }
    return nextChange.difference(now);
  }

  bool get canChangeDisplayName {
    final nextChange = nextDisplayNameChangeAt;
    if (nextChange == null) {
      return true;
    }
    final now = DateTime.now();
    return !now.isBefore(nextChange);
  }

  Duration? get displayNameCooldownRemaining {
    final nextChange = nextDisplayNameChangeAt;
    if (nextChange == null) {
      return null;
    }
    final now = DateTime.now();
    if (!now.isBefore(nextChange)) {
      return Duration.zero;
    }
    return nextChange.difference(now);
  }

  List<String> _deriveEquippedItemsList() {
    final items = <String>[];
    if (equippedFrameItemId?.trim().isNotEmpty == true) {
      items.add(equippedFrameItemId!.trim());
    }
    if (equippedNameColorItemId?.trim().isNotEmpty == true) {
      items.add(equippedNameColorItemId!.trim());
    }
    if (equippedBackgroundItemId?.trim().isNotEmpty == true) {
      items.add(equippedBackgroundItemId!.trim());
    }
    if (equippedBadgeItemIds.isNotEmpty) {
      for (final badge in equippedBadgeItemIds) {
        final normalized = badge.trim();
        if (normalized.isNotEmpty) {
          items.add(normalized);
        }
      }
    }
    return items;
  }
}

const Set<String> _allowedGenderValues = {
  'female',
  'male',
  'prefer_not',
  'other',
};

const Set<String> _allowedEducationLevels = {
  'primary',
  'middle',
  'high',
  'higher',
};

String _normalizeDisplayName(
  String? candidate,
  String fullName,
  String username,
) {
  final primary = _collapseWhitespace(candidate ?? '');
  if (primary.isNotEmpty) {
    return primary;
  }
  final fallback = _collapseWhitespace(fullName);
  if (fallback.isNotEmpty) {
    return fallback;
  }
  return username.trim();
}

String _normalizeGender(String candidate) {
  final normalized = (candidate).trim().toLowerCase();
  if (_allowedGenderValues.contains(normalized)) {
    return normalized;
  }
  return 'prefer_not';
}

String _normalizeEducationLevel(String candidate) {
  final normalized = candidate.trim().toLowerCase();
  if (_allowedEducationLevels.contains(normalized)) {
    return normalized;
  }
  return 'higher';
}

DateTime? _normalizeBirthDate(DateTime? birthDate) {
  if (birthDate == null) return null;
  return DateTime.utc(birthDate.year, birthDate.month, birthDate.day);
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) {
    return _normalizeBirthDate(value.toUtc());
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return _normalizeBirthDate(parsed.toUtc());
    }
    return null;
  }
  if (value is Map && value.containsKey('_seconds')) {
    final seconds = value['_seconds'];
    if (seconds is num) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      );
      return _normalizeBirthDate(date);
    }
  }
  try {
    final toDate = value as dynamic;
    if (toDate?.toDate is Function) {
      final date = toDate.toDate();
      if (date is DateTime) {
        return _normalizeBirthDate(date.toUtc());
      }
    }
    if (toDate?.toDateTime is Function) {
      final date = toDate.toDateTime();
      if (date is DateTime) {
        return _normalizeBirthDate(date.toUtc());
      }
    }
  } catch (_) {
    // Ignored – fallback to null
  }
  return null;
}

bool _readBool(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

String _collapseWhitespace(String? value) {
  if (value == null) return '';
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).join(' ');
}

List<String> _mergeLists(List<String> a, List<String> b) {
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  final merged = <String>{...a, ...b}
    ..removeWhere((value) => value.trim().isEmpty);
  return merged.toList(growable: false);
}

double _doubleOrZero(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 0;
    final parsed = double.tryParse(normalized);
    if (parsed != null) {
      return parsed;
    }
  }
  return 0;
}

List<String> _safeStringList(dynamic source) {
  if (source == null) return const [];
  if (source is String) {
    return source.isEmpty ? const [] : [source];
  }
  if (source is Iterable) {
    return source
        .map((value) => value.toString())
        .where((value) {
          return value.trim().isNotEmpty;
        })
        .toList(growable: false);
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

Map<String, List<String>> _parseCategoryPermissions(dynamic source) {
  if (source == null) return const {};
  if (source is Map<String, dynamic>) {
    final result = <String, List<String>>{};
    source.forEach((key, value) {
      if (value is List) {
        result[key] = value.map((e) => e.toString()).toList();
      }
    });
    return result;
  }
  if (source is Map) {
    final result = <String, List<String>>{};
    source.forEach((key, value) {
      if (value is List) {
        result[key.toString()] = value.map((e) => e.toString()).toList();
      }
    });
    return result;
  }
  return const {};
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

Map<String, dynamic> _mapFromDynamic(dynamic source) {
  if (source == null) {
    return const <String, dynamic>{};
  }
  if (source is Map<String, dynamic>) {
    return source;
  }
  if (source is Map) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc();
  }
  if (value is num) {
    // Assume seconds since epoch
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).round(),
      isUtc: true,
    );
  }
  if (value is Map && value.containsKey('_seconds')) {
    final seconds = value['_seconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      );
    }
  }
  try {
    final dynamicValue = value as dynamic;
    if (dynamicValue?.toDate is Function) {
      final date = dynamicValue.toDate();
      if (date is DateTime) {
        return date.toUtc();
      }
    }
    if (dynamicValue?.toDateTime is Function) {
      final date = dynamicValue.toDateTime();
      if (date is DateTime) {
        return date.toUtc();
      }
    }
  } catch (_) {
    // ignore
  }
  return null;
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback;
}

List<AdminRoleAssignment> _parseAdminRoles(dynamic source) {
  if (source == null) return const [];
  if (source is Iterable) {
    return source
        .map((item) => AdminRoleAssignment.fromMap(item))
        .toList(growable: false);
  }
  if (source is Map) {
    final now = DateTime.now();
    return source.entries
        .map((entry) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is Map || value is Map<String, dynamic>) {
            final map = _mapFromDynamic(value);
            return AdminRoleAssignment.fromMap({
              'role': map['role'] ?? key,
              'status': map['status'] ?? map['state'] ?? 'active',
              'scope': map['scope'] ?? map['scopes'],
              'grantedAt': map['grantedAt'] ?? map['createdAt'],
              'expiresAt': map['expiresAt'],
            });
          }
          final status = _stringOrNull(value) ?? 'active';
          return AdminRoleAssignment(
            role: key,
            status: status,
            scope: const <String, dynamic>{},
            grantedAt: now,
          );
        })
        .toList(growable: false);
  }
  if (source is String) {
    return [AdminRoleAssignment(role: source, grantedAt: DateTime.now())];
  }
  return const [];
}

List<PendingAdminApproval> _parsePendingApprovals(dynamic source) {
  if (source == null) return const [];
  if (source is Iterable) {
    return source
        .map((item) => PendingAdminApproval.fromMap(item))
        .toList(growable: false);
  }
  if (source is Map) {
    return source.values
        .map((value) => PendingAdminApproval.fromMap(value))
        .where((approval) => approval.id.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

bool _deriveIsSuperAdmin(
  bool? override,
  List<AdminRoleAssignment> roles,
  String email,
) {
  if (override != null) {
    return override;
  }
  if (roles.any((role) => role.isActive && role.role == 'superadmin')) {
    return true;
  }
  return email == 'umityeke@gmail.com';
}
