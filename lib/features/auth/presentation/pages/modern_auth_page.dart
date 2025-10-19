import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';

class ModernAuthPage extends ConsumerWidget {
  const ModernAuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Modern Kimlik Akışı')),
      body: Center(
        child: authState.when(
          data: (user) {
            if (user == null) {
              return const Text(
                'Oturum açmış bir kullanıcı bulunamadı. Giriş ekranına yönlendirme yapılacak.',
                textAlign: TextAlign.center,
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Merhaba, ${user.email ?? user.uid}!'),
                const SizedBox(height: 12),
                Text(
                  isAuthenticated
                      ? 'Kimlik doğrulama başarılı.'
                      : 'Kimlik doğrulama bekleniyor.',
                ),
              ],
            );
          },
          error: (error, _) => Text('Kimlik durumu alınamadı: $error'),
          loading: () => const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
