import 'package:damso_app/core/util/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UUID v4 형식(버전 4, 변이 8~b)', () {
    final v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    for (var i = 0; i < 100; i++) {
      expect(uuidV4(), matches(v4));
    }
  });

  test('1,000개를 만들어도 겹치지 않는다', () {
    expect({for (var i = 0; i < 1000; i++) uuidV4()}.length, 1000);
  });

  test('isUuid', () {
    expect(isUuid(uuidV4()), isTrue);
    expect(isUuid('9D8C7B6A-5F4E-4D3C-8B2A-1F0E9D8C7B6A'), isTrue);
    expect(isUuid('not-a-uuid'), isFalse);
    expect(isUuid(''), isFalse);
  });
}
