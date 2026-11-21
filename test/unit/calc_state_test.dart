import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';

/// 키를 순서대로 누른 결과 상태
CalcState _press(List<CalcKeyId> ids) =>
    ids.fold(CalcState.initial, (s, id) => s.pressKey(id));

const _modifierKeys = {CalcKeyId.shift, CalcKeyId.alpha};

void main() {
  group('초기 상태', () {
    test('모디파이어 없음, 입력 없음, LCD는 초기 표시 상태다', () {
      final s = CalcState.initial;
      expect(s.modifier, KeyModifier.none);
      expect(s.lastInput, isNull);
      expect(s.inputCount, 0);
      expect(s.repeatableKey, isNull);
      expect(s.lcdStatus, LcdStatus.initial);
    });
  });

  group('생성자 불변식', () {
    test('기능 없는 층·모디파이어 키·반복 불가 입력은 KeyInput으로 만들 수 없다', () {
      expect(
        () => KeyInput(CalcKeyId.num4, KeyLayer.shift),
        throwsAssertionError,
      );
      expect(
        () => KeyInput(CalcKeyId.shift, KeyLayer.main),
        throwsAssertionError,
      );
      expect(
        () => KeyInput(CalcKeyId.num5, KeyLayer.main, isRepeat: true),
        throwsAssertionError,
      );
      expect(
        () => KeyInput(CalcKeyId.del, KeyLayer.shift, isRepeat: true),
        throwsAssertionError,
      );
    });

    test('CalcState는 입력 수·마지막 입력·반복 대상의 정합을 강제한다', () {
      expect(() => CalcState(inputCount: 1), throwsAssertionError);
      expect(
        () => CalcState(lastInput: KeyInput(CalcKeyId.sin, KeyLayer.main)),
        throwsAssertionError,
      );
      expect(
        () => CalcState(repeatableKey: CalcKeyId.num5),
        throwsAssertionError,
      );
      expect(() => CalcState(inputCount: -1), throwsAssertionError);
    });
  });

  group('SHIFT/ALPHA 토글', () {
    test('SHIFT를 누르면 S가 켜지고, 다시 누르면 꺼진다', () {
      final on = _press([CalcKeyId.shift]);
      expect(on.modifier, KeyModifier.shift);
      expect(on.lcdStatus.shift, isTrue);
      expect(on.lcdStatus.alpha, isFalse);
      final off = on.pressKey(CalcKeyId.shift);
      expect(off.modifier, KeyModifier.none);
      expect(off.lcdStatus, LcdStatus.initial);
    });

    test('ALPHA를 누르면 A가 켜지고, 다시 누르면 꺼진다', () {
      final on = _press([CalcKeyId.alpha]);
      expect(on.modifier, KeyModifier.alpha);
      expect(on.lcdStatus.alpha, isTrue);
      expect(on.lcdStatus.shift, isFalse);
      expect(on.pressKey(CalcKeyId.alpha).modifier, KeyModifier.none);
    });

    test('SHIFT 대기 중 ALPHA를 누르면 ALPHA로 바뀐다 (반대도 같다)', () {
      expect(
        _press([CalcKeyId.shift, CalcKeyId.alpha]).modifier,
        KeyModifier.alpha,
      );
      expect(
        _press([CalcKeyId.alpha, CalcKeyId.shift]).modifier,
        KeyModifier.shift,
      );
    });

    test('모디파이어 토글은 입력을 만들지 않는다', () {
      final s = _press([CalcKeyId.shift, CalcKeyId.alpha, CalcKeyId.alpha]);
      expect(s.inputCount, 0);
      expect(s.lastInput, isNull);
    });
  });

  group('1회성 해석과 자동 해제', () {
    test('모디파이어 없이 누르면 메인 기능을 입력한다', () {
      final s = _press([CalcKeyId.sin]);
      expect(s.lastInput, KeyInput(CalcKeyId.sin, KeyLayer.main));
      expect(s.lastInput!.label, 'sin');
      expect(s.inputCount, 1);
    });

    test('SHIFT + CALC = SOLVE, 입력 후 S가 꺼진다', () {
      final s = _press([CalcKeyId.shift, CalcKeyId.calc]);
      expect(s.lastInput, KeyInput(CalcKeyId.calc, KeyLayer.shift));
      expect(s.lastInput!.label, 'SOLVE');
      expect(s.modifier, KeyModifier.none);
      expect(s.lcdStatus.shift, isFalse);
    });

    test('ALPHA + CALC = "=", 입력 후 A가 꺼진다', () {
      final s = _press([CalcKeyId.alpha, CalcKeyId.calc]);
      expect(s.lastInput!.label, '=');
      expect(s.modifier, KeyModifier.none);
    });

    test('모디파이어는 다음 키 하나에만 적용된다', () {
      final s = _press([CalcKeyId.shift, CalcKeyId.sin, CalcKeyId.sin]);
      expect(s.lastInput, KeyInput(CalcKeyId.sin, KeyLayer.main));
      expect(s.inputCount, 2);
    });

    test('기능 없는 층을 누르면 입력 없이 대기만 해제한다', () {
      final before = _press([CalcKeyId.num1, CalcKeyId.shift]);
      final after = before.pressKey(CalcKeyId.num4); // 4에는 SHIFT 기능이 없다
      expect(after.modifier, KeyModifier.none);
      expect(after.inputCount, before.inputCount);
      expect(after.lastInput, before.lastInput);
    });

    test('불변식: 모든 키 × 모든 모디파이어 — 대기는 해제되고 입력 층·각인이 명세와 일치한다', () {
      for (final modifier in KeyModifier.values) {
        final from = CalcState(modifier: modifier);
        for (final def in allKeys) {
          if (_modifierKeys.contains(def.id)) continue;
          final next = from.pressKey(def.id);
          final reason = '${modifier.name} + ${def.id.name}';
          expect(next.modifier, KeyModifier.none, reason: reason);

          final expectedLabel = switch (modifier) {
            KeyModifier.none => def.mainLabel,
            KeyModifier.shift => def.shiftLabel,
            KeyModifier.alpha => def.alphaLabel,
          };
          if (expectedLabel == null) {
            expect(next.inputCount, 0, reason: reason);
            expect(next.lastInput, isNull, reason: reason);
          } else {
            expect(next.inputCount, 1, reason: reason);
            expect(next.lastInput!.id, def.id, reason: reason);
            expect(next.lastInput!.label, expectedLabel, reason: reason);
            expect(next.lastInput!.isRepeat, isFalse, reason: reason);
          }
        }
      }
    });
  });

  group('반복 입력', () {
    test('모디파이어 없이 누른 반복 키는 메인 기능으로 반복된다', () {
      for (final id in autoRepeatKeys) {
        var s = _press([id]);
        expect(s.repeatableKey, id);
        s = s.repeatKey(id).repeatKey(id);
        expect(s.inputCount, 3, reason: id.name);
        expect(s.lastInput, KeyInput(id, KeyLayer.main, isRepeat: true));
      }
    });

    test('반복 입력은 모디파이어 대기를 소비하지 않는다', () {
      // DEL을 누른 채 다른 손가락으로 SHIFT를 누른다.
      var s = _press([CalcKeyId.del, CalcKeyId.shift]);
      s = s.repeatKey(CalcKeyId.del).repeatKey(CalcKeyId.del);
      expect(s.modifier, KeyModifier.shift);
      expect(s.lcdStatus.shift, isTrue);
      expect(s.inputCount, 3);
      // 대기 중인 SHIFT는 다음 키 누름에 그대로 적용된다.
      expect(s.pressKey(CalcKeyId.calc).lastInput!.label, 'SOLVE');
    });

    test('모디파이어 기능(SHIFT + DEL = INS, ALPHA + DEL = UNDO)은 반복하지 않는다', () {
      for (final mod in [CalcKeyId.shift, CalcKeyId.alpha]) {
        final s = _press([mod, CalcKeyId.del]);
        expect(s.repeatableKey, isNull);
        expect(identical(s.repeatKey(CalcKeyId.del), s), isTrue);
      }
    });

    test('기능 없는 층으로 누른 커서 키(SHIFT + ◀)는 반복하지 않는다', () {
      final s = _press([
        CalcKeyId.cursorLeft,
        CalcKeyId.shift,
        CalcKeyId.cursorLeft,
      ]);
      expect(s.inputCount, 1);
      expect(identical(s.repeatKey(CalcKeyId.cursorLeft), s), isTrue);
    });

    test('반복 키가 아닌 키는 반복하지 않는다', () {
      final s = _press([CalcKeyId.num5]);
      expect(identical(s.repeatKey(CalcKeyId.num5), s), isTrue);
    });

    test('다른 키를 누르면 이전 키의 반복은 끊긴다', () {
      final s = _press([CalcKeyId.del, CalcKeyId.cursorRight]);
      expect(identical(s.repeatKey(CalcKeyId.del), s), isTrue);
      expect(s.repeatKey(CalcKeyId.cursorRight).inputCount, 3);
    });

    test('모디파이어 토글은 진행 중인 반복을 끊지 않는다', () {
      final s = _press([CalcKeyId.del, CalcKeyId.alpha, CalcKeyId.alpha]);
      expect(s.repeatKey(CalcKeyId.del).inputCount, 2);
    });
  });

  group('값 동등성', () {
    test('같은 필드면 같고, 필드가 다르면 다르다', () {
      expect(
        _press([CalcKeyId.shift, CalcKeyId.calc]),
        _press([CalcKeyId.shift, CalcKeyId.calc]),
      );
      expect(
        _press([CalcKeyId.shift, CalcKeyId.calc]).hashCode,
        _press([CalcKeyId.shift, CalcKeyId.calc]).hashCode,
      );
      expect(_press([CalcKeyId.sin]), isNot(_press([CalcKeyId.cos])));
      expect(
        KeyInput(CalcKeyId.del, KeyLayer.main),
        isNot(KeyInput(CalcKeyId.del, KeyLayer.main, isRepeat: true)),
      );
    });
  });

  group('CalcNotifier', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('pressKey/repeatKey는 상태 전이 함수와 같은 결과를 낸다', () {
      final notifier = container.read(calcProvider.notifier);
      notifier
        ..pressKey(CalcKeyId.del)
        ..pressKey(CalcKeyId.shift)
        ..repeatKey(CalcKeyId.del);
      expect(
        container.read(calcProvider),
        _press([CalcKeyId.del, CalcKeyId.shift]).repeatKey(CalcKeyId.del),
      );
    });

    test('lcdStatusProvider는 S/A를 반영하고, 표시가 같으면 알리지 않는다', () {
      final seen = <LcdStatus>[];
      container.listen(lcdStatusProvider, (_, next) => seen.add(next));
      final notifier = container.read(calcProvider.notifier);

      // 파생 provider는 읽을 때 다시 계산되므로 누를 때마다 읽어 알림을 확정한다.
      void press(CalcKeyId id) {
        notifier.pressKey(id);
        container.read(lcdStatusProvider);
      }

      press(CalcKeyId.shift);
      expect(container.read(lcdStatusProvider).shift, isTrue);
      press(CalcKeyId.num1); // S 해제
      press(CalcKeyId.num2); // 표시 변화 없음
      press(CalcKeyId.num3); // 표시 변화 없음
      expect(seen, [
        LcdStatus.initial.copyWith(shift: true),
        LcdStatus.initial,
      ]);
    });

    test('무시된 반복은 상태 알림을 보내지 않는다', () {
      var notified = 0;
      container.listen(calcProvider, (_, _) => notified++);
      container.read(calcProvider.notifier).repeatKey(CalcKeyId.del);
      expect(notified, 0);
    });
  });
}
