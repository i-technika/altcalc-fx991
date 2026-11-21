import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';

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
      expect(cursorPadKeys.length, 4);
      expect(functionRows.length, 3);
      for (final row in functionRows) {
        expect(row.length, functionColumns);
      }
      expect(numberRows.length, 4);
      for (final row in numberRows) {
        expect(row.length, numberColumns);
      }
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

  group('카테고리 색상 매핑', () {
    test('모든 카테고리는 배경/텍스트 색이 구분된다', () {
      for (final c in KeyCategory.values) {
        expect(c.background, isNot(c.foreground), reason: c.name);
      }
    });

    test('SHIFT/ALPHA 키 색은 각인 색과 일치한다', () {
      expect(KeyCategory.shift.background, CalcTheme.shiftLabel);
      expect(KeyCategory.alpha.background, CalcTheme.alphaLabel);
    });
  });

  group('광고 슬롯 치수', () {
    test('광고 슬롯 높이는 50~60dp, 안전 여백은 8~12dp 범위다', () {
      expect(CalcTheme.adSlotHeight, inInclusiveRange(50, 60));
      expect(CalcTheme.adSlotMaxHeight, inInclusiveRange(50, 60));
      expect(
        CalcTheme.adSlotHeight,
        lessThanOrEqualTo(CalcTheme.adSlotMaxHeight),
      );
      expect(CalcTheme.adSlotSafetyMargin, inInclusiveRange(8, 12));
    });
  });
}
