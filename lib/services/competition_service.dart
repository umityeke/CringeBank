import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/cringe_comment.dart';
import '../models/cringe_entry.dart';
import '../services/cringe_notification_service.dart';

enum CompetitionStatus { upcoming, active, ended, voting, results }

enum CompetitionType {
  weeklyBest,
  categorySpecific,
  krepLevelChallenge,
  aiJudged,
  communityChoice,
  speedRound,
  legendary,
}

enum CompetitionJoinResult {
  success,
  limitReached,
  alreadyJoined,
  notFound,
  unauthorized,
  closed,
  full,
}

enum CompetitionLeaveResult {
  success,
  notParticipant,
  notFound,
  unauthorized,
}

class CompetitionCommentWinner {
  const CompetitionCommentWinner({
    required this.commentId,
    required this.entryId,
    required this.userId,
    required this.authorName,
    required this.authorHandle,
    required this.content,
    required this.likeCount,
    required this.createdAt,
    this.authorAvatarUrl,
  });

  final String commentId;
  final String entryId;
  final String userId;
  final String authorName;
  final String authorHandle;
  final String content;
  final int likeCount;
  final DateTime createdAt;
  final String? authorAvatarUrl;

  factory CompetitionCommentWinner.fromMap(Map<String, dynamic> data) {
    DateTime parseCreatedAt(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return CompetitionCommentWinner(
      commentId: (data['commentId'] ?? '').toString(),
      entryId: (data['entryId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      authorName: (data['authorName'] ?? 'Anonim').toString(),
      authorHandle: (data['authorHandle'] ?? '@anonim').toString(),
      content: (data['content'] ?? '').toString(),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      createdAt: parseCreatedAt(data['createdAt']),
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'commentId': commentId,
      'entryId': entryId,
      'userId': userId,
      'authorName': authorName,
      'authorHandle': authorHandle,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'likeCount': likeCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'commentId': commentId,
      'entryId': entryId,
      'userId': userId,
      'authorName': authorName,
      'authorHandle': authorHandle,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'likeCount': likeCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class _CompetitionCommentWinnerCacheEntry {
  const _CompetitionCommentWinnerCacheEntry(this.winner, this.fetchedAt);

  final CompetitionCommentWinner? winner;
  final DateTime fetchedAt;
}

class Competition {
  final String id;
  final String title;
  final String description;
  final CompetitionType type;
  final CompetitionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime votingEndDate;
  final List<CringeEntry> entries;
  final Map<String, int> votes; // entry_id -> vote_count
  final int maxEntries;
  final double prizeKrepCoins;
  final CringeCategory? specificCategory;
  final double? targetKrepLevel;
  final String? sponsor;
  final String? createdByUserId;
  final List<String> participantUserIds;
  final int totalCommentCount;

  Competition({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.votingEndDate,
    this.entries = const [],
    this.votes = const {},
    this.maxEntries = 100,
    this.prizeKrepCoins = 1000.0,
    this.specificCategory,
    this.targetKrepLevel,
    this.sponsor,
    this.createdByUserId,
    this.participantUserIds = const [],
    this.totalCommentCount = 0,
  });

  Competition copyWith({
    String? id,
    String? title,
    String? description,
    CompetitionType? type,
    CompetitionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? votingEndDate,
    List<CringeEntry>? entries,
    Map<String, int>? votes,
    int? maxEntries,
    double? prizeKrepCoins,
    CringeCategory? specificCategory,
    double? targetKrepLevel,
    String? sponsor,
    String? createdByUserId,
    List<String>? participantUserIds,
    int? totalCommentCount,
  }) {
    return Competition(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      votingEndDate: votingEndDate ?? this.votingEndDate,
      entries: entries ?? this.entries,
      votes: votes ?? this.votes,
      maxEntries: maxEntries ?? this.maxEntries,
      prizeKrepCoins: prizeKrepCoins ?? this.prizeKrepCoins,
      specificCategory: specificCategory ?? this.specificCategory,
      targetKrepLevel: targetKrepLevel ?? this.targetKrepLevel,
      sponsor: sponsor ?? this.sponsor,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      participantUserIds: participantUserIds ?? this.participantUserIds,
      totalCommentCount: totalCommentCount ?? this.totalCommentCount,
    );
  }

  factory Competition.fromFirestore(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    CompetitionType parseType(String? value) {
      if (value == null) return CompetitionType.weeklyBest;
      return CompetitionType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => CompetitionType.weeklyBest,
      );
    }

    CompetitionStatus parseStatus(String? value) {
      if (value == null) return CompetitionStatus.upcoming;
      return CompetitionStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => CompetitionStatus.upcoming,
      );
    }

    CringeCategory? parseCategory(String? value) {
      if (value == null) return null;
      return CringeCategory.values.firstWhere(
        (category) => category.name == value,
        orElse: () => CringeCategory.values.first,
      );
    }

    final entriesData = (data['entries'] as List<dynamic>?) ?? [];
    final entries = entriesData
        .map((item) {
          if (item is Map<String, dynamic>) {
            return CringeEntry.fromJson(item);
          }
          if (item is Map) {
            return CringeEntry.fromJson(item.cast<String, dynamic>());
          }
          return null;
        })
        .whereType<CringeEntry>()
        .toList();

  final entryCommentSum = entries.fold<int>(0, (sum, entry) => sum + entry.yorumSayisi);

    final votesData = (data['votes'] as Map<String, dynamic>?) ?? {};
    final votes = votesData.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );

    return Competition(
      id: (data['id'] ?? documentId ?? '').toString(),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: parseType(data['type'] as String?),
      status: parseStatus(data['status'] as String?),
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      votingEndDate: parseDate(data['votingEndDate']),
      entries: entries,
      votes: votes,
      maxEntries: (data['maxEntries'] as num?)?.toInt() ?? 100,
      prizeKrepCoins: (data['prizeKrepCoins'] as num?)?.toDouble() ?? 0,
      specificCategory: parseCategory(data['specificCategory'] as String?),
      targetKrepLevel: (data['targetKrepLevel'] as num?)?.toDouble(),
      sponsor: data['sponsor'] as String?,
      createdByUserId: data['createdByUserId'] as String?,
      participantUserIds: ((data['participantUserIds'] ?? data['participants'])
              as List?)
              ?.map((value) => value.toString())
              .toList() ??
          const [],
    totalCommentCount:
      (data['totalCommentCount'] as num?)?.toInt() ?? entryCommentSum,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'status': status.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'votingEndDate': Timestamp.fromDate(votingEndDate),
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'votes': votes,
      'maxEntries': maxEntries,
      'prizeKrepCoins': prizeKrepCoins,
      'specificCategory': specificCategory?.name,
      'targetKrepLevel': targetKrepLevel,
      'sponsor': sponsor,
      'createdByUserId': createdByUserId,
      'participantUserIds': participantUserIds,
      'totalCommentCount': totalCommentCount,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'status': status.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'votingEndDate': votingEndDate.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'votes': votes,
      'maxEntries': maxEntries,
      'prizeKrepCoins': prizeKrepCoins,
      'specificCategory': specificCategory?.name,
      'targetKrepLevel': targetKrepLevel,
      'sponsor': sponsor,
      'createdByUserId': createdByUserId,
      'participantUserIds': participantUserIds,
      'totalCommentCount': totalCommentCount,
    };
  }
}

class CompetitionService {
  static const int maxCompetitionDurationDays = 10;

  static final List<Competition> _competitions = [];
  static final StreamController<List<Competition>> _competitionsController =
      StreamController<List<Competition>>.broadcast();
  static Timer? _updateTimer;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _firestoreSubscription;
  static bool _isInitialized = false;
  static final Map<String, _CompetitionCommentWinnerCacheEntry>
    _commentWinnerCache = <String, _CompetitionCommentWinnerCacheEntry>{};
  static const Duration _commentWinnerCacheTTL = Duration(minutes: 3);

  // Competition stream
  static Stream<List<Competition>> get competitionsStream =>
      _competitionsController.stream;

  static List<Competition> get currentCompetitions =>
    List.unmodifiable(_competitions);

  // Initialize competition service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // ignore: avoid_print
      print(
        '⚠️ CompetitionService: Initialization skipped, user not signed in',
      );
      return;
    }

    final firestoreCompetitions = await _loadCompetitionsFromFirestore();
    if (firestoreCompetitions.isNotEmpty) {
      _competitions
        ..clear()
        ..addAll(firestoreCompetitions);
      _competitionsController.add(List.unmodifiable(_competitions));
    } else {
      await _generateInitialCompetitions();
      await _persistCompetitionsToFirestore(_competitions);
    }

    _listenToFirestoreUpdates();
    _startPeriodicUpdates();

    _isInitialized = true;
  }

  // Generate initial competitions
  static Future<void> _generateInitialCompetitions() async {
    final now = DateTime.now();

    // Aktif yarışma
    final activeCompetition = Competition(
      id: 'weekly_001',
      title: '🏆 Bu Haftanın En Krep Anısı',
      description:
          'Bu haftanın en utanç verici anısını paylaş ve Krep Coin kazan! Topluluk oyu ile kazanan belirlenecek.',
      type: CompetitionType.weeklyBest,
      status: CompetitionStatus.active,
      startDate: now.subtract(const Duration(days: 2)),
      endDate: now.add(const Duration(days: 3)),
      votingEndDate: now.add(const Duration(days: 5)),
      maxEntries: 50,
      prizeKrepCoins: 2500.0,
    );

    // Yaklaşan kategori-spesifik yarışma
    final upcomingCompetition = Competition(
      id: 'category_002',
      title: '💕 Aşk Acısı Kreplikleri Özel Yarışması',
      description:
          'Sadece aşk acısı kategorisindeki en dramatik anılar! AI hakemi de olacak.',
      type: CompetitionType.categorySpecific,
      status: CompetitionStatus.upcoming,
      startDate: now.add(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 8)),
      votingEndDate: now.add(const Duration(days: 10)),
      specificCategory: CringeCategory.askAcisiKrepligi,
      maxEntries: 30,
      prizeKrepCoins: 1500.0,
      sponsor: 'Dr. Utanmaz AI Therapy',
    );

    // Krep seviyesi challenge
    final challengeCompetition = Competition(
      id: 'challenge_003',
      title: '🔥 Ultimate Cringe Challenge - 9+ Krep Seviyesi',
      description:
          'Sadece 9.0 ve üzeri krep seviyesindeki legendary anılar! Cesaret isteyen yarışma.',
      type: CompetitionType.krepLevelChallenge,
      status: CompetitionStatus.upcoming,
      startDate: now.add(const Duration(days: 5)),
      endDate: now.add(const Duration(days: 12)),
      votingEndDate: now.add(const Duration(days: 14)),
      targetKrepLevel: 9.0,
      maxEntries: 20,
      prizeKrepCoins: 5000.0,
    );

    // Speed round
    final speedCompetition = Competition(
      id: 'speed_004',
      title: '⚡ Hızlı Krep Turu - 24 Saat',
      description: '24 saat süren hızlı yarışma! En çok oy alan anı kazanır.',
      type: CompetitionType.speedRound,
      status: CompetitionStatus.upcoming,
      startDate: now.add(const Duration(hours: 6)),
      endDate: now.add(const Duration(hours: 30)),
      votingEndDate: now.add(const Duration(hours: 32)),
      maxEntries: 100,
      prizeKrepCoins: 800.0,
    );

    _competitions.addAll([
      activeCompetition,
      upcomingCompetition,
      challengeCompetition,
      speedCompetition,
    ]);

    // Mock entries ekle aktif yarışmaya
    await _addMockEntriesToActiveCompetition(activeCompetition.id);

    _competitionsController.add(List.unmodifiable(_competitions));
  }

