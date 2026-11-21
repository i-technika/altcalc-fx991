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
    test('이슈 #10에서 요구한 표시기 슬롯을 모두 갖는다', () {
      final all = _possibleIndicators().values.expand((e) => e).toSet();
      for (final required in [
        'S',
        'A',
        'D',
        'R',
        'G',
        'FIX',
        'SCI',
        'M',
        'STO',
        'Math',
        'E',
        'i',
        '∠',
        'Disp',
      ]) {
        expect(all, contains(required), reason: required);
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
    test('초기 상태는 Deg·Norm·MathI/MathO로 D와 Math만 켜진다', () {
      expect(LcdStatus.initial.activeIndicators, ['D', 'Math']);
    });

    test('각도 단위는 항상 켜져 있다', () {
      for (final u in AngleUnit.values) {
        expect(
          LcdStatus(angleUnit: u).indicatorFor(LcdIndicatorSlot.angleUnit),
          u.indicator,
        );
      }
    });

    test('Norm과 복소수 아님은 표시기를 끈다', () {
      const s = LcdStatus();
      expect(s.indicatorFor(LcdIndicatorSlot.numberFormat), isNull);
      expect(s.indicatorFor(LcdIndicatorSlot.complex), isNull);
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
      expect(s.activeIndicators, ['S', 'R', 'SCI', '∠', 'Disp']);
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
      ];
      for (final v in variants) {
        expect(v, isNot(base), reason: '$v');
      }
    });
  });

  group('LcdLineOverflow', () {
    test('기본값은 넘침 없음이며 동등성을 지킨다', () {
      expect(const LcdLineOverflow(), LcdLineOverflow.none);
      expect(
        const LcdLineOverflow(left: true),
        isNot(const LcdLineOverflow(right: true)),
      );
      expect(
        const LcdLineOverflow(left: true).hashCode,
        const LcdLineOverflow(left: true).hashCode,
      );
    });
  });
}
