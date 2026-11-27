import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/screen_reader_announcer.dart';

/// 음성 라벨에 허용하는 글자: 한글 음절, 영문, 숫자, 공백, 아포스트로피(Euler's).
/// 쉼표는 키 힌트에서 시프트·알파 기능을 나누는 구분자로만 쓰므로 기능 이름에는 넣지 않는다.
/// 표시용 기호(`◼`·`◻`·`◄`·`▲`·`⁻¹`·`²`·`√`·`∫`·`=` 등)는 기호 이름으로 읽히므로 넣지 않는다.
final _speakable = RegExp(r"^[가-힣A-Za-z0-9 ']+$");

/// 실제 영단어라 영어 음성 라벨이 각인과 같은 철자여도 되는 각인
const _realWordLegends = {
  'SHIFT',
  'ALPHA',
  'MENU',
  'SOLVE',
  'RECALL',
  'RESET',
  'UNDO',
};

/// [slot] 표시기를 켠 상태 목록 (값이 여러 개인 슬롯은 값마다)
List<LcdStatus> _statusesWith(LcdIndicatorSlot slot) => switch (slot) {
  LcdIndicatorSlot.shift => [const LcdStatus(shift: true)],
  LcdIndicatorSlot.alpha => [const LcdStatus(alpha: true)],
  LcdIndicatorSlot.memory => [const LcdStatus(memory: true)],
  LcdIndicatorSlot.store => [const LcdStatus(store: true)],
  LcdIndicatorSlot.angleDegree => [const LcdStatus()],
  LcdIndicatorSlot.angleRadian => [
    const LcdStatus(angleUnit: AngleUnit.radian),
  ],
  LcdIndicatorSlot.angleGradian => [
    const LcdStatus(angleUnit: AngleUnit.gradian),
  ],
  LcdIndicatorSlot.fixFormat => [
    const LcdStatus(numberFormat: NumberDisplayFormat.fix),
  ],
  LcdIndicatorSlot.sciFormat => [
    const LcdStatus(numberFormat: NumberDisplayFormat.sci),
  ],
  LcdIndicatorSlot.engineering => [const LcdStatus(engineering: true)],
  LcdIndicatorSlot.math => [const LcdStatus()],
  LcdIndicatorSlot.complexRectangular => [
    const LcdStatus(complex: ComplexResultIndicator.rectangular),
  ],
  LcdIndicatorSlot.complexPolar => [
    const LcdStatus(complex: ComplexResultIndicator.polar),
  ],
  LcdIndicatorSlot.historyDown => [const LcdStatus(historyDown: true)],
  LcdIndicatorSlot.historyUp => [const LcdStatus(historyUp: true)],
  LcdIndicatorSlot.disp => [const LcdStatus(disp: true)],
  LcdIndicatorSlot.keepScreenOn => [const LcdStatus(keepScreenOn: true)],
};