  // Mock entries ekle
  static Future<void> _addMockEntriesToActiveCompetition(
    String competitionId,
  ) async {
    final competition = _competitions.firstWhere((c) => c.id == competitionId);

    final mockEntries = [
      CringeEntry(
        id: 'mock_1',
        userId: 'user_1',
        authorName: 'Mehmet S.',
        authorHandle: '@mehmets',
        baslik: 'Sınıfın ortasında osurdum',
        aciklama:
            'Matematik dersinde sessizlik varken müthiş bir osuruk çıkardım. Herkes baktı, hoca bile güldü. 3 gün kimseyle konuşamadım.',
        kategori: CringeCategory.fizikselRezillik,
        krepSeviyesi: 8.5,
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        etiketler: ['sınıf', 'osuruk', 'utanç'],
        isAnonim: false,
        begeniSayisi: 15,
        yorumSayisi: 3,
      ),
      CringeEntry(
        id: 'mock_2',
        userId: 'user_2',
        authorName: 'Anonim',
        authorHandle: '@anonim2',
        baslik: 'Crush\'uma yanlış mesaj attım',
        aciklama:
            'Arkadaşıma crush\'um hakkında yazdığım şeyi yanlışlıkla ona attım. "Keşke cesaretim olsa da konuşsam" yazmıştım. O da "şimdi konuşuyorsun zaten" dedi.',
        kategori: CringeCategory.askAcisiKrepligi,
        krepSeviyesi: 9.2,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        etiketler: ['aşk', 'mesaj', 'hata'],
        isAnonim: true,
        begeniSayisi: 23,
        yorumSayisi: 7,
      ),
      CringeEntry(
        id: 'mock_3',
        userId: 'user_3',
        authorName: 'Fatma K.',
        authorHandle: '@fatmak',
        baslik: 'Anne toplantısında rezil oldum',
        aciklama:
            'Annem parent-teacher meeting\'e geldi. Hoca "çocuğunuz çok sessiz" derken annem "evde hiç susmaz ki" deyip bütün utanç verici hikayelerimi anlattı.',
        kategori: CringeCategory.aileSofrasiFelaketi,
        krepSeviyesi: 7.8,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        etiketler: ['anne', 'okul', 'toplantı'],
        isAnonim: false,
        begeniSayisi: 8,
        yorumSayisi: 2,
      ),
    ];

    // Votes ekle
    final updatedVotes = Map<String, int>.from(competition.votes);
    updatedVotes['mock_1'] = 15;
    updatedVotes['mock_2'] = 23;
    updatedVotes['mock_3'] = 8;

    final mergedEntries = [...competition.entries, ...mockEntries];
    final updatedCompetition = competition.copyWith(
      entries: mergedEntries,
      votes: updatedVotes,
      totalCommentCount:
          mergedEntries.fold<int>(0, (sum, entry) => sum + entry.yorumSayisi),
    );

    final index = _competitions.indexWhere((c) => c.id == competitionId);
    _competitions[index] = updatedCompetition;
  }

