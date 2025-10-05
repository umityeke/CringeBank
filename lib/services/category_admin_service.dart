import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import 'admin_panel_service.dart';

/// 🏢 CATEGORY ADMIN SERVICE
/// 
/// Her kategoride maksimum 3 admin yönetimi
/// Süper admin (umityeke@gmail.com) tüm kategorilere tam erişim
class CategoryAdminService {
  CategoryAdminService._();
  static final CategoryAdminService instance = CategoryAdminService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  static const int _maxAdminsPerCategory = 3;
  static const String _superAdminEmail = 'umityeke@gmail.com';

  /// Mevcut kullanıcının süper admin olup olmadığını kontrol et
  bool get isSuperAdmin {
    final email = _auth.currentUser?.email;
    return email != null && email.toLowerCase() == _superAdminEmail.toLowerCase();
  }

  /// Kullanıcının süper admin olup olmadığını kontrol et
  bool isUserSuperAdmin(String email) {
    return email.toLowerCase() == _superAdminEmail.toLowerCase();
  }

  /// Kategoriye admin ata
  /// 
  /// [category] - Kategori adı (CringeCategory enum'dan gelmeli)
  /// [userId] - Atanacak kullanıcının ID'si
  /// [username] - Atanacak kullanıcının username'i
  /// [permissions] - Verilecek yetkiler ["approve", "reject", "delete"]
  /// 
  /// Throws: Exception - Süper admin değilse veya 3 admin limitine ulaşıldıysa
  Future<void> assignCategoryAdmin({
    required String category,
    required String userId,
    required String username,
    List<String> permissions = const ["approve", "reject"],
  }) async {
    // Sadece süper admin atama yapabilir
    if (!isSuperAdmin) {
      throw Exception('❌ Sadece süper admin kategori yöneticisi atayabilir!');
    }

    final existingAdmins = await getCategoryAdmins(category);
    final activeCount = existingAdmins.where((a) => a['isActive'] ?? true).length;

    if (activeCount >= _maxAdminsPerCategory) {
      throw Exception('⚠️ $category kategorisi için izin verilen maksimum admin sayısına ( $_maxAdminsPerCategory ) ulaşıldı.');
    }

    final result = await AdminPanelService.instance.assignCategoryAdmin(
      category: category,
      targetUserId: userId,
      targetUsername: username,
      permissions: permissions,
    );

    debugPrint(
      '✅ Admin ataması tamamlandı → kategori: ${result['category']} | toplam admin: ${result['adminCount']}',
    );
  }

  /// Bir kategorinin tüm adminlerini getir
  Future<List<Map<String, dynamic>>> getCategoryAdmins(String category) async {
    debugPrint('📥 Kategori adminleri getiriliyor: $category');

    final doc = await _firestore.collection('category_admins').doc(category).get();

    if (!doc.exists) {
      debugPrint('⚠️ Kategori dokümanı bulunamadı: $category');
      return [];
    }

    final admins = List<Map<String, dynamic>>.from(doc.data()?['admins'] ?? []);
    debugPrint('✅ ${admins.length} admin bulundu: $category');

    return admins;
  }

  /// Kullanıcının admin olduğu kategorileri getir
  Future<List<String>> getUserModeratedCategories(String userId) async {
    debugPrint('📥 Kullanıcının yönettiği kategoriler getiriliyor: $userId');

    final snapshot = await _firestore.collection('category_admins').get();
    final categories = <String>[];

    for (final doc in snapshot.docs) {
      final admins = List<Map<String, dynamic>>.from(doc.data()['admins'] ?? []);
      
      final isAdmin = admins.any(
        (a) => a['userId'] == userId && (a['isActive'] ?? true),
      );

      if (isAdmin) {
        categories.add(doc.id);
      }
    }

    debugPrint('✅ ${categories.length} kategori bulundu: $categories');
    return categories;
  }

  /// Kullanıcının belirli bir kategoriyi yönetme yetkisi var mı?
  Future<bool> canModerateCategory(String userId, String category) async {
    // Süper admin her şeyi yönetebilir
    final user = await _firestore.collection('users').doc(userId).get();
    if (user.exists) {
      final email = user.data()?['email'] as String?;
      if (email != null && isUserSuperAdmin(email)) {
        return true;
      }
    }

    debugPrint('🔍 Yetki kontrolü: $userId → $category');

    final admins = await getCategoryAdmins(category);
    final canModerate = admins.any(
      (a) => a['userId'] == userId && (a['isActive'] ?? true),
    );

    debugPrint(canModerate ? '✅ Yetki var' : '❌ Yetki yok');
    return canModerate;
  }

  /// Kullanıcının bir kategorideki yetkilerini getir
  Future<List<String>> getCategoryPermissions(
    String userId,
    String category,
  ) async {
    // Süper admin tüm yetkilere sahip
    final user = await _firestore.collection('users').doc(userId).get();
    if (user.exists) {
      final email = user.data()?['email'] as String?;
      if (email != null && isUserSuperAdmin(email)) {
        return ['approve', 'reject', 'delete', 'assign_admins', 'all'];
      }
    }

    final admins = await getCategoryAdmins(category);
    final admin = admins.firstWhere(
      (a) => a['userId'] == userId,
      orElse: () => <String, dynamic>{},
    );

    return List<String>.from(admin['permissions'] ?? []);
  }

  /// Tüm kategorileri ve admin sayılarını getir
  Future<Map<String, int>> getAllCategoriesWithAdminCount() async {
    debugPrint('📊 Tüm kategoriler ve admin sayıları getiriliyor...');

    final snapshot = await _firestore.collection('category_admins').get();
    final result = <String, int>{};

    for (final doc in snapshot.docs) {
      final admins = List<Map<String, dynamic>>.from(doc.data()['admins'] ?? []);
      final activeAdmins = admins.where((a) => a['isActive'] ?? true).length;
      result[doc.id] = activeAdmins;
    }

    debugPrint('✅ ${result.length} kategori bulundu');
    return result;
  }

  /// Admin yetkisini aktif/pasif yap
  Future<void> toggleAdminStatus({
    required String category,
    required String userId,
    required bool isActive,
  }) async {
    if (!isSuperAdmin) {
      throw Exception('❌ Sadece süper admin durum değiştirebilir!');
    }
    await AdminPanelService.instance.toggleCategoryAdminStatus(
      category: category,
      targetUserId: userId,
      isActive: isActive,
    );

    debugPrint(
      '✅ Admin durumu değiştirildi: ${isActive ? "Aktif" : "Pasif"} - $userId → $category',
    );
  }
}
