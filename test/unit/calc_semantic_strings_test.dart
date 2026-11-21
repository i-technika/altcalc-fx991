import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';

/// 음성 라벨에 허용하는 글자: 한글 음절, 영문, 숫자, 공백.
/// 표시용 기호(`◼`·`◻`·`◄`·`▲`·`⁻¹`·`²`·`√`·`∫`·`=` 등)는 기호 이름으로 읽히므로 넣지 않는다.
final _speakable = RegExp(r'^[가-힣A-Za-z0-9 ]+$');

void main() {
  const strings = KoSemanticStrings();

  group('키 음성 라벨 불변식 (한국어)', () {
    test('50키 모두 음성 라벨이 있다', () {
      expect(strings.keys.keys.toSet(), CalcKeyId.values.toSet());
    });

    test('SHIFT/ALPHA 음성 라벨은 그 층에 각인이 있는 키에만 있다', () {
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
    });

    test('음성 라벨에는 표시용 기호가 없다 (한글·영문·숫자·공백만)', () {
      for (final speech in strings.keys.values) {
        for (final text in [speech.main, speech.shift, speech.alpha]) {
          if (text == null) continue;
          expect(text, matches(_speakable), reason: text);
          expect(text.trim(), text, reason: '앞뒤 공백: "$text"');
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
      expect(
        strings.keyFunction(CalcKeyId.cos, KeyLayer.alpha),
        isNot(strings.keyFunction(CalcKeyId.exp10, KeyLayer.alpha)),
      );
    });

    test('같은 기능으로 가는 두 경로는 같은 말로 읽는다 (변수 x)', () {
      // 가이드 인쇄 13쪽 각주 *1: x는 `x` 키 메인과 ALPHA + `)` 두 경로로 입력된다.
      expect(
        strings.keyFunction(CalcKeyId.parenClose, KeyLayer.alpha),
        strings.keyFunction(CalcKeyId.variableX, KeyLayer.main),
      );
    });

    test('키 버튼 라벨은 메인·SHIFT·ALPHA 기능을 층 이름과 함께 읽는다', () {
      expect(strings.keyButton(CalcKeyId.sin), '사인, 시프트 역사인, 알파 변수 D');
      expect(strings.keyButton(CalcKeyId.num4), '4');
      expect(strings.keyButton(CalcKeyId.cursorLeft), '왼쪽 커서');
    });
  });

  group('LCD 음성 문구', () {
    /// [slot] 표시기를 켠 상태 목록 (값이 여러 개인 슬롯은 값마다)
    List<LcdStatus> statusesWith(LcdIndicatorSlot slot) => switch (slot) {
      LcdIndicatorSlot.shift => [const LcdStatus(shift: true)],
      LcdIndicatorSlot.alpha => [const LcdStatus(alpha: true)],
      LcdIndicatorSlot.memory => [const LcdStatus(memory: true)],
      LcdIndicatorSlot.store => [const LcdStatus(store: true)],
      LcdIndicatorSlot.angleUnit => [
        for (final unit in AngleUnit.values) LcdStatus(angleUnit: unit),
      ],
      LcdIndicatorSlot.numberFormat => [
        const LcdStatus(numberFormat: NumberDisplayFormat.fix),
        const LcdStatus(numberFormat: NumberDisplayFormat.sci),
      ],
      LcdIndicatorSlot.engineering => [const LcdStatus(engineering: true)],
      LcdIndicatorSlot.math => [const LcdStatus()],
      LcdIndicatorSlot.complex => [
        const LcdStatus(complex: ComplexResultIndicator.rectangular),
        const LcdStatus(complex: ComplexResultIndicator.polar),
      ],
      LcdIndicatorSlot.disp => [const LcdStatus(disp: true)],
      LcdIndicatorSlot.historyUp => [const LcdStatus(historyUp: true)],
      LcdIndicatorSlot.historyDown => [const LcdStatus(historyDown: true)],
    };

    test('켜진 표시기는 모두 기호 없는 의미 라벨을 갖고, 꺼진 표시기는 읽지 않는다', () {
      for (final slot in LcdIndicatorSlot.values) {
        final labels = <String>{};
        for (final status in statusesWith(slot)) {
          expect(status.indicatorFor(slot), isNotNull, reason: slot.name);
          final label = strings.indicator(slot, status);
          expect(label, isNotNull, reason: slot.name);
          expect(label, matches(_speakable), reason: label);
          labels.add(label!);
        }
        // 값이 여러 개인 슬롯(D/R/G, FIX/SCI, i/∠)은 값마다 다르게 읽는다.
        expect(labels, hasLength(statusesWith(slot).length), reason: slot.name);
      }
      const allOff = LcdStatus(mathIO: false);
      expect(strings.indicator(LcdIndicatorSlot.shift, allOff), isNull);
      expect(strings.indicator(LcdIndicatorSlot.numberFormat, allOff), isNull);
      expect(strings.indicator(LcdIndicatorSlot.complex, allOff), isNull);
      expect(strings.indicator(LcdIndicatorSlot.math, allOff), isNull);
    });

    test('상태 표시줄은 켜진 표시기의 의미를 슬롯 순서로 읽는다', () {
      expect(strings.statusBar(LcdStatus.initial), '각도 도, 수학 입출력');
      expect(
        strings.statusBar(const LcdStatus(shift: true, memory: true)),
        '시프트, 메모리, 각도 도, 수학 입출력',
      );
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
    });
  });

  test('지원하지 않는 언어는 한국어로 대체한다', () {
    expect(CalcSemanticStrings.forLanguage('en'), isA<KoSemanticStrings>());
    expect(CalcSemanticStrings.forLanguage(null), isA<KoSemanticStrings>());
  });
}
