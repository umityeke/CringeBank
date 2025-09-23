import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._();
  UserService._();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Stream for auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();
  
  // Get current Firebase user
  firebase_auth.User? get firebaseUser => _auth.currentUser;

  Future<bool> login(String username, String password) async {
    try {
      // Firebase Authentication ile email/password ile giriş
      // Username'i email formatına çevir
      String email = username.contains('@') ? username : '$username@cringebank.com';
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Firestore'dan kullanıcı verilerini al
        await _loadUserData(credential.user!.uid);
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> register(String username, String password, {String fullName = ''}) async {
    try {
      // Kullanıcı adı kontrolü
      if (await _isUsernameExists(username)) {
        return false;
      }

      // Firebase Authentication ile kayıt
      String email = username.contains('@') ? username : '$username@cringebank.com';
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Kullanıcı profilini güncelle
        await credential.user!.updateDisplayName(fullName.isEmpty ? username : fullName);
        
        // Firestore'a kullanıcı verilerini kaydet
        final newUser = User(
          id: credential.user!.uid,
          username: username,
          email: email,
          fullName: fullName.isEmpty ? username : fullName,
          krepScore: 0,
          joinDate: DateTime.now(),
          lastActive: DateTime.now(),
          rozetler: ['Yeni Üye'],
          isPremium: false,
        );

        await _saveUserData(newUser);
        _currentUser = newUser;
        return true;
      }
      return false;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // Firestore'dan kullanıcı verilerini yükle
  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = User.fromMap(doc.data()!);
        // Son aktif zamanını güncelle
        await _updateLastActive();
      }
    } catch (e) {
      print('Load user data error: $e');
    }
  }

  // Firestore'a kullanıcı verilerini kaydet
  Future<void> _saveUserData(User user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toMap());
    } catch (e) {
      print('Save user data error: $e');
    }
  }

  // Kullanıcı adının var olup olmadığını kontrol et
  Future<bool> _isUsernameExists(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Check username error: $e');
      return false;
    }
  }

  // Son aktif zamanını güncelle
  Future<void> _updateLastActive() async {
    if (_currentUser != null) {
      try {
        await _firestore.collection('users').doc(_currentUser!.id).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Update last active error: $e');
      }
    }
  }

  bool get isLoggedIn => _currentUser != null;

  // Kullanıcı puanını güncelle
  Future<void> updateUserPoints(int points) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        krepScore: _currentUser!.krepScore + points,
      );

      // Firebase'de güncelle
      try {
        await _firestore.collection('users').doc(_currentUser!.id).update({
          'krepScore': _currentUser!.krepScore,
        });
      } catch (e) {
        print('Update user points error: $e');
      }
    }
  }

  // Bio güncelle
  Future<void> updateUserBio(String newBio) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(bio: newBio);

      // Firebase'de güncelle
      try {
        await _firestore.collection('users').doc(_currentUser!.id).update({
          'bio': newBio,
        });
      } catch (e) {
        print('Update user bio error: $e');
      }
    }
  }

  // Profil güncelle
  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? bio,
  }) async {
    // Mock update delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        fullName: fullName ?? _currentUser!.fullName,
        email: email ?? _currentUser!.email,
        bio: bio ?? _currentUser!.bio,
      );

      // Firebase'de güncelle
      try {
        await _firestore.collection('users').doc(_currentUser!.id).update({
          'fullName': _currentUser!.fullName,
          'email': _currentUser!.email,
          'bio': _currentUser!.bio,
        });
      } catch (e) {
        print('Update profile error: $e');
      }
    }
  }

  // Rozet ekle
  Future<void> addBadge(String badge) async {
    if (_currentUser != null && !_currentUser!.rozetler.contains(badge)) {
      final updatedBadges = [..._currentUser!.rozetler, badge];
      _currentUser = _currentUser!.copyWith(rozetler: updatedBadges);

      // Firebase'de güncelle
      try {
        await _firestore.collection('users').doc(_currentUser!.id).update({
          'rozetler': updatedBadges,
        });
      } catch (e) {
        print('Add badge error: $e');
      }
    }
  }

  // Tüm kullanıcıları getir (leaderboard için)
  Future<List<User>> getAllUsers() async {
    try {
      final query = await _firestore
          .collection('users')
          .orderBy('krepScore', descending: true)
          .get();
      return query.docs.map((doc) => User.fromMap(doc.data())).toList();
    } catch (e) {
      print('Get all users error: $e');
      return [];
    }
  }

  // Kullanıcı sıralamasında konumu
  Future<int> getUserRank() async {
    if (_currentUser == null) return -1;

    final sortedUsers = await getAllUsers();
    return sortedUsers.indexWhere((u) => u.id == _currentUser!.id) + 1;
  }

  // Şifre sıfırlama (email ile)
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Reset password error: $e');
      return false;
    }
  }

  // Kullanıcı var mı kontrolü
  Future<bool> userExists(String username) async {
    return await _isUsernameExists(username);
  }

  // Initialize user service
  Future<void> initialize() async {
    // Eğer zaten giriş yapılmışsa kullanıcı verilerini yükle
    final currentFirebaseUser = _auth.currentUser;
    if (currentFirebaseUser != null) {
      await _loadUserData(currentFirebaseUser.uid);
    }

    // Auth state changes'i dinle
    _auth.authStateChanges().listen((firebase_auth.User? user) async {
      if (user != null) {
        // Kullanıcı giriş yaptı
        await _loadUserData(user.uid);
      } else {
        // Kullanıcı çıkış yaptı
        _currentUser = null;
      }
    });
  }
}
