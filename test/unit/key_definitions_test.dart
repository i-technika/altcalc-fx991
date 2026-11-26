import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';

void main() {
  group('키패드 명세 불변식', () {
    test('전체 키는 정확히 50개이며 CalcKeyId와 1:1 대응한다', () {
      expect(allKeys.length, totalKeyCount);
      expect(CalcKeyId.values.length, totalKeyCount);
      expect(keyById.length, totalKeyCount, reason: 'ID 중복이 있으면 맵 크기가 줄어든다');
      for (final id in CalcKeyId.values) {
        expect(keyDefOf(id).id, id);
      }
    });

    test('allKeys 순서는 CalcKeyId 선언 순서(실물 배열 순서)와 같다', () {
      expect(allKeys.map((k) => k.id).toList(), CalcKeyId.values);
    });

    test('구역별 키 개수: 조작부 2×2+2×2, 커서 4, 함수부 3×6, 숫자부 4×5', () {
      expect(controlLeftRows.length, 2);
      expect(controlRightRows.length, 2);
      for (final row in [...controlLeftRows, ...controlRightRows]) {
        expect(row.length, 2);
      }
      expect(cursorPad.all.length, 4);
      expect(functionRows.length, 3);
      for (final row in functionRows) {
        expect(row.length, functionColumns);
      }
      expect(numberRows.length, 4);
      for (final row in numberRows) {
        expect(row.length, numberColumns);
      }
    });

    test('커서 패드 각 방향은 올바른 ID에 대응한다', () {
      expect(cursorPad.up.id, CalcKeyId.cursorUp);
      expect(cursorPad.down.id, CalcKeyId.cursorDown);
      expect(cursorPad.left.id, CalcKeyId.cursorLeft);
      expect(cursorPad.right.id, CalcKeyId.cursorRight);
      expect(
        cursorPad.all.every((k) => k.category == KeyCategory.cursor),
        isTrue,
      );
    });

    test('메인 라벨은 키 간에 중복되지 않는다', () {
      final labels = allKeys.map((k) => k.mainLabel).toList();
      expect(labels.toSet().length, labels.length);
    });

    test('ALPHA 각인은 키 간에 중복되지 않는다', () {
      final labels = allKeys
          .map((k) => k.alphaLabel)
          .whereType<String>()
          .toList();
      expect(labels.toSet().length, labels.length);
    });

    test('메인 라벨은 비어 있지 않고, SHIFT/ALPHA 라벨은 null이거나 비어 있지 않다', () {
      for (final key in allKeys) {
        expect(key.mainLabel.trim(), isNotEmpty, reason: '$key');
        if (key.shiftLabel != null) {
          expect(key.shiftLabel!.trim(), isNotEmpty, reason: '$key');
        }
        if (key.alphaLabel != null) {
          expect(key.alphaLabel!.trim(), isNotEmpty, reason: '$key');
        }
      }
    });

    test('등호(=) 메인 키는 하나뿐이다', () {
      expect(allKeys.where((k) => k.mainLabel == '=').length, 1);
      expect(allKeys.where((k) => k.category == KeyCategory.equals).length, 1);
    });

    test('SHIFT 각인은 키 간에 중복되지 않는다', () {
      final labels = allKeys
          .map((k) => k.shiftLabel)
          .whereType<String>()
          .toList();
      expect(labels.toSet().length, labels.length);
    });

    test('ALPHA 층에서 변수 A~F, x, y, M은 각각 정확히 하나의 키에 있다', () {
      // 가이드 인쇄 13쪽 "Variables (A, B, C, D, E, F, M, x, y)" — x, y는 소문자다.
      // ALPHA 층만 센다. 변수 x는 x 키 메인으로도 입력된다 (아래 '층 간 라벨 겹침' 테스트).
      const variables = ['A', 'B', 'C', 'D', 'E', 'F', 'x', 'y', 'M'];
      for (final v in variables) {
        expect(allKeys.where((k) => k.alphaLabel == v).length, 1, reason: v);
      }
      // 변수 A~F는 함수부 2행에 순서대로 배치된다.
      expect(functionRows[1].map((k) => k.alphaLabel).toList(), [
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
      ]);
    });

    test('모디파이어 키에는 SHIFT/ALPHA 기능이 없다', () {
      for (final id in [CalcKeyId.shift, CalcKeyId.alpha]) {
        expect(keyDefOf(id).hasShift, isFalse);
        expect(keyDefOf(id).hasAlpha, isFalse);
      }
    });

    test('숫자 0~9 키가 모두 number 카테고리로 존재한다', () {
      final digits = allKeys
          .where((k) => RegExp(r'^[0-9]$').hasMatch(k.mainLabel))
          .toList();
      expect(digits.map((k) => k.mainLabel).toSet(), {
        for (var i = 0; i < 10; i++) '$i',
      });
      expect(digits.every((k) => k.category == KeyCategory.number), isTrue);
    });

    test('사칙연산 키 4개는 operator 카테고리다', () {
      final ops = allKeys.where((k) => k.category == KeyCategory.operator);
      expect(ops.map((k) => k.mainLabel).toSet(), {'+', '−', '×', '÷'});
    });

    test('반복 입력 키는 커서 패드 4방향과 DEL뿐이다', () {
      expect(autoRepeatKeys, {
        for (final k in cursorPad.all) k.id,
        CalcKeyId.del,
      });
    });

    // 출처: QSG 1쪽 사진(1~6 키 위 각인 없음). 가이드에도 SHIFT/ALPHA + 1~6 조작 예가 없다.
    test('숫자 1~6 키에는 SHIFT/ALPHA 각인이 없다', () {
      for (final id in [
        CalcKeyId.num1,
        CalcKeyId.num2,
        CalcKeyId.num3,
        CalcKeyId.num4,
        CalcKeyId.num5,
        CalcKeyId.num6,
      ]) {
        expect(keyDefOf(id).hasShift, isFalse, reason: id.name);
        expect(keyDefOf(id).hasAlpha, isFalse, reason: id.name);
      }
    });

    test('SHIFT/ALPHA 층에 모드 전용(보라색·파란색) 각인이 섞이지 않는다', () {
      // 가이드 인쇄 3쪽 "Key Markings": 보라색 = Complex 모드, 파란색 = Base-N 모드 전용.
      // 이 명세는 노란색(SHIFT)·빨간색(ALPHA) 각인만 담는다. 모드별 각인은 #33.
      const modeOnly = {'∠', 'i', 'DEC', 'HEX', 'BIN', 'OCT'};
      for (final key in allKeys) {
        expect(modeOnly, isNot(contains(key.shiftLabel)), reason: '$key');
        expect(modeOnly, isNot(contains(key.alphaLabel)), reason: '$key');
      }
    });

    test('층 간 라벨 겹침은 의도된 두 경우뿐이다', () {
      // 라벨 문자열 → (키, 층) 목록
      final owners = <String, List<String>>{};
      void add(String? label, CalcKeyDef key, String layer) {
        if (label == null) return;
        owners.putIfAbsent(label, () => []).add('${key.id.name}.$layer');
      }

      for (final key in allKeys) {
        add(key.mainLabel, key, 'main');
        add(key.shiftLabel, key, 'shift');
        add(key.alphaLabel, key, 'alpha');
      }
      final shared = {
        for (final e in owners.entries)
          if (e.value.length > 1) e.key: e.value.toSet(),
      };
      expect(shared, {
        // 같은 변수 x로 가는 두 경로 (가이드 인쇄 13쪽 각주 *1).
        'x': {'variableX.main', 'parenClose.alpha'},
        // 라벨만 같고 기능은 다르다: ALPHA = 은 방정식 기호 입력, = 키는 계산 실행.
        '=': {'equals.main', 'calc.alpha'},
      });
    });

    test('템플릿 각인은 첫 입력 칸 ◼를 정확히 하나 갖고, ▭는 쓰지 않는다', () {
      // key_definitions.dart 머리 주석 "각인 표기" (#16): ◼ = 커서가 처음 들어가는 칸, ◻ = 나머지 칸.
      // 2차원 각인(#155)은 칸이 분수·첨자 안에 흩어져 있으므로 글자 조각 전체를 센다.
      for (final legend in _allLegends()) {
        final text = legend.texts.map((t) => t.text).join();
        expect(text, isNot(contains('▭')), reason: legend.plainText);
        if (text.contains('◼') || text.contains('◻')) {
          expect('◼'.allMatches(text).length, 1, reason: legend.plainText);
        }
      }
    });

    group('2차원 각인 (#155)', () {
      test('각인 글자에 한 줄 임시 표기(분수 /·위첨자 ^·유니코드 위첨자·근호 글자)가 없다', () {
        // 분수·첨자·근호는 구조(LegendFraction·LegendScript·LegendRadical)로 담고 그림으로 그린다.
        final forbidden = RegExp('[/^⁰¹²³⁴⁵⁶⁷⁸⁹⁻ˣ√∛]');
        for (final legend in _allLegends()) {
          for (final t in legend.texts) {
            expect(
              forbidden.hasMatch(t.text),
              isFalse,
              reason: '${legend.plainText}: "${t.text}"',
            );
          }
        }
      });

      test('실물이 2차원 모양인 각인은 모두 2차원 각인이고, 그 밖의 각인은 글자만 있다', () {
        final twoDimensional = {
          for (final k in allKeys)
            for (final (layer, legend) in [
              ('main', k.mainLegend),
              ('shift', k.shiftLegend),
              ('alpha', k.alphaLegend),
            ])
              if (legend != null && !legend.isPlain) (k.id, layer),
        };
        expect(twoDimensional, _twoDimensionalLegends);
      });

      test('LegendRow는 조각이 둘 이상이고 중첩되지 않으며, 빈 글자 조각이 없다', () {
        void check(KeyLegend legend, String reason) {
          switch (legend) {
            case LegendText(:final text):
              expect(text, isNotEmpty, reason: reason);
            case LegendRow(:final children):
              expect(children.length, greaterThanOrEqualTo(2), reason: reason);
              for (final c in children) {
                expect(c, isNot(isA<LegendRow>()), reason: '$reason: 중첩 Row');
                check(c, reason);
              }
            case LegendScript(
              :final base,
              :final superscript,
              :final subscript,
            ):
              check(base, reason);
              if (superscript != null) check(superscript, reason);
              if (subscript != null) check(subscript, reason);
            case LegendFraction(:final numerator, :final denominator):
              check(numerator, reason);
              check(denominator, reason);
            case LegendRadical(:final radicand, :final index):
              check(radicand, reason);
              if (index != null) check(index, reason);
          }
        }

        for (final legend in _allLegends()) {
          check(legend, legend.plainText);
        }
      });
    });

    test('50키의 각인은 실물 대조표와 일치한다', () {
      expect(_verifiedLegends.keys.toSet(), CalcKeyId.values.toSet());
      for (final key in allKeys) {
        final (main, shift, alpha) = _verifiedLegends[key.id]!;
        expect(
          (key.mainLabel, key.shiftLabel, key.alphaLabel),
          (main, shift, alpha),
          reason: key.id.name,
        );
      }
    });

    test('컬렉션은 수정할 수 없다', () {
      expect(() => allKeys.add(allKeys.first), throwsUnsupportedError);
      expect(() => keyById.remove(CalcKeyId.ac), throwsUnsupportedError);
      expect(() => cursorPad.all.clear(), throwsUnsupportedError);
    });
  });
}

