import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';
import '../support/lcd_glyphs.dart';

/// 실제 번들 글꼴로 [text]를 [style]로 그린 폭 (글자 크기 1dp당, 자간 제외).
double _emWidth(String text, TextStyle style) {
  const probe = 100.0;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: style.copyWith(fontSize: probe, letterSpacing: 0),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width / probe;
  painter.dispose();
  return width;
}

/// 실제 번들 글꼴로 [span]을 그린 폭 (dp)
double _spanWidth(InlineSpan span) {
  final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
    ..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> families;
  setUpAll(() async => families = await loadBundledFonts());

  const cell = CalcTheme.lcdLineCharWidthRatio;

  test('FontManifest에 테마의 기본·대체 글꼴 패밀리가 있다', () {
    expect(families, contains(CalcTheme.monoFontFamily));
    expect(families, containsAll(CalcTheme.monoFontFallback));
  });

  group('LCD 줄 칸 폭 실측 (lcdLineCharWidthRatio)', () {
    for (final (name, style) in [
      ('입력 줄', CalcTheme.lcdInputStyle),
      ('결과 줄', CalcTheme.lcdResultStyle),
    ]) {
      test('$name: LCD 줄 글자(lcdLineGlyphs)는 모두 한 칸(0.6em)이다', () {
        // 두 칸 폭 글자(▶·℃·⇔ 등)가 LCD 글자 목록에 들어오면 여기서 걸린다.
        for (final ch in lcdLineGlyphs.split('')) {
          expect(
            _emWidth(ch, style),
            moreOrLessEquals(cell, epsilon: 0.005),
            reason: ch,
          );
        }
      });
    }

    test('상태 표시줄 글자는 모두 한 칸(0.6em)이다 — 슬롯 폭은 글자 수 × 고정 비율로 잡는다 (#44)', () {
      final glyphs = {
        // 아이콘 슬롯(#57)은 글자로 그리지 않는다.
        for (final slot in LcdIndicatorSlot.values)
          if (slot.icon == null) ...slot.template.split(''),
        for (final c in ComplexResultIndicator.values)
          ...(c.indicator ?? '').split(''),
        for (final unit in AngleUnit.values) ...unit.indicator.split(''),
        for (final f in NumberDisplayFormat.values)
          ...(f.indicator ?? '').split(''),
      };
      for (final ch in glyphs) {
        expect(
          _emWidth(ch, CalcTheme.lcdStatusStyle),
          moreOrLessEquals(cell, epsilon: 0.005),
          reason: ch,
        );
      }
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets(
        '상태 표시 슬롯은 글자 크기와 무관하게 표시 문자를 축소 없이 담는다 (글자 배율 $scale, #44 리뷰 R1)',
        (tester) async {
          const all = LcdStatus(
            shift: true,
            alpha: true,
            memory: true,
            store: true,
            numberFormat: NumberDisplayFormat.fix,
            engineering: true,
            complex: ComplexResultIndicator.polar,
            historyUp: true,
            historyDown: true,
            disp: true,
          );
          for (final fontSize in [6.0, 8.0, 10.0, 14.0]) {
            await tester.pumpWidget(
              MaterialApp(
                home: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 2000,
                    child: LcdStatusBar(
                      status: all,
                      style: CalcTheme.lcdStatusStyle.copyWith(
                        fontSize: fontSize,
                      ),
                      textScaler: TextScaler.linear(scale),
                    ),
                  ),
                ),
              ),
            );
            for (final slot in LcdIndicatorSlot.values) {
              if (slot.icon != null) continue; // 아이콘은 슬롯 크기에 맞춰 그린다
              final slotBox = find.byKey(ValueKey(slot));
              final text = find.descendant(
                of: slotBox,
                matching: find.byType(Text),
              );
              expect(
                tester.getSize(text).width,
                lessThanOrEqualTo(tester.getSize(slotBox).width + 0.01),
                reason: '${slot.name} @ $fontSize',
              );
            }
          }
        },
      );
    }

    test('가장 긴 결과는 지수를 lcdExponentMaxScale 크기(자간 포함)로 그리면 여유를 두고 17칸에 들어가고, 유니코드 위첨자로 그리면 넘친다', () {
      const mantissa = '−1.234567891×10';
      const f = 20.0;
      final ls = CalcTheme.lcdResultStyle.letterSpacing!;
      final base = CalcTheme.lcdResultStyle.copyWith(fontSize: f);
      final columns = CalcTheme.lcdLineColumns * (f * cell + ls);

      final scaled = _spanWidth(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: mantissa),
            TextSpan(
              text: '−99',
              style: base.copyWith(
                fontSize: f * CalcTheme.lcdExponentMaxScale,
                letterSpacing:
                    base.letterSpacing! * CalcTheme.lcdExponentMaxScale,
              ),
            ),
          ],
        ),
      );
      // 여유: 위첨자 올림 오프셋·픽셀 맞춤을 흡수할 만큼(0.1칸 이상) 남는다.
      expect(scaled, lessThan(columns - 0.1 * (f * cell + ls)));

      final unicode = _spanWidth(TextSpan(text: '$mantissa⁻⁹⁹', style: base));
      expect(unicode, greaterThan(columns), reason: '18칸 — 지수는 작게 그려야 한다');
    });

    for (final size in const [
      Size(296, 130), // 320dp 폭 폰
      Size(336, 150), // 360dp 폭 폰
      Size(388, 180), // 412dp 폭 폰
      Size(560, 240), // 태블릿 세로
    ]) {
      test(
        'LCD ${size.width}×${size.height}: 가장 긴 결과가 ◄/► 자리를 빼고 잘림 없이 들어간다',
        () {
          final f = LcdFontSizes.forSize(size, TextScaler.noScaling).result;
          const chrome =
              2 * (CalcTheme.lcdFrameWidth + CalcTheme.lcdInnerPadding);
          final arrow =
              f *
              CalcTheme.lcdScrollArrowFontRatio *
              CalcTheme.lcdScrollArrowWidthRatio;
          final available = size.width - chrome - 2 * arrow;
          final base = CalcTheme.lcdResultStyle.copyWith(fontSize: f);
          final width = _spanWidth(
            TextSpan(
              style: base,
              children: [
                const TextSpan(text: '−1.234567891×10'),
                TextSpan(
                  text: '−99',
                  style: base.copyWith(
                    fontSize: f * CalcTheme.lcdExponentMaxScale,
                    letterSpacing:
                        base.letterSpacing! * CalcTheme.lcdExponentMaxScale,
                  ),
                ),
              ],
            ),
          );
          expect(width, lessThanOrEqualTo(available + 0.01));
        },
      );
    }
  });

  test('통계 표기용 결합 문자(x̄·x̂)는 폭이 0이라 한 칸에 겹치고, 위첨자 문자 ᵍ는 한 칸이다', () {
    const style = CalcTheme.lcdResultStyle;
    expect(_emWidth('x\u0304', style), moreOrLessEquals(cell, epsilon: 0.005));
    expect(_emWidth('x\u0302', style), moreOrLessEquals(cell, epsilon: 0.005));
    expect(_emWidth('ᵍ', style), moreOrLessEquals(cell, epsilon: 0.005));
  });

  group('키 라벨 폭 실측', () {
    test('라벨 글자는 두 칸 폭 ⇔와 대체 글꼴 기호(∑·∛·∫)를 빼면 모두 한 칸이다', () {
      // 글자 폭이 글자 수에 비례한다는 가정(각인 배분)이 실제 글꼴에서도 성립하는지 본다.
      const style = CalcTheme.keyShiftLabelStyle;
      final odd = <String, double>{};
      for (final key in allKeys) {
        for (final label in [key.mainLabel, key.shiftLabel, key.alphaLabel]) {
          for (final ch in (label ?? '').split('')) {
            final w = _emWidth(ch, style);
            if ((w - cell).abs() > 0.005) odd[ch] = w;
          }
        }
      }
      // ∑·∛·∫는 대체 글꼴 Noto Sans Math의 진행폭(852·679·836/1000)이어야 한다.
      // 테스트 글꼴(1em)이나 플랫폼 글꼴로 떨어지면 값이 달라진다.
      expect(odd.keys.toSet(), {'⇔', '∑', '∛', '∫'});
      expect(odd['⇔'], moreOrLessEquals(2 * cell, epsilon: 0.005));
      expect(odd['∑'], moreOrLessEquals(0.852, epsilon: 0.005));
      expect(odd['∛'], moreOrLessEquals(0.679, epsilon: 0.005));
      expect(odd['∫'], moreOrLessEquals(0.836, epsilon: 0.005));
    });

    test('가장 넓은 메인 라벨은 SHIFT·ALPHA(5칸)이고 log◼◻도 5칸을 넘지 않는다', () {
      const style = CalcTheme.keyMainLabelStyle;
      final shift = _emWidth('SHIFT', style);
      expect(shift, moreOrLessEquals(5 * cell, epsilon: 0.01));
      for (final key in allKeys) {
        expect(
          _emWidth(key.mainLabel, style),
          lessThanOrEqualTo(shift + 0.001),
          reason: key.mainLabel,
        );
      }
      expect(
        _emWidth(keyDefOf(CalcKeyId.logBase).mainLabel, style),
        moreOrLessEquals(5 * cell, epsilon: 0.01),
      );
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('배율 $scale: 대체 글꼴 글자(∑·∛·∫)가 섞인 라벨도 줄 높이가 다른 라벨과 같다', (
        tester,
      ) async {
        // Noto Sans Math의 descent(423)는 Noto Sans Mono(293)보다 깊어, strut 없이는 그 라벨만
        // 줄이 높아진다(20 → 21dp). 키 라벨은 기본 글꼴 기준 strut로 줄 높이를 고정한다.
        // strut 글자 크기도 textScaler를 따르므로 배율을 바꿔도 같아야 한다.
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Center(
                child: SizedBox(
                  width: 390,
                  height: 520,
                  child: CalcKeypad(enableHaptics: false),
                ),
              ),
            ),
          ),
        );
        double heightOf(String label) =>
            tester.getSize(find.text(label)).height;
        expect(heightOf('∫◻◻◼'), heightOf('OPTN'));
        expect(heightOf('∛◼'), heightOf('x³'));
        expect(heightOf('∑◻◻◼'), heightOf('x³'));
      });
    }

    test('글자 배율은 keyMaxTextScaleFactor(1.3)에서 멈춘다 — 2.0도 1.3과 같은 크기', () {
      const size = Size(390, 520);
      final at13 = KeypadMetrics.compute(size, const TextScaler.linear(1.3));
      final at20 = KeypadMetrics.compute(size, const TextScaler.linear(2.0));
      expect(at20.mainLabelFontSize, at13.mainLabelFontSize);
      expect(at20.legendFontSize, at13.legendFontSize);
    });

    // 실제 글꼴에서 라벨이 FittedBox로 따로 줄지 않는지 본다 (#11 메모: 하한에 걸리는 화면 크기 확인).
    // 배율 1.0에서는 모든 라벨이 통일 크기 그대로 그려진다. 배율을 키우면 통일 크기가 하한
    // (keypadUniformFontMinRatio)에 걸릴 수 있고, 그때는 가장 긴 라벨만 FittedBox로 조금 준다.
    // 실측(#16): 412×915 배율 1.3에서만 각인 띠가 하한에 걸려 `a b/c⇔d/c`가 약 0.4% 준다.
    // 이 표는 레이아웃 상수(각인 띠 비율·하한 비율·간격 등)에 대한 실측 스냅샷이다. 상수를 바꾸면
    // 다시 실측해 갱신한다. 허용 항목도 1% 넘게 줄면 실패한다.
    final allowedShrink = {
      (412.0, 915.0, 1.3): {'sdToggle "a b/c⇔d/c"'},
    };
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(412, 915),
      Size(600, 960),
    ]) {
      for (final scale in [1.0, 1.3]) {
        final allowed =
            allowedShrink[(size.width, size.height, scale)] ?? const {};
        testWidgets(
          '${size.width}×${size.height} 배율 $scale: 라벨이 FittedBox로 줄지 않는다${allowed.isEmpty ? '' : ' (허용: $allowed, 1% 이내)'}',
          (tester) async {
            tester.view.physicalSize = size * tester.view.devicePixelRatio;
            addTearDown(tester.view.resetPhysicalSize);
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: const CalculatorScreen(),
                  ),
                ),
              ),
            );
            final shrunk = <String>{};
            for (final b in tester.widgetList<CalcKeyButton>(
              find.byType(CalcKeyButton),
            )) {
              final def = b.keyDef;
              if (def.category == KeyCategory.cursor) continue;
              for (final label in [
                def.mainLabel,
                def.shiftLabel,
                def.alphaLabel,
              ]) {
                if (label == null) continue;
                final text = find.descendant(
                  of: find.byWidget(b),
                  matching: find.text(label),
                );
                final rendered = tester.getRect(text).height;
                final natural = tester.getSize(text).height;
                if (rendered < natural - 0.01) {
                  final id = '${def.id.name} "$label"';
                  shrunk.add(id);
                  expect(rendered / natural, greaterThan(0.99), reason: id);
                }
              }
            }
            expect(shrunk, allowed);
          },
        );
      }
    }
  });
}
