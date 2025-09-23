import '../models/user_model.dart';

class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._();
  UserService._();

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Kullanıcı veritabanı (gerçek kullanıcılar)
  static final List<User> _users = [];

  Future<bool> login(String username, String password) async {
    // Mock authentication delay
    await Future.delayed(const Duration(seconds: 1));

    final user = _users.firstWhere(
      (u) =>
          u.username.toLowerCase() == username.toLowerCase(),
      orElse: () => User(
        id: '',
        username: '',
        email: '',
        fullName: '',
        krepScore: 0,
        joinDate: DateTime.now(),
        lastActive: DateTime.now(),
        rozetler: [],
        isPremium: false,
      ),
    );

    if (user.id.isNotEmpty) {
      _currentUser = user;
      return true;
    }
    return false;
  }

  Future<bool> register(String username, String email, String password) async {
    // Mock registration delay
    await Future.delayed(const Duration(seconds: 1));

    // Kullanıcı adı kontrolü
    if (_users.any((u) => u.username.toLowerCase() == username.toLowerCase())) {
      return false; // Kullanıcı adı zaten alınmış
    }

    final newUser = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      email: email,
      fullName: username,
      krepScore: 0,
      joinDate: DateTime.now(),
      lastActive: DateTime.now(),
      rozetler: ['Yeni Üye'],
      isPremium: false,
    );

    _users.add(newUser);
    _currentUser = newUser;
    return true;
  }

  void logout() {
    _currentUser = null;
  }

  bool get isLoggedIn => _currentUser != null;

  // Kullanıcı puanını güncelle
  void updateUserPoints(int points) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        krepScore: _currentUser!.krepScore + points,
      );

      // Update in mock database
      final index = _users.indexWhere((u) => u.id == _currentUser!.id);
      if (index != -1) {
        _users[index] = _currentUser!;
      }
    }
  }

  // Bio güncelle
  void updateUserBio(String newBio) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(bio: newBio);

      // Update in mock database
      final index = _users.indexWhere((u) => u.id == _currentUser!.id);
      if (index != -1) {
        _users[index] = _currentUser!;
      }
    }
  }

  // Rozet ekle
  void addBadge(String badge) {
    if (_currentUser != null && !_currentUser!.rozetler.contains(badge)) {
      final updatedBadges = [..._currentUser!.rozetler, badge];
      _currentUser = _currentUser!.copyWith(rozetler: updatedBadges);

      // Update in mock database
      final index = _users.indexWhere((u) => u.id == _currentUser!.id);
      if (index != -1) {
        _users[index] = _currentUser!;
      }
    }
  }

  // Tüm kullanıcıları getir (leaderboard için)
  List<User> getAllUsers() {
    return List.from(_users)
      ..sort((a, b) => b.krepScore.compareTo(a.krepScore));
  }

  // Kullanıcı sıralamasında konumu
  int getUserRank() {
    if (_currentUser == null) return -1;

    final sortedUsers = getAllUsers();
    return sortedUsers.indexWhere((u) => u.id == _currentUser!.id) + 1;
  }

  // Şifre sıfırlama (kullanıcı adı ile)
  Future<bool> resetPassword(String username, String newPassword) async {
    // Mock delay
    await Future.delayed(const Duration(seconds: 2));

    final userIndex = _users.indexWhere(
      (u) => u.username.toLowerCase() == username.toLowerCase(),
    );

    if (userIndex != -1) {
      // Password değişikliği Firebase Auth ile yapılacak
      return true;
    }
    return false;
  }

  // Kullanıcı var mı kontrolü (şifre sıfırlama için)
  bool userExists(String username) {
    return _users.any(
      (u) => u.username.toLowerCase() == username.toLowerCase(),
    );
  }
}
