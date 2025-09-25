import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
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
    };
  }
}

class CompetitionService {
  static final List<Competition> _competitions = [];
  static final StreamController<List<Competition>> _competitionsController =
      StreamController<List<Competition>>.broadcast();
  static Timer? _updateTimer;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _firestoreSubscription;
  static bool _isInitialized = false;

  // Competition stream
  static Stream<List<Competition>> get competitionsStream =>
      _competitionsController.stream;

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

    final updatedCompetition = competition.copyWith(
      entries: [...competition.entries, ...mockEntries],
      votes: updatedVotes,
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
        final winner = _getCompetitionWinner(competition);
        _sendCompetitionNotification(
          title: '🎉 Sonuçlar Açıklandı!',
          body: winner != null
              ? 'Kazanan: "\${winner.title}" - \${competition.prizeKrepCoins} Krep Coin!'
              : '"\${competition.title}" sonuçları açıklandı!',
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

  // Get competition winner
  static CringeEntry? _getCompetitionWinner(Competition competition) {
    if (competition.votes.isEmpty) return null;

    // En çok oy alan entry'yi bul
    String winnerEntryId = '';
    int maxVotes = 0;

    competition.votes.forEach((entryId, voteCount) {
      if (voteCount > maxVotes) {
        maxVotes = voteCount;
        winnerEntryId = entryId;
      }
    });

    if (winnerEntryId.isEmpty) return null;

    return competition.entries.firstWhere(
      (entry) => entry.id == winnerEntryId,
      orElse: () => competition.entries.first,
    );
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

      final updatedEntries = [...competition.entries, entry];
      _competitions[competitionIndex] = competition.copyWith(
        entries: updatedEntries,
      );
      _competitionsController.add(List.unmodifiable(_competitions));
      await _persistCompetitionsToFirestore(_competitions);

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
      _competitions.add(competition);
      _competitionsController.add(List.unmodifiable(_competitions));
      await _persistCompetitionsToFirestore(_competitions);

      // Yeni yarışma bildirimini gönder
      _sendCompetitionNotification(
        title: '🆕 Yeni Yarışma!',
        body: '"\${competition.title}" yarışması eklendi. Katılmayı unutma!',
      );

      return true;
    } catch (e) {
      // Debug: 'Create competition error: \$e'
      return false;
    }
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
