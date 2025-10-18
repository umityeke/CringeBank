import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cringebank/features/profile/presentation/widgets/media_tagging_canvas.dart';
import 'package:cringebank/models/user_model.dart';
import 'package:cringebank/services/style_search_service.dart'
  show MentionSuggestionFetcher;

void main() {
  testWidgets('MediaTaggingCanvas adds tag after selecting suggestion', (tester) async {
    final fetcher = _StubMentionFetcher();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TagHarness(
            fetcher: fetcher.call,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('mediaTaggingCanvas')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('mediaTagSearchField')), 'al');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.contains('Alice Doe') == true,
      ),
      findsWidgets,
    );
    await tester.tap(find.byKey(const Key('mediaTagSuggestion_alice')));
    await tester.pumpAndSettle();

    final harnessState = tester.state<_TagHarnessState>(find.byType(_TagHarness));
    expect(harnessState.tags, hasLength(1));
  expect(find.text('Alice Doe'), findsOneWidget);
  });
}

class _StubMentionFetcher {
  Future<List<User>> call(String query, {int limit = 6}) async {
    if (query.toLowerCase().startsWith('al')) {
      return [
        User(
          id: 'alice',
          username: 'alice',
          email: 'alice@example.com',
          fullName: 'Alice Doe',
          joinDate: DateTime(2024, 1, 1),
          lastActive: DateTime(2025, 1, 1),
        ),
      ];
    }
    return [];
  }
}

class _TagHarness extends StatefulWidget {
  const _TagHarness({required this.fetcher});

  final MentionSuggestionFetcher fetcher;

  @override
  State<_TagHarness> createState() => _TagHarnessState();
}

class _TagHarnessState extends State<_TagHarness> {
  List<MediaTag> _tags = const [];

  List<MediaTag> get tags => _tags;

  void _handleChanged(List<MediaTag> next) {
    setState(() {
      _tags = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 240,
        height: 320,
        child: MediaTaggingCanvas(
          tags: _tags,
          onChanged: _handleChanged,
          mentionSuggestionFetcher: widget.fetcher,
          background: Container(color: Colors.blueGrey.shade800),
        ),
      ),
    );
  }
}
