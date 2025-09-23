import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart' as app_user;
import 'firebase_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Current user stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;

  // Email & Password Authentication
  static Future<AuthResult> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        return AuthResult.success(credential.user!);
      }
      return AuthResult.failure('Giriş başarısız');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('Beklenmeyen bir hata oluştu');
    }
  }

  static Future<AuthResult> createUserWithEmailAndPassword(
    String email,
    String password,
    String username,
    String fullName,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        // Create user profile in Firestore
        final user = app_user.User(
          id: credential.user!.uid,
          email: email.trim(),
          username: username.trim(),
          fullName: fullName.trim(),
          avatar: '👤',
          bio: 'Yeni krep avcısı!',
          krepLevel: 1,
          krepScore: 0,
          followersCount: 0,
          followingCount: 0,
          entriesCount: 0,
          isPremium: false,
          isVerified: false,
          joinDate: DateTime.now(),
          lastActive: DateTime.now(),
        );

        await FirebaseService.createUserRecord(user);
        
        return AuthResult.success(credential.user!);
      }
      return AuthResult.failure('Hesap oluşturulamadı');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('Beklenmeyen bir hata oluştu');
    }
  }

  // Google Sign In
  static Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Google girişi iptal edildi');
      }

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Check if user exists in Firestore
        final existingUser = await FirebaseService.getUser(userCredential.user!.uid);
        
        if (existingUser == null) {
          // Create new user profile
          final user = app_user.User(
            id: userCredential.user!.uid,
            email: userCredential.user!.email ?? '',
            username: _generateUsernameFromEmail(userCredential.user!.email ?? ''),
            fullName: userCredential.user!.displayName ?? 'Google Kullanıcısı',
            avatar: userCredential.user!.photoURL ?? '👤',
            bio: 'Google ile katıldı!',
            krepLevel: 1,
            krepScore: 0,
            followersCount: 0,
            followingCount: 0,
            entriesCount: 0,
            isPremium: false,
            isVerified: false,
            joinDate: DateTime.now(),
            lastActive: DateTime.now(),
          );

          await FirebaseService.createUserRecord(user);
        }
        
        return AuthResult.success(userCredential.user!);
      }
      return AuthResult.failure('Google girişi başarısız');
    } catch (e) {
      return AuthResult.failure('Google girişi sırasında hata oluştu');
    }
  }

  // Phone Authentication
  static Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(PhoneAuthCredential) verificationCompleted,
    Function(FirebaseAuthException) verificationFailed,
    Function(String, int?) codeSent,
    Function(String) codeAutoRetrievalTimeout,
  ) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print('Phone verification error: $e');
    }
  }

  static Future<AuthResult> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Check if user exists in Firestore
        final existingUser = await FirebaseService.getUser(userCredential.user!.uid);
        
        if (existingUser == null) {
          // Create new user profile
          final user = app_user.User(
            id: userCredential.user!.uid,
            email: '',
            username: 'kullanici_${DateTime.now().millisecondsSinceEpoch}',
            fullName: 'Telefon Kullanıcısı',
            avatar: '📱',
            bio: 'Telefon ile katıldı!',
            krepLevel: 1,
            krepScore: 0,
            followersCount: 0,
            followingCount: 0,
            entriesCount: 0,
            isPremium: false,
            isVerified: false,
            joinDate: DateTime.now(),
            lastActive: DateTime.now(),
          );

          await FirebaseService.createUserRecord(user);
        }
        
        return AuthResult.success(userCredential.user!);
      }
      return AuthResult.failure('Telefon girişi başarısız');
    } catch (e) {
      return AuthResult.failure('Telefon doğrulama hatası');
    }
  }

  // Password Reset
  static Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null, message: 'Şifre sıfırlama e-postası gönderildi');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('E-posta gönderilemedi');
    }
  }

  // Sign Out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Delete Account
  static Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure('Kullanıcı bulunamadı');
      }

      // Delete user data from Firestore
      final userEntries = await FirebaseService.getUserCringeEntries(user.uid);
      for (final entry in userEntries) {
        await FirebaseService.deleteCringeEntry(entry.id);
      }

      // Delete user profile
      await FirebaseFirestore.instance
          .collection(FirebaseService.usersCollection)
          .doc(user.uid)
          .delete();

      // Delete Firebase Auth account
      await user.delete();
      
      return AuthResult.success(null, message: 'Hesap başarıyla silindi');
    } catch (e) {
      return AuthResult.failure('Hesap silinirken hata oluştu');
    }
  }

  // Helper Methods
  static String _generateUsernameFromEmail(String email) {
    final username = email.split('@')[0];
    return username.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  static String _getFirebaseAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı';
      case 'wrong-password':
        return 'Hatalı şifre';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda';
      case 'weak-password':
        return 'Şifre çok zayıf';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin';
      case 'network-request-failed':
        return 'İnternet bağlantısı hatası';
      case 'operation-not-allowed':
        return 'Bu işlem şu anda kullanılamıyor';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış';
      default:
        return 'Bir hata oluştu. Lütfen tekrar deneyin';
    }
  }

  // Update user activity
  static Future<void> updateUserActivity() async {
    try {
      final userId = currentUserId;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection(FirebaseService.usersCollection)
            .doc(userId)
            .update({'lastActive': DateTime.now()});
      }
    } catch (e) {
      print('Update user activity error: $e');
    }
  }
}

// Auth Result Class
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? message;
  final String? error;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.message,
    this.error,
  });

  factory AuthResult.success(User? user, {String? message}) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      message: message,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(
      isSuccess: false,
      error: error,
    );
  }
}

// Auth State Notifier
class AuthStateNotifier {
  static final _instance = AuthStateNotifier._internal();
  factory AuthStateNotifier() => _instance;
  AuthStateNotifier._internal();

  Stream<User?> get authStateChanges => AuthService.authStateChanges;
  User? get currentUser => AuthService.currentUser;
  String? get currentUserId => AuthService.currentUserId;

  bool get isAuthenticated => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;
}