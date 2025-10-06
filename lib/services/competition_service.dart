import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/competition_category_model.dart';
import '../models/competition_model.dart';
import '../models/competition_entry_model.dart';
import '../models/competition_participant_models.dart';

/// Yarışma servisi - tüm competition CRUD işlemleri
class CompetitionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CompetitionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // ====================================================================
  // CATEGORIES
  // ====================================================================

  /// Tüm kategorileri listele
  Stream<List<CompetitionCategory>> streamCategories() {
    return _firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => CompetitionCategory.fromFirestore(doc))
              .toList(),
        );
  }

  /// Kategori oluştur (sadece superadmin)
  Future<CompetitionCategory> createCategory({
    required String name,
    String? description,
    String? iconUrl,
    int order = 0,
  }) async {
    final now = DateTime.now();
    final data = {
      'name': name,
      if (description != null) 'description': description,
      if (iconUrl != null) 'iconUrl': iconUrl,
      'order': order,
      'isActive': true,
      'createdAt': Timestamp.fromDate(now),
    };

    final docRef = await _firestore.collection('categories').add(data);
    return CompetitionCategory(
      id: docRef.id,
      name: name,
      description: description,
      iconUrl: iconUrl,
      order: order,
      isActive: true,
      createdAt: now,
    );
  }

  // ====================================================================
  // COMPETITIONS - CRUD
  // ====================================================================

  /// Aktif yarışmaları listele (public + live)
  Stream<List<Competition>> streamLiveCompetitions({String? categoryId}) {
    var query = _firestore
        .collection('competitions')
        .where('status', isEqualTo: 'live')
        .where('visibility', isEqualTo: 'public');

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query
        .orderBy('startAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => Competition.fromFirestore(doc)).toList(),
        );
  }

  /// Belirli bir yarışmayı getir
  Future<Competition?> getCompetition(String competitionId) async {
    final doc = await _firestore
        .collection('competitions')
        .doc(competitionId)
        .get();
    if (!doc.exists) return null;
    return Competition.fromFirestore(doc);
  }

  /// Yarışma oluştur (admin only)
  Future<Competition> createCompetition({
    required String title,
    String? description,
    required String categoryId,
    String? subCategoryId,
    required CompetitionType type,
    required DateTime startAt,
    required DateTime endAt,
    required double prizeAmount,
    bool isPublic = true,
    bool requiresApproval = false,
    int? entryLimitPerUser,
    Map<String, dynamic>? options,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı girişi gerekli');

    final now = DateTime.now();
    final data = {
      'title': title,
      if (description != null) 'description': description,
      'categoryId': categoryId,
      if (subCategoryId != null) 'subCategoryId': subCategoryId,
      'type': type.name,
      'status': CompetitionStatus.draft.name,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'visibility': isPublic ? 'public' : 'private',
      'createdAt': Timestamp.fromDate(now),
      'createdBy': user.uid,
      'prize': {'currency': 'CG', 'amount': prizeAmount},
      if (entryLimitPerUser != null) 'entryLimitPerUser': entryLimitPerUser,
      'requiresApproval': requiresApproval,
      if (options != null) 'options': options,
      'participantCount': 0,
      'totalVotes': 0,
    };

    final docRef = await _firestore.collection('competitions').add(data);
    data['id'] = docRef.id;
    return Competition.fromJson(data);
  }

  /// Yarışma durumunu güncelle (admin only)
  Future<void> updateCompetitionStatus(
    String competitionId,
    CompetitionStatus newStatus,
  ) async {
    await _firestore.collection('competitions').doc(competitionId).update({
      'status': newStatus.name,
    });
  }

  /// Yarışma bilgilerini güncelle (admin only, draft durumunda)
  Future<void> updateCompetition(
    String competitionId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore
        .collection('competitions')
        .doc(competitionId)
        .update(updates);
  }

  // ====================================================================
  // ENTRIES - Upload Yarışma Katılımları
  // ====================================================================

  /// Yarışma entry'lerini listele (onaylı olanlar)
  Stream<List<CompetitionEntry>> streamCompetitionEntries(
    String competitionId,
  ) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('entries')
        .where('status', isEqualTo: 'approved')
        .orderBy('votes', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => CompetitionEntry.fromFirestore(
                  doc,
                  competitionId: competitionId,
                ),
              )
              .toList(),
        );
  }

  /// Entry oluştur (upload yarışması)
  Future<CompetitionEntry> createEntry({
    required String competitionId,
    String? caption,
    required List<String> mediaRefs,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı girişi gerekli');

    final now = DateTime.now();
    final data = {
      'ownerId': user.uid,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      'mediaRefs': mediaRefs,
      'status': EntryStatus.pending.name,
      'createdAt': Timestamp.fromDate(now),
      'votes': 0,
    };

    await _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('entries')
        .doc(user.uid)
        .set(data);

    return CompetitionEntry(
      id: user.uid,
      competitionId: competitionId,
      ownerId: user.uid,
      caption: caption,
      mediaRefs: mediaRefs,
      status: EntryStatus.pending,
      createdAt: now,
      votes: 0,
    );
  }

  /// Entry durumunu güncelle (admin only)
  Future<void> updateEntryStatus(
    String competitionId,
    String entryId,
    EntryStatus newStatus,
  ) async {
    await _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('entries')
        .doc(entryId)
        .update({'status': newStatus.name});
  }

  /// Kullanıcının entry'sini getir
  Future<CompetitionEntry?> getMyEntry(String competitionId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('entries')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return CompetitionEntry.fromFirestore(doc, competitionId: competitionId);
  }

  // ====================================================================
  // VOTES - Oylama Yarışmaları
  // ====================================================================

  /// Oy ver (kişi başı 1)
  Future<void> submitVote({
    required String competitionId,
    required String optionId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı girişi gerekli');

    final now = DateTime.now();
    await _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('votes')
        .doc(user.uid)
        .set({'optionId': optionId, 'createdAt': Timestamp.fromDate(now)});
  }

  /// Kullanıcının oyunu getir
  Future<CompetitionVote?> getMyVote(String competitionId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('votes')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return CompetitionVote.fromFirestore(doc, competitionId: competitionId);
  }

  // ====================================================================
  // PREDICTIONS - Tahmin Yarışmaları
  // ====================================================================

  /// Tahmin gönder (kişi başı 1)
  Future<void> submitPrediction({
    required String competitionId,
    required dynamic prediction,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı girişi gerekli');

    final now = DateTime.now();
    await _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('predictions')
        .doc(user.uid)
        .set({'prediction': prediction, 'createdAt': Timestamp.fromDate(now)});
  }

  /// Kullanıcının tahminini getir
  Future<CompetitionPrediction?> getMyPrediction(String competitionId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('predictions')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return CompetitionPrediction.fromFirestore(
      doc,
      competitionId: competitionId,
    );
  }

  // ====================================================================
  // QUIZ - Quiz Yarışmaları
  // ====================================================================

  /// Quiz cevabı gönder (kişi başı 1)
  Future<void> submitQuizAnswer({
    required String competitionId,
    required Map<String, dynamic> answers,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı girişi gerekli');

    final now = DateTime.now();
    await _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('quizAnswers')
        .doc(user.uid)
        .set({'answers': answers, 'createdAt': Timestamp.fromDate(now)});
  }

  /// Kullanıcının quiz cevabını getir
  Future<QuizAnswer?> getMyQuizAnswer(String competitionId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('quizAnswers')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return QuizAnswer.fromFirestore(doc, competitionId: competitionId);
  }

  // ====================================================================
  // ADMIN HELPERS
  // ====================================================================

  /// Tüm entry'leri listele (admin, onay bekleyenler dahil)
  Stream<List<CompetitionEntry>> streamAllEntries(
    String competitionId, {
    EntryStatus? filterStatus,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('entries');

    if (filterStatus != null) {
      query = query.where('status', isEqualTo: filterStatus.name);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => CompetitionEntry.fromFirestore(
                  doc,
                  competitionId: competitionId,
                ),
              )
              .toList(),
        );
  }

  /// Yarışma kazananını belirle (admin only)
  Future<void> setWinner(String competitionId, String winnerId) async {
    await _firestore.collection('competitions').doc(competitionId).update({
      'winnerId': winnerId,
      'status': CompetitionStatus.finished.name,
    });
  }
}