void main() {
  // 모든 언어 구현에 같은 불변식을 적용한다.
  for (final strings in CalcSemanticStrings.all) {
    group('${strings.runtimeType} 키 음성 라벨 불변식', () {
      test('50키 모두 음성 라벨이 있다', () {
        expect(strings.keys.keys.toSet(), CalcKeyId.values.toSet());
      });

      test(
        'SHIFT/ALPHA 음성 라벨은 그 층에 각인이 있는 키에만 있다 (MENU·AC에는 SHIFT 기능이 없다, #253)',
        () {
          for (final def in allKeys) {
            final speech = strings.keys[def.id]!;
            expect(
              speech.shift != null,
              def.hasShift,
              reason: '${def.id.name} SHIFT',
            );
            expect(
              speech.alpha != null,
              def.hasAlpha,
              reason: '${def.id.name} ALPHA',
            );
          }
        },
      );

      test('음성 라벨에는 표시용 기호가 없다', () {
        for (final speech in strings.keys.values) {
          for (final text in [speech.main, speech.shift, speech.alpha]) {
            if (text == null) continue;
            expect(text, matches(_speakable), reason: text);
            expect(text.trim(), text, reason: '앞뒤 공백: "$text"');
          }
        }
      });

      test('숫자 키를 빼면 음성 라벨은 표시 각인을 그대로 옮긴 것이 아니다', () {
        // `SOLVE`, `FACT`처럼 각인을 그대로 쓰면 기호 검사는 통과해도 철자로 읽힌다.
        for (final def in allKeys) {
          for (final layer in KeyLayer.values) {
            final display = KeyInput.labelOf(def.id, layer);
            if (display == null || RegExp(r'^[0-9]$').hasMatch(display)) {
              continue;
            }
            // 대소문자만 다른 경우(OPTN/Optn)도 철자로 읽히므로 막는다. 각인 자체가 실제 영단어라
            // 그대로 읽어도 되는 것만 허용한다.
            if (_realWordLegends.contains(display)) continue;
            final speech = strings.keyFunction(def.id, layer)!;
            expect(
              speech.toLowerCase(),
              isNot(display.toLowerCase()),
              reason: '${def.id.name} ${layer.name}',
            );
          }
        }
      });

      test('같은 층 안에서 음성 라벨은 서로 다르다 (대소문자만 다른 E·e도 말로 구분)', () {
        for (final layer in KeyLayer.values) {
          final labels = [
            for (final id in CalcKeyId.values) ?strings.keyFunction(id, layer),
          ];
          expect(labels.toSet().length, labels.length, reason: layer.name);
        }
      });

      test('같은 기능으로 가는 두 경로는 같은 말로 읽는다 (변수 x)', () {
        // 가이드 인쇄 13쪽 각주 *1: x는 `x` 키 메인과 ALPHA + `)` 두 경로로 입력된다.
        expect(
          strings.keyFunction(CalcKeyId.parenClose, KeyLayer.alpha),
          strings.keyFunction(CalcKeyId.variableX, KeyLayer.main),
        );
      });

      test('키 버튼 힌트는 SHIFT·ALPHA 기능이 있는 키에만 있다', () {
        for (final def in allKeys) {
          expect(
            strings.keyButtonHint(def.id) != null,
            def.hasShift || def.hasAlpha,
            reason: def.id.name,
          );
        }
        // 실물 SHIFT 각인을 뺀 MENU(SETUP)·AC(OFF)는 힌트가 없다 (#253)
        expect(strings.keyButtonHint(CalcKeyId.menu), isNull);
        expect(strings.keyButtonHint(CalcKeyId.ac), isNull);
      });

      test('켜진 표시기는 모두 기호 없는 의미 라벨을 갖고, 꺼진 표시기는 읽지 않는다', () {
        final labels = <String>[];
        for (final slot in LcdIndicatorSlot.values) {
          for (final status in _statusesWith(slot)) {
            expect(status.indicatorFor(slot), isNotNull, reason: slot.name);
            final label = strings.indicator(slot, status);
            expect(label, isNotNull, reason: slot.name);
            expect(label, matches(_speakable), reason: label);
            labels.add(label!);
          }
        }
        // 슬롯마다 다르게 읽는다 — 자리가 나뉜 D/R/G, i/∠도 값마다 다른 말이다(#58).
        expect(labels.toSet(), hasLength(labels.length));
        const allOff = LcdStatus(mathIO: false);
        for (final slot in [
          LcdIndicatorSlot.shift,
          LcdIndicatorSlot.fixFormat,
          LcdIndicatorSlot.sciFormat,
          LcdIndicatorSlot.complexRectangular,
          LcdIndicatorSlot.complexPolar,
          LcdIndicatorSlot.angleRadian,
          LcdIndicatorSlot.angleGradian,
          LcdIndicatorSlot.math,
        ]) {
          expect(strings.indicator(slot, allOff), isNull, reason: slot.name);
        }
      });

      test('줄 이름·스크롤·모디파이어 알림 문구에도 기호가 없다', () {
        for (final text in [
          strings.inputLine,
          strings.resultLine,
          strings.scrollMore(left: true),
          strings.scrollMore(left: false),
          for (final m in [KeyModifier.shift, KeyModifier.alpha]) ...[
            strings.modifierChanged(m, on: true),
            strings.modifierChanged(m, on: false),
          ],
        ]) {
          expect(text, matches(_speakable), reason: text);
        }
        expect(
          () => strings.modifierChanged(KeyModifier.none, on: true),
          throwsArgumentError,
        );
      });
    });
  }

  group('한국어 문구', () {
    const ko = KoSemanticStrings();

    test('키 버튼: 라벨은 메인 기능, 힌트는 시프트·알파 기능', () {
      expect(ko.keyButton(CalcKeyId.sin), '사인');
      expect(ko.keyButtonHint(CalcKeyId.sin), '시프트 아크사인, 알파 변수 D');
      expect(ko.keyButtonHint(CalcKeyId.num4), isNull);
      expect(ko.keyButton(CalcKeyId.cursorLeft), '왼쪽 커서');
    });

    test('한국어 TTS가 숫자 2("이")로 읽을 "e의"·"E의" 표현을 쓰지 않는다', () {
      final risky = RegExp(r'(^|\s)[eE]의');
      for (final speech in ko.keys.values) {
        for (final text in [speech.main, speech.shift, speech.alpha]) {
          if (text == null) continue;
          expect(text, isNot(matches(risky)), reason: text);
        }
      }
    });

    test('상태 표시줄은 켜진 표시기의 의미를 슬롯 순서로 읽는다', () {
      expect(ko.statusBar(LcdStatus.initial), '수학 입출력, 각도 단위 도');
      expect(
        ko.statusBar(const LcdStatus(shift: true, memory: true)),
        '시프트, 메모리, 수학 입출력, 각도 단위 도',
      );
    });

    test('스크롤 표시기·중간 결과·화면 켜짐 유지는 화면 순서(▼, ▲, ‖, 👁)대로 읽는다', () {
      expect(
        ko.statusBar(
          const LcdStatus(
            historyUp: true,
            historyDown: true,
            disp: true,
            keepScreenOn: true,
          ),
        ),
        '수학 입출력, 각도 단위 도, 아래쪽에 내용 더 있음, 위쪽에 내용 더 있음, 중간 결과 표시 중, 화면 켜짐 유지',
      );
    });

    test('FIX와 SCI는 각자의 의미로 읽고, 꺼진 쪽은 읽지 않는다 (#44 — 슬롯 분리)', () {
      const fix = LcdStatus(numberFormat: NumberDisplayFormat.fix);
      const sci = LcdStatus(numberFormat: NumberDisplayFormat.sci);
      expect(ko.statusBar(fix), '수학 입출력, 각도 단위 도, 소수 자릿수 고정');
      expect(ko.statusBar(sci), '수학 입출력, 각도 단위 도, 유효숫자 고정');
      const en = EnSemanticStrings();
      expect(en.statusBar(fix), 'Math input output, Degrees, Fixed decimals');
      expect(
        en.statusBar(sci),
        'Math input output, Degrees, Significant digits',
      );
      for (final strings in CalcSemanticStrings.all) {
        expect(strings.indicator(LcdIndicatorSlot.sciFormat, fix), isNull);
        expect(strings.indicator(LcdIndicatorSlot.fixFormat, sci), isNull);
      }
    });
  });

  group('언어 선택', () {
    test('한국어 로캘은 한국어, 그 밖에는 영어', () {
      expect(
        CalcSemanticStrings.forLocale(const Locale('ko', 'KR')),
        isA<KoSemanticStrings>(),
      );
      expect(
        CalcSemanticStrings.forLocale(const Locale('en', 'US')),
        isA<EnSemanticStrings>(),
      );
      expect(
        CalcSemanticStrings.forLocale(const Locale('ja')),
        isA<EnSemanticStrings>(),
      );
    });
  });

  group('스크린리더 알림 규칙 (announcementFor)', () {
    const ko = KoSemanticStrings();
    KeyInput input(CalcKeyId id, KeyLayer layer, {bool repeat = false}) =>
        KeyInput(id, layer, isRepeat: repeat);
    String? say(
      (KeyModifier, int, KeyInput?) previous,
      (KeyModifier, int, KeyInput?) next,
    ) => announcementFor(ko, previous, next);

    test('대기가 켜지면 켜짐, 입력 없이 풀리면 꺼짐', () {
      expect(
        say((KeyModifier.none, 0, null), (KeyModifier.shift, 0, null)),
        '시프트 켜짐',
      );
      expect(
        say((KeyModifier.shift, 0, null), (KeyModifier.none, 0, null)),
        '시프트 꺼짐',
      );
      expect(
        say((KeyModifier.shift, 0, null), (KeyModifier.alpha, 0, null)),
        '알파 켜짐',
      );
      expect(
        say((KeyModifier.alpha, 3, null), (KeyModifier.none, 3, null)),
        '알파 꺼짐',
      );
    });

    test('기능이 입력되면 그 기능 이름을 알린다 (대기가 풀린 것도 이것으로 전달)', () {
      final asin = input(CalcKeyId.sin, KeyLayer.shift);
      expect(
        say((KeyModifier.shift, 0, null), (KeyModifier.none, 1, asin)),
        '아크사인',
      );
      final seven = input(CalcKeyId.num7, KeyLayer.main);
      expect(
        say((KeyModifier.none, 1, asin), (KeyModifier.none, 2, seven)),
        '7',
      );
    });

    test('길게 눌러 반복되는 입력과 변화 없는 상태는 알리지 않는다', () {
      final del = input(CalcKeyId.del, KeyLayer.main);
      final delRepeat = input(CalcKeyId.del, KeyLayer.main, repeat: true);
      expect(
        say((KeyModifier.none, 1, del), (KeyModifier.none, 2, delRepeat)),
        isNull,
      );
      expect(
        say((KeyModifier.shift, 2, del), (KeyModifier.shift, 2, del)),
        isNull,
      );
    });
  });
}
