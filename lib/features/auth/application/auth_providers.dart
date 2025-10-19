import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<firebase_auth.FirebaseAuth>((ref) {
  return firebase_auth.FirebaseAuth.instance;
});

final authStateChangesProvider = StreamProvider<firebase_auth.User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

final authIdTokenChangesProvider = StreamProvider<firebase_auth.User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.idTokenChanges();
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref
      .watch(authStateChangesProvider)
      .maybeWhen(data: (user) => user != null, orElse: () => false);
});

final currentUserProvider = Provider<firebase_auth.User?>((ref) {
  return ref
      .watch(authStateChangesProvider)
      .maybeWhen(data: (user) => user, orElse: () => null);
});
