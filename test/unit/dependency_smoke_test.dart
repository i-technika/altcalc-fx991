import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('의존성 스모크 테스트 (Dependency Smoke Test)', () {
    test('Decimal 고정밀도 연산 검증 (0.1 + 0.2 == 0.3)', () {
      final a = Decimal.parse('0.1');
      final b = Decimal.parse('0.2');
      final sum = a + b;
      expect(sum, equals(Decimal.parse('0.3')));
      expect(sum.toString(), equals('0.3'));
    });

    test('Riverpod ProviderScope 및 StateProvider 기본 동작 검증', () {
      final testProvider = StateProvider<int>((ref) => 42);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(testProvider), equals(42));
      container.read(testProvider.notifier).state = 991;
      expect(container.read(testProvider), equals(991));
    });

    test('SharedPreferences 기본 모의 인스턴스 획득 검증', () async {
      SharedPreferences.setMockInitialValues({'test_key': 'fx991'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('test_key'), equals('fx991'));
    });
  });
}
