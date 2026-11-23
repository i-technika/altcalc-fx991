import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/settings_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

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

/// 불러오기·저장이 실패하는 가짜 저장소
class _FailingStore extends InMemorySharedPreferencesStore {
  /// 불러오기를 실패시킬지
  final bool failLoad;

  /// 저장 결과: `false`면 실패 응답, 예외 객체면 그 예외를 던진다.
  final Object saveResult;

  _FailingStore({this.failLoad = false, this.saveResult = true})
    : super.empty();

  Future<Map<String, Object>> _load(
    Future<Map<String, Object>> Function() ok,
  ) async {
    if (failLoad) throw PlatformException(code: 'io');
    return ok();
  }

  @override
  Future<Map<String, Object>> getAll() => _load(super.getAll);

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => _load(() => super.getAllWithParameters(parameters));

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final result = saveResult;
    if (result is bool) return result;
    throw result;
  }
}

/// [store]를 저장소 플랫폼으로 쓰고, 테스트가 끝나면 빈 메모리 저장소로 되돌린다.
void _useStore(SharedPreferencesStorePlatform store) {
  SharedPreferences.resetStatic();
  SharedPreferencesStorePlatform.instance = store;
  addTearDown(() => SharedPreferences.setMockInitialValues({}));
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

    test('같은 키에 문자열이 아닌 값이 있으면 기본값으로 시작한다 (화면이 깨지지 않는다)', () async {
      for (final value in <Object>[
        true,
        1,
        2.5,
        <String>['left'],
      ]) {
        final (container, _) = await _containerWith({
          HandednessNotifier.storageKey: value,
        });
        expect(
          container.read(handednessProvider),
          Handedness.right,
          reason: '$value',
        );
      }
    });

    for (final (name, result) in <(String, Object)>[
      ('false 응답', false),
      ('예외 발생', PlatformException(code: 'io')),
    ]) {
      test('저장 실패($name)에도 오류 없이 이번 실행 동안은 바꾼 값을 쓴다', () async {
        _useStore(_FailingStore(saveResult: result));
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);
        container.read(handednessProvider.notifier).set(Handedness.left);
        await pumpEventQueue();
        expect(container.read(handednessProvider), Handedness.left);
      });
    }

    test('저장소를 열지 못하면 openSettingsStorage는 null이고 설정은 기본값으로 동작한다', () async {
      _useStore(_FailingStore(failLoad: true));
      final prefs = await openSettingsStorage();
      expect(prefs, isNull);
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(handednessProvider), Handedness.right);
      container.read(handednessProvider.notifier).set(Handedness.left);
      expect(container.read(handednessProvider), Handedness.left);
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
        expect(s.handednessNote.trim(), isNotEmpty);
        expect(s.close.trim(), isNotEmpty);
        expect(s.windowTooSmall.trim(), isNotEmpty);
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
