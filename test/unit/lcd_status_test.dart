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
      keepScreenOn: true,
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

/// 상태줄 세그먼트 스프라이트 (#58).
/// 출처: CasioEmu models/fx991cnx/model.lua의 rsd_* 사각형(LCD 왼쪽 x=47 기준으로 뺀 값)과,
/// interface.png(RGBA)를 흰 배경에 알파 합성하고 회색(PIL `L`)으로 바꾼 뒤, y=603~610에서 회색값 < 200인
/// 열의 범위 [lo, hi). 슬롯이 없는 ⇩·◀·▶도 적어 둔다. ☀ 자리는 앱 고유 화면 켜짐 유지 슬롯(`👁`, #233)이다.
/// 슬롯 대표 문자가 실물 세그먼트와 다른 슬롯은 [_spriteOf]로 이름을 바꿔 찾는다.
const _sprites = <String, (int, int, int, int)>{
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

/// 슬롯 → 그 자리 스프라이트 이름. 대표 문자가 실물 세그먼트와 다른 슬롯만 적는다.
const _spriteOf = <LcdIndicatorSlot, String>{
  // 실물 ☀(태양광) 자리에 앱 고유 화면 켜짐 유지 표시기를 둔다(#233).
  LcdIndicatorSlot.keepScreenOn: '☀',
};

/// [slot] 자리의 스프라이트 이름
String _spriteName(LcdIndicatorSlot slot) => _spriteOf[slot] ?? slot.template;

/// 스프라이트 잉크 가운데 (도트)
double _spriteCenter(String name) {
  final (_, _, lo, hi) = _sprites[name]!;
  return (lo + hi) / 2;
}

void main() {
  group('LcdIndicatorSlot 불변식', () {
    test('슬롯 순서는 fx-991EX 실물 LCD 세그먼트 순서를 따른다 (#58)', () {
      // 출처: LcdIndicatorSlot 문서 주석 — 실물 사진·ClassWiz 세그먼트 좌표 대조.
      // ⇩·◀·▶는 가이드 표시기 표에 없어 슬롯이 없다(자리만 비워 둔다). 맨 끝 ☀ 자리는 앱 고유 화면 켜짐 유지(👁, #233).
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
        '👁',
      ]);
    });

    test('세그먼트 가운데 위치는 출처 스프라이트의 잉크 범위 가운데다 (#58)', () {
      // 출처: 파일 위 [_sprites] 문서.
      // 사각형은 192도트를 빈틈없이 덮고, 잉크는 자기 사각형 안에 있으며 이웃 잉크와 겹치지 않는다.
      var next = 0;
      var prevInkEnd = 0;
      for (final MapEntry(key: name, value: (x, w, lo, hi))
          in _sprites.entries) {
        expect(x, next, reason: name);
        next = x + w;
        expect(lo, inInclusiveRange(x, hi), reason: name);
        expect(hi, lessThanOrEqualTo(x + w), reason: name);
        expect(lo, greaterThanOrEqualTo(prevInkEnd), reason: name);
        prevInkEnd = hi;
      }
      expect(next, LcdIndicatorSlot.dotColumns);
      for (final slot in LcdIndicatorSlot.values) {
        final (_, _, lo, hi) = _sprites[_spriteName(slot)]!;
        expect(slot.dotCenter, (lo + hi) / 2, reason: slot.name);
      }
      // 슬롯 순서는 스프라이트 순서에서 슬롯이 없는 세그먼트를 뺀 것과 같다.
      expect(
        LcdIndicatorSlot.values.map(_spriteName),
        _sprites.keys.where((k) => !{'⇩', '◀', '▶'}.contains(k)),
      );
      // 자리를 바꿔 찾는 슬롯의 대표 문자는 실물 세그먼트 이름과 겹치지 않는다(다른 세그먼트로 읽히지 않게).
      for (final slot in _spriteOf.keys) {
        expect(
          _sprites.keys,
          isNot(contains(slot.template)),
          reason: slot.name,
        );
      }
    });

    test('사진 대조: 켜진 표시기의 실측 위치와 1도트 안쪽으로 맞는다', () {
      // 사진(Wikimedia Commons "Casio fx-991EX Scientific Calculator.jpg", 1920×2560)의 상태줄(y 540~560)에서
      // 켜진 표시기의 가로 범위를 재고, D와 ☀의 가운데를 위 표의 값(60.5, 187)에 맞춰 사진 x를 도트로 바꿨다
      // (1도트 ≈ 4.27px, 회색값 < 95인 열). 그 환산으로 잰 나머지 표시기 위치다. ☀는 환산 기준으로만 쓴다
      // (그 자리 화면 켜짐 유지 슬롯의 가운데가 같은 187도트다 — 위 테스트).
      for (final (slot, measured) in [
        (LcdIndicatorSlot.math, 46.8),
        (LcdIndicatorSlot.historyUp, 158.8),
      ]) {
        expect(slot.dotCenter, closeTo(measured, 1.0), reason: slot.name);
      }
    });

    test('영상 대조: 모든 세그먼트가 켜진 진단 화면에서 잰 위치가 1도트 안쪽으로 맞는다 (#183)', () {
      // 출처: YouTube "Casio calculator fx-991EX hidden diagnostic test mode functions"(SergeiFrolovMuseum)
      // 1:22 화면(사용자가 준 캡처, 2340×1080). 진단 모드라 상태줄 세그먼트가 모두 켜져 있다. 상태줄이 약 0.9° 기울어
      // 있어 (528, 416)–(1500, 432) 선을 따라 세로 8px 평균 밝기를 재고, 좌우 ±25px 최댓값의 65% 미만인 열을
      // 잉크로 보아 6px 이하 틈은 이었다. D·R·G는 붙어 한 덩어리(D 왼쪽 ~ G 오른쪽)로 잡혔다.
      // 사진 x를 직선 하나(최소제곱)로 도트에 맞추면 모든 세그먼트가 1도트 안쪽으로 맞는다(약 5.44px/도트).
      // 슬롯이 없는 ⇩·◀·▶는 스프라이트 잉크 가운데를 쓴다([_sprites]). ☀는 그 자리 화면 켜짐 유지 슬롯(#233)이다.
      final measured = <(String, double, double)>[
        // (이름, 도트 가운데, 사진 x 가운데)
        ('S', LcdIndicatorSlot.shift.dotCenter, 528.5),
        ('A', LcdIndicatorSlot.alpha.dotCenter, 568.5),
        ('M', LcdIndicatorSlot.memory.dotCenter, 624),
        ('→x', LcdIndicatorSlot.store.dotCenter, 685.5),
        ('√◻', LcdIndicatorSlot.math.dotCenter, 763),
        (
          'D~G',
          (LcdIndicatorSlot.angleDegree.dotCenter +
                  LcdIndicatorSlot.angleGradian.dotCenter) /
              2,
          877.5,
        ),
        ('FIX', LcdIndicatorSlot.fixFormat.dotCenter, 986),
        ('SCI', LcdIndicatorSlot.sciFormat.dotCenter, 1060),
        ('E', LcdIndicatorSlot.engineering.dotCenter, 1120),
        ('i', LcdIndicatorSlot.complexRectangular.dotCenter, 1168),
        ('∠', LcdIndicatorSlot.complexPolar.dotCenter, 1206),
        ('⇩', _spriteCenter('⇩'), 1249.5),
        ('◀', _spriteCenter('◀'), 1305.5),
        ('▼', LcdIndicatorSlot.historyDown.dotCenter, 1340.5),
        ('▲', LcdIndicatorSlot.historyUp.dotCenter, 1376),
        ('▶', _spriteCenter('▶'), 1412),
        ('‖', LcdIndicatorSlot.disp.dotCenter, 1470),
        ('☀', LcdIndicatorSlot.keepScreenOn.dotCenter, 1526),
      ];
      final n = measured.length;
      final sx = measured.fold(0.0, (a, e) => a + e.$2);
      final sy = measured.fold(0.0, (a, e) => a + e.$3);
      final sxx = measured.fold(0.0, (a, e) => a + e.$2 * e.$2);
      final sxy = measured.fold(0.0, (a, e) => a + e.$2 * e.$3);
      final scale = (n * sxy - sx * sy) / (n * sxx - sx * sx);
      final offset = (sy - scale * sx) / n;
      expect(scale, closeTo(5.44, 0.05), reason: '사진 px/도트');
      for (final (name, dot, x) in measured) {
        expect((x - offset) / scale, closeTo(dot, 1.0), reason: name);
      }
      // 참고(검사하지 않는 자료): 같은 환산으로 잰 잉크 폭은 S 상자 511~546px ≈ 6.4, →x 666~705px ≈ 7.2,
      // ‖ 상자 1450~1490px ≈ 7.4도트다. 스프라이트(7·8·7도트)와 각각 1도트 안쪽이지만, 이 흐림(약 2도트 번짐)으로는
      // 7도트와 8도트를 가릴 수 없다(영상에서는 ‖가 →x보다 넓게 잡힌다). 폭의 근거는 스프라이트이고 영상은 그와
      // 모순되지 않는다는 정도다.
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

    test('가이드의 표시기를 모두 표시할 수 있다 (☀ 태양광은 앱에 해당 상태가 없어 제외 — 그 자리는 화면 켜짐 유지 👁, '
        'RCL은 가이드 표에 없음)', () {
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
        '👁',
      ]) {
        expect(all, contains(required), reason: required);
      }
      for (final excluded in ['☀', 'RCL', 'STO', 'Math', 'Disp']) {
        expect(all, isNot(contains(excluded)), reason: excluded);
      }
    });

    test('아이콘으로 그리는 슬롯은 →x·√▭✎·‖·👁 넷이고 아이콘이 겹치지 않는다 (#57, #233)', () {
      final icons = {
        for (final slot in LcdIndicatorSlot.values)
          if (slot.icon != null) slot: slot.icon,
      };
      expect(icons, {
        LcdIndicatorSlot.store: LcdIndicatorIcon.storeArrow,
        LcdIndicatorSlot.math: LcdIndicatorIcon.mathInput,
        LcdIndicatorSlot.disp: LcdIndicatorIcon.multiStatement,
        LcdIndicatorSlot.keepScreenOn: LcdIndicatorIcon.keepScreenOn,
      });
      expect(icons.values.toSet(), LcdIndicatorIcon.values.toSet());
      // 아이콘 슬롯은 켜지면 대표 문자 하나만 표시한다(값이 여러 개인 아이콘은 없다).
      for (final MapEntry(key: slot, value: labels)
          in _possibleIndicators().entries) {
        if (slot.icon != null) {
          expect(labels, {slot.template}, reason: slot.name);
        }
      }
      // 아이콘 슬롯 폭: →x 2칸(잉크는 가운데 1.5칸, #183), √▭✎ 3칸(잉크는 가운데 2.4칸, #217), ‖ 1칸,
      // 👁 2칸(잉크는 가운데 1.4칸 — ☀ 잉크 6도트쯤, #233)
      expect(LcdIndicatorSlot.store.columns, 2);
      expect(LcdIndicatorSlot.math.columns, 3);
      expect(LcdIndicatorSlot.disp.columns, 1);
      expect(LcdIndicatorSlot.keepScreenOn.columns, 2);
    });

    test('화면 켜짐 유지(👁)는 실물 ☀ 자리의 맨 끝 슬롯이고 반전 상자가 아니다 (#233)', () {
      const slot = LcdIndicatorSlot.keepScreenOn;
      expect(LcdIndicatorSlot.values.last, slot);
      expect(slot.dotCenter, _spriteCenter('☀'));
      // 실물 좌표 정합성: ☀는 맨 오른쪽 세그먼트이고 그 잉크(184~190도트)는 앞 ‖ 잉크와 떨어져 있다.
      // 앱 슬롯이 실제로 표시줄 안에 들고 이웃과 겹치지 않는지는 표시줄 배치 테스트(`lcd_display_test.dart`)가 본다.
      final (x, w, lo, hi) = _sprites['☀']!;
      final (_, _, _, dispInkEnd) = _sprites['‖']!;
      expect(lo, greaterThan(dispInkEnd));
      expect(hi, lessThanOrEqualTo(LcdIndicatorSlot.dotColumns));
      expect(x + w, LcdIndicatorSlot.dotColumns, reason: '오른쪽 끝 세그먼트');
      expect(slot.boxed, isFalse);
      // 대표 문자는 태양(☀)이 아니다 — 앱에는 태양광 상태가 없다.
      expect(slot.template, isNot('☀'));
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
    test('초기 상태는 Deg·Norm·MathI/MathO로 D와 √◻만 켜진다 (화면 켜짐 유지는 꺼짐)', () {
      expect(LcdStatus.initial.activeIndicators, ['√◻', 'D']);
      expect(LcdStatus.initial.keepScreenOn, isFalse);
    });

    test('화면 켜짐 유지는 자기 자리(👁) 하나만 켜고 맨 끝에 놓인다 (#233)', () {
      const s = LcdStatus(keepScreenOn: true, disp: true);
      expect(s.indicatorFor(LcdIndicatorSlot.keepScreenOn), '👁');
      expect(s.activeIndicators, ['√◻', 'D', '‖', '👁']);
      expect(
        const LcdStatus().indicatorFor(LcdIndicatorSlot.keepScreenOn),
        isNull,
      );
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
        base.copyWith(keepScreenOn: true),
      ];
      for (final v in variants) {
        expect(v, isNot(base), reason: '$v');
      }
    });
  });
}
