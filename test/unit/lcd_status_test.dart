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
    test('슬롯 순서는 사용자 제공 fx-991EX 실물 순서를 따른다 (잠정 슬롯 제외)', () {
      // 출처: LcdIndicatorSlot 문서 주석 — S, A, M, →x, D/R/G, FIX, SCI, √▭✎, ▼/▲, Disp ‖ (☀ 제외)
      final confirmed = [
        for (final slot in LcdIndicatorSlot.values)
          if (!LcdIndicatorSlot.provisional.contains(slot)) slot.template,
      ];
      expect(confirmed, [
        'S',
        'A',
        'M',
        '→x',
        'D',
        'FIX',
        'SCI',
        '√◻',
        '▼',
        '▲',
        '‖',
      ]);
    });

    test('실물 순서 자료에 없는 잠정 슬롯은 E와 i/∠ 뿐이다', () {
      expect(LcdIndicatorSlot.provisional, {
        LcdIndicatorSlot.engineering,
        LcdIndicatorSlot.complex,
      });
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

    test('슬롯 대표 문자는 비어 있지 않고 서로 다르다', () {
      final templates = LcdIndicatorSlot.values.map((s) => s.template).toList();
      expect(templates.every((t) => t.isNotEmpty), isTrue);
      expect(templates.toSet().length, templates.length);
    });

    test('표시 문자는 슬롯 대표 문자보다 길지 않다 (고정 너비 유지)', () {
      for (final MapEntry(key: slot, value: labels)
          in _possibleIndicators().entries) {
        expect(labels, isNotEmpty, reason: '${slot.name} 슬롯을 켤 방법이 없다');
        for (final label in labels) {
          expect(
            label.length,
            lessThanOrEqualTo(slot.template.length),
            reason: '${slot.name}: $label',
          );
        }
      }
    });

    test('대표 문자는 그 슬롯이 실제로 표시할 수 있는 문자다', () {
      for (final MapEntry(key: slot, value: labels)
          in _possibleIndicators().entries) {
        expect(labels, contains(slot.template), reason: slot.name);
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
      expect(LcdStatus.initial.activeIndicators, ['D', '√◻']);
    });

    test('각도 단위는 항상 켜져 있다', () {
      for (final u in AngleUnit.values) {
        expect(
          LcdStatus(angleUnit: u).indicatorFor(LcdIndicatorSlot.angleUnit),
          u.indicator,
        );
      }
    });

    test('Norm과 복소수 표시 안 함은 표시기를 끈다', () {
      const s = LcdStatus();
      expect(s.indicatorFor(LcdIndicatorSlot.fixFormat), isNull);
      expect(s.indicatorFor(LcdIndicatorSlot.sciFormat), isNull);
      expect(s.indicatorFor(LcdIndicatorSlot.complex), isNull);
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
