// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

// 🏢 ENTERPRISE USER SERVICE WITH ADVANCED AUTHENTICATION & MONITORING
class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._();
  UserService._() {
    _initializeEnterpriseService();
  }

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  final Map<String, User> _userCache = {}; // Enterprise user cache
  DateTime? _lastCacheUpdate;
  bool _isInitialized = false;

  // Enterprise getters with monitoring
  User? get currentUser {
    if (!_isInitialized) {
      print('⚠️ WARNING: Service not fully initialized yet');
    }
    print(
      '🔍 ENTERPRISE ACCESS: Current user requested - ${_currentUser?.displayName ?? 'null'}',
    );
    return _currentUser;
  }

  // Enterprise auth state stream with advanced monitoring
  Stream<firebase_auth.User?> get authStateChanges {
    print('🔄 ENTERPRISE STREAM: Auth state changes stream requested');
    return _auth.authStateChanges().map((user) {
      print(
        '🔐 AUTH STATE CHANGE: ${user?.uid ?? 'null'} (${user?.email ?? 'no email'})',
      );
      _logAuthStateChange(user);
      return user;
    });
  }

  // Enterprise Firebase user with validation
  firebase_auth.User? get firebaseUser {
    final user = _auth.currentUser;
    print(
      '👤 FIREBASE USER ACCESS: ${user?.uid ?? 'null'} - Verified: ${user?.emailVerified ?? false}',
    );
    return user;
  }

  // Initialize enterprise service with monitoring
  void _initializeEnterpriseService() {
    print(
      '🚀 ENTERPRISE INIT: Initializing advanced user service with monitoring',
    );

    // Setup auth state listener with enterprise features
    _auth.authStateChanges().listen((user) {
      _handleEnterpriseAuthStateChange(user);
    });

    // Setup periodic cache cleanup
    Timer.periodic(const Duration(minutes: 15), (_) {
      _performEnterpriseCacheCleanup();
    });

    _isInitialized = true;
    print(
      '✅ ENTERPRISE READY: User service initialized with enterprise features',
    );
  }

  // Handle enterprise auth state changes
  void _handleEnterpriseAuthStateChange(firebase_auth.User? user) async {
    final timestamp = DateTime.now();
    print(
      '🔄 ENTERPRISE AUTH CHANGE: Processing at ${timestamp.toIso8601String()}',
    );

    if (user != null) {
      print('✅ USER SIGNED IN: ${user.uid} - ${user.email}');
      await _loadEnterpriseUserData(user.uid);
      await _updateUserActivity(user.uid);
    } else {
      print('🚪 USER SIGNED OUT: Clearing enterprise cache');
      _currentUser = null;
      _clearEnterpriseCache();
    }

    await _logAuthActivity(user, 'AUTH_STATE_CHANGE');
  }

  // Load enterprise user data with caching
  Future<void> _loadEnterpriseUserData(String userId) async {
    print('📊 LOADING: Enterprise user data for $userId');

    try {
      // Check cache first
      if (_userCache.containsKey(userId) && _isCacheValid()) {
        _currentUser = _userCache[userId];
        print('💾 CACHE HIT: User data loaded from enterprise cache');
        return;
      }

      // Load from Firestore with timeout
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists && doc.data() != null) {
        final user = User.fromMap(doc.data()!);
        _currentUser = user;
        _userCache[userId] = user;
        _lastCacheUpdate = DateTime.now();

        print('✅ FIRESTORE SUCCESS: User data loaded and cached');
      } else {
        print('⚠️ NO USER DATA: Document does not exist for $userId');
      }
    } catch (e) {
      print('❌ LOAD ERROR: Failed to load user data: $e');
      // Use cached data if available
      if (_userCache.containsKey(userId)) {
        _currentUser = _userCache[userId];
        print('💊 FALLBACK: Using cached user data');
      }
    }
  }

  // Check if cache is valid
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final age = DateTime.now().difference(_lastCacheUpdate!);
    final isValid = age.inMinutes < 30; // 30 minute cache TTL
    print('🕒 CACHE CHECK: Age ${age.inMinutes}min - Valid: $isValid');
    return isValid;
  }

  // Update user activity
  Future<void> _updateUserActivity(String userId) async {
    try {
      await _firestore.collection('user_activity').doc(userId).set({
        'lastActive': FieldValue.serverTimestamp(),
        'platform': 'web',
        'sessionStart': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      print('📱 ACTIVITY: Updated user activity for $userId');
    } catch (e) {
      print('⚠️ ACTIVITY ERROR: Failed to update activity: $e');
    }
  }

  // Log authentication activity
  Future<void> _logAuthActivity(firebase_auth.User? user, String action) async {
    try {
      await _firestore.collection('auth_logs').add({
        'userId': user?.uid,
        'email': user?.email,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'web',
        'verified': user?.emailVerified ?? false,
      });

      print('📋 AUTH LOG: Logged $action for ${user?.uid ?? 'anonymous'}');
    } catch (e) {
      print('⚠️ LOG ERROR: Failed to log auth activity: $e');
    }
  }

  // Log auth state changes
  void _logAuthStateChange(firebase_auth.User? user) {
    final timestamp = DateTime.now().toIso8601String();
    if (user != null) {
      print('📊 AUTH ANALYTICS: User ${user.uid} active at $timestamp');
    } else {
      print('📊 AUTH ANALYTICS: User signed out at $timestamp');
    }
  }

  // Perform enterprise cache cleanup
  void _performEnterpriseCacheCleanup() {
    print('🧹 CACHE CLEANUP: Starting enterprise cache maintenance');

    // Remove old cache entries
    final cutoff = DateTime.now().subtract(const Duration(hours: 2));
    if (_lastCacheUpdate != null && _lastCacheUpdate!.isBefore(cutoff)) {
      _userCache.clear();
      _lastCacheUpdate = null;
      print('🗑️ CACHE CLEARED: Old cache data removed');
    }

    print('✅ CLEANUP COMPLETE: Enterprise cache maintenance finished');
  }

  // Clear enterprise cache
  void _clearEnterpriseCache() {
    print('🧹 CLEARING: Enterprise cache data');
    _userCache.clear();
    _lastCacheUpdate = null;
  }

  // 🏢 ENTERPRISE REAL-TIME USER DATA STREAM WITH ADVANCED MONITORING
  Stream<User?> get userDataStream {
    print('🔄 ENTERPRISE STREAM: Initializing advanced user data stream');

    // Check if service is properly initialized
    if (!_isInitialized) {
      print(
        '⚠️ STREAM WARNING: Service not fully initialized, using basic stream',
      );
      return Stream.value(_currentUser);
    }

    // Enterprise multi-source stream with fallback strategies
    return Stream.fromFuture(_initializeEnterpriseUserStream()).asyncExpand((
      initialUser,
    ) {
      return _createEnterpriseUserStream(initialUser);
    });
  }

  // Initialize enterprise user stream
  Future<User?> _initializeEnterpriseUserStream() async {
    print('⚡ STREAM INIT: Starting enterprise user stream initialization');
    final stopwatch = Stopwatch()..start();

    try {
      // Check current Firebase auth state
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        print('👤 NO AUTH: No authenticated user found');
        return null;
      }

      // Check enterprise cache first
      if (_userCache.containsKey(firebaseUser.uid) && _isCacheValid()) {
        print('💾 CACHE HIT: Using cached user data for stream initialization');
        return _userCache[firebaseUser.uid];
      }

      // Load fresh data from Firestore
      final userData = await _loadFreshUserData(firebaseUser.uid);

      final elapsedTime = stopwatch.elapsedMilliseconds;
      print('✅ STREAM INIT SUCCESS: Completed in ${elapsedTime}ms');

      return userData;
    } catch (e) {
      print('❌ STREAM INIT ERROR: $e');
      return _currentUser; // Fallback to cached data
    } finally {
      stopwatch.stop();
    }
  }

  // Create enterprise user stream with monitoring
  Stream<User?> _createEnterpriseUserStream(User? initialUser) {
    return Stream.multi((controller) {
      // Emit initial user data immediately
      controller.add(initialUser);
      print('📊 STREAM EMIT: Initial user data sent to controller');

      StreamSubscription? firestoreSubscription;
      Timer? healthCheckTimer;
      int reconnectAttempts = 0;
      const maxReconnectAttempts = 3;

      void startFirestoreStream() {
        final firebaseUser = _auth.currentUser;
        if (firebaseUser == null) {
          print('🔄 STREAM: No Firebase user, using static stream');
          return;
        }

        print(
          '🔗 CONNECTING: Enterprise Firestore stream for ${firebaseUser.uid}',
        );

        firestoreSubscription = _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .snapshots()
            .timeout(const Duration(seconds: 15)) // Enterprise timeout
            .listen(
              (doc) => _handleEnterpriseUserSnapshot(doc, controller),
              onError: (error) => _handleEnterpriseStreamError(
                error,
                controller,
                () {
                  if (reconnectAttempts < maxReconnectAttempts) {
                    reconnectAttempts++;
                    print(
                      '🔄 RECONNECT: Attempt $reconnectAttempts/$maxReconnectAttempts',
                    );
                    Future.delayed(
                      Duration(seconds: reconnectAttempts * 2),
                      startFirestoreStream,
                    );
                  }
                },
              ),
              onDone: () => print(
                '✅ STREAM COMPLETE: Firestore stream completed normally',
              ),
            );
      }

      // Start the stream
      startFirestoreStream();

      // Enterprise health monitoring
      healthCheckTimer = Timer.periodic(const Duration(minutes: 3), (_) {
        print(
          '🏥 HEALTH CHECK: User stream operational - User: ${_currentUser?.displayName ?? 'null'}',
        );
        _performStreamHealthCheck(controller);
      });

      // Cleanup resources
      controller.onCancel = () {
        print('🧹 CLEANUP: Releasing enterprise user stream resources');
        firestoreSubscription?.cancel();
        healthCheckTimer?.cancel();
      };
    });
  }

  // Load fresh user data with error handling
  Future<User?> _loadFreshUserData(String userId) async {
    try {
      print('📥 LOADING: Fresh user data for $userId');

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists && doc.data() != null) {
        final user = User.fromMap(doc.data()!);
        _currentUser = user;
        _userCache[userId] = user;
        _lastCacheUpdate = DateTime.now();

        print('✅ FRESH DATA: User data loaded and cached');
        return user;
      } else {
        print('⚠️ NO DOCUMENT: User document not found for $userId');
        return _currentUser;
      }
    } catch (e) {
      print('❌ LOAD ERROR: Failed to load fresh user data: $e');
      return _currentUser;
    }
  }

  // Handle enterprise user snapshot
  void _handleEnterpriseUserSnapshot(
    DocumentSnapshot doc,
    MultiStreamController<User?> controller,
  ) {
    final stopwatch = Stopwatch()..start();

    try {
      print('📥 SNAPSHOT: Processing enterprise user data update');

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final user = User.fromMap(data);

        // Update cache and current user
        _currentUser = user;
        _userCache[doc.id] = user;
        _lastCacheUpdate = DateTime.now();

        // Emit updated user data
        controller.add(user);

        final processingTime = stopwatch.elapsedMilliseconds;
        print('✅ SNAPSHOT SUCCESS: User data processed in ${processingTime}ms');

        // Log user activity update
        _logUserDataUpdate(doc.id, user);
      } else {
        print('⚠️ EMPTY SNAPSHOT: Document exists but has no data');
        controller.add(_currentUser);
      }
    } catch (e) {
      print('❌ SNAPSHOT ERROR: Failed to process user snapshot: $e');
      controller.add(_currentUser); // Fallback to cached data
    } finally {
      stopwatch.stop();
    }
  }

  // Handle enterprise stream errors
  void _handleEnterpriseStreamError(
    dynamic error,
    MultiStreamController<User?> controller,
    VoidCallback reconnect,
  ) {
    print('🚨 STREAM ERROR: Enterprise user stream error: $error');

    // Log the error
    _logStreamError(error);

    // Emit cached data as fallback
    controller.add(_currentUser);

    // Attempt reconnection
    print('🔄 RECOVERY: Attempting stream recovery');
    reconnect();
  }

  // Perform stream health check
  void _performStreamHealthCheck(MultiStreamController<User?> controller) {
    try {
      // Check cache validity
      if (!_isCacheValid() && _auth.currentUser != null) {
        print('⚠️ HEALTH: Cache expired, refreshing user data');
        _loadFreshUserData(_auth.currentUser!.uid).then((user) {
          if (user != null) {
            controller.add(user);
          }
        });
      }

      // Check authentication state
      if (_auth.currentUser == null && _currentUser != null) {
        print('🚪 HEALTH: User signed out, clearing data');
        _currentUser = null;
        controller.add(null);
      }
    } catch (e) {
      print('❌ HEALTH CHECK ERROR: $e');
    }
  }

  // Log user data updates
  void _logUserDataUpdate(String userId, User user) async {
    try {
      await _firestore.collection('user_data_logs').add({
        'userId': userId,
        'action': 'DATA_UPDATE',
        'timestamp': FieldValue.serverTimestamp(),
        'displayName': user.displayName,
        'platform': 'web',
      });
    } catch (e) {
      print('⚠️ UPDATE LOG ERROR: Failed to log user data update: $e');
    }
  }

  // Log stream errors
  void _logStreamError(dynamic error) async {
    try {
      await _firestore.collection('stream_error_logs').add({
        'service': 'UserService',
        'stream': 'userDataStream',
        'error': error.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid,
        'platform': 'web',
      });
    } catch (e) {
      print('💥 ERROR LOG FAILED: Cannot log stream error: $e');
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final identifier = username.trim();
      final normalizedIdentifier = identifier.toLowerCase();
      print('Starting login process for: $normalizedIdentifier');

      const emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
      if (!RegExp(emailPattern).hasMatch(identifier)) {
        print('Login failed: invalid email format -> $identifier');
        return false;
      }

      // Firebase Authentication ile giriş
      final String email = normalizedIdentifier;
      print('Attempting Firebase login with: $email');

      try {
        final credential = await _auth
            .signInWithEmailAndPassword(email: email, password: password)
            .timeout(const Duration(seconds: 10));

        if (credential.user != null) {
          print('Firebase login successful: ${credential.user!.uid}');
          await loadUserData(credential.user!.uid);

          // Eğer Firestore'dan yüklenemezse fallback user oluştur
          if (_currentUser == null) {
            print('Creating fallback user for: ${credential.user!.uid}');
            _currentUser = User(
              id: credential.user!.uid,
              username: identifier.contains('@')
                  ? normalizedIdentifier.split('@').first
                  : identifier,
              email: email,
              fullName: identifier.contains('@')
                  ? identifier
                  : normalizedIdentifier,
              krepScore: 0,
              joinDate: DateTime.now(),
              lastActive: DateTime.now(),
              rozetler: ['Yeni Üye'],
              isPremium: false,
              avatar: '👤',
            );
            // Firestore'a kaydet (hata görmezden gel)
            try {
              await _saveUserData(_currentUser!);
            } catch (e) {
              print('Failed to save user data to Firestore: $e');
            }
          }

          print('Login completed, current user: ${_currentUser?.username}');
          return true;
        }
      } catch (firebaseError) {
        print('Firebase authentication failed: $firebaseError');
        // Firebase hatası durumunda false döndür
        return false;
      }

      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> isEmailAvailable(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    return !(await _isEmailRegistered(normalizedEmail));
  }

  Future<bool> isUsernameAvailable(String username) async {
    return !(await _isUsernameExists(username.toLowerCase()));
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    String fullName = '',
  }) async {
    try {
      final rawEmail = email.trim();
      final normalizedEmail = rawEmail.toLowerCase();
      final normalizedUsername = username.trim();
      final usernameLower = normalizedUsername.toLowerCase();

      print(
        'Starting registration for: $normalizedEmail with username $normalizedUsername',
      );

      const emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
      if (!RegExp(emailPattern).hasMatch(rawEmail)) {
        print('Registration failed: invalid email format -> $rawEmail');
        return false;
      }

      // E-posta benzersizliği kontrolü
      if (await _isEmailRegistered(normalizedEmail)) {
        print('Email already registered: $normalizedEmail');
        return false;
      }

      // Kullanıcı adı kontrolü (Firebase'e bağlanmazsa skip et)
      try {
        if (await _isUsernameExists(usernameLower)) {
          print('Username already exists');
          return false;
        }
      } catch (e) {
        print('Username check failed, continuing: $e');
      }

      // Firebase Authentication ile kayıt
      try {
        final credential = await _auth
            .createUserWithEmailAndPassword(
              email: normalizedEmail,
              password: password,
            )
            .timeout(const Duration(seconds: 10));

        if (credential.user != null) {
          // Kullanıcı profilini güncelle
          try {
            await credential.user!.updateDisplayName(
              fullName.isEmpty ? normalizedUsername : fullName,
            );
          } catch (e) {
            print('Failed to update display name: $e');
          }

          // Firestore'a kullanıcı verilerini kaydet
          final newUser = User(
            id: credential.user!.uid,
            username: normalizedUsername,
            email: normalizedEmail,
            fullName: fullName.isEmpty ? normalizedUsername : fullName,
            krepScore: 0,
            joinDate: DateTime.now(),
            lastActive: DateTime.now(),
            rozetler: ['Yeni Üye'],
            isPremium: false,
            avatar: '👤',
            isVerified: true,
          );

          try {
            await _saveUserData(newUser);
          } catch (e) {
            print('Failed to save user data: $e');
          }

          _currentUser = newUser;
          await _logAuthActivity(credential.user, 'REGISTER');
          print('Registration successful');
          return true;
        }
      } catch (firebaseError) {
        print('Firebase registration failed: $firebaseError');
        return false;
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
  Future<void> loadUserData(String uid) async {
    try {
      print('Loading user data for UID: $uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        print('User document exists, loading data...');
        _currentUser = User.fromMap(doc.data()!);
        print('User loaded: ${_currentUser?.username}');
        // Son aktif zamanını güncelle
        await _updateLastActive();
      } else {
        print('User document does not exist for UID: $uid');

        final firebaseUser = _auth.currentUser;
        if (firebaseUser != null) {
          final email = firebaseUser.email ?? '';
          final username = firebaseUser.displayName?.trim().isNotEmpty == true
              ? firebaseUser.displayName!.trim()
              : (email.isNotEmpty
                    ? email.split('@').first
                    : 'user_${firebaseUser.uid.substring(0, 6)}');

          final fallbackUser = User(
            id: firebaseUser.uid,
            username: username,
            email: email,
            fullName: firebaseUser.displayName?.trim() ?? username,
            avatar: firebaseUser.photoURL?.trim().isNotEmpty == true
                ? firebaseUser.photoURL!
                : '👤',
            krepScore: 0,
            joinDate: DateTime.now(),
            lastActive: DateTime.now(),
            rozetler: const ['Yeni Üye'],
            isPremium: false,
            isVerified: firebaseUser.emailVerified,
          );

          try {
            await _saveUserData(fallbackUser);
            print('Fallback user document created for UID: $uid');
          } catch (e) {
            print('Failed to create fallback user document: $e');
          }

          _currentUser = fallbackUser;
          await _updateLastActive();
        }
      }
    } catch (e) {
      print('Load user data error: $e');
    }
  }

  // Firestore'a kullanıcı verilerini kaydet
  Future<void> _saveUserData(User user) async {
    try {
      final data = user.toMap();
      data['usernameLower'] = user.username.toLowerCase();
      data['emailLower'] = user.email.toLowerCase();

      final existing = await _firestore
          .collection('users')
          .where('emailLower', isEqualTo: data['emailLower'])
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty && existing.docs.first.id != user.id) {
        throw StateError('Email already associated with another account');
      }

      await _firestore
          .collection('users')
          .doc(user.id)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print('Save user data error: $e');
    }
  }

  // Kullanıcı adının var olup olmadığını kontrol et
  Future<bool> _isUsernameExists(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('usernameLower', isEqualTo: username.toLowerCase())
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Check username error: $e');
      return false;
    }
  }

  Future<bool> _isEmailRegistered(String emailLower) async {
    final normalized = emailLower.trim().toLowerCase();
    try {
      final query = await _firestore
          .collection('users')
          .where('emailLower', isEqualTo: normalized)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Check email error: $e');
      return true; // Fail-safe: treat as registered when query fails
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
  Future<bool> updateProfile(User updatedUser) async {
    try {
      print('Updating user profile for: ${updatedUser.username}');

      // Firestore'a güncellenen verileri kaydet
      await _saveUserData(updatedUser);

      // Mevcut kullanıcıyı güncelle
      _currentUser = updatedUser;

      print('Profile updated successfully');
      return true;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    }
  }

  // Eski updateProfile metodu (named parameters)
  Future<void> updateProfileOld({
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
      await loadUserData(currentFirebaseUser.uid);
    }

    // Auth state changes'i dinle
    _auth.authStateChanges().listen((firebase_auth.User? user) async {
      if (user != null) {
        // Kullanıcı giriş yaptı
        await loadUserData(user.uid);
      } else {
        // Kullanıcı çıkış yaptı
        _currentUser = null;
      }
    });

    // Otomatik başlangıç kullanıcısı oluşturmayı kaldırdık; gerekliysa manuel tetikleyin.
  }
}
