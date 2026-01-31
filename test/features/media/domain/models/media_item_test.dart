import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';

void main() {
  group('MediaItem', () {
    test('supports value equality', () {
      final date = DateTime.now();
      final item1 = MediaItem(id: '1', base64: 'abc', chatId: 'c1', timestamp: date);
      final item2 = MediaItem(id: '1', base64: 'abc', chatId: 'c1', timestamp: date);
      final item3 = MediaItem(id: '2', base64: 'def', chatId: 'c2', timestamp: date);

      expect(item1, equals(item2));
      expect(item1, isNot(equals(item3)));
    });

    test('hashCode is consistent with equality', () {
       final date = DateTime.now();
       final item1 = MediaItem(id: '1', base64: 'abc', chatId: 'c1', timestamp: date);
       final item2 = MediaItem(id: '1', base64: 'abc', chatId: 'c1', timestamp: date);

       expect(item1.hashCode, equals(item2.hashCode));
    });
  });
}
