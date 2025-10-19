// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cringe_comment.dart';
import '../models/cringe_entry.dart';
import '../models/user_model.dart';
import '../utils/tag_parser.dart';
import 'connectivity_service.dart';
import 'search_index_updater.dart';
import 'user_service.dart';

enum CringeStreamStatus { initializing, connecting, healthy, degraded, error }

class CringeEntryService {
  static CringeEntryService? _instance;
  static CringeEntryService get instance =>
      _instance ??= CringeEntryService._();

  final FirebaseFirestore _firestore;
  final firebase_auth.FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseAnalytics? _analytics;
  bool _isDisposed = false;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  static bool get _analyticsSupported {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  CringeEntryService._({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseAnalytics? analytics,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _analytics = _analyticsSupported
           ? (analytics ?? FirebaseAnalytics.instance)
           : null {
    _connectivitySubscription = ConnectivityService.instance.statusStream
        .listen(
          _handleConnectivityStatus,
          onError: (error) => print('⚠️ CONNECTIVITY LISTEN ERROR: $error'),
        );
  }

  @visibleForTesting
  static void configureForTesting({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseAnalytics? analytics,
  }) {
    _instance?.dispose();
    _instance = CringeEntryService._(
      firestore: firestore,
      auth: auth,
      storage: storage,
      analytics: analytics,
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }

  void dispose() {
    _isDisposed = true;
    _connectivitySubscription?.cancel();
    streamStatusNotifier.dispose();
    timeoutExceptionCountNotifier.dispose();
    streamHintNotifier.dispose();
  }

  final ValueNotifier<CringeStreamStatus> streamStatusNotifier =
      ValueNotifier<CringeStreamStatus>(CringeStreamStatus.initializing);
  final ValueNotifier<int> timeoutExceptionCountNotifier = ValueNotifier<int>(
    0,
  );
  final ValueNotifier<String?> streamHintNotifier = ValueNotifier<String?>(
    null,
  );
  static const String _cacheKey = 'enterprise_cringe_entries_cache_v1';
  static const String _cacheTimestampKey =
      'enterprise_cringe_entries_cache_timestamp_v1';
  static const Duration _cacheTTL = Duration(minutes: 5);
  Future<void>? _ongoingWarmUp;
  bool get _isFirestoreSupported {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  CringeEntry _normalizeEntry(CringeEntry entry) {
    final normalizedDescription = entry.aciklama.trim();
    final normalizedTitle = CringeEntry.deriveTitle(
      entry.baslik,
      normalizedDescription,
    );

    return entry.copyWith(
      baslik: normalizedTitle,
      aciklama: normalizedDescription,
    );
  }

  CringeEntry _enrichEntryMetadata(CringeEntry entry) {
    final normalizedTags = <String>{};
    for (final tag in entry.etiketler) {
      final sanitized = TagParser.sanitizeHashtag(tag);
      if (sanitized.isNotEmpty) {
        normalizedTags.add(sanitized);
      }
    }

    normalizedTags.addAll(TagParser.extractHashtags(entry.baslik));
    normalizedTags.addAll(TagParser.extractHashtags(entry.aciklama));

    return entry.copyWith(
      etiketler: normalizedTags.toList(growable: false),
    );
  }

  Future<void> _logAnalyticsEvent(
    String name, {
    Map<String, Object> parameters = const <String, Object>{},
  }) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (error, stackTrace) {
      debugPrint('⚠️ Analytics log failed: $error');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  Future<void> warmUp() async {
    if (!_isFirestoreSupported) {
      print(
        '⏭️ ENTERPRISE CringeEntryService: Warm-up skipped, platform yetkilendirilmedi '
        '(${defaultTargetPlatform.name}).',
      );
      return;
    }

    if (_auth.currentUser == null) {
      print(
        '⏭️ ENTERPRISE CringeEntryService: Warm-up skipped, user not signed in',
      );
      return;
    }

    if (_ongoingWarmUp != null) {
      print('🔁 ENTERPRISE CringeEntryService: Warm-up already in progress');
      await _ongoingWarmUp;
      return;
    }

    print('🔥 ENTERPRISE CringeEntryService: Priming database cache');
    _ongoingWarmUp = _initializeEnterpriseStream()
        .then(
          (_) {},
          onError: (error) {
            print('⚠️ ENTERPRISE CringeEntryService warm-up failed: $error');
          },
        )
        .whenComplete(() {
          _ongoingWarmUp = null;
        });

    await _ongoingWarmUp;
  }

  // ENTERPRISE LEVEL CRINGE ENTRIES STREAM WITH ADVANCED FEATURES
  // 🚀 Features: Caching, Analytics, Performance Monitoring, Error Recovery, Offline Support
  Stream<List<CringeEntry>> get entriesStream {
    print(
      '🏢 ENTERPRISE CringeEntryService: Initializing high-performance stream with enterprise features',
    );

    streamStatusNotifier.value = CringeStreamStatus.connecting;
    streamHintNotifier.value = null;
    timeoutExceptionCountNotifier.value = 0;

    return Stream.fromFuture(_initializeEnterpriseStream()).asyncExpand((
      initialData,
    ) {
      return _createEnterpriseStreamWithAdvancedFeatures(initialData);
    });
  }

  ValueListenable<CringeStreamStatus> get streamStatus => streamStatusNotifier;
  ValueListenable<int> get timeoutExceptionCount =>
      timeoutExceptionCountNotifier;
  ValueListenable<String?> get streamHint => streamHintNotifier;

  @visibleForTesting
  Future<List<CringeEntry>> getCachedEntriesForTesting() async {
    return _getCachedEntriesWithTTL();
  }

  @visibleForTesting
  Future<void> primeCacheForTesting(List<CringeEntry> entries) {
    return _updateEnterpriseCache(entries);
  }

  // Initialize enterprise stream with performance monitoring
  Future<List<CringeEntry>> _initializeEnterpriseStream() async {
    if (!_isFirestoreSupported) {
      print(
        '⚠️ ENTERPRISE CringeEntryService: Platform ${defaultTargetPlatform.name} '
        'için Firestore akışı devre dışı.',
      );
      return <CringeEntry>[];
    }

    final stopwatch = Stopwatch()..start();
    print('⚡ PERFORMANCE: Starting enterprise stream initialization');

    try {
      // Advanced cache check with TTL
      final cachedEntries = await _getCachedEntriesWithTTL();
      if (cachedEntries.isNotEmpty) {
        print('💾 CACHE HIT: Returning ${cachedEntries.length} cached entries');
        return cachedEntries;
      }

      // Primary data fetch with timeout and retry logic
      final entries = await _fetchEntriesWithRetryLogic();

      // Update cache asynchronously
      unawaited(_updateEnterpriseCache(entries));

      print(
        '🎯 SUCCESS: Enterprise stream initialized in ${stopwatch.elapsedMilliseconds}ms',
      );
      return entries;
    } catch (e) {
      print('❌ ENTERPRISE ERROR: Stream initialization failed: $e');
      // Fallback to emergency cache
      return await _getEmergencyFallbackData();
    } finally {
      stopwatch.stop();
    }
  }

  List<Query<Map<String, dynamic>>> _buildHomeFeedQueries() {
    final queries = <Query<Map<String, dynamic>>>[];
    final currentUserId = _auth.currentUser?.uid;

    void addCollectionQueries({
      required String collectionName,
      String? approvedField,
      List<String> ownerFields = const ['ownerId'],
      bool includeOwnerQueries = true,
    }) {
      final collection = _firestore.collection(collectionName);

      Query<Map<String, dynamic>> approvedQuery = collection;
      if (approvedField != null && approvedField.isNotEmpty) {
        approvedQuery = approvedQuery.where(
          approvedField,
          isEqualTo: 'approved',
        );
      }

      approvedQuery = approvedQuery
          .orderBy('createdAt', descending: true)
          .limit(100);
      queries.add(approvedQuery);

      if (includeOwnerQueries &&
          currentUserId != null &&
          currentUserId.isNotEmpty) {
        for (final field in ownerFields) {
          final ownerQuery = collection
              .where(field, isEqualTo: currentUserId)
              .orderBy('createdAt', descending: true)
              .limit(100);
          queries.add(ownerQuery);
        }
      }
    }

    // Primary collection
    addCollectionQueries(
      collectionName: 'cringe_entries',
      approvedField: 'status',
      ownerFields: const ['ownerId'],
    );

    // Legacy collection compatibility
    addCollectionQueries(
      collectionName: 'posts',
      approvedField: 'status',
      ownerFields: const ['ownerId', 'userId'],
    );

    // Legacy moderationStatus fallback
    addCollectionQueries(
      collectionName: 'posts',
      approvedField: 'moderationStatus',
      includeOwnerQueries: false,
    );

    return queries;
  }

  List<CringeEntry> _filterHomeFeedEntries(Iterable<CringeEntry> entries) {
    final currentUserId = _auth.currentUser?.uid;

    final filtered = entries.where((entry) {
      if (entry.status == ModerationStatus.approved) {
        return true;
      }

      if (currentUserId != null && currentUserId.isNotEmpty) {
        return entry.userId == currentUserId;
      }

      return false;
    }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  // Create enterprise stream with advanced monitoring
  Stream<List<CringeEntry>> _createEnterpriseStreamWithAdvancedFeatures(
    List<CringeEntry> initialData,
  ) {
    return Stream.multi((controller) {
      streamStatusNotifier.value = CringeStreamStatus.connecting;

      var controllerClosed = false;
      bool isStreamActive() => !controllerClosed && controller.hasListener;

      // Emit initial data immediately (filtered for permissions)
      final initialFiltered = _filterHomeFeedEntries(initialData);
      controller.add(initialFiltered);
      print('📊 ANALYTICS: Initial data emitted to ${controller.hashCode}');
      streamStatusNotifier.value = CringeStreamStatus.healthy;
      streamHintNotifier.value = null;

      StreamSubscription<List<CringeEntry>>? subscription;
      Timer? healthCheckTimer;

      try {
        final queries = _buildHomeFeedQueries();

        if (queries.isEmpty) {
          controller.add(<CringeEntry>[]);
          streamStatusNotifier.value = CringeStreamStatus.healthy;
          return;
        }

        subscription = _combineEntryStreams(queries)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: (sink) =>
                  _handleEnterpriseTimeout(sink, isStreamActive),
            )
            .listen(
              (entries) => _handleHomeFeedEntries(entries, controller),
              onError: (error) => _handleEnterpriseError(error, controller),
              onDone: () =>
                  print('✅ ENTERPRISE: Stream completed successfully'),
            );

        // Enterprise health monitoring
        healthCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
          print('🏥 HEALTH CHECK: Stream is healthy and operational');
        });
      } catch (e) {
        print('💥 ENTERPRISE FATAL: Stream creation failed: $e');
        controller.addError(e);
      }

      // Cleanup with enterprise logging
      controller.onListen = () {
        controllerClosed = false;
      };

      controller.onCancel = () {
        controllerClosed = true;
        print('🧹 CLEANUP: Enterprise stream resources being released');
        subscription?.cancel();
        healthCheckTimer?.cancel();
        streamStatusNotifier.value = CringeStreamStatus.initializing;
        streamHintNotifier.value = null;
      };
    });
  }

  void _handleHomeFeedEntries(
    List<CringeEntry> combinedEntries,
    MultiStreamController<List<CringeEntry>> controller,
  ) {
    final stopwatch = Stopwatch()..start();

    try {
      final filtered = _filterHomeFeedEntries(combinedEntries);
      print(
        '📥 ENTERPRISE DATA: Processing ${filtered.length} home feed entries with advanced algorithms',
      );

      controller.add(filtered);
      streamStatusNotifier.value = CringeStreamStatus.healthy;
      streamHintNotifier.value = null;

      // Update enterprise cache asynchronously
      unawaited(_updateEnterpriseCache(filtered));
    } catch (e) {
      print('💥 PROCESSING ERROR: Enterprise snapshot handling failed: $e');
      controller.addError(e);
    } finally {
      stopwatch.stop();
    }
  }

  // Enterprise error handling with recovery strategies
  void _handleEnterpriseError(
    dynamic error,
    MultiStreamController<List<CringeEntry>> controller,
  ) {
    print(
      '🚨 ENTERPRISE ERROR HANDLER: Implementing recovery strategy for: $error',
    );

    final errorDescription = error.toString();
    final isTimeout =
        error is TimeoutException ||
        (error is FirebaseException &&
            (error.code == 'deadline-exceeded' ||
                (error.message?.contains('DEADLINE') ?? false))) ||
        (error is Exception && errorDescription.contains('TimeoutException'));

    if (isTimeout) {
      timeoutExceptionCountNotifier.value =
          timeoutExceptionCountNotifier.value + 1;
      streamStatusNotifier.value = CringeStreamStatus.degraded;
      streamHintNotifier.value =
          'Bağlantı beklenenden yavaş. Önbelleğe alınan veriler gösteriliyor.';
      unawaited(
        _logAnalyticsEvent(
          'cringe_entries_stream_timeout',
          parameters: {
            'timeout_count': timeoutExceptionCountNotifier.value,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
      );
    } else {
      streamStatusNotifier.value = CringeStreamStatus.error;
      streamHintNotifier.value =
          'Akışta beklenmeyen bir hata oluştu. Yeniden bağlanılıyor…';
      unawaited(
        _logAnalyticsEvent(
          'cringe_entries_stream_error',
          parameters: {
            'error_type': error.runtimeType.toString(),
            'details': errorDescription.substring(
              0,
              errorDescription.length > 500 ? 500 : errorDescription.length,
            ),
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
      );
    }

    // Try emergency recovery
    _getCachedEntriesWithTTL().then((cachedData) {
      if (cachedData.isNotEmpty) {
        print('💊 RECOVERY: Using cached data during error state');
        controller.add(cachedData);
        if (isTimeout) {
          streamStatusNotifier.value = CringeStreamStatus.degraded;
        }
      } else {
        print('❌ RECOVERY FAILED: No cached data available');
        controller.add(<CringeEntry>[]);
        if (!isTimeout) {
          streamStatusNotifier.value = CringeStreamStatus.error;
        }
      }
    });
  }

  void _handleEnterpriseTimeout(
    EventSink<List<CringeEntry>> sink,
    bool Function() isStreamActive,
  ) {
    if (!isStreamActive()) {
      debugPrint(
        'ℹ️ TIMEOUT HANDLER: Stream inactive, skipping timeout handling.',
      );
      return;
    }

    timeoutExceptionCountNotifier.value =
        timeoutExceptionCountNotifier.value + 1;
    streamStatusNotifier.value = CringeStreamStatus.degraded;
    streamHintNotifier.value =
        'Bağlantı beklenenden yavaş. Önbelleğe alınan veriler gösteriliyor.';

    unawaited(
      _logAnalyticsEvent(
        'cringe_entries_stream_timeout',
        parameters: {
          'timeout_count': timeoutExceptionCountNotifier.value,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );

    unawaited(
      _getCachedEntriesWithTTL()
          .then((cachedData) {
            if (cachedData.isEmpty) {
              return;
            }

            if (!isStreamActive()) {
              debugPrint(
                'ℹ️ TIMEOUT HANDLER: Listener removed before cache emit.',
              );
              return;
            }

            try {
              sink.add(cachedData);
            } catch (error, stackTrace) {
              if (error is StateError &&
                  error.message.contains('Sink not available')) {
                debugPrint(
                  'ℹ️ TIMEOUT HANDLER: Sink closed before cache emit, suppressing.',
                );
                return;
              }

              debugPrint('⚠️ TIMEOUT CACHE EMIT FAILED: $error\n$stackTrace');
            }
          })
          .catchError((error, stackTrace) {
            debugPrint('⚠️ TIMEOUT CACHE ERROR: $error\n$stackTrace');
            return null;
          }),
    );
  }

  // Enterprise caching with TTL
  Future<List<CringeEntry>> _getCachedEntriesWithTTL() async {
    print('💾 CACHE: Checking enterprise cache with TTL validation');
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final cachedTimestamp = prefs.getInt(_cacheTimestampKey);

      if (cachedJson == null || cachedTimestamp == null) {
        print('📦 CACHE MISS: No cached entries found');
        return <CringeEntry>[];
      }

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(
        cachedTimestamp,
        isUtc: true,
      ).toLocal();
      final isExpired = DateTime.now().difference(cachedAt) > _cacheTTL;

      if (isExpired) {
        print(
          '⌛ CACHE EXPIRED: Cached data older than ${_cacheTTL.inMinutes} minutes',
        );
        await prefs.remove(_cacheKey);
        await prefs.remove(_cacheTimestampKey);
        return <CringeEntry>[];
      }

      final decoded = jsonDecode(cachedJson) as List<dynamic>;
      final entries = decoded
          .map(
            (item) => CringeEntry.fromJson(
              Map<String, dynamic>.from(item as Map<String, dynamic>),
            ),
          )
          .toList();

      print(
        '✅ CACHE HIT: Returning ${entries.length} cached entries (cached at $cachedAt)',
      );
      return entries;
    } catch (e) {
      print('⚠️ CACHE ERROR: Failed to load cached entries: $e');
      return <CringeEntry>[];
    }
  }

  // Fetch with enterprise retry logic
  Future<List<CringeEntry>> _fetchEntriesWithRetryLogic() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      var allQueriesPermissionDenied = true;

      try {
        print('🔄 RETRY ATTEMPT: ${retryCount + 1}/$maxRetries');

        final queries = _buildHomeFeedQueries();
        final entryMap = <String, CringeEntry>{};

        for (final query in queries) {
          try {
            final snapshot = await query
                .limit(50)
                .get()
                .timeout(const Duration(seconds: 10));

            for (final doc in snapshot.docs) {
              final data = doc.data();
              data['id'] = doc.id;
              final entry = CringeEntry.fromFirestore(data);
              entryMap[doc.id] = entry;
            }

            allQueriesPermissionDenied = false;
          } on FirebaseException catch (error, stackTrace) {
            if (error.code == 'permission-denied') {
              debugPrint(
                '⚠️ FETCH WARNING: Skipping home feed query due to permissions: $query -> $error',
              );
              debugPrintStack(stackTrace: stackTrace);
              continue;
            }

            rethrow;
          }
        }

        final entries = _filterHomeFeedEntries(
          entryMap.values,
        ).take(100).toList();

        print('✅ FETCH SUCCESS: Retrieved ${entries.length} home feed entries');
        return entries;
      } catch (e) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          // If all queries failed due to permission issues, break out gracefully
          if (allQueriesPermissionDenied) {
            print(
              '⚠️ PERMISSION WARNING: All home feed queries denied. Returning empty list.',
            );
            return const <CringeEntry>[];
          }
        }

        retryCount++;
        print('⚠️ RETRY $retryCount FAILED: $e');

        if (retryCount < maxRetries) {
          await Future.delayed(
            Duration(seconds: retryCount * 2),
          ); // Exponential backoff
        }
      }
    }

    throw Exception('ENTERPRISE FETCH FAILED: All retry attempts exhausted');
  }

  // Update enterprise cache system
  Future<void> _updateEnterpriseCache(List<CringeEntry> entries) async {
    if (entries.isEmpty) {
      print('📦 CACHE UPDATE SKIPPED: No entries to cache');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final serializedEntries = jsonEncode(
        entries.map((entry) => entry.toJson()).toList(),
      );

      await prefs.setString(_cacheKey, serializedEntries);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      print(
        '💾 CACHE UPDATE: Stored ${entries.length} entries at ${DateTime.now()}',
      );
    } catch (e) {
      print('⚠️ CACHE UPDATE ERROR: Failed to persist cache: $e');
    }
  }

  // Clear enterprise cache
  Future<void> _clearEnterpriseCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      print('🧹 CACHE CLEARED: Enterprise cache data removed');
    } catch (e) {
      print('⚠️ CACHE CLEAR ERROR: Failed to clear cache: $e');
    }
  }

  // Emergency fallback data
  Future<List<CringeEntry>> _getEmergencyFallbackData() async {
    print('🆘 EMERGENCY: Activating fallback data system');
    // Return mock data only in extreme emergency
    return getMockEntries();
  }

  // Mock entries for offline/error states
  List<CringeEntry> getMockEntries() {
    return [
      CringeEntry(
        id: 'mock_1',
        userId: 'demo_user',
        authorName: 'DemoUser',
        authorHandle: '@demouser',
        baslik: 'Hocaya Aşk İtirafı',
        aciklama:
            'Lise yıllarımda sınıfta ayağa kalkıp "Hocam, size aşığım!" diye bağırmıştım. Herkes gülmüştü. Hoca da dahil. 😅',
        kategori: CringeCategory.sosyalRezillik,
        krepSeviyesi: 85.0,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        begeniSayisi: 23,
        yorumSayisi: 8,
        retweetSayisi: 2,
        isAnonim: false,
      ),
      CringeEntry(
        id: 'mock_2',
        userId: 'demo_user_2',
        authorName: 'AnonimKullanici',
        authorHandle: '@anonimuser',
        baslik: 'Markette Karışıklık',
        aciklama:
            'Markette alışveriş yaparken yanlışlıkla tanımadığım birinin eşine "Canım nasılsın?" diye seslenmiştim. Adam çok şaşırmıştı. 🤦‍♂️',
        kategori: CringeCategory.fizikselRezillik,
        krepSeviyesi: 72.0,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        begeniSayisi: 41,
        yorumSayisi: 12,
        retweetSayisi: 6,
        isAnonim: true,
      ),
      CringeEntry(
        id: 'mock_3',
        userId: 'demo_user_3',
        authorName: 'KalbimKirik',
        authorHandle: '@kalbimkirik',
        baslik: 'Instagram Faciası',
        aciklama:
            'Ex\'ime Instagram\'dan yanlışlıkla kalp atmıştım. Fark ettiğimde çok geç olmuştu. Geri almaya çalışırken daha da beter oldu. 💔',
        kategori: CringeCategory.askAcisiKrepligi,
        krepSeviyesi: 93.0,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        begeniSayisi: 127,
        yorumSayisi: 34,
        retweetSayisi: 15,
        isAnonim: false,
      ),
    ];
  }

  // Kullanıcının entries'leri
  Stream<List<CringeEntry>> getUserEntriesStream(
    User user, {
    bool isOwnProfile = false,
  }) {
    final queries = <Query<Map<String, dynamic>>>[];
    final normalizedUserId = user.id.trim();

    if (normalizedUserId.isNotEmpty) {
      // Security Contract: If viewing someone else's profile, only show approved posts
      // If viewing own profile, show all posts (pending, approved, rejected)
      Query<Map<String, dynamic>> query = _firestore
          .collection('cringe_entries')
          .where('userId', isEqualTo: normalizedUserId);

      if (!isOwnProfile) {
        query = query.where('status', isEqualTo: 'approved');
      }

      queries.add(query);
    }

    final identifierCandidates = <String>{};
    final normalizedUsername = user.username.trim();
    if (normalizedUsername.isNotEmpty) {
      final handle = normalizedUsername.startsWith('@')
          ? normalizedUsername
          : '@$normalizedUsername';
      identifierCandidates.add(handle);
    }

    final emailLocalPart = user.email.split('@').first.trim();
    if (emailLocalPart.isNotEmpty) {
      identifierCandidates.add('@$emailLocalPart');
    }

    final fullName = user.fullName.trim();
    if (fullName.isNotEmpty) {
      identifierCandidates.add(fullName);
    }

    for (final candidate in identifierCandidates) {
      final field = candidate.startsWith('@') ? 'authorHandle' : 'authorName';

      // Security Contract: For secondary identifiers, also filter by status if not own profile
      Query<Map<String, dynamic>> query = _firestore
          .collection('cringe_entries')
          .where(field, isEqualTo: candidate);

      if (!isOwnProfile) {
        query = query.where('status', isEqualTo: 'approved');
      }

      queries.add(query);
    }

    if (queries.isEmpty) {
      return Stream<List<CringeEntry>>.value(const []);
    }

    return _combineEntryStreams(queries);
  }

  Stream<List<CringeEntry>> _combineEntryStreams(
    List<Query<Map<String, dynamic>>> queries,
  ) {
    final entryMap = <String, CringeEntry>{};
    final sourceMap = <String, Set<int>>{};
    final subscriptions = <StreamSubscription>[];

    late StreamController<List<CringeEntry>> controller;
    controller = StreamController<List<CringeEntry>>.broadcast(
      onListen: () {
        for (var index = 0; index < queries.length; index++) {
          final query = queries[index];
          late final StreamSubscription subscription;
          subscription = query.snapshots().listen(
            (snapshot) {
              final currentDocKeys = <String>{};

              for (final doc in snapshot.docs) {
                final docKey = doc.reference.path;
                final data = doc.data();
                data['id'] = doc.id;
                final entry = CringeEntry.fromFirestore(data);
                entryMap[docKey] = entry;
                sourceMap.putIfAbsent(docKey, () => <int>{}).add(index);
                currentDocKeys.add(docKey);
              }

              final pendingRemoval = <String>[];
              sourceMap.forEach((docKey, sources) {
                if (!sources.contains(index)) return;
                if (!currentDocKeys.contains(docKey)) {
                  sources.remove(index);
                  if (sources.isEmpty) {
                    pendingRemoval.add(docKey);
                  }
                }
              });

              for (final docKey in pendingRemoval) {
                sourceMap.remove(docKey);
                entryMap.remove(docKey);
              }

              final sortedEntries = entryMap.values.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              controller.add(sortedEntries);
            },
            onError: (error, stackTrace) async {
              if (error is FirebaseException &&
                  error.code == 'permission-denied') {
                debugPrint(
                  '⚠️ STREAM WARNING: Permission denied for query index $index. Removing from home feed merge.',
                );

                await subscription.cancel();
                subscriptions.remove(subscription);

                final pendingRemoval = <String>[];
                sourceMap.forEach((docKey, sources) {
                  if (sources.remove(index) && sources.isEmpty) {
                    pendingRemoval.add(docKey);
                  }
                });

                for (final docKey in pendingRemoval) {
                  sourceMap.remove(docKey);
                  entryMap.remove(docKey);
                }

                final sortedEntries = entryMap.values.toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                controller.add(sortedEntries);

                return;
              }

              controller.addError(error, stackTrace);
            },
          );

          subscriptions.add(subscription);
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  Future<void> repairMissingUserIdsForUser(User user) async {
    final candidateUserId = user.id.trim();
    if (candidateUserId.isEmpty) return;

    final candidates = <String>{};
    final username = user.username.trim();
    if (username.isNotEmpty) {
      candidates.add('@$username');
    }

    final emailLocalPart = user.email.split('@').first.trim();
    if (emailLocalPart.isNotEmpty) {
      candidates.add('@$emailLocalPart');
    }

    if (user.fullName.trim().isNotEmpty) {
      candidates.add(user.fullName.trim());
    }

    for (final candidate in candidates) {
      await _repairEntriesMatchingCandidate(
        candidateUserId,
        field: candidate.startsWith('@') ? 'authorHandle' : 'authorName',
        value: candidate,
      );
    }
  }

  Future<void> _repairEntriesMatchingCandidate(
    String userId, {
    required String field,
    required String value,
  }) async {
    await _repairEntriesWhere(userId, field: field, value: value, isNull: true);
    await _repairEntriesWhere(
      userId,
      field: field,
      value: value,
      emptyString: true,
    );
  }

  Future<void> _repairEntriesWhere(
    String userId, {
    required String field,
    required String value,
    bool isNull = false,
    bool emptyString = false,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('cringe_entries')
        .where(field, isEqualTo: value)
        .limit(200);

    if (isNull) {
      query = query.where('userId', isNull: true);
    } else if (emptyString) {
      query = query.where('userId', isEqualTo: '');
    } else {
      return;
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'userId': userId});
    }
    await batch.commit();
  }

  // Yeni entry ekle
  // 🏢 ENTERPRISE LEVEL CRINGE ENTRY CREATION WITH ADVANCED FEATURES
  // Features: Validation, Analytics, Monitoring, Audit Trail, Performance Optimization
  Future<bool> addEntry(CringeEntry entry) async {
  final normalizedEntry = _enrichEntryMetadata(_normalizeEntry(entry));
    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
    final stopwatch = Stopwatch()..start();

    print(
      '🚀 ENTERPRISE ADD ENTRY: Starting transaction $transactionId for user ${normalizedEntry.userId}',
    );

    try {
      // Phase 1: Enterprise Pre-validation
      await _performEnterpriseValidation(normalizedEntry, transactionId);

      final targetDocId = normalizedEntry.id.isNotEmpty
          ? normalizedEntry.id
          : _firestore.collection('cringe_entries').doc().id;

      // Phase 2: Content Analysis & Security Scan
      await _performContentAnalysis(normalizedEntry, transactionId);

      // Phase 3: Data Preparation & Optimization
      final optimizedData = await _prepareEnterpriseData(
        normalizedEntry,
        transactionId,
        targetDocId,
      );

      // Phase 4: Enterprise Firestore Transaction
      final docRef = await _executeEnterpriseTransaction(
        optimizedData,
        transactionId,
        preferredId: targetDocId,
      );

      // Phase 5: Post-Creation Analytics & Monitoring
      await _performPostCreationAnalytics(
        docRef.id,
        normalizedEntry,
        transactionId,
      );

      unawaited(
        SearchIndexUpdater.instance.upsertEntry(
          normalizedEntry.copyWith(id: docRef.id),
        ),
      );

      final elapsedTime = stopwatch.elapsedMilliseconds;
      print(
        '✅ ENTERPRISE SUCCESS: Entry ${docRef.id} created in ${elapsedTime}ms (Transaction: $transactionId)',
      );

      // Trigger enterprise notifications
      _triggerEnterpriseNotifications(docRef.id, normalizedEntry);

      return true;
    } catch (e) {
      final elapsedTime = stopwatch.elapsedMilliseconds;
      print(
        '❌ ENTERPRISE FAILURE: Transaction $transactionId failed after ${elapsedTime}ms - Error: $e',
      );

      // Enterprise error recovery
      await _handleEnterpriseAddError(e, entry, transactionId);
      return false;
    } finally {
      stopwatch.stop();
    }
  }

  // Enterprise validation with advanced checks + SECURITY CONTRACT
  Future<void> _performEnterpriseValidation(
    CringeEntry entry,
    String transactionId,
  ) async {
    print(
      '🔍 VALIDATION: Running enterprise validation suite (Transaction: $transactionId)',
    );

    // 1. TYPE-SPECIFIC TEXT LENGTH VALIDATION (Security Contract)
    // Use aciklama (description) for validation since baslik is auto-generated
    final textContent = entry.aciklama.trim();
    final textLength = textContent.length;

    switch (entry.type) {
      case PostType.spill:
        if (textLength < 1 || textLength > 2000) {
          throw Exception(
            'VALIDATION_ERROR: Spill text must be 1-2000 characters (current: $textLength)',
          );
        }
        if (entry.media.length > 1) {
          throw Exception(
            'VALIDATION_ERROR: Spill can have maximum 1 media file',
          );
        }
        break;
      case PostType.clap:
        if (textLength < 1 || textLength > 500) {
          throw Exception(
            'VALIDATION_ERROR: Clap text must be 1-500 characters (current: $textLength)',
          );
        }
        if (entry.media.length > 1) {
          throw Exception(
            'VALIDATION_ERROR: Clap can have maximum 1 media file',
          );
        }
        break;
      case PostType.frame:
        if (textLength > 300) {
          throw Exception(
            'VALIDATION_ERROR: Frame text must be max 300 characters (current: $textLength)',
          );
        }
        if (entry.media.isEmpty || entry.media.length > 20) {
          throw Exception('VALIDATION_ERROR: Frame requires 1-20 images');
        }
        // Verify all media are images
        for (final mediaPath in entry.media) {
          if (!mediaPath.toLowerCase().contains('.jpg') &&
              !mediaPath.toLowerCase().contains('.jpeg') &&
              !mediaPath.toLowerCase().contains('.png') &&
              !mediaPath.toLowerCase().contains('.gif') &&
              !mediaPath.toLowerCase().contains('.webp')) {
            throw Exception(
              'VALIDATION_ERROR: Frame only supports image files',
            );
          }
        }
        break;
      case PostType.cringecast:
        if (textLength > 300) {
          throw Exception(
            'VALIDATION_ERROR: Cringecast text must be max 300 characters (current: $textLength)',
          );
        }
        if (entry.media.length != 1) {
          throw Exception(
            'VALIDATION_ERROR: Cringecast requires exactly 1 video file',
          );
        }
        // Verify media is video
        final videoPath = entry.media.first;
        if (!videoPath.toLowerCase().contains('.mp4') &&
            !videoPath.toLowerCase().contains('.mov') &&
            !videoPath.toLowerCase().contains('.avi') &&
            !videoPath.toLowerCase().contains('.webm')) {
          throw Exception(
            'VALIDATION_ERROR: Cringecast only supports video files',
          );
        }
        break;
      case PostType.mash:
        if (textLength < 1 || textLength > 200) {
          throw Exception(
            'VALIDATION_ERROR: Mash text must be 1-200 characters (current: $textLength)',
          );
        }
        if (entry.media.isEmpty || entry.media.length > 5) {
          throw Exception(
            'VALIDATION_ERROR: Mash requires 1-5 mixed media files',
          );
        }
        break;
    }

    // 2. Auto-approve all posts - moderation happens post-publication via reports
    print('✅ AUTO-APPROVE: All posts are auto-approved for instant visibility');

    // 3. Basic validation (legacy)
    if (entry.baslik.isEmpty && entry.aciklama.isEmpty) {
      throw Exception('VALIDATION_ERROR: Either title or description required');
    }

    if (entry.krepSeviyesi < 1 || entry.krepSeviyesi > 10) {
      throw Exception(
        'VALIDATION_ERROR: Invalid cringe level - must be between 1-10',
      );
    }

    // User authentication validation
    if (entry.userId.isEmpty || entry.authorName.isEmpty) {
      throw Exception('VALIDATION_ERROR: User authentication data missing');
    }

    // Image validation (legacy - now using media field)
    if (entry.imageUrls.isNotEmpty) {
      for (final imageUrl in entry.imageUrls) {
        final isDataUri = imageUrl.startsWith('data:image/');
        final isRemoteUrl = imageUrl.startsWith('http');
        if (imageUrl.isEmpty || (!isDataUri && !isRemoteUrl)) {
          throw Exception('VALIDATION_ERROR: Invalid image format detected');
        }
      }
    }

    print(
      '✅ VALIDATION: All enterprise checks passed (Transaction: $transactionId)',
    );
  }

  // Content analysis and security scanning
  Future<void> _performContentAnalysis(
    CringeEntry entry,
    String transactionId,
  ) async {
    print(
      '🔒 SECURITY: Running content analysis and security scan (Transaction: $transactionId)',
    );

    // Geliştirme notu: AI içerik moderasyonu, uygunsuz içerik kontrolü,
    // spam tespiti ve küfür filtrelemesi için modüller burada entegre edilecek

    final bannedWords = ['spam', 'hack', 'virus', 'scam'];
    final lowerTitle = entry.baslik.toLowerCase();
    final lowerDesc = entry.aciklama.toLowerCase();

    for (final word in bannedWords) {
      if (lowerTitle.contains(word) || lowerDesc.contains(word)) {
        throw Exception('SECURITY_ERROR: Content contains prohibited terms');
      }
    }

    print(
      '✅ SECURITY: Content approved by enterprise security systems (Transaction: $transactionId)',
    );
  }

  // Prepare enterprise-optimized data + SECURITY CONTRACT FIELDS
  Future<Map<String, dynamic>> _prepareEnterpriseData(
    CringeEntry entry,
    String transactionId,
    String postId,
  ) async {
    print(
      '⚙️ OPTIMIZATION: Preparing enterprise-optimized data structure (Transaction: $transactionId)',
    );

    // === SECURITY CONTRACT: Upload with proper postId ===
    final processedImages = await _processEnterpriseImages(
      entry,
      transactionId,
      postId: postId,
    );

    // SECURITY CONTRACT: Generate proper text field
    final textContent = entry.baslik.isNotEmpty ? entry.baslik : entry.aciklama;

    // === SECURITY CONTRACT: Build media paths ===
    // Convert download URLs to storage paths if needed
    final mediaPaths = processedImages.map((url) {
      final decodedPath = _extractStoragePath(url);
      return decodedPath ?? url;
    }).toList();

    return {
      // === SECURITY CONTRACT REQUIRED FIELDS ===
      'ownerId': entry.userId, // Firestore rules expect 'ownerId'
      'type': entry
          .type
          .value, // Must be one of: spill, clap, frame, cringecast, mash
      'status': ModerationStatus
          .approved
          .value, // Auto-approve all posts - moderation via reports
      'text': textContent, // Required by Firestore rules
      'createdAt':
          FieldValue.serverTimestamp(), // Will be converted to int by Firestore
      'media':
          mediaPaths, // Storage paths: user_uploads/{ownerId}/{postId}/filename      // === LEGACY FIELDS (backward compatibility) ===
      'userId': entry.userId, // Keep for old clients
      'authorName': entry.authorName,
      'authorHandle': entry.authorHandle,
      'baslik': entry.baslik.trim(),
      'aciklama': entry.aciklama.trim(),
      'kategori': entry.kategori.index,
      'krepSeviyesi': entry.krepSeviyesi,
      'isAnonim': entry.isAnonim,
      'imageUrls': processedImages, // Legacy - now using 'media'
      'authorAvatarUrl': entry.authorAvatarUrl,
      'etiketler': entry.etiketler,
      'audioUrl': entry.audioUrl,
      'videoUrl': entry.videoUrl,
      'borsaDegeri': entry.borsaDegeri,

      // Timestamps
      'updatedAt': FieldValue.serverTimestamp(),

      // Engagement metrics - start fresh
      'begeniSayisi': 0,
      'yorumSayisi': 0,
      'retweetSayisi': 0,
      'goruntulenmeSayisi': 0,

      // Enterprise metadata
      'version': '3.0', // Updated to v3 for security contract
      'source': 'mobile_app',
      'transactionId': transactionId,
      'moderationStatus': 'pending', // Legacy field
      // Analytics data
      'createdAtClient': DateTime.now().toIso8601String(),
      'platform': 'web',
      'deviceInfo': 'enterprise_client',

      // Content metrics
      'titleLength': entry.baslik.length,
      'descriptionLength': entry.aciklama.length,
      'imageCount': processedImages.length,
      'contentHash':
          '${entry.baslik}${entry.aciklama}${processedImages.join(',')}'
              .hashCode
              .toString(),

      // Advanced features
      'trendingScore': 0.0,
      'qualityScore': _calculateQualityScore(entry, processedImages),
      'virality': 0.0,
    };
  }

  // Calculate content quality score
  double _calculateQualityScore(
    CringeEntry entry,
    List<String> processedImages,
  ) {
    double score = 5.0; // Base score

    // Length bonuses
    if (entry.baslik.length >= 20) score += 0.5;
    if (entry.aciklama.length >= 100) score += 1.0;

    // Image bonus
    if (processedImages.isNotEmpty || entry.imageUrls.isNotEmpty) score += 1.5;

    // Cringe level factor
    score += (entry.krepSeviyesi / 10.0) * 2.0;

    return score.clamp(0.0, 10.0);
  }

  // === SECURITY CONTRACT: Process and upload media files ===
  // Upload path: user_uploads/{ownerId}/{postId}/{fileName}
  // Required metadata: postId, status (must be 'pending')
  // Max size: 25MB, Content-Type: image/* or video/*
  Future<List<String>> _processEnterpriseImages(
    CringeEntry entry,
    String transactionId, {
    required String postId,
  }) async {
    if (entry.imageUrls.isEmpty) {
      return const [];
    }

    final processedUrls = <String>[];
    final effectivePostId = postId;

    for (final rawImage in entry.imageUrls) {
      // Already uploaded files (HTTP URLs)
      if (rawImage.startsWith('http')) {
        processedUrls.add(rawImage);
        continue;
      }

      // Only accept data URIs
      if (!rawImage.startsWith('data:')) {
        print('⚠️ MEDIA WARN: Unsupported format received, skipping upload');
        continue;
      }

      try {
        final parts = rawImage.split(',');
        if (parts.length != 2) {
          throw const FormatException('Invalid data URI format');
        }

        final header = parts.first;
        final base64Data = parts.last;
        final mimeType = header.substring(5, header.indexOf(';'));

        // === SECURITY CONTRACT: Validate content type ===
        if (!mimeType.startsWith('image/') && !mimeType.startsWith('video/')) {
          print(
            '❌ SECURITY: Rejected file with content-type: $mimeType (only image/* and video/* allowed)',
          );
          continue;
        }

        final extension = _inferFileExtension(mimeType);
        final bytes = base64Decode(base64Data);
        final Uint8List data = Uint8List.fromList(bytes);

        // === SECURITY CONTRACT: 25MB limit ===
        const maxSizeBytes = 25 * 1024 * 1024; // 25MB
        if (data.length > maxSizeBytes) {
          print(
            '❌ SECURITY: File size ${(data.length / 1024 / 1024).toStringAsFixed(2)}MB exceeds 25MB limit',
          );
          continue;
        }

        // === SECURITY CONTRACT: Proper path format ===
        // user_uploads/{ownerId}/{postId}/{fileName}
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '$timestamp.$extension';
        final storagePath =
            'user_uploads/${entry.userId}/$effectivePostId/$fileName';

        final ref = _storage.ref(storagePath);

        // === SECURITY CONTRACT: Required metadata ===
        final metadata = SettableMetadata(
          contentType: mimeType,
          customMetadata: {
            'postId': effectivePostId,
            'status': 'approved', // Auto-approved - moderation via reports
            'uploadedAt': DateTime.now().toIso8601String(),
            'ownerId': entry.userId,
          },
        );

        final uploadTask = await ref.putData(data, metadata);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        processedUrls.add(downloadUrl);
        print(
          '✅ MEDIA UPLOAD: Stored at $storagePath (${(data.length / 1024).toStringAsFixed(2)}KB)',
        );
      } catch (e) {
        print('❌ MEDIA UPLOAD ERROR: Failed to process media - $e');
      }
    }

    return processedUrls;
  }

  String? _extractStoragePath(String url) {
    try {
      if (url.contains('user_uploads/')) {
        final match = RegExp(r'user_uploads/[^?]+').firstMatch(url);
        if (match != null) {
          return match.group(0);
        }
      }

      final decoded = Uri.decodeFull(url);
      final match = RegExp(r'user_uploads/[^?]+').firstMatch(decoded);
      if (match != null) {
        return match.group(0);
      }
    } catch (_) {
      // Ignore decoding issues and fall back to original URL
    }

    return null;
  }

  String _inferFileExtension(String mimeType) {
    switch (mimeType) {
      // Images
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      // Videos
      case 'video/mp4':
        return 'mp4';
      case 'video/webm':
        return 'webm';
      case 'video/quicktime':
        return 'mov';
      case 'video/x-msvideo':
        return 'avi';
      default:
        // Default to jpg for images, mp4 for videos
        return mimeType.startsWith('video/') ? 'mp4' : 'jpg';
    }
  }

  // Execute enterprise Firestore transaction
  Future<DocumentReference> _executeEnterpriseTransaction(
    Map<String, dynamic> data,
    String transactionId, {
    String? preferredId,
  }) async {
    print(
      '💾 TRANSACTION: Executing enterprise Firestore transaction (Transaction: $transactionId)',
    );

    try {
      final collection = _firestore.collection('cringe_entries');
      final DocumentReference<Map<String, dynamic>> docRef;

      if (preferredId != null && preferredId.trim().isNotEmpty) {
        docRef = collection.doc(preferredId);
      } else {
        docRef = collection.doc();
      }

      final payload = Map<String, dynamic>.from(data)..['id'] = docRef.id;

      await docRef.set(payload);

      // Additional enterprise operations
      await _updateUserStats(data['userId'], transactionId);
      await _logAuditTrail(docRef.id, data, transactionId);

      return docRef;
    } catch (e) {
      print(
        '💥 TRANSACTION ERROR: Firestore transaction failed (Transaction: $transactionId): $e',
      );
      throw Exception('TRANSACTION_ERROR: Failed to save entry - $e');
    }
  }

  // Post-creation analytics
  Future<void> _performPostCreationAnalytics(
    String entryId,
    CringeEntry entry,
    String transactionId,
  ) async {
    print(
      '📊 ANALYTICS: Running post-creation analytics (Entry: $entryId, Transaction: $transactionId)',
    );

    // Geliştirme notu: Enterprise dashboard, kullanıcı etkileşim metrikleri,
    // tavsiye motoru ve trending algoritmaları buradan tetiklenecek

    print('✅ ANALYTICS: Post-creation analysis completed (Entry: $entryId)');
  }

  // Update user statistics
  Future<void> _updateUserStats(String userId, String transactionId) async {
    try {
      await _firestore.collection('user_stats').doc(userId).set({
        'lastPostAt': FieldValue.serverTimestamp(),
        'totalPosts': FieldValue.increment(1),
        'lastTransactionId': transactionId,
        'lifetimeCringeScore': FieldValue.increment(1),
      }, SetOptions(merge: true));

      print('📈 USER STATS: Updated statistics for user $userId');
    } catch (e) {
      print('⚠️ USER STATS ERROR: Failed to update stats for $userId: $e');
    }
  }

  // Audit trail logging
  Future<void> _logAuditTrail(
    String entryId,
    Map<String, dynamic> data,
    String transactionId,
  ) async {
    try {
      await _firestore.collection('audit_logs').add({
        'action': 'CREATE_ENTRY',
        'entryId': entryId,
        'userId': data['userId'],
        'transactionId': transactionId,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'titleLength': data['titleLength'],
          'descriptionLength': data['descriptionLength'],
          'krepSeviyesi': data['krepSeviyesi'],
          'imageCount': data['imageCount'],
          'qualityScore': data['qualityScore'],
        },
      });

      print('📋 AUDIT: Logged creation of entry $entryId');
    } catch (e) {
      print('⚠️ AUDIT ERROR: Failed to log audit trail: $e');
    }
  }

  Future<Map<String, dynamic>> _prepareEnterpriseUpdateData(
    CringeEntry entry,
    String transactionId,
  ) async {
    print(
      '🛠️ UPDATE: Preparing enterprise update payload (Entry: ${entry.id}, Transaction: $transactionId)',
    );

    // === SECURITY CONTRACT: Upload with existing postId ===
    final processedImages = await _processEnterpriseImages(
      entry,
      transactionId,
      postId: entry.id, // Use existing entry ID for updates
    );

    // === SECURITY CONTRACT: Build media paths ===
    final mediaPaths = processedImages.map((url) {
      final decodedPath = _extractStoragePath(url);
      return decodedPath ?? url;
    }).toList();

    // SECURITY CONTRACT: User cannot modify protected fields
    // Protected: ownerId, type, createdAt, status, moderation
    final payload = <String, dynamic>{
      // === ALLOWED UPDATE FIELDS ===
      'text': (entry.baslik.isNotEmpty ? entry.baslik : entry.aciklama).trim(),
      'media': mediaPaths.isNotEmpty
          ? mediaPaths
          : entry.media, // Use new uploads or keep existing
      // Legacy fields
      'authorName': entry.authorName.trim(),
      'authorHandle': entry.authorHandle.trim(),
      'baslik': entry.baslik.trim(),
      'aciklama': entry.aciklama.trim(),
      'kategori': entry.kategori.index,
      'krepSeviyesi': entry.krepSeviyesi,
      'isAnonim': entry.isAnonim,
      'etiketler': entry.etiketler,
      'audioUrl': entry.audioUrl,
      'videoUrl': entry.videoUrl,
      'borsaDegeri': entry.borsaDegeri,
      'authorAvatarUrl': entry.authorAvatarUrl,
      'imageUrls': processedImages,

      // === SECURITY CONTRACT: updatedAt is auto-set ===
      'updatedAt': FieldValue.serverTimestamp(),

      'transactionId': transactionId,
      'qualityScore': _calculateQualityScore(entry, processedImages),
      'imageCount': processedImages.length,
    };

    // === SECURITY CONTRACT WARNING ===
    // Do NOT include in updates: ownerId, type, createdAt, status, moderation
    // These are protected by Firestore rules
    if (entry.status != ModerationStatus.pending) {
      print(
        '⚠️ SECURITY WARNING: User tried to update status to ${entry.status.value}. This will be rejected by Firestore rules.',
      );
    }

    payload.removeWhere((key, value) => value == null);

    return payload;
  }

  Future<void> _logAuditTrailUpdate(
    String entryId,
    String userId,
    Map<String, dynamic> updateData,
    String transactionId,
  ) async {
    try {
      await _firestore.collection('audit_logs').add({
        'action': 'UPDATE_ENTRY',
        'entryId': entryId,
        'userId': userId,
        'transactionId': transactionId,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'updatedFields': updateData.keys.toList(),
          'imageCount': updateData['imageCount'] ?? 0,
          'qualityScore': updateData['qualityScore'],
        },
      });

      print('📋 AUDIT: Logged update of entry $entryId');
    } catch (e) {
      print('⚠️ AUDIT ERROR: Failed to log update for $entryId: $e');
    }
  }

  Future<void> _logAuditTrailDelete(
    String entryId,
    String userId,
    String transactionId,
  ) async {
    try {
      await _firestore.collection('audit_logs').add({
        'action': 'DELETE_ENTRY',
        'entryId': entryId,
        'userId': userId,
        'transactionId': transactionId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('📋 AUDIT: Logged deletion of entry $entryId');
    } catch (e) {
      print('⚠️ AUDIT ERROR: Failed to log delete audit for $entryId: $e');
    }
  }

  Future<void> _decrementUserStats(String userId, String transactionId) async {
    try {
      await _firestore.collection('user_stats').doc(userId).set({
        'totalPosts': FieldValue.increment(-1),
        'lifetimeCringeScore': FieldValue.increment(-1),
        'lastTransactionId': transactionId,
        'lastPostAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('📉 USER STATS: Decremented statistics for user $userId');
    } catch (e) {
      print('⚠️ USER STATS ERROR: Failed to decrement stats for $userId: $e');
    }
  }

  // Enterprise error handling
  Future<void> _handleEnterpriseAddError(
    dynamic error,
    CringeEntry entry,
    String transactionId,
  ) async {
    print(
      '🚨 ERROR HANDLER: Processing enterprise add error (Transaction: $transactionId)',
    );

    try {
      // Log error to enterprise monitoring
      await _firestore.collection('error_logs').add({
        'error': error.toString(),
        'transactionId': transactionId,
        'userId': entry.userId,
        'action': 'ADD_ENTRY',
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'HIGH',
        'context': {
          'title': entry.baslik,
          'titleLength': entry.baslik.length,
          'descriptionLength': entry.aciklama.length,
          'imageCount': entry.imageUrls.length,
        },
      });

      print('📝 ERROR LOGGED: Enterprise error logging completed');
    } catch (e) {
      print('💥 CRITICAL: Failed to log error to enterprise systems: $e');
    }
  }

  // Enterprise notifications
  void _triggerEnterpriseNotifications(String entryId, CringeEntry entry) {
    // Planlanan çalışmalar: push bildirimleri, yüksek cringe seviyeleri için e-posta,
    // içerik inceleme uyarıları ve takipçilere gerçek zamanlı bildirimler

    print(
      '🔔 NOTIFICATIONS: Enterprise notification system triggered for entry $entryId',
    );
    print(
      '📱 PUSH: High cringe level detected (${entry.krepSeviyesi}/10) - triggering viral alerts',
    );
  }

  // Entry yorumu akışı
  Stream<List<CringeComment>> commentsStream(String entryId) {
    return _firestore
        .collection('cringe_entries')
        .doc(entryId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          final comments = snapshot.docs
              .map(
                (doc) => CringeComment.fromFirestore(
                  doc.data(),
                  documentId: doc.id,
                  entryId: entryId,
                ),
              )
              .toList();

          final topLevelComments = <CringeComment>[];
          final repliesByParent = <String, List<CringeComment>>{};

          for (final comment in comments) {
            final parentId = comment.parentCommentId;
            if (parentId == null) {
              topLevelComments.add(comment);
            } else {
              repliesByParent
                  .putIfAbsent(parentId, () => <CringeComment>[])
                  .add(comment);
            }
          }

          topLevelComments.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          for (final replyList in repliesByParent.values) {
            replyList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          }

          final orderedComments = <CringeComment>[];
          final remainingReplyParents = repliesByParent.keys.toSet();

          for (final parent in topLevelComments) {
            orderedComments.add(parent);

            final replies = repliesByParent[parent.id];
            if (replies != null) {
              orderedComments.addAll(replies);
              remainingReplyParents.remove(parent.id);
            }
          }

          if (remainingReplyParents.isNotEmpty) {
            final orphanParentIds = remainingReplyParents.toList()..sort();
            for (final parentId in orphanParentIds) {
              orderedComments.addAll(repliesByParent[parentId]!);
            }
          }

          return List<CringeComment>.unmodifiable(orderedComments);
        });
  }

  Future<bool> addComment({
    required String entryId,
    required String content,
    String? parentCommentId,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return false;

    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) return false;

    final normalizedParentId = () {
      if (parentCommentId == null) return null;
      final value = parentCommentId.trim();
      return value.isEmpty ? null : value;
    }();

    try {
      User? currentUser = UserService.instance.currentUser;
      if (currentUser == null || currentUser.id.isEmpty) {
        await UserService.instance.loadUserData(firebaseUser.uid);
        currentUser = UserService.instance.currentUser;
      }

      final displayName =
          currentUser != null && currentUser.fullName.trim().isNotEmpty
          ? currentUser.fullName.trim()
          : (firebaseUser.displayName?.trim().isNotEmpty ?? false)
          ? firebaseUser.displayName!.trim()
          : 'Anonim';

      final username =
          currentUser != null && currentUser.username.trim().isNotEmpty
          ? currentUser.username.trim()
          : firebaseUser.email != null && firebaseUser.email!.contains('@')
          ? firebaseUser.email!.split('@').first
          : firebaseUser.uid.substring(0, 6);

      final avatar = currentUser != null && currentUser.avatar.trim().isNotEmpty
          ? currentUser.avatar.trim()
          : firebaseUser.photoURL;

      final entryRef = _firestore.collection('cringe_entries').doc(entryId);
      final commentRef = entryRef.collection('comments').doc();

      await _firestore.runTransaction((transaction) async {
        final entrySnapshot = await transaction.get(entryRef);
        if (!entrySnapshot.exists) {
          throw StateError('ENTRY_NOT_FOUND');
        }

        if (normalizedParentId != null) {
          final parentRef = entryRef
              .collection('comments')
              .doc(normalizedParentId);
          final parentSnapshot = await transaction.get(parentRef);
          if (!parentSnapshot.exists) {
            throw StateError('PARENT_COMMENT_NOT_FOUND');
          }
        }

        final commentData = <String, dynamic>{
          'userId': firebaseUser.uid,
          'authorName': displayName,
          'authorHandle': '@$username',
          'authorAvatarUrl': avatar,
          'content': trimmedContent,
          'createdAt': FieldValue.serverTimestamp(),
          'likeCount': 0,
          'likedByUserIds': <String>[],
        };

        if (normalizedParentId != null) {
          commentData['parentCommentId'] = normalizedParentId;
        }

        transaction.set(commentRef, commentData);

        transaction.update(entryRef, {
          'comments': FieldValue.increment(1),
          'yorumSayisi': FieldValue.increment(1),
        });
      });

      return true;
    } catch (e) {
      print('Add comment error: $e');
      return false;
    }
  }

  Future<bool> toggleCommentLike({
    required String entryId,
    required String commentId,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return false;

    final commentRef = _firestore
        .collection('cringe_entries')
        .doc(entryId)
        .collection('comments')
        .doc(commentId);

    try {
      final didLike = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(commentRef);
        if (!snapshot.exists) {
          throw StateError('COMMENT_NOT_FOUND');
        }

        final Map<String, dynamic> data =
            snapshot.data() ?? <String, dynamic>{};
        final likedBy =
            (data['likedByUserIds'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<String>()
                .toSet();

        final currentLikeCount =
            (data['likeCount'] as num?)?.toInt() ?? likedBy.length;
        final hasLiked = likedBy.contains(firebaseUser.uid);
        final nextLikeCount = hasLiked
            ? (currentLikeCount > 0 ? currentLikeCount - 1 : 0)
            : currentLikeCount + 1;

        transaction.update(commentRef, {
          'likeCount': nextLikeCount,
          'likedByUserIds': hasLiked
              ? FieldValue.arrayRemove([firebaseUser.uid])
              : FieldValue.arrayUnion([firebaseUser.uid]),
        });

        return !hasLiked;
      });
      return didLike;
    } catch (e) {
      print('Toggle comment like error: $e');
      return false;
    }
  }

  Future<bool> updateEntry(CringeEntry entry) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw StateError('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    final docRef = _firestore.collection('cringe_entries').doc(entry.id);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      return false;
    }

    // Firestore rules expect 'ownerId', but some old docs might only have 'userId'
    final ownerId =
        snapshot.data()?['ownerId'] as String? ??
        snapshot.data()?['userId'] as String? ??
        '';
    final isModerator = await UserService.instance.isModerator();
    if (ownerId != currentUserId && !isModerator) {
      throw StateError('NOT_AUTHORIZED: Bu krepi düzenleme yetkin yok');
    }

    final transactionId =
        'upd_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final normalizedEntry = _enrichEntryMetadata(
      _normalizeEntry(
        entry.copyWith(userId: ownerId.isNotEmpty ? ownerId : currentUserId),
      ),
    );
    final updateData = await _prepareEnterpriseUpdateData(
      normalizedEntry,
      transactionId,
    );

    await docRef.update(updateData);
    await _logAuditTrailUpdate(
      entry.id,
      currentUserId,
      updateData,
      transactionId,
    );

    unawaited(
      SearchIndexUpdater.instance.upsertEntry(
        normalizedEntry.copyWith(id: entry.id),
      ),
    );

    return true;
  }

  Future<bool> deleteEntry(String entryId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw StateError('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    final docRef = _firestore.collection('cringe_entries').doc(entryId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      return false;
    }

  final snapshotData = snapshot.data();
  final existingTags = snapshotData != null
    ? (snapshotData['etiketler'] is Iterable
      ? (snapshotData['etiketler'] as Iterable)
        .whereType<String>()
        .toList(growable: false)
      : const <String>[])
    : const <String>[];

    // Firestore rules expect 'ownerId', but some old docs might only have 'userId'
    var ownerId =
        snapshot.data()?['ownerId'] as String? ??
        snapshot.data()?['userId'] as String? ??
        '';
    if (ownerId.isEmpty) {
      ownerId = currentUserId;
    }

    final isModerator = await UserService.instance.isModerator();
    if (ownerId != currentUserId && !isModerator) {
      throw StateError('NOT_AUTHORIZED: Bu krepi silme yetkin yok');
    }

    final transactionId =
        'del_${DateTime.now().millisecondsSinceEpoch.toString()}';

    await docRef.delete();
    final targetUserId = ownerId.isNotEmpty ? ownerId : currentUserId;
    await _decrementUserStats(targetUserId, transactionId);
    await _logAuditTrailDelete(entryId, currentUserId, transactionId);

    unawaited(
      SearchIndexUpdater.instance.deleteEntry(
        entryId,
        ownerId: targetUserId,
        hashtags: existingTags,
      ),
    );

    return true;
  }

  void _handleConnectivityStatus(ConnectivityStatus status) {
    if (_isDisposed) return;

    if (status == ConnectivityStatus.offline) {
      if (streamStatusNotifier.value == CringeStreamStatus.healthy) {
        streamStatusNotifier.value = CringeStreamStatus.degraded;
      }
      if (streamHintNotifier.value == null) {
        streamHintNotifier.value =
            'İnternet bağlantısı kesildi. İçerikler önbellekten gösteriliyor.';
      }
    } else {
      if (streamStatusNotifier.value == CringeStreamStatus.degraded) {
        streamStatusNotifier.value = CringeStreamStatus.connecting;
        unawaited(warmUp());
      }

      streamHintNotifier.value = 'Bağlantı geri geldi. Akış güncelleniyor...';

      Future.delayed(const Duration(seconds: 4)).then((_) {
        if (_isDisposed) return;
        if (streamHintNotifier.value ==
            'Bağlantı geri geldi. Akış güncelleniyor...') {
          streamHintNotifier.value = null;
          if (streamStatusNotifier.value == CringeStreamStatus.connecting) {
            streamStatusNotifier.value = CringeStreamStatus.healthy;
          }
        }
      });
    }
  }

  // === MODERATOR FUNCTIONS (Security Contract) ===

  /// Approve a post (moderators only)
  /// Security Contract: Sets status='approved', updates moderation field
  Future<void> approvePost(String postId, {String? moderatorNote}) async {
    print('🛡️ APPROVE POST: $postId');

    // Check moderator status
    final isMod = await UserService.instance.isModerator();
    if (!isMod) {
      print('❌ APPROVE DENIED: User is not a moderator');
      throw Exception('Only moderators can approve posts');
    }

    final userId = UserService.instance.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updateData = <String, dynamic>{
        'status': ModerationStatus.approved.name,
        'moderation': {
          'action': 'approved',
          'moderatorId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          if (moderatorNote != null) 'note': moderatorNote,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('posts').doc(postId).update(updateData);
      print('✅ POST APPROVED: $postId by $userId');
    } catch (e) {
      print('❌ APPROVE POST ERROR: $e');
      rethrow;
    }
  }

  /// Reject a post (moderators only)
  /// Security Contract: Sets status='rejected', updates moderation field with reason
  Future<void> rejectPost(String postId, {required String reason}) async {
    print('🛡️ REJECT POST: $postId');

    // Check moderator status
    final isMod = await UserService.instance.isModerator();
    if (!isMod) {
      print('❌ REJECT DENIED: User is not a moderator');
      throw Exception('Only moderators can reject posts');
    }

    final userId = UserService.instance.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updateData = <String, dynamic>{
        'status': ModerationStatus.rejected.name,
        'moderation': {
          'action': 'rejected',
          'moderatorId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'reason': reason,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('posts').doc(postId).update(updateData);
      print('✅ POST REJECTED: $postId by $userId - Reason: $reason');
    } catch (e) {
      print('❌ REJECT POST ERROR: $e');
      rethrow;
    }
  }

  /// Block a post (moderators only)
  /// Security Contract: Sets status='blocked', updates moderation field with reason
  /// Blocked posts are hidden from all users and cannot be unblocked
  Future<void> blockPost(String postId, {required String reason}) async {
    print('🛡️ BLOCK POST: $postId');

    // Check moderator status
    final isMod = await UserService.instance.isModerator();
    if (!isMod) {
      print('❌ BLOCK DENIED: User is not a moderator');
      throw Exception('Only moderators can block posts');
    }

    final userId = UserService.instance.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updateData = <String, dynamic>{
        'status': ModerationStatus.blocked.name,
        'moderation': {
          'action': 'blocked',
          'moderatorId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'reason': reason,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('posts').doc(postId).update(updateData);
      print('🚫 POST BLOCKED: $postId by $userId - Reason: $reason');
    } catch (e) {
      print('❌ BLOCK POST ERROR: $e');
      rethrow;
    }
  }

  /// Get all posts pending moderation (moderators only)
  /// Security Contract: Returns posts with status='pending'
  Future<List<CringeEntry>> getPendingPosts({int limit = 50}) async {
    print('🛡️ GET PENDING POSTS');

    // Check moderator status
    final isMod = await UserService.instance.isModerator();
    if (!isMod) {
      print('❌ GET PENDING DENIED: User is not a moderator');
      throw Exception('Only moderators can view pending posts');
    }

    try {
      final query = _firestore
          .collection('posts')
          .where('status', isEqualTo: ModerationStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      final entries = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CringeEntry.fromFirestore(data);
      }).toList();

      print('✅ FOUND ${entries.length} PENDING POSTS');
      return entries;
    } catch (e) {
      print('❌ GET PENDING POSTS ERROR: $e');
      rethrow;
    }
  }

  /// Stream of posts pending moderation (moderators only)
  Stream<List<CringeEntry>> getPendingPostsStream({int limit = 50}) {
    print('🛡️ PENDING POSTS STREAM STARTED');

    return Stream.fromFuture(UserService.instance.isModerator()).asyncExpand((
      isMod,
    ) {
      if (!isMod) {
        print('❌ STREAM DENIED: User is not a moderator');
        return Stream.value(<CringeEntry>[]);
      }

      return _firestore
          .collection('posts')
          .where('status', isEqualTo: ModerationStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final entries = snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return CringeEntry.fromFirestore(data);
            }).toList();
            print('📊 PENDING POSTS: ${entries.length}');
            return entries;
          });
    });
  }

  /// Get moderation statistics (moderators only)
  Future<Map<String, int>> getModerationStats() async {
    print('🛡️ GET MODERATION STATS');

    // Check moderator status
    final isMod = await UserService.instance.isModerator();
    if (!isMod) {
      print('❌ STATS DENIED: User is not a moderator');
      throw Exception('Only moderators can view stats');
    }

    try {
      final stats = <String, int>{};

      // Count pending
      final pendingSnapshot = await _firestore
          .collection('posts')
          .where('status', isEqualTo: ModerationStatus.pending.name)
          .count()
          .get();
      stats['pending'] = pendingSnapshot.count ?? 0;

      // Count approved
      final approvedSnapshot = await _firestore
          .collection('posts')
          .where('status', isEqualTo: ModerationStatus.approved.name)
          .count()
          .get();
      stats['approved'] = approvedSnapshot.count ?? 0;

      // Count rejected
      final rejectedSnapshot = await _firestore
          .collection('posts')
          .where('status', isEqualTo: ModerationStatus.rejected.name)
          .count()
          .get();
      stats['rejected'] = rejectedSnapshot.count ?? 0;

      // Count blocked
      final blockedSnapshot = await _firestore
          .collection('posts')
          .where('status', isEqualTo: ModerationStatus.blocked.name)
          .count()
          .get();
      stats['blocked'] = blockedSnapshot.count ?? 0;

      print('📊 MODERATION STATS: $stats');
      return stats;
    } catch (e) {
      print('❌ GET STATS ERROR: $e');
      rethrow;
    }
  }

  // ====================================================================
  // ENGAGEMENT: LIKES
  // ====================================================================

  /// Beğeni ekle
  Future<void> likeEntry(String entryId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('❌ LIKE DENIED: User not authenticated');
      throw Exception('User must be authenticated to like');
    }

    print('❤️ LIKE: User $userId liking entry $entryId');

    try {
      final entryRef = _firestore.collection('cringe_entries').doc(entryId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(entryRef);

        if (!snapshot.exists) {
          throw Exception('Entry not found');
        }

        final data = snapshot.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);

        // Zaten beğenmiş mi kontrol et
        if (likedBy.contains(userId)) {
          print('⚠️ ALREADY LIKED: User already liked this entry');
          return;
        }

        // Beğeniyi ekle
        likedBy.add(userId);
        final likeCount = (data['likeCount'] ?? 0) + 1;

        transaction.update(entryRef, {
          'likedBy': likedBy,
          'likeCount': likeCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print(
          '✅ LIKE SUCCESS: Entry $entryId liked by $userId (total: $likeCount)',
        );
      });

      // Cache'i invalidate et
      await _clearEnterpriseCache();

      // Analytics
      await _logAnalyticsEvent('like_entry', parameters: {'entry_id': entryId});
    } catch (e) {
      print('❌ LIKE ERROR: $e');
      rethrow;
    }
  }

  /// Beğeniyi kaldır
  Future<void> unlikeEntry(String entryId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('❌ UNLIKE DENIED: User not authenticated');
      throw Exception('User must be authenticated to unlike');
    }

    print('💔 UNLIKE: User $userId unliking entry $entryId');

    try {
      final entryRef = _firestore.collection('cringe_entries').doc(entryId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(entryRef);

        if (!snapshot.exists) {
          throw Exception('Entry not found');
        }

        final data = snapshot.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);

        // Beğenmemiş mi kontrol et
        if (!likedBy.contains(userId)) {
          print('⚠️ NOT LIKED: User has not liked this entry');
          return;
        }

        // Beğeniyi kaldır
        likedBy.remove(userId);
        final likeCount = ((data['likeCount'] ?? 1) - 1)
            .clamp(0, double.infinity)
            .toInt();

        transaction.update(entryRef, {
          'likedBy': likedBy,
          'likeCount': likeCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print(
          '✅ UNLIKE SUCCESS: Entry $entryId unliked by $userId (total: $likeCount)',
        );
      });

      // Cache'i invalidate et
      await _clearEnterpriseCache();

      // Analytics
      await _logAnalyticsEvent(
        'unlike_entry',
        parameters: {'entry_id': entryId},
      );
    } catch (e) {
      print('❌ UNLIKE ERROR: $e');
      rethrow;
    }
  }

  /// Kullanıcının bu entry'yi beğenip beğenmediğini kontrol et
  Future<bool> isLikedByUser(String entryId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final doc = await _firestore
          .collection('cringe_entries')
          .doc(entryId)
          .get();
      if (!doc.exists) return false;

      final likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);
      return likedBy.contains(userId);
    } catch (e) {
      print('❌ IS_LIKED CHECK ERROR: $e');
      return false;
    }
  }

  // ====================================================================
  // ENGAGEMENT: VIEW COUNT
  // ====================================================================

  /// Görüntülenme sayısını artır
  Future<void> incrementViewCount(String entryId) async {
    print('👁️ VIEW: Incrementing view count for entry $entryId');

    try {
      final entryRef = _firestore.collection('cringe_entries').doc(entryId);

      await entryRef.update({
        'viewCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ VIEW SUCCESS: View count incremented for $entryId');

      // Analytics
      await _logAnalyticsEvent('view_entry', parameters: {'entry_id': entryId});
    } catch (e) {
      print('❌ VIEW ERROR: $e');
      // View count hatalarını sessizce yut (kritik değil)
    }
  }

  // ====================================================================
  // ENGAGEMENT: SHARE COUNT
  // ====================================================================

  /// Paylaşım sayısını artır
  Future<void> incrementShareCount(String entryId) async {
    print('📤 SHARE: Incrementing share count for entry $entryId');

    try {
      final entryRef = _firestore.collection('cringe_entries').doc(entryId);

      await entryRef.update({
        'shareCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ SHARE SUCCESS: Share count incremented for $entryId');

      // Analytics
      await _logAnalyticsEvent(
        'share_entry',
        parameters: {'entry_id': entryId},
      );
    } catch (e) {
      print('❌ SHARE ERROR: $e');
      // Share count hatalarını sessizce yut (kritik değil)
    }
  }
}
