// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/legal/legal_consent_util.dart';
import '../core/legal/legal_versions.dart';
import '../models/user_model.dart';
import '../utils/search_normalizer.dart';
import '../utils/username_policies.dart';
import '../utils/store_feature_flags.dart';
import 'telemetry/callable_latency_tracker.dart';
import 'telemetry/trace_http_client.dart';

class UsernameCheckResult {
  const UsernameCheckResult({
    required this.input,
    required this.normalized,
    required this.isValid,
    required this.isAvailable,
    this.isOnCooldown = false,
    this.reasons = const <String>[],
    this.nextChangeAt,
    this.cooldown,
  });

  final String input;
  final String normalized;
  final bool isValid;
  final bool isAvailable;
  final bool isOnCooldown;
  final List<String> reasons;
  final DateTime? nextChangeAt;
  final Duration? cooldown;

  bool get canProceed => isValid && isAvailable && !isOnCooldown;
}

class UsernameOperationException implements Exception {
  UsernameOperationException({
    required this.code,
    required this.message,
    this.reasons = const <String>[],
    this.nextChangeAt,
    this.cooldown,
  });

  final String code;
  final String message;
  final List<String> reasons;
  final DateTime? nextChangeAt;
  final Duration? cooldown;

  @override
  String toString() => 'UsernameOperationException($code, $message)';
}

class DisplayNameOperationException implements Exception {
  DisplayNameOperationException({
    required this.code,
    required this.message,
    this.reasons = const <String>[],
    this.nextChangeAt,
    this.cooldown,
  });

  final String code;
  final String message;
  final List<String> reasons;
  final DateTime? nextChangeAt;
  final Duration? cooldown;

  @override
  String toString() => 'DisplayNameOperationException($code, $message)';
}

