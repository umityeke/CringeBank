import 'package:flutter_test/flutter_test.dart';

import 'package:cringebank/features/feed/presentation/controllers/feed_lazy_loader.dart';

void main() {
  group('FeedLazyLoader', () {
    test('başlangıçta chunk boyutunu uygular', () {
      final loader = FeedLazyLoader(chunkSize: 5);
      expect(loader.state.visibleCount, 0);

      loader.syncWithTotal(12);

      expect(loader.state.visibleCount, 5);
    });

    test('extend chunk boyutunda artar ve üst sınırı aşmaz', () {
      final loader = FeedLazyLoader(chunkSize: 4);
      loader.syncWithTotal(10);
      expect(loader.state.visibleCount, 4);

      loader.extend(10);
      expect(loader.state.visibleCount, 8);

      loader.extend(10);
      expect(loader.state.visibleCount, 10);

      loader.extend(10);
      expect(loader.state.visibleCount, 10);
    });

    test('toplam azaldığında görünür sayıyı kısar', () {
      final loader = FeedLazyLoader(chunkSize: 6);
      loader.syncWithTotal(12);
      loader.extend(12);
      expect(loader.state.visibleCount, 12);

      loader.syncWithTotal(5);
      expect(loader.state.visibleCount, 5);
    });

    test('reset görünür sayıyı sıfırlar', () {
      final loader = FeedLazyLoader(chunkSize: 3);
      loader.syncWithTotal(5);
      expect(loader.state.visibleCount, 3);

      loader.reset();
      expect(loader.state.visibleCount, 0);
    });
  });
}
