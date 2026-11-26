import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';

/// 각 슬롯을 켤 수 있는 모든 상태 (슬롯 → 가능한 표시 문자 목록)
Map<LcdIndicatorSlot, Set<String>> _possibleIndicators() {
  final variants = <LcdStatus>[
    const LcdStatus(
      shift: true,
      alpha: true,
      memory: true,
      store: true,
      engineering: true,
      disp: true,
      historyUp: true,
      historyDown: true,
    ),
    for (final u in AngleUnit.values) LcdStatus(angleUnit: u),
    for (final f in NumberDisplayFormat.values) LcdStatus(numberFormat: f),
    for (final c in ComplexResultIndicator.values) LcdStatus(complex: c),
  ];
  return {
    for (final slot in LcdIndicatorSlot.values)
      slot: {for (final s in variants) ?s.indicatorFor(slot)},
  };
}

void main() {
  group('LcdIndicatorSlot 불변식', () {
    test('슬롯 순서는 fx-991EX 실물 LCD 세그먼트 순서를 따른다 (#58)', () {
      // 출처: LcdIndicatorSlot 문서 주석 — 실물 사진·ClassWiz 세그먼트 좌표 대조.
      // ⇩·◀·▶·☀는 앱에 해당 상태가 없어 슬롯이 없다(자리만 비워 둔다).
      expect(LcdIndicatorSlot.values.map((s) => s.template), [
        'S',
        'A',
        'M',
        '→x',
        '√◻',
        'D',
        'R',
        'G',
        'FIX',
        'SCI',
        'E',
        'i',
        '∠',
        '▼',
        '▲',
        '‖',
      ]);
    });

    test('세그먼트 가운데 위치는 출처 스프라이트의 잉크 범위 가운데다 (#58)', () {
      // 출처: CasioEmu models/fx991cnx/model.lua의 rsd_* 사각형(LCD 왼쪽 x=47 기준으로 뺀 값)과,
      // interface.png(RGBA)를 흰 배경에 알파 합성하고 회색(PIL `L`)으로 바꾼 뒤, y=603~610에서 회색값 < 200인
      // 열의 범위 [lo, hi). 슬롯이 없는 ⇩·◀·▶·☀도 적어 둔다.
      const sprites = <String, (int, int, int, int)>{
        // 이름: (x, 폭, 잉크 lo, 잉크 hi)
        'S': (0, 8, 0, 7),
        'A': (8, 8, 8, 15),
        'M': (16, 10, 18, 23),
        '→x': (26, 13, 28, 36),
        '√◻': (39, 17, 40, 54),
        'D': (56, 8, 57, 64),
        'R': (64, 7, 64, 71),
        'G': (71, 9, 71, 78),
        'FIX': (80, 14, 81, 93),
        'SCI': (94, 15, 95, 106),
        'E': (109, 9, 110, 116),
        'i': (118, 6, 119, 123),
        '∠': (124, 7, 126, 131),
        '⇩': (131, 11, 133, 138),
        '◀': (142, 7, 143, 148),
        '▼': (149, 7, 150, 155),
        '▲': (156, 6, 157, 162),
        '▶': (162, 9, 164, 169),
        '‖': (171, 12, 173, 180),
        '☀': (183, 9, 184, 190),
      };
      // 사각형은 192도트를 빈틈없이 덮고, 잉크는 자기 사각형 안에 있으며 이웃 잉크와 겹치지 않는다.
      var next = 0;
      var prevInkEnd = 0;
      for (final MapEntry(key: name, value: (x, w, lo, hi))
          in sprites.entries) {
        expect(x, next, reason: name);
        next = x + w;
        expect(lo, inInclusiveRange(x, hi), reason: name);
        expect(hi, lessThanOrEqualTo(x + w), reason: name);
        expect(lo, greaterThanOrEqualTo(prevInkEnd), reason: name);
        prevInkEnd = hi;
      }
      expect(next, LcdIndicatorSlot.dotColumns);
      for (final slot in LcdIndicatorSlot.values) {
        final (_, _, lo, hi) = sprites[slot.template]!;
        expect(slot.dotCenter, (lo + hi) / 2, reason: slot.name);
      }
      // 슬롯 순서는 스프라이트 순서에서 슬롯이 없는 세그먼트를 뺀 것과 같다.
      expect(
        LcdIndicatorSlot.values.map((s) => s.template),
        sprites.keys.where((k) => !{'⇩', '◀', '▶', '☀'}.contains(k)),
      );
    });

    test('사진 대조: 켜진 표시기의 실측 위치와 1도트 안쪽으로 맞는다', () {
      // 사진(Wikimedia Commons "Casio fx-991EX Scientific Calculator.jpg", 1920×2560)의 상태줄(y 540~560)에서
      // 켜진 표시기의 가로 범위를 재고, D와 ☀의 가운데를 위 표의 값(60.5, 187)에 맞춰 사진 x를 도트로 바꿨다
      // (1도트 ≈ 4.27px, 회색값 < 95인 열). 그 환산으로 잰 나머지 표시기 위치다. ☀는 슬롯이 없어 환산 기준으로만 쓴다.
      for (final (slot, measured) in [
        (LcdIndicatorSlot.math, 46.8),
        (LcdIndicatorSlot.historyUp, 158.8),
      ]) {
        expect(slot.dotCenter, closeTo(measured, 1.0), reason: slot.name);
      }
    });

    test('세그먼트 위치는 선언 순서대로 커지고 표시줄 안에 있다', () {
      final slots = LcdIndicatorSlot.values;
      for (final slot in slots) {
        expect(slot.centerFraction, inExclusiveRange(0, 1), reason: slot.name);
      }
      for (var i = 1; i < slots.length; i++) {
        expect(
          slots[i].dotCenter,
          greaterThan(slots[i - 1].dotCenter),
          reason: '${slots[i - 1].name} → ${slots[i].name}',
        );
      }
    });

    test('▼와 ▲는 한 자리에 겹치지 않고 나란한 두 자리다 (▼ 왼쪽)', () {
      final down = LcdIndicatorSlot.historyDown;
      final up = LcdIndicatorSlot.historyUp;
      expect(up.index, down.index + 1);
      expect(up.dotCenter - down.dotCenter, greaterThan(5));
    });

    test('가이드의 표시기를 모두 표시할 수 있다 (☀는 앱에 해당 상태가 없어 제외, RCL은 가이드 표에 없음)', () {
      final all = _possibleIndicators().values.expand((e) => e).toSet();
      for (final required in [
        'S',
        'A',
        'M',
        '→x',
        'D',
        'R',
        'G',
        'FIX',
        'SCI',
        'E',
        '√◻',
        'i',
        '∠',
        '▲',
        '▼',
        '‖',
      ]) {
        expect(all, contains(required), reason: required);
      }
      for (final excluded in ['☀', 'RCL', 'STO', 'Math', 'Disp']) {
        expect(all, isNot(contains(excluded)), reason: excluded);
      }
    });

    test('아이콘으로 그리는 슬롯은 →x·√▭✎·‖ 셋이고 아이콘이 겹치지 않는다 (#57)', () {
      final icons = {
        for (final slot in LcdIndicatorSlot.values)
          if (slot.icon != null) slot: slot.icon,
      };
      expect(icons, {
        LcdIndicatorSlot.store: LcdIndicatorIcon.storeArrow,
        LcdIndicatorSlot.math: LcdIndicatorIcon.mathInput,
        LcdIndicatorSlot.disp: LcdIndicatorIcon.multiStatement,
      });
      // 아이콘 슬롯은 켜지면 대표 문자 하나만 표시한다(값이 여러 개인 아이콘은 없다).
      for (final MapEntry(key: slot, value: labels)
          in _possibleIndicators().entries) {
        if (slot.icon != null) {
          expect(labels, {slot.template}, reason: slot.name);
        }
      }
      // 실물 아이콘 폭: →x 2칸, √▭✎ 3칸, ‖ 1칸
      expect(LcdIndicatorSlot.store.columns, 2);
      expect(LcdIndicatorSlot.math.columns, 3);
      expect(LcdIndicatorSlot.disp.columns, 1);
    });

    test('반전 상자 글자 슬롯은 S·A·D·R·G 다섯이고, 글자 하나짜리 1칸 글자 슬롯이다 (#160)', () {
      final boxed = [
        for (final slot in LcdIndicatorSlot.values)
          if (slot.boxed) slot,
      ];
      expect(boxed, [
        LcdIndicatorSlot.shift,
        LcdIndicatorSlot.alpha,
        LcdIndicatorSlot.angleDegree,
        LcdIndicatorSlot.angleRadian,
        LcdIndicatorSlot.angleGradian,
      ]);
      for (final slot in boxed) {
        // 상자는 한 칸 폭이고 아이콘과 겹치지 않는다. 켜지면 대표 문자 그대로를 상자 안에 그린다.
        expect(slot.icon, isNull, reason: slot.name);
        expect(slot.columns, 1, reason: slot.name);
        expect(slot.template.runes.length, 1, reason: slot.name);
        expect(_possibleIndicators()[slot], {slot.template}, reason: slot.name);
      }
    });

    test('슬롯 대표 문자는 비어 있지 않고 서로 다르다', () {
      final templates = LcdIndicatorSlot.values.map((s) => s.template).toList();
      expect(templates.every((t) => t.isNotEmpty), isTrue);
      expect(templates.toSet().length, templates.length);
    });

    test('글자 슬롯의 표시 문자는 슬롯 칸 수를 넘지 않는다 (고정 너비 유지)', () {
      for (final MapEntry(key: slot, value: labels)
          in _possibleIndicators().entries) {
        expect(labels, isNotEmpty, reason: '${slot.name} 슬롯을 켤 방법이 없다');
        expect(slot.columns, greaterThan(0), reason: slot.name);
        if (slot.icon != null) continue;
        for (final label in labels) {
          expect(
            label.runes.length,
            lessThanOrEqualTo(slot.columns),
            reason: '${slot.name}: $label',
          );
        }
      }
    });

    test('모든 슬롯은 켜지면 대표 문자 하나만 표시한다 (슬롯 = 실물 세그먼트 하나, #58)', () {
      // 꺼졌을 때 흐리게 그리는 글자와 켜졌을 때의 글자가 같아야 자리가 고정된 의미가 산다.
      for (final MapEntry(key: slot, value: labels)
          in _possibleIndicators().entries) {
        expect(labels, {slot.template}, reason: slot.name);
      }
    });

    test('각도 단위·표시 형식·복소수 표시 문자는 서로 다르다', () {
      final angle = AngleUnit.values.map((u) => u.indicator).toSet();
      expect(angle.length, AngleUnit.values.length);
      final formats = NumberDisplayFormat.values
          .map((f) => f.indicator)
          .toSet();
      expect(formats.length, NumberDisplayFormat.values.length);
      final complex = ComplexResultIndicator.values
          .map((c) => c.indicator)
          .toSet();
      expect(complex.length, ComplexResultIndicator.values.length);
    });
  });

  group('LcdStatus', () {
    test('초기 상태는 Deg·Norm·MathI/MathO로 D와 √◻만 켜진다', () {
      expect(LcdStatus.initial.activeIndicators, ['√◻', 'D']);
    });

    test('각도 단위는 항상 켜져 있고, D/R/G 세 자리 중 그 단위의 자리 하나만 켜진다', () {
      const angleSlots = {
        AngleUnit.degree: LcdIndicatorSlot.angleDegree,
        AngleUnit.radian: LcdIndicatorSlot.angleRadian,
        AngleUnit.gradian: LcdIndicatorSlot.angleGradian,
      };
      for (final u in AngleUnit.values) {
        final s = LcdStatus(angleUnit: u);
        for (final MapEntry(key: unit, value: slot) in angleSlots.entries) {
          expect(
            s.indicatorFor(slot),
            unit == u ? u.indicator : null,
            reason: '${u.name} → ${slot.name}',
          );
        }
      }
    });

    test('복소수 형식은 i와 ∠ 두 자리 중 설정된 자리 하나만 켜진다', () {
      for (final c in ComplexResultIndicator.values) {
        final s = LcdStatus(complex: c);
        expect(
          s.indicatorFor(LcdIndicatorSlot.complexRectangular),
          c == ComplexResultIndicator.rectangular ? 'i' : null,
          reason: c.name,
        );
        expect(
          s.indicatorFor(LcdIndicatorSlot.complexPolar),
          c == ComplexResultIndicator.polar ? '∠' : null,
          reason: c.name,
        );
      }
    });

    test('Norm과 복소수 표시 안 함은 표시기를 끈다', () {
      const s = LcdStatus();
      expect(s.indicatorFor(LcdIndicatorSlot.fixFormat), isNull);
      expect(s.indicatorFor(LcdIndicatorSlot.sciFormat), isNull);
      expect(s.indicatorFor(LcdIndicatorSlot.complexRectangular), isNull);
      expect(s.indicatorFor(LcdIndicatorSlot.complexPolar), isNull);
    });

    test('FIX와 SCI는 서로 다른 자리이고 동시에 켜지지 않는다', () {
      for (final f in NumberDisplayFormat.values) {
        final s = LcdStatus(numberFormat: f);
        expect(
          s.indicatorFor(LcdIndicatorSlot.fixFormat),
          f == NumberDisplayFormat.fix ? 'FIX' : null,
          reason: f.name,
        );
        expect(
          s.indicatorFor(LcdIndicatorSlot.sciFormat),
          f == NumberDisplayFormat.sci ? 'SCI' : null,
          reason: f.name,
        );
      }
    });

    test('activeIndicators는 슬롯 순서를 따른다', () {
      const s = LcdStatus(
        disp: true,
        shift: true,
        complex: ComplexResultIndicator.polar,
        numberFormat: NumberDisplayFormat.sci,
        angleUnit: AngleUnit.radian,
        mathIO: false,
      );
      expect(s.activeIndicators, ['S', 'R', 'SCI', '∠', '‖']);
    });

    test('copyWith는 지정한 필드만 바꾸고 동등성·해시를 지킨다', () {
      const base = LcdStatus();
      final changed = base.copyWith(shift: true);
      expect(changed.shift, isTrue);
      expect(changed.copyWith(shift: false), base);
      expect(changed.copyWith(shift: false).hashCode, base.hashCode);
      expect(changed, isNot(base));
      expect(base.copyWith(), base);
    });

    test('모든 필드가 동등성에 반영된다', () {
      const base = LcdStatus();
      final variants = [
        base.copyWith(shift: true),
        base.copyWith(alpha: true),
        base.copyWith(memory: true),
        base.copyWith(store: true),
        base.copyWith(angleUnit: AngleUnit.gradian),
        base.copyWith(numberFormat: NumberDisplayFormat.fix),
        base.copyWith(engineering: true),
        base.copyWith(mathIO: false),
        base.copyWith(complex: ComplexResultIndicator.rectangular),
        base.copyWith(disp: true),
        base.copyWith(historyUp: true),
        base.copyWith(historyDown: true),
      ];
      for (final v in variants) {
        expect(v, isNot(base), reason: '$v');
      }
    });
  });
}