/// 실물 대조표 (#15).
///
/// 모든 행은 fx-991EX Quick Start Guide 1쪽 제품 사진과 한 줄씩 대조했다. User's Guide
/// (RJA532432-001V01)의 키 조작 예제에서 그 각인을 찾은 행에는 `G<인쇄 쪽>`을 덧붙였다.
/// `G` 표시가 없다고 가이드에 없다는 뜻은 아니다(쪽수를 이 표에 정리하지 않았을 뿐). "없음" 판정은
/// 사진이 근거다(예: Ans·ENG의 ALPHA 없음, 숫자 1~6 무각인).
///
/// `(메인, SHIFT, ALPHA)` — 각인이 없으면 `null`. 이 표는 명세의 사본이라 출처 없이 둘을 함께 고치면
/// 통과한다. 명세를 바꿀 때는 반드시 위 출처를 다시 확인하고 행 주석도 고친다.
const Map<CalcKeyId, (String, String?, String?)> _verifiedLegends = {
  // 상단 조작부
  CalcKeyId.shift: ('SHIFT', null, null),
  CalcKeyId.alpha: ('ALPHA', null, null),
  CalcKeyId.menu: ('MENU', 'SETUP', null), // G3
  CalcKeyId.on: ('ON', null, null),
  CalcKeyId.optn: ('OPTN', 'QR', null), // G7
  CalcKeyId.calc: ('CALC', 'SOLVE', '='),
  CalcKeyId.integral: ('∫◻◻◼', 'd/dx◼', ':'), // G15 d/dx, G11 :
  CalcKeyId.variableX: ('x', '∑◻◻◼', null), // G16 ∑ 예제
  // 커서 패드
  CalcKeyId.cursorUp: ('▲', null, null),
  CalcKeyId.cursorDown: ('▼', null, null),
  CalcKeyId.cursorLeft: ('◄', null, null),
  CalcKeyId.cursorRight: ('►', null, null),
  // 함수부 1행
  CalcKeyId.fraction: (
    '◼/◻',
    '◼ ◻/◻',
    null,
  ), // SHIFT 대분수 (한 줄 표기는 정수부 뒤를 띄운다, #155)
  CalcKeyId.sqrt: ('√◼', '∛◼', null),
  CalcKeyId.square: ('x²', 'x³', null), // G14
  CalcKeyId.power: ('x^◼', '◼√◻', null), // G15
  CalcKeyId.logBase: ('log◼◻', '10^◼', null),
  CalcKeyId.ln: ('ln', 'e^◼', null), // G14
  // 함수부 2행
  CalcKeyId.negative: ('(−)', 'log', 'A'), // G14 log 예제, G13 변수
  CalcKeyId.degMinSec: ('°\'"', 'FACT', 'B'),
  CalcKeyId.reciprocal: ('x⁻¹', 'x!', 'C'), // G16 x!
  CalcKeyId.sin: ('sin', 'sin⁻¹', 'D'),
  CalcKeyId.cos: ('cos', 'cos⁻¹', 'E'),
  CalcKeyId.tan: ('tan', 'tan⁻¹', 'F'),
  // 함수부 3행
  CalcKeyId.sto: ('STO', 'RECALL', null), // G13 변수 저장·호출
  CalcKeyId.eng: ('ENG', '←', null), // G11 ←, ALPHA 없음은 사진
  CalcKeyId.parenOpen: ('(', 'Abs', null), // G16 Abs 예제
  CalcKeyId.parenClose: (')', ',', 'x'), // G14·G15 ,  G13 변수 x
  CalcKeyId.sdToggle: ('S⇔D', 'a b/c⇔d/c', 'y'), // G11 a b/c⇔d/c, G13 변수 y
  CalcKeyId.mPlus: ('M+', 'M−', 'M'), // G13
  // 숫자부
  CalcKeyId.num7: ('7', 'CONST', null),
  CalcKeyId.num8: ('8', 'CONV', null),
  CalcKeyId.num9: ('9', 'RESET', null), // G7
  CalcKeyId.del: ('DEL', 'INS', 'UNDO'),
  CalcKeyId.ac: ('AC', 'OFF', null), // G3 전원
  CalcKeyId.num4: ('4', null, null),
  CalcKeyId.num5: ('5', null, null),
  CalcKeyId.num6: ('6', null, null),
  CalcKeyId.multiply: ('×', 'nPr', null), // G16
  CalcKeyId.divide: ('÷', 'nCr', null), // G16
  CalcKeyId.num1: ('1', null, null),
  CalcKeyId.num2: ('2', null, null),
  CalcKeyId.num3: ('3', null, null),
  CalcKeyId.add: ('+', 'Pol', null), // G16
  CalcKeyId.subtract: ('−', 'Rec', null), // G16
  CalcKeyId.num0: ('0', 'Rnd', null),
  CalcKeyId.dot: ('.', 'Ran#', 'RanInt'), // G16
  CalcKeyId.exp10: ('×10ˣ', 'π', 'e'), // G15
  CalcKeyId.ans: ('Ans', '%', null), // G11 %, ALPHA 없음은 사진 (가이드에 PreAns 없음)
  CalcKeyId.equals: ('=', '≈', null), // G7
};

