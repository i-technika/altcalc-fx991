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
/// (RJA532432-001V01) 예제로도 확인된 행은 `G<인쇄 쪽>`을 덧붙였다. 표시가 없는 행은 사진만 근거다.
///
/// `(메인, SHIFT, ALPHA)` — 각인이 없으면 `null`. 이 표는 명세의 사본이라 출처 없이 둘을 함께 고치면
/// 통과한다. 명세를 바꿀 때는 반드시 위 출처를 다시 확인하고 행 주석도 고친다.
const Map<CalcKeyId, (String, String?, String?)> _verifiedLegends = {
  // 상단 조작부
  CalcKeyId.shift: ('SHIFT', null, null),
  CalcKeyId.alpha: ('ALPHA', null, null),
  CalcKeyId.menu: ('MENU', 'SETUP', null),
  CalcKeyId.on: ('ON', null, null),
  CalcKeyId.optn: ('OPTN', 'QR', null),
  CalcKeyId.calc: ('CALC', 'SOLVE', '='),
  CalcKeyId.integral: ('∫▭', 'd/dx▭', ':'),
  CalcKeyId.variableX: ('x', '∑▭', null), // G16 ∑ 예제
  // 커서 패드
  CalcKeyId.cursorUp: ('▲', null, null),
  CalcKeyId.cursorDown: ('▼', null, null),
  CalcKeyId.cursorLeft: ('◀', null, null),
  CalcKeyId.cursorRight: ('▶', null, null),
  // 함수부 1행
  CalcKeyId.fraction: ('▭/▭', '▭▭/▭', null),
  CalcKeyId.sqrt: ('√▭', '∛▭', null),
  CalcKeyId.square: ('x²', 'x³', null),
  CalcKeyId.power: ('x^▭', '▭√▭', null),
  CalcKeyId.logBase: ('log▭▭', '10^▭', null),
  CalcKeyId.ln: ('ln', 'e^▭', null),
  // 함수부 2행
  CalcKeyId.negative: ('(−)', 'log', 'A'), // G14 log 예제, G13 변수
  CalcKeyId.degMinSec: ('°\'"', 'FACT', 'B'),
  CalcKeyId.reciprocal: ('x⁻¹', 'x!', 'C'),
  CalcKeyId.sin: ('sin', 'sin⁻¹', 'D'),
  CalcKeyId.cos: ('cos', 'cos⁻¹', 'E'),
  CalcKeyId.tan: ('tan', 'tan⁻¹', 'F'),
  // 함수부 3행
  CalcKeyId.sto: ('STO', 'RECALL', null), // G13 변수 저장·호출
  CalcKeyId.eng: ('ENG', '←', null),
  CalcKeyId.parenOpen: ('(', 'Abs', null), // G16 Abs 예제
  CalcKeyId.parenClose: (')', ',', 'x'), // G14 log(2,16), G13 변수 x
  CalcKeyId.sdToggle: ('S⇔D', 'a b/c⇔d/c', 'y'), // G13 변수 y
  CalcKeyId.mPlus: ('M+', 'M−', 'M'),
  // 숫자부
  CalcKeyId.num7: ('7', 'CONST', null),
  CalcKeyId.num8: ('8', 'CONV', null),
  CalcKeyId.num9: ('9', 'RESET', null),
  CalcKeyId.del: ('DEL', 'INS', 'UNDO'),
  CalcKeyId.ac: ('AC', 'OFF', null), // G3 전원
  CalcKeyId.num4: ('4', null, null),
  CalcKeyId.num5: ('5', null, null),
  CalcKeyId.num6: ('6', null, null),
  CalcKeyId.multiply: ('×', 'nPr', null),
  CalcKeyId.divide: ('÷', 'nCr', null),
  CalcKeyId.num1: ('1', null, null),
  CalcKeyId.num2: ('2', null, null),
  CalcKeyId.num3: ('3', null, null),
  CalcKeyId.add: ('+', 'Pol', null),
  CalcKeyId.subtract: ('−', 'Rec', null),
  CalcKeyId.num0: ('0', 'Rnd', null),
  CalcKeyId.dot: ('.', 'Ran#', 'RanInt'),
  CalcKeyId.exp10: ('×10ˣ', 'π', 'e'),
  CalcKeyId.ans: ('Ans', '%', null), // 사진만 (가이드에 PreAns 없음)
  CalcKeyId.equals: ('=', '≈', null),
};
