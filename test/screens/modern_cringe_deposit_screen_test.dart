import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cringebank/screens/modern_cringe_deposit_screen.dart';
import 'package:cringebank/services/competition_service.dart';
import 'package:cringebank/services/tagging_policy_service.dart';
import 'package:cringebank/shared/widgets/app_button.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpDepositScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ModernCringeDepositScreen(
          competitionServiceOverride: _MockCompetitionService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder buttonWithLabel(String label) {
    return find.byWidgetPredicate(
      (widget) => widget is AppButton && widget.label == label,
    );
  }

  testWidgets('yasakli hashtag uyarisi gosterilir ve ileri butonu pasif olur', (
    tester,
  ) async {
    final policy = TaggingPolicy(
      bannedHashtags: const {'yasakli_tag'},
      blockedUsernames: const <String>{},
      blockedUserIds: const <String>{},
      refreshedAt: DateTime.now(),
    );

    TaggingPolicyService.configureForTesting(
      firestore: _MockFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
      cachedPolicy: policy,
      cachedAt: DateTime.now(),
    );

    await pumpDepositScreen(tester);

    final descriptionField = find.byType(TextField).first;
    await tester.enterText(descriptionField, '#yasakli_tag');
    await tester.pump();

    expect(
      find.text('#yasakli_tag etiketi topluluk kuralları gereği engellendi.'),
      findsOneWidget,
    );

    final finder = buttonWithLabel('İleri');
    expect(finder, findsOneWidget);
    final AppButton nextButton = tester.widget<AppButton>(finder);
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('engelli mention uyarisi gosterilir ve ileri butonu pasif olur', (
    tester,
  ) async {
    final policy = TaggingPolicy(
      bannedHashtags: const <String>{},
      blockedUsernames: const {'blockeduser'},
      blockedUserIds: const <String>{},
      refreshedAt: DateTime.now(),
    );

    TaggingPolicyService.configureForTesting(
      firestore: _MockFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
      cachedPolicy: policy,
      cachedAt: DateTime.now(),
    );

    await pumpDepositScreen(tester);

    final descriptionField = find.byType(TextField).first;
    await tester.enterText(descriptionField, '@BlockedUser');
    await tester.pump();

    expect(
      find.text('@blockeduser kullanıcısını etiketleyemezsin.'),
      findsOneWidget,
    );

    final finder = buttonWithLabel('İleri');
    expect(finder, findsOneWidget);
    final AppButton nextButton = tester.widget<AppButton>(finder);
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('uyumsuz etiketi temizleyince ileri butonu aktif olur', (
    tester,
  ) async {
    final policy = TaggingPolicy(
      bannedHashtags: const {'yasakli_tag'},
      blockedUsernames: const <String>{},
      blockedUserIds: const <String>{},
      refreshedAt: DateTime.now(),
    );

    TaggingPolicyService.configureForTesting(
      firestore: _MockFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
      cachedPolicy: policy,
      cachedAt: DateTime.now(),
    );

    await pumpDepositScreen(tester);

    final descriptionField = find.byType(TextField).first;
    await tester.enterText(descriptionField, '#yasakli_tag');
    await tester.pump();

    await tester.enterText(descriptionField, 'safe caption');
    await tester.pump();

    expect(
      find.text('#yasakli_tag etiketi topluluk kuralları gereği engellendi.'),
      findsNothing,
    );

    final finder = buttonWithLabel('İleri');
    expect(finder, findsOneWidget);
    final AppButton nextButton = tester.widget<AppButton>(finder);
    expect(nextButton.onPressed, isNotNull);
  });
}

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class _MockCompetitionService extends Mock implements CompetitionService {}