  // Periodic updates
  static void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _updateCompetitionStatuses();
    });
  }

  // Update competition statuses
  static Future<void> _updateCompetitionStatuses() async {
    final now = DateTime.now();
    bool hasChanges = false;

    for (int i = 0; i < _competitions.length; i++) {
      final competition = _competitions[i];
      CompetitionStatus newStatus = competition.status;

      // Status güncellemeleri
      if (now.isBefore(competition.startDate) &&
          competition.status != CompetitionStatus.upcoming) {
        newStatus = CompetitionStatus.upcoming;
      } else if (now.isAfter(competition.startDate) &&
          now.isBefore(competition.endDate) &&
          competition.status != CompetitionStatus.active) {
        newStatus = CompetitionStatus.active;

        // Yarışma başladığında bildirim gönder
        _sendCompetitionNotification(
          title: '🏆 Yarışma Başladı!',
          body: '"\${competition.title}" yarışması şimdi aktif. Hemen katıl!',
        );
      } else if (now.isAfter(competition.endDate) &&
          now.isBefore(competition.votingEndDate) &&
          competition.status != CompetitionStatus.voting) {
        newStatus = CompetitionStatus.voting;

        // Oylama başladığında bildirim gönder
        _sendCompetitionNotification(
          title: '🗳️ Oylama Zamanı!',
          body:
              '"\${competition.title}" için oylama başladı. En iyi anıyı seç!',
        );
      } else if (now.isAfter(competition.votingEndDate) &&
          competition.status != CompetitionStatus.results) {
        newStatus = CompetitionStatus.results;

        // Sonuçlar açıklandığında bildirim gönder
        final winner = await fetchCommentWinner(
          competition,
          forceRefresh: true,
        );
        final notificationBody = winner != null
            ? 'Kazanan: ${winner.authorName} – ${winner.likeCount} beğeni kazandı!'
            : '"${competition.title}" sonuçları açıklandı!';
        _sendCompetitionNotification(
          title: '🎉 Sonuçlar Açıklandı!',
          body: notificationBody,
        );
      }

      if (newStatus != competition.status) {
        _competitions[i] = competition.copyWith(status: newStatus);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      _competitionsController.add(List.unmodifiable(_competitions));
      await _persistCompetitionsToFirestore(_competitions);
    }
  }

  // Send competition notification
  static void _sendCompetitionNotification({
    required String title,
    required String body,
  }) {
    CringeNotificationService.showCompetitionNotification(
      title: title,
      body: body,
    );
  }

  static Future<CompetitionCommentWinner?> fetchCommentWinner(
    Competition competition, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cacheEntry = _commentWinnerCache[competition.id];
      if (cacheEntry != null) {
        final isFresh =
            DateTime.now().difference(cacheEntry.fetchedAt) <=
                _commentWinnerCacheTTL;
        if (isFresh) {
          return cacheEntry.winner;
        }
      }
    }

    final winner = await _calculateCommentWinner(competition);
    _commentWinnerCache[competition.id] =
        _CompetitionCommentWinnerCacheEntry(winner, DateTime.now());
    return winner;
  }

  static Future<CompetitionCommentWinner?> _calculateCommentWinner(
    Competition competition,
  ) async {
    if (competition.entries.isEmpty) {
      return null;
    }

    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final entry in competition.entries) {
      futures.add(
        _firestore
            .collection('cringe_entries')
            .doc(entry.id)
            .collection('comments')
            .orderBy('likeCount', descending: true)
            .limit(25)
            .get(),
      );
    }

    final snapshots = await Future.wait(futures, eagerError: false);

    CompetitionCommentWinner? currentWinner;
    for (var i = 0; i < snapshots.length; i++) {
      final entry = competition.entries[i];
      final snapshot = snapshots[i];

      for (final doc in snapshot.docs) {
        final comment = CringeComment.fromFirestore(
          doc.data(),
          documentId: doc.id,
          entryId: entry.id,
        );

        final candidate = CompetitionCommentWinner(
          commentId: comment.id,
          entryId: entry.id,
          userId: comment.userId,
          authorName: comment.authorName,
          authorHandle: comment.authorHandle,
          content: comment.content,
          likeCount: comment.likeCount,
          createdAt: comment.createdAt,
          authorAvatarUrl: comment.authorAvatarUrl,
        );

        currentWinner = _selectBetterWinner(currentWinner, candidate);
      }
    }

    return currentWinner;
  }

  static CompetitionCommentWinner? _selectBetterWinner(
    CompetitionCommentWinner? current,
    CompetitionCommentWinner candidate,
  ) {
    if (current == null) {
      return candidate;
    }

    if (candidate.likeCount > current.likeCount) {
      return candidate;
    }
    if (candidate.likeCount < current.likeCount) {
      return current;
    }

    if (candidate.createdAt.isBefore(current.createdAt)) {
      return candidate;
    }
    if (candidate.createdAt.isAfter(current.createdAt)) {
      return current;
    }

    return candidate.commentId.compareTo(current.commentId) < 0
        ? candidate
        : current;
  }

  static void invalidateCommentWinnerForEntry(String entryId) {
    final affectedCompetitions = _competitions.where((competition) {
      return competition.entries.any((entry) => entry.id == entryId);
    });

    for (final competition in affectedCompetitions) {
      _commentWinnerCache.remove(competition.id);
    }
  }

  static void invalidateCommentWinner(String competitionId) {
    _commentWinnerCache.remove(competitionId);
  }

  // Get all competitions
  static List<Competition> getAllCompetitions() {
    return List.unmodifiable(_competitions);
  }

  // Get active competitions
  static List<Competition> getActiveCompetitions() {
    return _competitions
        .where((c) => c.status == CompetitionStatus.active)
        .toList();
  }

  // Get upcoming competitions
  static List<Competition> getUpcomingCompetitions() {
    return _competitions
        .where((c) => c.status == CompetitionStatus.upcoming)
        .toList();
  }

  // Vote for entry
  static Future<bool> voteForEntry(String competitionId, String entryId) async {
    try {
      final competitionIndex = _competitions.indexWhere(
        (c) => c.id == competitionId,
      );
      if (competitionIndex == -1) return false;

      final competition = _competitions[competitionIndex];
      if (competition.status != CompetitionStatus.active &&
          competition.status != CompetitionStatus.voting) {
        return false;
      }

      // Vote count artır
      final updatedVotes = Map<String, int>.from(competition.votes);
      updatedVotes[entryId] = (updatedVotes[entryId] ?? 0) + 1;

      _competitions[competitionIndex] = competition.copyWith(
        votes: updatedVotes,
      );
      _competitionsController.add(List.unmodifiable(_competitions));
      await _persistCompetitionsToFirestore(_competitions);

      return true;
    } catch (e) {
      // Debug: 'Vote error: \$e'
      return false;
    }
  }

  // Submit entry to competition
  static Future<bool> submitEntry(
    String competitionId,
    CringeEntry entry,
  ) async {
    try {
      final competitionIndex = _competitions.indexWhere(
        (c) => c.id == competitionId,
      );
      if (competitionIndex == -1) return false;

      final competition = _competitions[competitionIndex];
      if (competition.status != CompetitionStatus.active) return false;
      if (competition.entries.length >= competition.maxEntries) return false;

      // Entry validation
      if (competition.specificCategory != null &&
          entry.kategori != competition.specificCategory) {
        return false;
      }

      if (competition.targetKrepLevel != null &&
          entry.krepSeviyesi < competition.targetKrepLevel!) {
        return false;
      }

      if (_hasActiveParticipation(entry.userId,
          exceptCompetitionId: competitionId)) {
        return false;
      }

      if (competition.entries.any((e) => e.userId == entry.userId)) {
        return false;
      }

      final updatedEntries = [...competition.entries, entry];
      final updatedParticipants = {
        ...competition.participantUserIds,
        entry.userId,
      }.toList();
      _competitions[competitionIndex] = competition.copyWith(
        entries: updatedEntries,
        participantUserIds: updatedParticipants,
        totalCommentCount:
            competition.totalCommentCount + entry.yorumSayisi,
      );
      _competitionsController.add(List.unmodifiable(_competitions));
      await _persistCompetitionsToFirestore(_competitions);
      invalidateCommentWinner(competitionId);

      return true;
    } catch (e) {
      // Debug: 'Submit entry error: \$e'
      return false;
    }
  }

  // Get leaderboard
  static List<MapEntry<CringeEntry, int>> getLeaderboard(String competitionId) {
    final competition = _competitions.firstWhere(
      (c) => c.id == competitionId,
      orElse: () => _competitions.first,
    );

    final leaderboard = <MapEntry<CringeEntry, int>>[];

    for (final entry in competition.entries) {
      final voteCount = competition.votes[entry.id] ?? 0;
      leaderboard.add(MapEntry(entry, voteCount));
    }

    // Vote count'a göre sırala
    leaderboard.sort((a, b) => b.value.compareTo(a.value));

    return leaderboard;
  }

  // Create new competition (admin function)
  static Future<bool> createCompetition(Competition competition) async {
    try {
      if (!_isDurationWithinLimit(competition.startDate, competition.endDate)) {
        return false;
      }

      final createdBy =
          competition.createdByUserId ?? firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (createdBy != null && _hasOngoingCompetition(createdBy)) {
        return false;
      }

      final competitionToPersist = createdBy != null
          ? competition.copyWith(createdByUserId: createdBy)
          : competition;

      _competitions.add(competitionToPersist);
      _competitionsController.add(List.unmodifiable(_competitions));
      await _persistCompetitionsToFirestore(_competitions);

      // Yeni yarışma bildirimini gönder
      _sendCompetitionNotification(
        title: '🆕 Yeni Yarışma!',
        body:
            '"${competitionToPersist.title}" yarışması eklendi. Katılmayı unutma!',
      );

      return true;
    } catch (e) {
      // Debug: 'Create competition error: \$e'
      return false;
    }
  }

  static Future<bool> deleteCompetition(String competitionId) async {
    try {
      final index = _competitions.indexWhere((c) => c.id == competitionId);
      if (index == -1) return false;

      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final competition = _competitions[index];
      if (competition.createdByUserId != currentUser.uid) {
        return false;
      }

      _competitions.removeAt(index);
      _competitionsController.add(List.unmodifiable(_competitions));
      await _persistCompetitionsToFirestore(_competitions);

      return true;
    } catch (e) {
      // Debug: 'Delete competition error: $e'
      return false;
    }
  }

  static bool hasOngoingCompetitionForCurrentUser() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return _hasOngoingCompetition(user.uid);
  }

  static bool hasActiveParticipationForCurrentUser() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return _hasActiveParticipation(user.uid);
  }

  static Future<CompetitionJoinResult> joinCompetition(
      String competitionId) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return CompetitionJoinResult.unauthorized;
    }

    final index = _competitions.indexWhere((c) => c.id == competitionId);
    if (index == -1) {
      return CompetitionJoinResult.notFound;
    }

    final competition = _competitions[index];

    if (competition.status != CompetitionStatus.active &&
        competition.status != CompetitionStatus.upcoming) {
      return CompetitionJoinResult.closed;
    }

    if (competition.participantUserIds.contains(user.uid)) {
      return CompetitionJoinResult.alreadyJoined;
    }

    if (_hasActiveParticipation(user.uid)) {
      return CompetitionJoinResult.limitReached;
    }

    if (competition.participantUserIds.length >= competition.maxEntries) {
      return CompetitionJoinResult.full;
    }

    final updatedParticipants = [...competition.participantUserIds, user.uid];
    _competitions[index] = competition.copyWith(
      participantUserIds: updatedParticipants,
    );
    _competitionsController.add(List.unmodifiable(_competitions));
    await _persistCompetitionsToFirestore(_competitions);

    return CompetitionJoinResult.success;
  }

  static Future<CompetitionLeaveResult> leaveCompetition(
      String competitionId) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return CompetitionLeaveResult.unauthorized;
    }

    final index = _competitions.indexWhere((c) => c.id == competitionId);
    if (index == -1) {
      return CompetitionLeaveResult.notFound;
    }

    final competition = _competitions[index];

    if (!competition.participantUserIds.contains(user.uid)) {
      return CompetitionLeaveResult.notParticipant;
    }

    final updatedParticipants =
        competition.participantUserIds.where((id) => id != user.uid).toList();
    final updatedEntries =
        competition.entries.where((entry) => entry.userId != user.uid).toList();
    final removedCommentTotal = competition.entries
        .where((entry) => entry.userId == user.uid)
        .fold<int>(0, (sum, entry) => sum + entry.yorumSayisi);
    final updatedTotalCommentCount = max(
      0,
      competition.totalCommentCount - removedCommentTotal,
    );

    _competitions[index] = competition.copyWith(
      participantUserIds: updatedParticipants,
      entries: updatedEntries,
      totalCommentCount: updatedTotalCommentCount,
    );
    _competitionsController.add(List.unmodifiable(_competitions));
    await _persistCompetitionsToFirestore(_competitions);
    invalidateCommentWinner(competitionId);

    return CompetitionLeaveResult.success;
  }

  static Future<void> replaceEntryIdIfPresent({
    required String oldEntryId,
    required String newEntryId,
  }) async {
    if (oldEntryId.isEmpty || newEntryId.isEmpty || oldEntryId == newEntryId) {
      return;
    }

    bool hasChanges = false;

    for (var i = 0; i < _competitions.length; i++) {
      final competition = _competitions[i];
      final entryIndex = competition.entries.indexWhere(
        (entry) => entry.id == oldEntryId,
      );

      if (entryIndex == -1) {
        continue;
      }

      final updatedEntries = [...competition.entries];
      final updatedEntry = updatedEntries[entryIndex].copyWith(id: newEntryId);
      updatedEntries[entryIndex] = updatedEntry;

      final updatedVotes = Map<String, int>.from(competition.votes);
      if (updatedVotes.containsKey(oldEntryId)) {
        final voteCount = updatedVotes.remove(oldEntryId)!;
        updatedVotes[newEntryId] = voteCount;
      }

      _competitions[i] = competition.copyWith(
        entries: updatedEntries,
        votes: updatedVotes,
      );
      hasChanges = true;

      try {
        await _firestore.collection('competitions').doc(competition.id).update({
          'entries': updatedEntries.map((entry) => entry.toJson()).toList(),
          'votes': updatedVotes,
        });
      } catch (e) {
        // ignore: avoid_print
        print('CompetitionService entry ID sync error: $e');
      }
    }

    if (hasChanges) {
      _competitionsController.add(List.unmodifiable(_competitions));
    }
  }

  static Future<void> incrementEntryCommentCount(
    String entryId, {
    int delta = 1,
  }) async {
    if (delta == 0) return;

    bool updated = false;

    for (var i = 0; i < _competitions.length; i++) {
      final competition = _competitions[i];
      if (competition.entries.isEmpty) continue;

      final entryIndex = competition.entries.indexWhere(
        (entry) => entry.id == entryId,
      );

      if (entryIndex == -1) {
        continue;
      }

      final entry = competition.entries[entryIndex];
      final newCount = max(0, entry.yorumSayisi + delta);

      if (newCount == entry.yorumSayisi) {
        continue;
      }

      final appliedDelta = newCount - entry.yorumSayisi;

      final updatedEntries = [...competition.entries];
      updatedEntries[entryIndex] = entry.copyWith(yorumSayisi: newCount);

      final updatedTotalCommentCount = max(
        0,
        competition.totalCommentCount + appliedDelta,
      );

      _competitions[i] = competition.copyWith(
        entries: updatedEntries,
        totalCommentCount: updatedTotalCommentCount,
      );
      updated = true;

      try {
        await _firestore.collection('competitions').doc(competition.id).update({
          'entries': updatedEntries.map((e) => e.toJson()).toList(),
          'totalCommentCount': updatedTotalCommentCount,
        });
      } catch (e) {
        // ignore: avoid_print
        print('CompetitionService comment update error: $e');
      }
    }

    if (updated) {
      _competitionsController.add(List.unmodifiable(_competitions));
    }
  }

  static Future<void> incrementEntryLikeCount(
    String entryId, {
    int delta = 1,
  }) async {
    if (delta == 0) return;

    bool updated = false;

    for (var i = 0; i < _competitions.length; i++) {
      final competition = _competitions[i];
      if (competition.entries.isEmpty) continue;

      final entryIndex = competition.entries.indexWhere(
        (entry) => entry.id == entryId,
      );

      if (entryIndex == -1) {
        continue;
      }

      final entry = competition.entries[entryIndex];
      final newCount = max(0, entry.begeniSayisi + delta);

      if (newCount == entry.begeniSayisi) {
        continue;
      }

      final updatedEntries = [...competition.entries];
      updatedEntries[entryIndex] = entry.copyWith(begeniSayisi: newCount);

      _competitions[i] = competition.copyWith(entries: updatedEntries);
      updated = true;

      try {
        await _firestore.collection('competitions').doc(competition.id).update({
          'entries': updatedEntries.map((e) => e.toJson()).toList(),
        });
      } catch (e) {
        // ignore: avoid_print
        print('CompetitionService like update error: $e');
      }
    }

    if (updated) {
      _competitionsController.add(List.unmodifiable(_competitions));
    }
  }

  static bool _hasOngoingCompetition(String userId) {
    final now = DateTime.now();
    return _competitions.any((competition) {
      if (competition.createdByUserId != userId) return false;
      if (now.isAfter(competition.endDate)) return false;
      return competition.status == CompetitionStatus.active ||
          competition.status == CompetitionStatus.upcoming ||
          competition.status == CompetitionStatus.voting ||
          competition.status == CompetitionStatus.results;
    });
  }

  static bool _hasActiveParticipation(String userId,
      {String? exceptCompetitionId}) {
    final now = DateTime.now();
    return _competitions.any((competition) {
      if (competition.id == exceptCompetitionId) return false;
      if (!competition.participantUserIds.contains(userId)) return false;
      if (now.isAfter(competition.endDate)) return false;
      return competition.status == CompetitionStatus.active ||
          competition.status == CompetitionStatus.upcoming ||
          competition.status == CompetitionStatus.voting ||
          competition.status == CompetitionStatus.results;
    });
  }

  static bool _isDurationWithinLimit(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      return false;
    }
    final maxEnd = start.add(const Duration(days: maxCompetitionDurationDays));
    return !end.isAfter(maxEnd);
  }

  static Future<List<Competition>> _loadCompetitionsFromFirestore() async {
    try {
      final snapshot = await _firestore
          .collection('competitions')
          .orderBy('startDate')
          .get();

      return snapshot.docs
          .map(
            (doc) => Competition.fromFirestore(doc.data(), documentId: doc.id),
          )
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('CompetitionService Firestore load error: $e');
      return [];
    }
  }

  static Future<void> _persistCompetitionsToFirestore(
    List<Competition> competitions,
  ) async {
    try {
      final collection = _firestore.collection('competitions');
      final batch = _firestore.batch();

      final existingDocs = await collection.get();
      for (final doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }

      for (final competition in competitions) {
        final docRef = collection.doc(competition.id);
        batch.set(docRef, competition.toFirestore());
      }

      await batch.commit();
    } catch (e) {
      // ignore: avoid_print
      print('CompetitionService Firestore persist error: $e');
    }
  }

  static void _listenToFirestoreUpdates() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = _firestore
        .collection('competitions')
        .orderBy('startDate')
        .snapshots()
        .listen(
          (snapshot) {
            final competitions = snapshot.docs
                .map(
                  (doc) =>
                      Competition.fromFirestore(doc.data(), documentId: doc.id),
                )
                .toList();

            _competitions
              ..clear()
              ..addAll(competitions);
            _competitionsController.add(List.unmodifiable(_competitions));
          },
          onError: (error) {
            // ignore: avoid_print
            print('CompetitionService Firestore stream error: $error');
          },
        );
  }

  // Dispose
  static void dispose() {
    _updateTimer?.cancel();
    _firestoreSubscription?.cancel();
    _competitions.clear();
    _competitionsController.add(const []);
    _isInitialized = false;
  }

  // Generate sample competition for testing
  static Competition generateSampleCompetition() {
    final now = DateTime.now();
    final random = Random();

    final types = CompetitionType.values;
    final categories = CringeCategory.values;

    return Competition(
      id: 'sample_\${random.nextInt(1000)}',
      title: 'Test Yarışması \${random.nextInt(100)}',
      description: 'Test amaçlı oluşturulmuş örnek yarışma',
      type: types[random.nextInt(types.length)],
      status: CompetitionStatus.upcoming,
      startDate: now.add(Duration(hours: random.nextInt(24))),
      endDate: now.add(Duration(days: random.nextInt(7) + 1)),
      votingEndDate: now.add(Duration(days: random.nextInt(7) + 8)),
      prizeKrepCoins: (random.nextInt(10) + 1) * 100.0,
      specificCategory: random.nextBool()
          ? categories[random.nextInt(categories.length)]
          : null,
    );
  }
}
