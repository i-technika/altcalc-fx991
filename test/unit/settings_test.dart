import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/settings_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [values]로 저장소를 채우고 그 저장소를 쓰는 컨테이너를 만든다.
Future<(ProviderContainer, SharedPreferences)> _containerWith(
  Map<String, Object> values,
) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return (container, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Handedness', () {
    test('기본값은 오른손잡이(키패드 오른쪽)다', () {
      expect(Handedness.fallback, Handedness.right);
      expect(Handedness.right.keypadOnRight, isTrue);
      expect(Handedness.left.keypadOnRight, isFalse);
    });

    test('저장 값은 비어 있지 않고 서로 다르며, 읽으면 같은 값으로 돌아온다', () {
      final stored = Handedness.values.map((h) => h.storageValue).toList();
      expect(stored.every((v) => v.isNotEmpty), isTrue);
      expect(stored.toSet().length, Handedness.values.length);
      for (final h in Handedness.values) {
        expect(Handedness.fromStorage(h.storageValue), h);
      }
    });

    test('저장 값은 이미 배포된 값과 같다 (바꾸면 사용자 설정이 초기화된다)', () {
      expect(Handedness.right.storageValue, 'right');
      expect(Handedness.left.storageValue, 'left');
    });

    test('없거나 알 수 없는 저장 값은 기본값으로 읽는다', () {
      for (final v in [null, '', 'LEFT', 'ambidextrous']) {
        expect(Handedness.fromStorage(v), Handedness.fallback, reason: '$v');
      }
    });
  });

  group('handednessProvider', () {
    test('저장소가 없으면 기본값으로 시작하고, 바꾼 값은 실행 중에만 유지된다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(handednessProvider), Handedness.right);
      container.read(handednessProvider.notifier).set(Handedness.left);
      expect(container.read(handednessProvider), Handedness.left);
    });

    test('저장된 값으로 시작한다', () async {
      final (container, _) = await _containerWith({
        HandednessNotifier.storageKey: 'left',
      });
      expect(container.read(handednessProvider), Handedness.left);
    });

    test('알 수 없는 저장 값이면 기본값으로 시작한다', () async {
      final (container, _) = await _containerWith({
        HandednessNotifier.storageKey: 'unknown',
      });
      expect(container.read(handednessProvider), Handedness.right);
    });

    test('바꾸면 저장소에 저장되고, 새로 연 저장소에서도 읽힌다', () async {
      final (container, prefs) = await _containerWith({});
      container.read(handednessProvider.notifier).set(Handedness.left);
      expect(container.read(handednessProvider), Handedness.left);
      expect(prefs.getString(HandednessNotifier.storageKey), 'left');

      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(handednessProvider), Handedness.left);
    });

    test('같은 값으로 바꾸면 알림이 가지 않는다', () async {
      final (container, _) = await _containerWith({});
      var notified = 0;
      container.listen(handednessProvider, (_, _) => notified++);
      container.read(handednessProvider.notifier).set(Handedness.right);
      expect(notified, 0);
      container.read(handednessProvider.notifier).set(Handedness.left);
      expect(notified, 1);
    });

    test('openSettingsStorage는 저장소를 연다', () async {
      SharedPreferences.setMockInitialValues({
        HandednessNotifier.storageKey: 'left',
      });
      final prefs = await openSettingsStorage();
      expect(prefs?.getString(HandednessNotifier.storageKey), 'left');
    });
  });

  group('SettingsStrings', () {
    test('한국어 기기는 한국어, 그 밖에는 영어', () {
      expect(
        SettingsStrings.forLocale(const Locale('ko', 'KR')),
        isA<KoSettingsStrings>(),
      );
      expect(
        SettingsStrings.forLocale(const Locale('en', 'US')),
        isA<EnSettingsStrings>(),
      );
      expect(
        SettingsStrings.forLocale(const Locale('de')),
        isA<EnSettingsStrings>(),
      );
    });

    test('모든 언어: 문구가 비어 있지 않고, 손잡이 선택지끼리 구분된다', () {
      for (final s in SettingsStrings.all) {
        expect(s.settingsButton.trim(), isNotEmpty);
        expect(s.handednessTitle.trim(), isNotEmpty);
        final names = Handedness.values.map(s.handedness).toList();
        final details = Handedness.values.map(s.handednessDetail).toList();
        expect(names.every((v) => v.trim().isNotEmpty), isTrue);
        expect(details.every((v) => v.trim().isNotEmpty), isTrue);
        expect(names.toSet().length, Handedness.values.length);
        expect(details.toSet().length, Handedness.values.length);
      }
    });
  });
}
