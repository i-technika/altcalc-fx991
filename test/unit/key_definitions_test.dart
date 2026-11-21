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

    test('상단 조작부 좌우 블록은 행 수가 같다', () {
      expect(controlLeftRows.length, controlRightRows.length);
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

    test('ALPHA 변수 A~F, X, Y, M이 각각 정확히 하나의 키에 매핑된다', () {
      const variables = ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'];
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

    test('컬렉션은 수정할 수 없다', () {
      expect(() => allKeys.add(allKeys.first), throwsUnsupportedError);
      expect(() => keyById.remove(CalcKeyId.ac), throwsUnsupportedError);
    });
  });
}
