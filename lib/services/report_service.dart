// Report Service - User Reporting System
// Handles report creation, retrieval, and moderation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/report.dart';

class ReportService {
  static ReportService? _instance;
  static ReportService get instance => _instance ??= ReportService._();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ReportService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // === USER ACTIONS ===

  /// Create a new report (any authenticated user)
  /// Security Contract: Users can only create reports, not modify status
  Future<String> createReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? note,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    // Check if user already reported this target
    final existingReport = await _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: currentUser.uid)
        .where('target.type', isEqualTo: targetType.value)
        .where('target.id', isEqualTo: targetId)
        .limit(1)
        .get();

    if (existingReport.docs.isNotEmpty) {
      throw Exception('DUPLICATE_REPORT: Bu içeriği zaten bildirdiniz');
    }

    final report = Report(
      id: '', // Will be set by Firestore
      reporterId: currentUser.uid,
      target: ReportTarget(type: targetType, id: targetId),
      reason: reason,
      note: note,
      status: ReportStatus.pending,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('reports')
        .add(report.toFirestore());

    debugPrint(
      '📢 REPORT CREATED: ${targetType.value}/$targetId by ${currentUser.uid} (${reason.value})',
    );

    return docRef.id;
  }

  /// Get user's own reports
  Future<List<Report>> getUserReports() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    final snapshot = await _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) => Report.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Stream of user's own reports
  Stream<List<Report>> getUserReportsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Report.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  // === MODERATOR ACTIONS ===
  // Note: These methods check for moderator custom claim
  // UserService should provide isModerator() check

  /// Get all pending reports (moderators only)
  Future<List<Report>> getPendingReports() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    // Check if user is moderator
    final idTokenResult = await currentUser.getIdTokenResult();
    final isModerator = idTokenResult.claims?['moderator'] == true;

    if (!isModerator) {
      throw Exception(
        'NOT_AUTHORIZED: Bu işlem için moderatör yetkisi gerekli',
      );
    }

    final snapshot = await _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false) // Oldest first
        .limit(100)
        .get();

    return snapshot.docs
        .map((doc) => Report.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Stream of pending reports (moderators only)
  Stream<List<Report>> getPendingReportsStream() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    // Check moderator status
    final idTokenResult = await currentUser.getIdTokenResult();
    final isModerator = idTokenResult.claims?['moderator'] == true;

    if (!isModerator) {
      yield [];
      return;
    }

    yield* _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Report.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get reports for a specific target (moderators only)
  Future<List<Report>> getReportsForTarget({
    required ReportTargetType targetType,
    required String targetId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    final idTokenResult = await currentUser.getIdTokenResult();
    final isModerator = idTokenResult.claims?['moderator'] == true;

    if (!isModerator) {
      throw Exception(
        'NOT_AUTHORIZED: Bu işlem için moderatör yetkisi gerekli',
      );
    }

    final snapshot = await _firestore
        .collection('reports')
        .where('target.type', isEqualTo: targetType.value)
        .where('target.id', isEqualTo: targetId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Report.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Resolve a report (moderators only)
  /// This marks the report as resolved and optionally adds resolution notes
  Future<void> resolveReport({
    required String reportId,
    required String resolution,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    final idTokenResult = await currentUser.getIdTokenResult();
    final isModerator = idTokenResult.claims?['moderator'] == true;

    if (!isModerator) {
      throw Exception(
        'NOT_AUTHORIZED: Bu işlem için moderatör yetkisi gerekli',
      );
    }

    await _firestore.collection('reports').doc(reportId).update({
      'status': ReportStatus.resolved.value,
      'reviewedAt': DateTime.now().millisecondsSinceEpoch,
      'reviewedBy': currentUser.uid,
      'resolution': resolution,
    });

    debugPrint('✅ REPORT RESOLVED: $reportId by ${currentUser.uid}');
  }

  /// Dismiss a report (moderators only)
  /// This marks the report as dismissed (not a violation)
  Future<void> dismissReport({
    required String reportId,
    required String reason,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    final idTokenResult = await currentUser.getIdTokenResult();
    final isModerator = idTokenResult.claims?['moderator'] == true;

    if (!isModerator) {
      throw Exception(
        'NOT_AUTHORIZED: Bu işlem için moderatör yetkisi gerekli',
      );
    }

    await _firestore.collection('reports').doc(reportId).update({
      'status': ReportStatus.dismissed.value,
      'reviewedAt': DateTime.now().millisecondsSinceEpoch,
      'reviewedBy': currentUser.uid,
      'resolution': reason,
    });

    debugPrint('❌ REPORT DISMISSED: $reportId by ${currentUser.uid}');
  }

  /// Get report statistics (moderators only)
  Future<Map<String, int>> getReportStats() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    final idTokenResult = await currentUser.getIdTokenResult();
    final isModerator = idTokenResult.claims?['moderator'] == true;

    if (!isModerator) {
      throw Exception(
        'NOT_AUTHORIZED: Bu işlem için moderatör yetkisi gerekli',
      );
    }

    // Get counts for each status
    final pendingCount = await _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .count()
        .get();

    final resolvedCount = await _firestore
        .collection('reports')
        .where('status', isEqualTo: 'resolved')
        .count()
        .get();

    final dismissedCount = await _firestore
        .collection('reports')
        .where('status', isEqualTo: 'dismissed')
        .count()
        .get();

    return {
      'pending': pendingCount.count ?? 0,
      'resolved': resolvedCount.count ?? 0,
      'dismissed': dismissedCount.count ?? 0,
      'total':
          (pendingCount.count ?? 0) +
          (resolvedCount.count ?? 0) +
          (dismissedCount.count ?? 0),
    };
  }

  // === UTILITY METHODS ===

  /// Delete a report (only the reporter or moderators)
  Future<void> deleteReport(String reportId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('NOT_AUTHENTICATED: Kullanıcı oturumu bulunamadı');
    }

    final doc = await _firestore.collection('reports').doc(reportId).get();
    if (!doc.exists) {
      throw Exception('REPORT_NOT_FOUND: Rapor bulunamadı');
    }

    final report = Report.fromFirestore(doc.data()!, doc.id);

    // Check if user is reporter or moderator
    final idTokenResult = await currentUser.getIdTokenResult();
    final isModerator = idTokenResult.claims?['moderator'] == true;
    final isReporter = report.reporterId == currentUser.uid;

    if (!isReporter && !isModerator) {
      throw Exception('NOT_AUTHORIZED: Bu raporu silme yetkiniz yok');
    }

    await _firestore.collection('reports').doc(reportId).delete();
    debugPrint('🗑️ REPORT DELETED: $reportId');
  }
}
