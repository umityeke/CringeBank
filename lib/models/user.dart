class User {
  final String id;
  final String username;
  final String email;
  final String password;
  final String bio;
  final int utancPuani;
  final int seviye;
  final String avatarUrl;
  final DateTime createdAt;
  final List<String> rozetler;
  final bool isPremium;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.bio = '',
    this.utancPuani = 0,
    this.seviye = 1,
    this.avatarUrl = '',
    required this.createdAt,
    this.rozetler = const [],
    this.isPremium = false,
  });

  // Seviye hesaplama
  String get seviyeAdi {
    if (utancPuani < 100) return 'Utangaç';
    if (utancPuani < 500) return 'Krep';
    if (utancPuani < 1500) return 'Mega Krep';
    if (utancPuani < 5000) return 'Krep Master';
    return 'Cringe Lord';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      password: json['password'],
      bio: json['bio'] ?? '',
      utancPuani: json['utancPuani'] ?? 0,
      seviye: json['seviye'] ?? 1,
      avatarUrl: json['avatarUrl'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      rozetler: List<String>.from(json['rozetler'] ?? []),
      isPremium: json['isPremium'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'bio': bio,
      'utancPuani': utancPuani,
      'seviye': seviye,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'rozetler': rozetler,
      'isPremium': isPremium,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? password,
    String? bio,
    int? utancPuani,
    int? seviye,
    String? avatarUrl,
    DateTime? createdAt,
    List<String>? rozetler,
    bool? isPremium,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      bio: bio ?? this.bio,
      utancPuani: utancPuani ?? this.utancPuani,
      seviye: seviye ?? this.seviye,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      rozetler: rozetler ?? this.rozetler,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}