// 🏢 ENTERPRISE USER SERVICE WITH ADVANCED AUTHENTICATION & MONITORING
class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._();
  UserService._() {
    _initializeEnterpriseService();
  }

  static const String _lastUserIdKey = 'cb_last_user_id';
  static const String _lastUserEmailKey = 'cb_last_user_email';
  static const bool _firestoreLoggingEnabled = false;
  static const String _registrationFinalizeHttpEndpoint =
      'https://europe-west1-cringe-bank.cloudfunctions.net/registrationFinalizeHttp';

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  final TraceHttpClient _traceHttpClient = TraceHttpClient.shared;

  Map<String, dynamic> _normalizeCallableResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      try {
        return Map<String, dynamic>.from(data);
      } catch (_) {
        return data.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return <String, dynamic>{};
  }

  User? _currentUser;
  final Map<String, User> _userCache = {}; // Enterprise user cache
  DateTime? _lastCacheUpdate;
  bool _isInitialized = false;
  Map<String, dynamic>? _cachedDeviceFingerprint;
  final Set<String> _followingIds = <String>{};
  DateTime? _followingCacheUpdatedAt;
  bool _isFollowingCacheLoaded = false;
  bool? _cachedIsModerator;
  DateTime? _moderatorStatusCheckedAt;
  static const Duration _moderatorCacheTtl = Duration(minutes: 5);

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
    final profileVerified = _currentUser?.isVerified;
    print(
      '👤 FIREBASE USER ACCESS: ${user?.uid ?? 'null'} - EmailVerified: ${user?.emailVerified ?? false} | ProfileVerified: ${profileVerified ?? 'unknown'}',
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
      await _persistUserIdentity(user);
      unawaited(isModerator());
    } else {
      print('🚪 USER SIGNED OUT: Clearing enterprise cache');
      _currentUser = null;
      _clearEnterpriseCache();
      await _clearStoredIdentity();
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
        final data = doc.data()!;
        final user = User.fromMap({...data, 'id': doc.id});
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
    if (!_firestoreLoggingEnabled) {
      return;
    }
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
    if (!_firestoreLoggingEnabled) {
      return;
    }
    try {
      final deviceFingerprint = await _getDeviceFingerprint();
      await _firestore.collection('auth_logs').add({
        'userId': user?.uid,
        'email': user?.email,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'web',
        'verified': user?.emailVerified ?? false,
        'device': deviceFingerprint,
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

  void _clearFollowingCache() {
    _followingIds.clear();
    _followingCacheUpdatedAt = null;
    _isFollowingCacheLoaded = false;
  }

  // Clear enterprise cache
  void _clearEnterpriseCache() {
    print('🧹 CLEARING: Enterprise cache data');
    _userCache.clear();
    _lastCacheUpdate = null;
    _clearFollowingCache();
    _cachedIsModerator = null;
    _moderatorStatusCheckedAt = null;
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
            .listen(
              (doc) {
                reconnectAttempts = 0;
                _handleEnterpriseUserSnapshot(doc, controller);
              },
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
        final data = doc.data()!;
        final user = User.fromMap({...data, 'id': doc.id});
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
        final user = User.fromMap({...data, 'id': doc.id});

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
    if (!_firestoreLoggingEnabled) {
      return;
    }
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
    if (!_firestoreLoggingEnabled) {
      return;
    }
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
    final result = await checkUsername(username);
    return result.isValid && result.isAvailable;
  }

  Future<UsernameCheckResult> checkUsername(String username) async {
    final normalizedInput = UsernamePolicies.normalize(username);
    final validation = UsernamePolicies.validate(normalizedInput);
    final current = _currentUser;
    final cooldown = current?.usernameCooldownRemaining;

    if (!validation.isValid) {
      return UsernameCheckResult(
        input: username,
        normalized: normalizedInput,
        isValid: false,
        isAvailable: false,
        isOnCooldown: cooldown != null && cooldown > Duration.zero,
        nextChangeAt: current?.nextUsernameChangeAt,
        cooldown: cooldown,
        reasons: UsernamePolicies.issueMessages(validation),
      );
    }

    try {
      final response = await _functions.callWithLatency<dynamic>(
        'usernameCheck',
        category: 'userAccount',
        payload: <String, dynamic>{'username': normalizedInput},
      );

      final payload = _mapFromResponse(response.data);

      final remoteValid = payload['valid'] != false;
      final remoteAvailable = payload['available'] != false;
      final reasons = _listOfStrings(payload['reasons']);
      final cooldownDuration =
          _durationFromDynamic(payload['cooldown']) ??
          _durationUntil(payload['nextChangeAt']);
      final nextChangeAt =
          _parseFlexibleTimestamp(payload['nextChangeAt']) ??
          current?.nextUsernameChangeAt;
      final isOnCooldown =
          cooldownDuration != null && cooldownDuration > Duration.zero;

      return UsernameCheckResult(
        input: username,
        normalized: normalizedInput,
        isValid: remoteValid,
        isAvailable: remoteAvailable,
        isOnCooldown: isOnCooldown,
        cooldown: cooldownDuration,
        nextChangeAt: nextChangeAt,
        reasons: reasons,
      );
    } on FirebaseFunctionsException catch (error, stack) {
      debugPrint('usernameCheck callable failed: ${error.message}\n$stack');
      return UsernameCheckResult(
        input: username,
        normalized: normalizedInput,
        isValid: false,
        isAvailable: false,
        isOnCooldown: cooldown != null && cooldown > Duration.zero,
        nextChangeAt: current?.nextUsernameChangeAt,
        cooldown: cooldown,
        reasons: <String>[error.message ?? 'Kullanıcı adı kontrolü başarısız.'],
      );
    } catch (error, stack) {
      debugPrint('usernameCheck unexpected error: $error\n$stack');
      return UsernameCheckResult(
        input: username,
        normalized: normalizedInput,
        isValid: false,
        isAvailable: false,
        isOnCooldown: cooldown != null && cooldown > Duration.zero,
        nextChangeAt: current?.nextUsernameChangeAt,
        cooldown: cooldown,
        reasons: <String>['Kullanıcı adı uygunluğu doğrulanamadı.'],
      );
    }
  }

  Future<void> setUsername(String username) async {
    final normalizedInput = UsernamePolicies.normalize(username);
    final validation = UsernamePolicies.validate(normalizedInput);
    final current = _currentUser;

    if (current == null) {
      throw UsernameOperationException(
        code: 'not-authenticated',
        message: 'Kullanıcı oturumu bulunamadı.',
      );
    }

    if (normalizedInput == current.username) {
      return;
    }

    if (!validation.isValid) {
      throw UsernameOperationException(
        code: 'invalid-username',
        message: 'Kullanıcı adı geçersiz.',
        reasons: UsernamePolicies.issueMessages(validation),
      );
    }

    final remainingCooldown = current.usernameCooldownRemaining;
    if (remainingCooldown != null && remainingCooldown > Duration.zero) {
      throw UsernameOperationException(
        code: 'cooldown-active',
        message:
            'Kullanıcı adını tekrar değiştirebilmen için beklemen gerekiyor.',
        cooldown: remainingCooldown,
        nextChangeAt: current.nextUsernameChangeAt,
      );
    }

    try {
      await _functions.callWithLatency<dynamic>(
        'usernameSet',
        category: 'userAccount',
        payload: <String, dynamic>{'username': normalizedInput},
      );

      await refreshCurrentUser(forceRemote: true);
    } on FirebaseFunctionsException catch (error) {
      throw UsernameOperationException(
        code: error.code,
        message:
            error.message ?? 'Kullanıcı adını güncellerken bir sorun oluştu.',
        reasons: _reasonsFromDetails(error.details),
        nextChangeAt: _parseFlexibleTimestamp(
          _valueFromDetails(error.details, 'nextChangeAt'),
        ),
        cooldown: _durationFromDynamic(
          _valueFromDetails(error.details, 'cooldown'),
        ),
      );
    } catch (error) {
      throw UsernameOperationException(
        code: 'unknown',
        message:
            'Kullanıcı adı güncellemesi tamamlanamadı. Lütfen tekrar dene.',
        reasons: <String>[error.toString()],
      );
    }
  }

  Future<void> setDisplayName(String displayName) async {
    final normalizedInput = DisplayNamePolicies.normalize(displayName);
    final validation = DisplayNamePolicies.validate(normalizedInput);
    final current = _currentUser;

    if (current == null) {
      throw DisplayNameOperationException(
        code: 'not-authenticated',
        message: 'Kullanıcı oturumu bulunamadı.',
      );
    }

    if (normalizedInput == current.displayName) {
      return;
    }

    if (!validation.isValid) {
      throw DisplayNameOperationException(
        code: 'invalid-display-name',
        message: 'Görünen ad geçersiz.',
        reasons: DisplayNamePolicies.issueMessages(validation),
      );
    }

    final remainingCooldown = current.displayNameCooldownRemaining;
    if (remainingCooldown != null && remainingCooldown > Duration.zero) {
      throw DisplayNameOperationException(
        code: 'cooldown-active',
        message: 'Adını yeniden düzenleyebilmek için beklemen gerekiyor.',
        cooldown: remainingCooldown,
        nextChangeAt: current.nextDisplayNameChangeAt,
      );
    }

    try {
      await _functions.callWithLatency<dynamic>(
        'displayNameSet',
        category: 'userAccount',
        payload: <String, dynamic>{'displayName': normalizedInput},
      );

      await refreshCurrentUser(forceRemote: true);
    } on FirebaseFunctionsException catch (error) {
      throw DisplayNameOperationException(
        code: error.code,
        message: error.message ?? 'Görünen adı güncellerken bir sorun oluştu.',
        reasons: _reasonsFromDetails(error.details),
        nextChangeAt: _parseFlexibleTimestamp(
          _valueFromDetails(error.details, 'nextChangeAt'),
        ),
        cooldown: _durationFromDynamic(
          _valueFromDetails(error.details, 'cooldown'),
        ),
      );
    } catch (error) {
      throw DisplayNameOperationException(
        code: 'unknown',
        message: 'Adını güncellerken beklenmeyen bir hata oluştu.',
        reasons: <String>[error.toString()],
      );
    }
  }

  Future<User?> refreshCurrentUser({bool forceRemote = false}) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    if (forceRemote) {
      return await _loadFreshUserData(firebaseUser.uid);
    }

    await _loadEnterpriseUserData(firebaseUser.uid);
    return _currentUser;
  }

  Map<String, dynamic> _mapFromResponse(dynamic data) {
    if (data == null) {
      return const <String, dynamic>{};
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  List<String> _listOfStrings(dynamic value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      return <String>[value];
    }
    return const <String>[];
  }

  Duration? _durationFromDynamic(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Duration) {
      return value;
    }
    if (value is num) {
      if (value <= 0) {
        return Duration.zero;
      }
      return Duration(seconds: value.round());
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return Duration(seconds: parsed.round());
      }
    }
    if (value is Map && value.containsKey('seconds')) {
      final seconds = value['seconds'];
      if (seconds is num) {
        return Duration(seconds: seconds.round());
      }
    }
    return null;
  }

  Duration? _durationUntil(dynamic timestamp) {
    final target = _parseFlexibleTimestamp(timestamp);
    if (target == null) {
      return null;
    }
    final now = DateTime.now();
    if (!now.isBefore(target)) {
      return Duration.zero;
    }
    return target.difference(now);
  }

  DateTime? _parseFlexibleTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000).round(),
          isUtc: true,
        ).toLocal();
      }
    }
    return null;
  }

  List<String> _reasonsFromDetails(dynamic details) {
    if (details == null) {
      return const <String>[];
    }
    if (details is List) {
      final extracted = <String>[];
      for (final item in details) {
        if (item is String) {
          extracted.add(item);
        } else if (item is Map && item['message'] is String) {
          extracted.add(item['message'] as String);
        }
      }
      return extracted;
    }
    final map = _mapFromResponse(details);
    final reasons = _listOfStrings(map['reasons']);
    if (reasons.isNotEmpty) {
      return reasons;
    }
    final message = map['message'];
    if (message is String && message.trim().isNotEmpty) {
      return <String>[message.trim()];
    }
    return const <String>[];
  }

  dynamic _valueFromDetails(dynamic details, String key) {
    if (details == null) {
      return null;
    }
    if (details is Map) {
      final map = _mapFromResponse(details);
      return map[key];
    }
    return null;
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    required String sessionId,
    String fullName = '',
    bool marketingOptIn = false,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = username.trim();
    final sanitizedFullName = fullName.trim();

    print(
      'registrationFinalize starting for: $normalizedEmail with username $normalizedUsername',
    );

    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'username': normalizedUsername,
      'password': password,
      'marketingOptIn': marketingOptIn,
    };

    if (sanitizedFullName.isNotEmpty) {
      payload['fullName'] = sanitizedFullName;
    }

    Map<String, dynamic> result;
    try {
      result = await _registrationFinalize(payload);
    } on FirebaseFunctionsException {
      rethrow;
    } catch (error, stack) {
      print('registrationFinalize unexpected error: $error');
      debugPrint('registrationFinalize stack: $stack');
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Kayıt işlemi tamamlanamadı. Lütfen tekrar deneyin.',
        details: error.toString(),
      );
    }

    if (result['success'] != true) {
      final errorCode = result['error']?.toString() ?? 'internal';
      final message = result['message']?.toString() ??
          'Kayıt işlemi tamamlanamadı. Lütfen tekrar deneyin.';
      throw FirebaseFunctionsException(
        code: errorCode,
        message: message,
        details: result,
      );
    }

    final customToken = result['customToken']?.toString();
    if (customToken == null || customToken.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Kayıt işlemi tamamlandı ancak oturum açılamadı.',
        details: result,
      );
    }

    firebase_auth.UserCredential credential;
    try {
      credential = await _auth.signInWithCustomToken(customToken);
    } on firebase_auth.FirebaseAuthException catch (error) {
      print('signInWithCustomToken failed: ${error.code} ${error.message}');
      throw FirebaseFunctionsException(
        code: 'auth-error',
        message: 'Kayıt tamamlandı ancak oturum açılamadı. Lütfen tekrar deneyin.',
        details: {'firebaseCode': error.code, 'message': error.message},
      );
    }

    final firebase_auth.User? firebaseUser = credential.user;
    final uid = firebaseUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw FirebaseFunctionsException(
        code: 'auth-error',
        message: 'Kayıt tamamlandı ancak kullanıcı oturum bilgisi alınamadı.',
        details: result,
      );
    }

    await loadUserData(uid);
    await _logAuthActivity(firebaseUser, 'REGISTER');
    await _applyInitialLegalMetadata(uid);
    print('registrationFinalize completed successfully for $uid');
    return true;
  }

  Future<Map<String, dynamic>> _registrationFinalize(
    Map<String, dynamic> payload,
  ) async {
    try {
      final callableResult = await _functions.callWithLatency<dynamic>(
        'registrationFinalize',
        category: 'registration',
        payload: payload,
      );

      final normalized = _normalizeCallableResponse(callableResult.data);
      if (normalized.isNotEmpty) {
        return normalized;
      }

      if (callableResult.data is Map) {
        return Map<String, dynamic>.from(callableResult.data as Map);
      }

      return const <String, dynamic>{};
    } on MissingPluginException catch (error, stack) {
      debugPrint(
        'Firebase callable registrationFinalize missing plugin, falling back to HTTP: $error\n$stack',
      );
      return _registrationFinalizeViaHttp(payload);
    }
  }

  Future<Map<String, dynamic>> _registrationFinalizeViaHttp(
    Map<String, dynamic> payload,
  ) async {
    TraceHttpResponse traceResponse;
    try {
      traceResponse = await _traceHttpClient.postJson(
        Uri.parse(_registrationFinalizeHttpEndpoint),
        jsonBody: payload,
        operation: 'registration.finalizeHttp',
      );
    } catch (error) {
      print('registrationFinalizeHttp request failed: $error');
      rethrow;
    }

    final response = traceResponse.response;

    Map<String, dynamic>? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (error) {
        print('registrationFinalizeHttp invalid JSON: $error');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorCode = decoded?['error']?.toString() ?? 'internal';
      final message = decoded?['message']?.toString() ??
          'Kayıt işlemi tamamlanamadı. Lütfen tekrar deneyin.';
      throw FirebaseFunctionsException(
        code: errorCode,
        message: message,
        details: decoded,
      );
    }

    return decoded ?? const <String, dynamic>{};
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
      final firebaseUser = _auth.currentUser;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        print('User document exists, loading data...');
        final data = doc.data()!;
        _currentUser = User.fromMap({...data, 'id': doc.id});
        print('User loaded: ${_currentUser?.username}');
        // Son aktif zamanını güncelle
        await _updateLastActive();
        if (firebaseUser != null &&
            firebaseUser.uid.trim() == _currentUser?.id.trim()) {
          await getFollowingIds(forceRefresh: true);
        }
      } else {
        print('User document does not exist for UID: $uid');
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
            await _ensureServerUser(fallbackUser);
            print(
              'Fallback user document created via ensureSqlUser for UID: $uid',
            );
          } on FirebaseFunctionsException catch (error) {
            print(
              'ensureSqlUser fallback creation failed: ${error.code} ${error.message}',
            );
          } catch (e) {
            print(
              'Failed to create fallback user document via ensureSqlUser: $e',
            );
          }

          _currentUser ??= fallbackUser;
          await _updateLastActive();
          await getFollowingIds(forceRefresh: true);
        }
      }
    } catch (e) {
      print('Load user data error: $e');
    }
  }

  Future<void> _applyInitialLegalMetadata(String uid) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      final snapshot = await docRef.get();
      final existing = snapshot.data();
      final updates = buildInitialLegalUpdate(
        existingData: existing,
        claimsVersion: ClaimsVersioning.minimum,
        termsVersion: LegalVersions.termsOfService,
        privacyVersion: LegalVersions.privacyPolicy,
      );

      if (updates.isEmpty) {
        return;
      }

      updates['legalConsentUpdatedAt'] = FieldValue.serverTimestamp();
      await docRef.set(updates, SetOptions(merge: true));
    } catch (error, stack) {
      debugPrint('⚠️ INITIAL LEGAL METADATA FAILED: $error');
      debugPrint('STACK: $stack');
    }
  }

  Future<User?> getUserById(String userId, {bool forceRefresh = false}) async {
    final normalizedId = userId.trim();
    if (normalizedId.isEmpty) {
      print('⚠️ getUserById called with empty userId');
      return null;
    }

    if (!forceRefresh && _userCache.containsKey(normalizedId)) {
      print('💾 getUserById cache hit for $normalizedId');
      return _userCache[normalizedId];
    }

    try {
      print('🔍 Fetching user data for $normalizedId');
      final doc = await _firestore.collection('users').doc(normalizedId).get();

      if (!doc.exists || doc.data() == null) {
        print('⚠️ getUserById: No document found for $normalizedId');
        return _userCache[normalizedId];
      }

      final data = doc.data()!;
      final user = User.fromMap({...data, 'id': doc.id});

      _userCache[normalizedId] = user;
      _lastCacheUpdate = DateTime.now();

      if (_currentUser?.id == normalizedId) {
        _currentUser = user;
      }

      print('✅ getUserById success for $normalizedId');
      return user;
    } catch (e) {
      print('❌ getUserById error for $normalizedId: $e');
      return _userCache[normalizedId];
    }
  }

  Future<Set<String>> getFollowingIds({bool forceRefresh = false}) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _clearFollowingCache();
      return const <String>{};
    }

    final normalizedUid = firebaseUser.uid.trim();
    if (normalizedUid.isEmpty) {
      _clearFollowingCache();
      return const <String>{};
    }

    final now = DateTime.now();
    const cacheTtl = Duration(minutes: 5);

    if (!forceRefresh && _isFollowingCacheLoaded) {
      final cacheAge = _followingCacheUpdatedAt != null
          ? now.difference(_followingCacheUpdatedAt!)
          : cacheTtl + const Duration(seconds: 1);

      if (cacheAge <= cacheTtl) {
        return Set.unmodifiable(_followingIds);
      }
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(normalizedUid)
          .collection('following')
          .get();

      _followingIds
        ..clear()
        ..addAll(
          snapshot.docs
              .map((doc) => doc.id.trim())
              .where((id) => id.isNotEmpty),
        );

      _followingCacheUpdatedAt = now;
      _isFollowingCacheLoaded = true;

      return Set.unmodifiable(_followingIds);
    } catch (e) {
      print('❌ Following cache load error: $e');
      return Set.unmodifiable(_followingIds);
    }
  }

  bool isFollowingCached(String userId) {
    final normalizedId = userId.trim();
    if (normalizedId.isEmpty) return false;
    return _followingIds.contains(normalizedId);
  }

  Future<bool> isFollowing(String userId, {bool forceRefresh = false}) async {
    final firebaseUser = _auth.currentUser;
    final normalizedId = userId.trim();

    if (firebaseUser == null || normalizedId.isEmpty) {
      return false;
    }

    if (firebaseUser.uid.trim() == normalizedId) {
      return false;
    }

    if (!forceRefresh && _isFollowingCacheLoaded) {
      return _followingIds.contains(normalizedId);
    }

    final ids = await getFollowingIds(forceRefresh: forceRefresh);
    return ids.contains(normalizedId);
  }

  Future<bool> followUser(String targetUserId) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('Takip işlemi için önce giriş yapmalısın.');
    }

    final currentUserId = firebaseUser.uid.trim();
    final normalizedTargetId = targetUserId.trim();

    if (normalizedTargetId.isEmpty) {
      throw ArgumentError('Takip edilecek kullanıcı kimliği geçersiz.');
    }

    if (normalizedTargetId == currentUserId) {
      throw StateError('Kendini takip edemezsin.');
    }

    if (_followingIds.contains(normalizedTargetId)) {
      print('ℹ️ followUser: already following $normalizedTargetId');
      return false;
    }

    try {
      final result = await _firestore.runTransaction<bool>((transaction) async {
        final followerRef = _firestore
            .collection('users')
            .doc(normalizedTargetId)
            .collection('followers')
            .doc(currentUserId);

        final followingRef = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(normalizedTargetId);

        final followerSnapshot = await transaction.get(followerRef);
        if (followerSnapshot.exists) {
          return false;
        }

        final timestamp = FieldValue.serverTimestamp();

        transaction.set(followerRef, {
          'followerId': currentUserId,
          'followedAt': timestamp,
        });

        transaction.set(followingRef, {
          'userId': normalizedTargetId,
          'followedAt': timestamp,
        });

        transaction.update(
          _firestore.collection('users').doc(normalizedTargetId),
          {'followersCount': FieldValue.increment(1)},
        );

        transaction.update(_firestore.collection('users').doc(currentUserId), {
          'followingCount': FieldValue.increment(1),
        });

        return true;
      });

      if (result) {
        _followingIds.add(normalizedTargetId);
        _followingCacheUpdatedAt = DateTime.now();
        _isFollowingCacheLoaded = true;

        final currentCached = _currentUser;
        if (currentCached != null && currentCached.id.trim() == currentUserId) {
          final updatedCurrent = currentCached.copyWith(
            followingCount: currentCached.followingCount + 1,
          );
          _currentUser = updatedCurrent;
          _userCache[currentUserId] = updatedCurrent;
        }

        final cachedTarget = _userCache[normalizedTargetId];
        if (cachedTarget != null) {
          final updatedTarget = cachedTarget.copyWith(
            followersCount: cachedTarget.followersCount + 1,
          );
          _userCache[normalizedTargetId] = updatedTarget;
        }
      }

      return result;
    } catch (e) {
      print('❌ followUser error for $targetUserId: $e');
      throw StateError('Takip işlemi başarısız oldu. Lütfen tekrar dene.');
    }
  }

  Future<bool> unfollowUser(String targetUserId) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('Takibi bırakmak için önce giriş yapmalısın.');
    }

    final currentUserId = firebaseUser.uid.trim();
    final normalizedTargetId = targetUserId.trim();

    if (normalizedTargetId.isEmpty) {
      return false;
    }

    if (normalizedTargetId == currentUserId) {
      return false;
    }

    try {
      final result = await _firestore.runTransaction<bool>((transaction) async {
        final followerRef = _firestore
            .collection('users')
            .doc(normalizedTargetId)
            .collection('followers')
            .doc(currentUserId);

        final followingRef = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(normalizedTargetId);

        final followerSnapshot = await transaction.get(followerRef);
        if (!followerSnapshot.exists) {
          return false;
        }

        transaction.delete(followerRef);
        transaction.delete(followingRef);

        transaction.update(
          _firestore.collection('users').doc(normalizedTargetId),
          {'followersCount': FieldValue.increment(-1)},
        );

        transaction.update(_firestore.collection('users').doc(currentUserId), {
          'followingCount': FieldValue.increment(-1),
        });

        return true;
      });

      if (result) {
        _followingIds.remove(normalizedTargetId);
        _followingCacheUpdatedAt = DateTime.now();
        _isFollowingCacheLoaded = true;

        final currentCached = _currentUser;
        if (currentCached != null && currentCached.id.trim() == currentUserId) {
          final updatedFollowingCount = currentCached.followingCount > 0
              ? currentCached.followingCount - 1
              : 0;
          final updatedCurrent = currentCached.copyWith(
            followingCount: updatedFollowingCount,
          );
          _currentUser = updatedCurrent;
          _userCache[currentUserId] = updatedCurrent;
        }

        final cachedTarget = _userCache[normalizedTargetId];
        if (cachedTarget != null) {
          final updatedFollowersCount = cachedTarget.followersCount > 0
              ? cachedTarget.followersCount - 1
              : 0;
          final updatedTarget = cachedTarget.copyWith(
            followersCount: updatedFollowersCount,
          );
          _userCache[normalizedTargetId] = updatedTarget;
        }
      }

      return result;
    } catch (e) {
      print('❌ unfollowUser error for $targetUserId: $e');
      throw StateError(
        'Takibi bırakma işlemi başarısız oldu. Lütfen tekrar dene.',
      );
    }
  }

  // Firestore'a kullanıcı verilerini kaydet
  Future<User?> _ensureServerUser(User user) async {
    final payload = <String, dynamic>{
      'username': user.username,
      'displayName': user.displayName,
      'fullName': user.fullName,
      'email': user.email,
      'avatar': user.avatar,
    };

    if (StoreFeatureFlags.useSqlEscrowGateway) {
      final sqlUser = await _ensureServerUserViaSqlGateway(user, payload);
      if (sqlUser != null) {
        return sqlUser;
      }
      print(
        'Fallback to legacy ensureSqlUser callable after SQL gateway failure',
      );
    }

    return _ensureServerUserViaLegacy(user, payload);
  }

  Future<User?> _ensureServerUserViaSqlGateway(
    User user,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _functions.callWithLatency<dynamic>(
        'sqlGatewayEnsureUser',
        category: 'userSqlGateway',
        payload: payload,
      );
      final data = _normalizeCallableResponse(response.data);

      print(
        'sqlGatewayEnsureUser: completed with created=${data['created']} userId=${data['userId']}',
      );

      Map<String, dynamic>? profile;
      try {
        final profileResponse = await _functions.callWithLatency<dynamic>(
          'sqlGatewayGetUserProfile',
          category: 'userSqlGateway',
          payload: <String, dynamic>{'authUid': user.id},
        );
        final profileData = _normalizeCallableResponse(profileResponse.data);

        if (profileData.isNotEmpty) {
          String pickString(dynamic value, String fallback) {
            if (value == null) return fallback;
            final text = value.toString().trim();
            return text.isEmpty ? fallback : text;
          }

          final merged = Map<String, dynamic>.from(user.toMap())
            ..['id'] = user.id
            ..['username'] = pickString(profileData['username'], user.username)
            ..['displayName'] = pickString(
              profileData['displayName'] ?? profileData['fullName'],
              user.displayName,
            )
            ..['fullName'] = pickString(
              profileData['fullName'] ?? profileData['displayName'],
              user.fullName,
            )
            ..['email'] = pickString(profileData['email'], user.email)
            ..['avatar'] = user.avatar;

          profile = merged;
        }
      } catch (profileError) {
        print('sqlGatewayEnsureUser profile fetch failed: $profileError');
      }

      final ensuredUser = profile != null ? User.fromMap(profile) : user;

      _userCache[user.id] = ensuredUser;
      _currentUser = ensuredUser;
      _lastCacheUpdate = DateTime.now();

      return ensuredUser;
    } on FirebaseFunctionsException catch (error) {
      print(
        'Firebase callable sqlGatewayEnsureUser failed: ${error.code} ${error.message}',
      );
      return null;
    } catch (e) {
      print('Failed to synchronize user data via sqlGatewayEnsureUser: $e');
      return null;
    }
  }

  Future<User?> _ensureServerUserViaLegacy(
    User user,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _functions.callWithLatency<dynamic>(
        'ensureSqlUser',
        category: 'userLegacy',
        payload: payload,
      );
      var ensuredUser = user;

      final responseData = _normalizeCallableResponse(response.data);
      final profileData = responseData['profile'];
      if (profileData is Map) {
        final profile = Map<String, dynamic>.from(profileData)
          ..['id'] = user.id;
        ensuredUser = User.fromMap(profile);
      }

      _userCache[user.id] = ensuredUser;
      _currentUser = ensuredUser;
      _lastCacheUpdate = DateTime.now();
      return ensuredUser;
    } on FirebaseFunctionsException catch (error) {
      print('ensureServerUser failed: ${error.code} ${error.message}');
      rethrow;
    } catch (e) {
      print('ensureServerUser unexpected error: $e');
      return null;
    }
  }

  // Firestore'a kullanıcı verilerini kaydet
  Future<void> _saveUserData(User user) async {
    try {
      final data = user.toMap();
      final normalizedUsername = SearchNormalizer.normalizeForSearch(
        user.username,
      ).replaceAll(RegExp(r'[@\s]+'), '');
      final normalizedFullName = SearchNormalizer.normalizeForSearch(
        user.fullName,
      );
      final normalizedEmail = user.email.trim().toLowerCase();

      data['usernameLower'] = normalizedUsername;
      data['fullNameLower'] = normalizedFullName;
      data['emailLower'] = normalizedEmail;
      data['fullNameTokens'] = normalizedFullName
          .split(' ')
          .where((token) => token.isNotEmpty)
          .toList(growable: false);
      data['searchKeywords'] = SearchNormalizer.generateUserSearchKeywords(
        fullName: user.fullName,
        username: user.username,
        email: user.email,
      );

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
      final firebaseUserId = _auth.currentUser?.uid.trim();
      final targetUserId = updatedUser.id.trim();

      if (firebaseUserId == null || firebaseUserId.isEmpty) {
        print('❌ Update profile denied: No authenticated Firebase user');
        throw StateError('Profil güncellemek için giriş yapmalısın.');
      }

      if (targetUserId.isEmpty || targetUserId != firebaseUserId) {
        print(
          '🚫 Unauthorized profile update attempt: auth=$firebaseUserId target=$targetUserId',
        );
        throw StateError('Yalnızca kendi profilini güncelleyebilirsin.');
      }

      if (_currentUser != null && _currentUser!.id.trim() != targetUserId) {
        print(
          '🚫 Mismatched current user during update: current=${_currentUser!.id} target=$targetUserId',
        );
        throw StateError('Yalnızca kendi profilini güncelleyebilirsin.');
      }

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
      return query.docs.map((doc) {
        final data = doc.data();
        return User.fromMap({...data, 'id': doc.id});
      }).toList();
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
    final result = await checkUsername(username);
    if (!result.isValid) {
      return false;
    }
    return !result.isAvailable;
  }

  // Initialize user service
  Future<void> initialize() async {
    // Eğer zaten giriş yapılmışsa kullanıcı verilerini yükle
    final currentFirebaseUser = _auth.currentUser;
    if (currentFirebaseUser != null) {
      await loadUserData(currentFirebaseUser.uid);
      unawaited(isModerator());
    }

    // Auth state changes'i dinle
    _auth.authStateChanges().listen((firebase_auth.User? user) async {
      if (user != null) {
        // Kullanıcı giriş yaptı
        await loadUserData(user.uid);
        unawaited(isModerator());
      } else {
        // Kullanıcı çıkış yaptı
        _currentUser = null;
        _cachedIsModerator = null;
        _moderatorStatusCheckedAt = null;
      }
    });

    // Otomatik başlangıç kullanıcısı oluşturmayı kaldırdık; gerekliysa manuel tetikleyin.
  }

  Future<void> _persistUserIdentity(firebase_auth.User user) async {
    try {
      await _secureStorage.write(key: _lastUserIdKey, value: user.uid);
      if (user.email != null) {
        await _secureStorage.write(key: _lastUserEmailKey, value: user.email);
      }
    } catch (error) {
      print('⚠️ SECURE STORAGE WRITE FAILED: $error');
    }
  }

  Future<void> _clearStoredIdentity() async {
    try {
      await _secureStorage.delete(key: _lastUserIdKey);
      await _secureStorage.delete(key: _lastUserEmailKey);
    } catch (error) {
      print('⚠️ SECURE STORAGE CLEAR FAILED: $error');
    }
  }

  Future<Map<String, dynamic>> _getDeviceFingerprint() async {
    if (_cachedDeviceFingerprint != null) {
      return _cachedDeviceFingerprint!;
    }

    try {
      if (kIsWeb) {
        final info = await _deviceInfoPlugin.webBrowserInfo;
        _cachedDeviceFingerprint = {
          'browserName': info.browserName.name,
          'userAgent': info.userAgent,
          'platform': info.platform,
        };
      } else {
        final info = await _deviceInfoPlugin.deviceInfo;
        final data = Map<String, dynamic>.from(info.data);
        _cachedDeviceFingerprint = {
          'model': data['model'] ?? data['name'] ?? 'unknown',
          'manufacturer': data['manufacturer'] ?? data['brand'] ?? 'unknown',
          'os':
              data['operatingSystem'] ??
              data['systemVersion'] ??
              data['version'],
        };
      }
    } catch (error) {
      print('⚠️ DEVICE INFO ERROR: $error');
      _cachedDeviceFingerprint = {'error': error.toString()};
    }

    return _cachedDeviceFingerprint!;
  }

  // === MODERATOR FUNCTIONS (Security Contract) ===

  /// Check if current user is a moderator
  /// Security Contract: Moderators have custom claim 'moderator: true'
  Future<bool> isModerator() async {
    final user = _auth.currentUser;
    if (user == null) {
      _cachedIsModerator = false;
      _moderatorStatusCheckedAt = DateTime.now();
      return false;
    }

    final now = DateTime.now();
    if (_cachedIsModerator != null &&
        _moderatorStatusCheckedAt != null &&
        now.difference(_moderatorStatusCheckedAt!) < _moderatorCacheTtl) {
      return _cachedIsModerator!;
    }

    try {
      final idTokenResult = await user.getIdTokenResult();
      final isMod = idTokenResult.claims?['moderator'] == true;
      _cachedIsModerator = isMod;
      _moderatorStatusCheckedAt = now;
      print('🛡️ MODERATOR CHECK: ${user.uid} - $isMod');
      return isMod;
    } catch (e) {
      print('❌ MODERATOR CHECK ERROR: $e');
      _cachedIsModerator ??= false;
      _moderatorStatusCheckedAt ??= now;
      return _cachedIsModerator!;
    }
  }

  /// Get moderator status synchronously (cached in token)
  /// Note: Requires user to have refreshed their token recently
  bool get isModeratorSync {
    return _cachedIsModerator ?? false;
  }

  /// Force token refresh to get latest custom claims
  Future<void> refreshModeratorStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await user.getIdToken(true); // Force refresh
      print('🔄 TOKEN REFRESHED: Custom claims updated');
    } catch (e) {
      print('❌ TOKEN REFRESH ERROR: $e');
    }
  }
}
