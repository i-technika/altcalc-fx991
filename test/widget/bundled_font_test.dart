import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/core/theme/font_licenses.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';

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
      test('$name: 숫자·연산·지수·위첨자 글자는 모두 한 칸(0.6em)이다', () {
        for (final ch in '0123456789.−+×÷E⁰¹²³⁴⁵⁶⁷⁸⁹⁻■□◄►▲▼'.split('')) {
          expect(
            _emWidth(ch, style),
            moreOrLessEquals(cell, epsilon: 0.005),
            reason: ch,
          );
        }
      });
    }

    test('가장 긴 결과는 지수를 2/3 크기(자간 포함)로 그리면 17칸에 들어가고, 유니코드 위첨자로 그리면 넘친다', () {
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
      expect(scaled, lessThanOrEqualTo(columns + 0.01));

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
      expect(odd.keys.toSet(), {'⇔', '∑', '∛', '∫'});
      expect(odd['⇔'], moreOrLessEquals(2 * cell, epsilon: 0.005));
    });

    test('가장 넓은 메인 라벨은 SHIFT·ALPHA(5칸)이고 log■□도 5칸을 넘지 않는다', () {
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

    // 실제 글꼴에서 라벨이 FittedBox로 따로 줄지 않는지 본다 (#11 메모: 하한에 걸리는 화면 크기 확인).
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(412, 915),
      Size(600, 960),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        // 배율 1.0에서는 모든 라벨이 통일 크기 그대로 그려진다. 배율을 키우면 통일 크기가 하한
        // (keypadUniformFontMinRatio)에 걸릴 수 있고, 그때는 가장 긴 라벨만 FittedBox로 조금 준다.
        // 실측(#16): 412×915 배율 1.3 이상에서 각인 띠가 하한에 걸려 `a b/c⇔d/c`가 약 0.4% 준다.
        final minRatio = scale == 1.0 ? 1.0 : 0.95;
        testWidgets(
          '${size.width}×${size.height} 배율 $scale: 라벨이 FittedBox로 ${scale == 1.0 ? '줄지 않는다' : '5% 넘게 줄지 않는다'}',
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
            final shrunk = <String>[];
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
                if (rendered < natural * minRatio - 0.01) {
                  shrunk.add(
                    '${def.id.name} "$label" ${(rendered / natural).toStringAsFixed(5)}',
                  );
                }
              }
            }
            expect(shrunk, isEmpty);
          },
        );
      }
    }
  });

  test('번들 글꼴 라이선스(OFL)가 LicenseRegistry에 등록된다', () async {
    addTearDown(LicenseRegistry.reset);
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    for (final family in bundledFontLicenseAssets.keys) {
      final entry = entries.singleWhere((e) => e.packages.contains(family));
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('SIL Open Font License, Version 1.1'));
    }
  });
}
