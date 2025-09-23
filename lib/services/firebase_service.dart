import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart' as app_user;
import '../models/cringe_entry.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collections
  static const String usersCollection = 'users';
  static const String cringeEntriesCollection = 'cringe_entries';
  static const String tradesCollection = 'trades';
  static const String competitionsCollection = 'competitions';

  // Authentication
  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Auth Methods
  static Future<UserCredential?> signInWithEmailAndPassword(
    String email, 
    String password
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  static Future<UserCredential?> createUserWithEmailAndPassword(
    String email, 
    String password
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
    } catch (e) {
      print('Sign up error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google Sign In işlemi burada implement edilecek
      // Şimdilik mock response
      throw UnimplementedError('Google Sign In not implemented yet');
    } catch (e) {
      print('Google sign in error: $e');
      rethrow;
    }
  }

  // User Data Methods
  static Future<void> createUserRecord(app_user.User user) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(user.id)
          .set(user.toJson());
    } catch (e) {
      print('Create user error: $e');
    }
  }

  // Overloaded createUser method for compatibility
  Future<void> createUser({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    try {
      final user = app_user.User(
        id: userId,
        username: displayName.toLowerCase().replaceAll(' ', '_'),
        email: email,
        fullName: displayName,
        joinDate: DateTime.now(),
        lastActive: DateTime.now(),
      );
      
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .set(user.toJson());
    } catch (e) {
      print('Create user error: $e');
    }
  }

  static Future<app_user.User?> getUser(String userId) async {
    try {
      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return app_user.User.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Get user error: $e');
      return null;
    }
  }

  // Method aliases for compatibility
  Future<app_user.User?> getUserData(String userId) async {
    return await getUser(userId);
  }

  Stream<app_user.User?> getUserStream(String userId) {
    return _firestore
        .collection(usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return app_user.User.fromJson(doc.data()!);
      }
      return null;
    });
  }

  Future<List<CringeEntry>> getRecentCringeEntries({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection(cringeEntriesCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => CringeEntry.fromMap({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      print('Get recent entries error: $e');
      return [];
    }
  }

  static Future<app_user.User?> getUserById(String userId) async {
    try {
      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return app_user.User.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Get user error: $e');
      return null;
    }
  }

  static Future<void> updateUser(app_user.User user) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(user.id)
          .update(user.toJson());
    } catch (e) {
      print('Update user error: $e');
    }
  }

  // Cringe Entry Methods
  static Future<void> createCringeEntry(CringeEntry entry) async {
    try {
      await _firestore
          .collection(cringeEntriesCollection)
          .doc(entry.id)
          .set(entry.toJson());
    } catch (e) {
      print('Create cringe entry error: $e');
    }
  }

  static Future<CringeEntry?> getCringeEntry(String entryId) async {
    try {
      final doc = await _firestore
          .collection(cringeEntriesCollection)
          .doc(entryId)
          .get();
      
      if (doc.exists) {
        return CringeEntry.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Get cringe entry error: $e');
      return null;
    }
  }

  static Stream<List<CringeEntry>> getCringeEntriesStream({
    int limit = 20,
    String? category,
    bool isPublic = true,
  }) {
    try {
      Query query = _firestore
          .collection(cringeEntriesCollection)
          .where('isPublic', isEqualTo: isPublic)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      return query.snapshots().map((snapshot) =>
          snapshot.docs
              .map((doc) => CringeEntry.fromJson(doc.data() as Map<String, dynamic>))
              .toList());
    } catch (e) {
      print('Get cringe entries stream error: $e');
      return Stream.value([]);
    }
  }

  static Future<List<CringeEntry>> getUserCringeEntries(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(cringeEntriesCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => CringeEntry.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Get user cringe entries error: $e');
      return [];
    }
  }

  static Stream<List<CringeEntry>> getUserCringeEntriesStream(String userId) {
    return _firestore
        .collection(cringeEntriesCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CringeEntry.fromJson(doc.data()))
            .toList());
  }

  static Future<void> updateCringeEntry(CringeEntry entry) async {
    try {
      await _firestore
          .collection(cringeEntriesCollection)
          .doc(entry.id)
          .update(entry.toJson());
    } catch (e) {
      print('Update cringe entry error: $e');
    }
  }

  static Future<void> deleteCringeEntry(String entryId) async {
    try {
      await _firestore
          .collection(cringeEntriesCollection)
          .doc(entryId)
          .delete();
    } catch (e) {
      print('Delete cringe entry error: $e');
    }
  }

  // Like/Unlike Methods
  static Future<void> likeCringeEntry(String entryId, String userId) async {
    try {
      await _firestore
          .collection(cringeEntriesCollection)
          .doc(entryId)
          .update({
        'likedBy': FieldValue.arrayUnion([userId]),
        'likesCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Like cringe entry error: $e');
    }
  }

  static Future<void> unlikeCringeEntry(String entryId, String userId) async {
    try {
      await _firestore
          .collection(cringeEntriesCollection)
          .doc(entryId)
          .update({
        'likedBy': FieldValue.arrayRemove([userId]),
        'likesCount': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Unlike cringe entry error: $e');
    }
  }

  // Search Methods
  static Future<List<CringeEntry>> searchCringeEntries(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection(cringeEntriesCollection)
          .where('isPublic', isEqualTo: true)
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => CringeEntry.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Search cringe entries error: $e');
      return [];
    }
  }

  static Future<List<app_user.User>> searchUsers(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection(usersCollection)
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => app_user.User.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Search users error: $e');
      return [];
    }
  }

  // Storage Methods
  static Future<String?> uploadImage(String path, List<int> bytes) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putData(
        bytes as Uint8List,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Upload image error: $e');
      return null;
    }
  }

  static Future<void> deleteImage(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } catch (e) {
      print('Delete image error: $e');
    }
  }

  // Analytics Methods
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userEntries = await getUserCringeEntries(userId);
      final totalLikes = userEntries.fold<int>(0, (sum, entry) => sum + entry.begeniSayisi);
      final totalShares = userEntries.fold<int>(0, (sum, entry) => sum + entry.retweetSayisi);
      
      return {
        'totalEntries': userEntries.length,
        'totalLikes': totalLikes,
        'totalShares': totalShares,
        'averageLikes': userEntries.isNotEmpty ? totalLikes / userEntries.length : 0,
        'categories': _getCategoriesStats(userEntries),
      };
    } catch (e) {
      print('Get user stats error: $e');
      return {};
    }
  }

  static Map<String, int> _getCategoriesStats(List<CringeEntry> entries) {
    final Map<String, int> categories = {};
    for (final entry in entries) {
      categories[entry.kategori.displayName] = (categories[entry.kategori.displayName] ?? 0) + 1;
    }
    return categories;
  }

  // Batch Operations
  static Future<void> batchUpdate(List<Map<String, dynamic>> updates) async {
    try {
      final batch = _firestore.batch();
      
      for (final update in updates) {
        final docRef = _firestore
            .collection(update['collection'])
            .doc(update['docId']);
        batch.update(docRef, update['data']);
      }
      
      await batch.commit();
    } catch (e) {
      print('Batch update error: $e');
    }
  }
}

// Firestore Extensions
extension FirestoreExtensions on DocumentReference {
  Future<bool> exists() async {
    final doc = await this.get();
    return doc.exists;
  }
}