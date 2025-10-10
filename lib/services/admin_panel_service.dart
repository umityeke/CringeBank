import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'telemetry/callable_latency_tracker.dart';

/// 🛡️ ADMIN PANEL SERVICE - Secure Admin Operations
///
/// Tüm admin işlemleri Cloud Functions üzerinden yapılır.
/// Client-side Firestore yazma işlemleri güvenlik nedeniyle kapalıdır.
class AdminPanelService {
  AdminPanelService._();
  static final AdminPanelService instance = AdminPanelService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Mevcut kullanıcının süper admin olup olmadığını kontrol et
  Future<bool> get isSuperAdmin async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Force token refresh to get latest claims
    await user.getIdToken(true);
    final idTokenResult = await user.getIdTokenResult();
    final claims = idTokenResult.claims;

    return claims?['superadmin'] == true ||
        claims?['admin'] == true ||
        user.email?.toLowerCase() == 'umityeke@gmail.com';
  }

  /// Kategori admin atama (süper admin only)
  Future<Map<String, dynamic>> assignCategoryAdmin({
    required String category,
    required String targetUserId,
    required String targetUsername,
    List<String> permissions = const ['approve', 'reject'],
  }) async {
    debugPrint('🔐 Calling assignCategoryAdmin function...');

    try {
      final result = await _functions.callWithLatency<dynamic>(
        'assignCategoryAdmin',
        payload: {
          'category': category,
          'targetUserId': targetUserId,
          'targetUsername': targetUsername,
          'permissions': permissions,
        },
        category: 'adminPanel',
      );

      debugPrint('✅ ${result.data['message']}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Error: $e');
      rethrow;
    }
  }

  /// Kategori admin kaldırma (süper admin only)
  Future<Map<String, dynamic>> removeCategoryAdmin({
    required String category,
    required String targetUserId,
  }) async {
    debugPrint('🔐 Calling removeCategoryAdmin function...');

    try {
      final result = await _functions.callWithLatency<dynamic>(
        'removeCategoryAdmin',
        payload: {'category': category, 'targetUserId': targetUserId},
        category: 'adminPanel',
      );

      debugPrint('✅ ${result.data['message']}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Error: $e');
      rethrow;
    }
  }

  /// Admin durumu değiştir (aktif/pasif)
  Future<Map<String, dynamic>> toggleCategoryAdminStatus({
    required String category,
    required String targetUserId,
    required bool isActive,
  }) async {
    debugPrint('🔐 Calling toggleCategoryAdminStatus function...');

    try {
      final result = await _functions.callWithLatency<dynamic>(
        'toggleCategoryAdminStatus',
        payload: {
          'category': category,
          'targetUserId': targetUserId,
          'isActive': isActive,
        },
        category: 'adminPanel',
      );

      debugPrint('✅ ${result.data['message']}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Error: $e');
      rethrow;
    }
  }

  /// Yarışma oluştur (süper admin only)
  Future<Map<String, dynamic>> createCompetition({
    required String title,
    String description = '',
    String visibility = 'public',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    debugPrint('🔐 Calling createCompetition function...');

    try {
      final result = await _functions.callWithLatency<dynamic>(
        'createCompetition',
        payload: {
          'title': title,
          'description': description,
          'visibility': visibility,
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
        category: 'adminPanel',
      );

      debugPrint('✅ Competition created: ${result.data['competitionId']}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Error: $e');
      rethrow;
    }
  }

  /// Yarışma güncelle (süper admin only)
  Future<Map<String, dynamic>> updateCompetition({
    required String competitionId,
    required Map<String, dynamic> updates,
  }) async {
    debugPrint('🔐 Calling updateCompetition function...');

    try {
      final result = await _functions.callWithLatency<dynamic>(
        'updateCompetition',
        payload: {'competitionId': competitionId, 'updates': updates},
        category: 'adminPanel',
      );

      debugPrint('✅ ${result.data['message']}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Error: $e');
      rethrow;
    }
  }

  /// Yarışma sil (süper admin only)
  Future<Map<String, dynamic>> deleteCompetition({
    required String competitionId,
  }) async {
    debugPrint('🔐 Calling deleteCompetition function...');

    try {
      final result = await _functions.callWithLatency<dynamic>(
        'deleteCompetition',
        payload: {'competitionId': competitionId},
        category: 'adminPanel',
      );

      debugPrint('✅ ${result.data['message']}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Error: $e');
      rethrow;
    }
  }

  /// Test function - Kategori admin atama testi
  Future<void> testAssignCategoryAdmin() async {
    debugPrint('');
    debugPrint('🧪 TEST: Category Admin Assignment');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('');

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ Not logged in!');
      return;
    }

    debugPrint('👤 Current user: ${user.email}');
    debugPrint('🔍 Checking super admin status...');

    final isSA = await isSuperAdmin;
    debugPrint(isSA ? '✅ Super admin confirmed' : '❌ Not super admin');
    debugPrint('');

    if (!isSA) {
      debugPrint('⚠️  You must be super admin to run this test');
      debugPrint('⚠️  Please logout and login again if you just got the claim');
      return;
    }

    try {
      // Test: Assign category admin
      debugPrint('📋 Test 1: Assign category admin...');
      final result = await assignCategoryAdmin(
        category: 'fizikselRezillik',
        targetUserId: user.uid, // Assign self for testing
        targetUsername: user.displayName ?? 'TestAdmin',
        permissions: ['approve', 'reject', 'delete'],
      );

      debugPrint('✅ Test 1 passed!');
      debugPrint('   Category: ${result['category']}');
      debugPrint('   Admin count: ${result['adminCount']}');
      debugPrint('');

      // Test: Toggle status
      debugPrint('📋 Test 2: Toggle admin status...');
      await toggleCategoryAdminStatus(
        category: 'fizikselRezillik',
        targetUserId: user.uid,
        isActive: false,
      );
      debugPrint('✅ Test 2 passed! (Status: Inactive)');
      debugPrint('');

      // Test: Toggle back
      debugPrint('📋 Test 3: Reactivate admin...');
      await toggleCategoryAdminStatus(
        category: 'fizikselRezillik',
        targetUserId: user.uid,
        isActive: true,
      );
      debugPrint('✅ Test 3 passed! (Status: Active)');
      debugPrint('');

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ ALL TESTS PASSED!');
      debugPrint('');
      debugPrint('📊 Check audit logs in Firestore:');
      debugPrint('   Collection: admin_audit');
      debugPrint('   Should contain 3 new entries');
      debugPrint('');
    } catch (e) {
      debugPrint('');
      debugPrint('❌ TEST FAILED');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Error: $e');
      debugPrint('');

      if (e.toString().contains('permission-denied')) {
        debugPrint('💡 TIP: Logout and login again to refresh claims');
      } else if (e.toString().contains('Re-authentication required')) {
        debugPrint('💡 TIP: You need to re-login within last 5 minutes');
      }
      debugPrint('');
    }
  }

  /// Test function - Yarışma oluşturma testi
  Future<void> testCreateCompetition() async {
    debugPrint('');
    debugPrint('🧪 TEST: Competition Creation');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('');

    final isSA = await isSuperAdmin;
    if (!isSA) {
      debugPrint('❌ Not super admin! Test skipped.');
      return;
    }

    try {
      final result = await createCompetition(
        title: 'Test Yarışma ${DateTime.now().millisecondsSinceEpoch}',
        description: 'Bu bir test yarışmasıdır',
        visibility: 'public',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
      );

      debugPrint('✅ Competition created!');
      debugPrint('   ID: ${result['competitionId']}');
      debugPrint('   Message: ${result['message']}');
      debugPrint('');

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ TEST PASSED!');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ TEST FAILED: $e');
    }
  }
}