/// 50키의 모든 각인 (메인·SHIFT·ALPHA)
Iterable<KeyLegend> _allLegends() => [
  for (final k in allKeys) ...[k.mainLegend, ?k.shiftLegend, ?k.alphaLegend],
];

/// 실물 키캡에 2차원 모양(분수·위첨자·아래첨자·근호)으로 인쇄된 각인 — 이슈 #155 "대상 각인" 표.
/// 기준은 #15·#16과 같은 Quick Start Guide 1쪽 제품 사진이다.
const Set<(CalcKeyId, String)> _twoDimensionalLegends = {
  (CalcKeyId.fraction, 'main'), // ◼/◻
  (CalcKeyId.fraction, 'shift'), // ◼ ◻/◻ (대분수)
  (CalcKeyId.sqrt, 'main'), // √◼
  (CalcKeyId.sqrt, 'shift'), // ∛◼
  (CalcKeyId.power, 'main'), // x^◼
  (CalcKeyId.power, 'shift'), // ◼√◻
  (CalcKeyId.logBase, 'main'), // log◼◻
  (CalcKeyId.logBase, 'shift'), // 10^◼
  (CalcKeyId.ln, 'shift'), // e^◼
  (CalcKeyId.integral, 'main'), // ∫◻◻◼
  (CalcKeyId.integral, 'shift'), // d/dx◼
  (CalcKeyId.variableX, 'shift'), // ∑◻◻◼
  (CalcKeyId.sdToggle, 'shift'), // a b/c⇔d/c
  (CalcKeyId.square, 'main'), // x²
  (CalcKeyId.square, 'shift'), // x³
  (CalcKeyId.reciprocal, 'main'), // x⁻¹
  (CalcKeyId.sin, 'shift'), // sin⁻¹
  (CalcKeyId.cos, 'shift'), // cos⁻¹
  (CalcKeyId.tan, 'shift'), // tan⁻¹
  (CalcKeyId.exp10, 'main'), // ×10ˣ
};
