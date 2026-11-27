import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/key_legend_view.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/text_fit.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';
import '../support/key_legends.dart';
import '../support/korean_locale.dart';
import '../support/ttf_cmap.dart';

/// 50키의 2차원 각인과 그 스타일 (메인·SHIFT·ALPHA)
List<(CalcKeyDef, KeyLegend, TextStyle)> _twoDimensional() => [
  for (final k in allKeys)
    for (final (legend, style) in [
      (k.mainLegend, CalcTheme.keyMainLabelStyle),
      (k.shiftLegend, CalcTheme.keyShiftLabelStyle),
      (k.alphaLegend, CalcTheme.keyAlphaLabelStyle),
    ])
      if (legend != null && !legend.isPlain) (k, legend, style),
];

Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Material(
      color: CalcTheme.bodyBackground,
      child: Center(child: child),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => loadBundledFonts());

  group('잉크 범위 표 (KeyLegendView.glyphInk)', () {
    test('2차원 각인의 모든 글자가 표에 있다 (변수 이탤릭 글자는 이탤릭 표에)', () {
      final missing = {
        for (final (_, legend, _) in _twoDimensional())
          for (final piece in legend.texts)
            for (final (i, ch) in piece.text.split('').indexed)
              if (!(CalcTheme.isKeyVariableLetter(piece.text, i)
                      ? KeyLegendView.variableGlyphInk
                      : KeyLegendView.glyphInk)
                  .containsKey(ch))
                ch,
      };
      expect(missing, isEmpty, reason: '표에 없으면 한 줄 상자를 잉크로 봐 배치가 성겨진다');
    });

    test(
      '표의 값은 그 글자를 그리는 번들 글꼴의 glyf 잉크 범위와 0.012em 안에서 같다 (각인에 쓰는 굵기 모두, #156)',
      () async {
        // 메인 각인은 SemiBold, SHIFT·ALPHA 각인은 Medium이다. 글자는 각인 글꼴 Saira에서, Saira에 없는 기호는 대체 글꼴
        // Noto Sans Mono에서, ∫·∑는 Noto Sans Math에서 찾는다(CalcTheme.keyFontFallback 순서).
        final key = {
          'SemiBold': await rootBundle.load('assets/fonts/Saira-SemiBold.ttf'),
          'Medium': await rootBundle.load('assets/fonts/Saira-Medium.ttf'),
        };
        final mono = {
          'SemiBold': await rootBundle.load(
            'assets/fonts/NotoSansMono-SemiBold.ttf',
          ),
          'Medium': await rootBundle.load(
            'assets/fonts/NotoSansMono-Medium.ttf',
          ),
        };
        final math = await rootBundle.load(
          'assets/fonts/NotoSansMath-Regular.ttf',
        );
        expect(
          {
            CalcTheme.keyMainLabelStyle.fontWeight,
            CalcTheme.keyShiftLabelStyle.fontWeight,
            CalcTheme.keyAlphaLabelStyle.fontWeight,
          },
          {FontWeight.w600, FontWeight.w500},
          reason: '굵기가 바뀌면 위 글꼴 목록도 바꾼다',
        );
        void check(
          String ch,
          (double, double) ink,
          String name,
          ByteData font,
        ) {
          final bounds = readGlyphYBounds(font, ch.runes.single)!;
          expect(
            ink.$1,
            moreOrLessEquals(bounds.yMin, epsilon: 0.012),
            reason: '$ch $name yMin',
          );
          expect(
            ink.$2,
            moreOrLessEquals(bounds.yMax, epsilon: 0.012),
            reason: '$ch $name yMax',
          );
        }

        for (final MapEntry(key: ch, value: ink)
            in KeyLegendView.glyphInk.entries) {
          final code = ch.runes.single;
          // `⇔`는 일부러 수학 글꼴로 그린다 (CalcTheme.isKeyMathSymbol, #156 R2)
          final sources = CalcTheme.isKeyMathSymbol(ch)
              ? {'Math': math}
              : readCmap(key['Medium']!).containsKey(code)
              ? key
              : readCmap(mono['Medium']!).containsKey(code)
              ? mono
              : {'Math': math};
          for (final MapEntry(key: weight, value: data) in sources.entries) {
            check(ch, ink, weight, data);
          }
        }
        // 변수 이탤릭 글자는 Noto Serif Bold Italic 하나로 그린다(굵기와 무관).
        final italic = await rootBundle.load(
          'assets/fonts/NotoSerif-BoldItalic.ttf',
        );
        for (final MapEntry(key: ch, value: ink)
            in KeyLegendView.variableGlyphInk.entries) {
          check(ch, ink, 'BoldItalic', italic);
        }
      },
    );
  });

  group('크기·기준선', () {
    testWidgets('글자만 있는 각인의 emSize는 같은 스타일 Text(strut 고정)의 크기와 같다', (
      tester,
    ) async {
      const style = CalcTheme.keyShiftLabelStyle;
      // `log`는 내림 글자 g가 한 줄 아래로 나가지만 Text처럼 한 줄 상자만 쓴다. 키 버튼의 Text와 같이 글자 조각(변수 이탤릭·
      // 수학 기호 `⇔`, #156)과 각인 strut로 그린다.
      for (final text in ['SOLVE', 'A', '⇔', 'log', 'x!', 'S⇔D']) {
        final sized = style.copyWith(fontSize: 100);
        await tester.pumpWidget(
          _host(
            Text.rich(
              keyLabelSpan(text, sized),
              strutStyle: keyLabelStrut(sized),
            ),
          ),
        );
        final size = KeyLegendView.emSize(LegendText(text), style) * 100;
        expect(
          size.width,
          moreOrLessEquals(tester.getSize(find.text(text)).width, epsilon: 0.5),
        );
        expect(
          size.height,
          moreOrLessEquals(tester.getSize(find.text(text)).height, epsilon: 1),
        );
      }
    });

    test('2차원 각인은 한 줄보다 크게 높아지지 않는다 — 가장 높아도 1.15em, 한 줄 아래로는 0.08em 미만', () {
      // 각인 띠는 글자 크기의 1/0.8 = 1.25em 높이다(keyLegendFontRatio). 첨자·분수가 한 줄을 크게 넘으면
      // 배율을 키웠을 때 통일 글자 크기 계산이 모든 각인을 그만큼 줄이므로, 넘는 폭을 상한으로 묶어 둔다.
      // 한 줄 아래로 넘는 만큼 기준선이 올라가므로(각인 띠는 아래 정렬) 이웃 각인과의 기준선 차이도 묶는다.
      for (final (k, legend, style) in _twoDimensional()) {
        final em = KeyLegendView.emMetrics(legend, style);
        final line = KeyLegendView.emMetrics(const LegendText('x'), style);
        final reason = '${k.id.name} ${legend.plainText}';
        expect(em.size.height, lessThanOrEqualTo(1.15), reason: reason);
        expect(em.baseline, greaterThanOrEqualTo(line.baseline - 1e-9));
        final below =
            (em.size.height - em.baseline) - (line.size.height - line.baseline);
        expect(below, inInclusiveRange(-1e-9, 0.08), reason: reason);
      }
    });

    test('높이 기준 글자 크기에서 2차원 각인이 실제로 띠·키캡에 들어가고, 실제로 넘칠 때만 줄인다', () {
      // KeypadMetrics의 높이 기준 판정(KeypadMetrics.fitToHeight)을 각인 띠·키캡 높이 격자와 글자 배율에서 돌리고,
      // 고른 크기에서 실제로 배치한 크기(KeyLegendView.layoutSize — 작은 글자의 줄 상자 반올림 포함)로 확인한다.
      // - 고른 크기에서 모든 2차원 각인의 실제 높이 ≤ 띠(키캡 안쪽) 높이 — FittedBox가 높이 때문에 줄이지 않는다(#155 R2).
      // - 잉크 높이를 넣어 #155 이전(한 줄 높이만)보다 작아졌다면, 이전 크기에서는 어떤 각인이 실제로 넘친다
      //   — 높이 측정이 불필요하게 다른 키 글자를 줄이지 않는다(#155 R1).
      for (final (style, ratio, maxFont, legends) in [
        (
          CalcTheme.keyShiftLabelStyle,
          CalcTheme.keyLegendFontRatio,
          CalcTheme.keyLegendMaxFontSize,
          [
            for (final (k, l, _) in _twoDimensional())
              if (!identical(l, k.mainLegend)) l,
          ],
        ),
        (
          CalcTheme.keyMainLabelStyle,
          CalcTheme.keyMainLabelFontRatio,
          CalcTheme.keyMainLabelMaxFontSize,
          [
            for (final (k, l, _) in _twoDimensional())
              if (identical(l, k.mainLegend)) l,
          ],
        ),
      ]) {
        final tall = [
          for (final l in legends) KeyLegendView.emMetrics(l, style),
        ];
        final isMain = identical(style, CalcTheme.keyMainLabelStyle);
        double tallestAt(double scaledFontSize) => legends
            .map(
              (l) => KeyLegendView.layoutSize(
                l,
                style.copyWith(fontSize: scaledFontSize),
              ).height,
            )
            .reduce(math.max);
        for (final scale in [1.0, 1.1, 1.2, 1.3]) {
          final scaler = TextScaler.linear(scale);
          for (
            var box = isMain ? 8.0 : 4.0;
            box <= 40;
            box += isMain ? 0.1 : 0.05
          ) {
            // 각인 띠는 띠 높이 그대로, 키캡은 눌림 여유·테두리를 뺀 안쪽 높이에 맞춘다.
            final max = isMain
                ? box -
                      math.min(CalcTheme.keyPressedOffset, box) -
                      2 * CalcTheme.keyBorderWidth
                : box;
            final start = math.max(
              minFittedFontSize,
              math.min(box * ratio, maxFont),
            );
            final withInk = KeypadMetrics.fitToHeight(
              start,
              maxHeight: max,
              textScaler: scaler,
              style: style,
              tallLegends: tall,
            );
            final lineOnly = fitFontSizeToHeight(
              start,
              maxHeight: max,
              textScaler: scaler,
              heightFactor: style.height ?? 1.0,
            );
            final reason = '${isMain ? '키캡' : '각인 띠'} $box, 배율 $scale';
            expect(
              tallestAt(scaler.scale(withInk)),
              lessThanOrEqualTo(max + 1e-6),
              reason: reason,
            );
            if (withInk < lineOnly - 1e-9) {
              expect(
                tallestAt(scaler.scale(lineOnly)),
                greaterThan(max),
                reason: '$reason: 넘치지 않는데 줄였다',
              );
            }
          }
        }
      }
    });

    testWidgets('기준선은 같은 글자 크기의 Text 기준선과 같고(아래로 넘치지 않는 각인), 글자 배율을 따른다', (
      tester,
    ) async {
      final legend = keyDefOf(CalcKeyId.square).mainLegend; // x²
      const style = TextStyle(
        fontFamily: CalcTheme.monoFontFamily,
        fontFamilyFallback: CalcTheme.monoFontFallback,
        fontSize: 20,
        height: 1,
        letterSpacing: 0,
      );
      for (final scale in [1.0, 1.3]) {
        await tester.pumpWidget(
          _host(
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'x',
                  style: style,
                  textScaler: TextScaler.linear(scale),
                  strutStyle: StrutStyle.fromTextStyle(
                    style,
                    forceStrutHeight: true,
                  ),
                ),
                KeyLegendView(
                  legend: legend,
                  style: style,
                  textScaler: TextScaler.linear(scale),
                ),
              ],
            ),
          ),
        );
        final view = tester.renderObject<RenderBox>(find.byType(KeyLegendView));
        final text = tester.renderObject<RenderBox>(find.text('x'));
        // 기준선 질의는 배치 밖에서 막혀 있다 — 프레임워크 테스트처럼 고유 크기 검사 중으로 표시하고 읽는다.
        double baselineOf(RenderBox box) {
          RenderObject.debugCheckingIntrinsics = true;
          try {
            return box.localToGlobal(Offset.zero).dy +
                box.getDistanceToBaseline(TextBaseline.alphabetic)!;
          } finally {
            RenderObject.debugCheckingIntrinsics = false;
          }
        }

        final viewBaseline = baselineOf(view);
        final textBaseline = baselineOf(text);
        expect(viewBaseline, moreOrLessEquals(textBaseline, epsilon: 0.01));
        expect(
          view.size.width,
          moreOrLessEquals(
            KeyLegendView.emSize(legend, style).width * 20 * scale,
            epsilon: 0.5,
          ),
          reason: '배율 $scale',
        );
      }
    });
  });

  group('그리기', () {
    testWidgets(
      '분수는 분자·가로줄·분모, 근호는 선과 피개법수, 첨자는 글자 둘로 그린다 (칸은 직접 그린다 — #186)',
      (tester) async {
        Future<RenderObject> draw(KeyLegend legend) async {
          await tester.pumpWidget(
            _host(
              KeyLegendView(
                legend: legend,
                style: CalcTheme.keyMainLabelStyle.copyWith(
                  fontSize: 30,
                  color: const Color(0xFF123456),
                ),
              ),
            ),
          );
          return tester.renderObject(find.byType(KeyLegendView));
        }

        expect(
          await draw(keyDefOf(CalcKeyId.fraction).mainLegend),
          paints
            // 채운 분자 칸 · 가로줄 · 빈 분모 칸(테두리)
            ..rect(color: const Color(0xFF123456))
            ..rect(color: const Color(0xFF123456))
            ..path(color: const Color(0xFF123456), style: PaintingStyle.stroke),
        );
        expect(
          await draw(keyDefOf(CalcKeyId.sqrt).mainLegend),
          paints
            ..path(color: const Color(0xFF123456), style: PaintingStyle.stroke)
            ..rect(color: const Color(0xFF123456)),
        );
        expect(
          await draw(keyDefOf(CalcKeyId.square).mainLegend),
          paints
            ..paragraph()
            ..paragraph(),
        );
      },
    );

    testWidgets('색만 바뀌면 다시 배치하지 않고 다시 그린다 (눌림 애니메이션)', (tester) async {
      final legend = keyDefOf(CalcKeyId.fraction).mainLegend;
      Widget view(Color color) => _host(
        KeyLegendView(
          legend: legend,
          style: CalcTheme.keyMainLabelStyle.copyWith(
            fontSize: 30,
            color: color,
          ),
        ),
      );
      await tester.pumpWidget(view(const Color(0xFF000000)));
      final render = tester.renderObject<RenderKeyLegend>(
        find.byType(KeyLegendView),
      );
      final built = render.debugLayoutBuildCount;
      await tester.pumpWidget(view(const Color(0xFFFFFFFF)));
      expect(
        render.debugLayoutBuildCount,
        built,
        reason: '색만 바뀌면 배치를 다시 만들지 않는다',
      );
      expect(
        render,
        paints
          ..rect(color: const Color(0xFFFFFFFF))
          ..rect(color: const Color(0xFFFFFFFF))
          ..path(color: const Color(0xFFFFFFFF), style: PaintingStyle.stroke),
      );
      // 글자 크기가 바뀌면 다시 배치한다.
      await tester.pumpWidget(
        _host(
          KeyLegendView(
            legend: legend,
            style: CalcTheme.keyMainLabelStyle.copyWith(fontSize: 40),
          ),
        ),
      );
      expect(render.debugLayoutBuildCount, built + 1);

      // 시스템 글꼴이 바뀌면(글꼴 지연 로드 등) Text처럼 다시 배치한다.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.system.name,
        SystemChannels.system.codec.encodeMessage(<String, Object?>{
          'type': 'fontsChange',
        }),
        (_) {},
      );
      await tester.pump();
      expect(render.debugLayoutBuildCount, built + 2);
    });
  });

  testWidgets('색만 바뀌어도 글자 조각까지 새 색으로 그린다 (배치 재사용, 그린 픽셀 검사)', (tester) async {
    // 같은 위젯 자리에서 색만 바꾼다 — 렌더 객체·배치를 재사용하므로 글자 조각의 span 색을 바꿔야 새 색이 된다.
    Future<(int, int)> countColors(Color fill) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(
          RepaintBoundary(
            key: key,
            child: KeyLegendView(
              legend: keyDefOf(CalcKeyId.logBase).mainLegend,
              style: CalcTheme.keyMainLabelStyle.copyWith(
                fontSize: 60,
                color: fill,
              ),
            ),
          ),
        ),
      );
      return (await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = (await image.toByteData())!;
        var red = 0;
        var green = 0;
        for (var p = 0; p < data.lengthInBytes; p += 4) {
          final (r, g, b, a) = (
            data.getUint8(p),
            data.getUint8(p + 1),
            data.getUint8(p + 2),
            data.getUint8(p + 3),
          );
          if (a < 128 || b > 80) continue;
          if (r > 180 && g < 80) red++;
          if (g > 180 && r < 80) green++;
        }
        image.dispose();
        return (red, green);
      }))!;
    }

    final (redBefore, _) = await countColors(const Color(0xFFFF0000));
    expect(redBefore, greaterThan(0));
    final (redAfter, greenAfter) = await countColors(const Color(0xFF00FF00));
    expect(redAfter, 0, reason: '글자 조각이 옛 색으로 남았다');
    expect(greenAfter, greaterThan(redBefore ~/ 2));
  });

  group('∑·log 각인과 칸 모양 (#169 Quick Start Guide 1쪽 제품 사진·#186 근접 사진 대조)', () {
    test('∑ 각인은 끝 칸을 위아래에 쌓는 LegendLimits(직접 그리는 칸)이고, ∫ 각인은 오른쪽 첨자다', () {
      final sum = keyDefOf(CalcKeyId.variableX).shiftLegend! as LegendRow;
      final limits = sum.children.first as LegendLimits;
      expect(limits.over, isA<LegendBox>());
      expect(limits.under, isA<LegendBox>());
      expect(sum.children.last, isA<LegendBox>());
      expect(sum.plainText, '∑◻◻◼');
      final integral = keyDefOf(CalcKeyId.integral).mainLegend as LegendRow;
      expect(integral.children.first, isA<LegendScript>());
      expect(integral.plainText, '∫◻◻◼');
    });

    test('쌓은 ∑ 각인은 가장 높은 각인(d/dx◼)보다 높지 않다 — 키패드 통일 각인 크기를 줄이지 않는다', () {
      const style = CalcTheme.keyShiftLabelStyle;
      final sum = KeyLegendView.emMetrics(
        keyDefOf(CalcKeyId.variableX).shiftLegend!,
        style,
      );
      final derivative = KeyLegendView.emMetrics(
        keyDefOf(CalcKeyId.integral).shiftLegend!,
        style,
      );
      expect(
        derivative.size.height,
        greaterThan(1.0),
      ); // d/dx◼가 한 줄을 넘는 가장 높은 각인
      expect(sum.size.height, lessThanOrEqualTo(derivative.size.height));
      expect(sum.inkTop, lessThanOrEqualTo(derivative.inkTop + 1e-9));
      expect(sum.inkBottom, greaterThanOrEqualTo(derivative.inkBottom - 1e-9));
    });

    test('분수 키 각인 높이는 사진(약 1.13em)이고, 굵게 한 각인(#206)이 메인·SHIFT 각인 높이 맞춤의 기준 각인을 넘지 않는다', () {
      // 사진의 분수 키 각인 높이 37.9px ÷ 33.5px ≈ 1.13em
      final fraction = KeyLegendView.emMetrics(
        keyDefOf(CalcKeyId.fraction).mainLegend,
        CalcTheme.keyMainLabelStyle,
      );
      expect(
        fraction.inkTop - fraction.inkBottom,
        moreOrLessEquals(37.9 / 33.5, epsilon: 0.02),
      );
      // 키패드 통일 글자 크기의 높이 맞춤(KeypadMetrics)은 가장 높은 각인이 정한다 — 메인은 ∫◻◻◼, SHIFT·ALPHA는
      // d/dx◼다. 분수 키(메인)·∛◼(SHIFT, 지수가 굵은 근호 머리 위로 올라감)를 굵게 해도 어느 글자 크기에서든(작은 글자의
      // 줄 상자 반올림 포함) 실제 배치 높이가 그 기준을 넘지 않아야 글자 크기가 #206 전과 같다(#206 R1).
      final integral = keyDefOf(CalcKeyId.integral);
      for (final (isMain, reference) in [
        (true, integral.mainLegend),
        (false, integral.shiftLegend!),
      ]) {
        // 메인·SHIFT·ALPHA는 각인을 그리는 스타일로 나눈다(같은 const 각인이 두 자리에 쓰여도 섞이지 않게, #206 R2).
        // SHIFT·ALPHA 스타일은 글꼴·굵기가 같아 기준 높이는 SHIFT 스타일로 잰다.
        final legends = [
          for (final (_, legend, style) in _twoDimensional())
            if (identical(style, CalcTheme.keyMainLabelStyle) == isMain)
              (legend, style),
        ];
        final referenceStyle = isMain
            ? CalcTheme.keyMainLabelStyle
            : CalcTheme.keyShiftLabelStyle;
        expect(
          CalcTheme.keyAlphaLabelStyle.fontWeight,
          CalcTheme.keyShiftLabelStyle.fontWeight,
        );
        for (var f = 3.0; f <= 40; f += 0.1) {
          final limit = KeyLegendView.layoutSize(
            reference,
            referenceStyle.copyWith(fontSize: f),
          ).height;
          for (final (legend, style) in legends) {
            expect(
              KeyLegendView.layoutSize(
                legend,
                style.copyWith(fontSize: f),
              ).height,
              lessThanOrEqualTo(limit + 1e-9),
              reason: '${legend.plainText} 글자 $f',
            );
          }
        }
      }
    });

    /// [legend]를 글자 크기 [fontSize]·빨간색으로 그려 잉크 픽셀을 `(x, y)` 목록으로 돌려준다.
    Future<List<(int, int)>> inkPixels(
      WidgetTester tester,
      KeyLegend legend,
      double fontSize,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(
          RepaintBoundary(
            key: key,
            child: KeyLegendView(
              legend: legend,
              style: CalcTheme.keyShiftLabelStyle.copyWith(
                fontSize: fontSize,
                color: const Color(0xFFFF0000),
              ),
            ),
          ),
        ),
      );
      return (await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = (await image.toByteData())!;
        final ink = <(int, int)>[];
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final p = (y * image.width + x) * 4;
            if (data.getUint8(p + 3) > 128 &&
                data.getUint8(p) > 160 &&
                data.getUint8(p + 1) < 100) {
              ink.add((x, y));
            }
          }
        }
        image.dispose();
        return ink;
      }))!;
    }

    /// [xs]가 빈 칸으로 갈라진 연속 구간들 (정렬된 서로 다른 값)
    List<(int, int)> runsOf(Iterable<int> values) {
      final sorted = values.toSet().toList()..sort();
      final runs = <(int, int)>[];
      for (final v in sorted) {
        if (runs.isNotEmpty && runs.last.$2 == v - 1) {
          runs[runs.length - 1] = (runs.last.$1, v);
        } else {
          runs.add((v, v));
        }
      }
      return runs;
    }

    testWidgets(
      '그린 ∑ 각인: 납작한 빈 칸·∑·납작한 빈 칸이 세로로 쌓이고, 채운 칸은 ∑와 세로 가운데가 같다 (사진 비율)',
      (tester) async {
        final ink = await inkPixels(
          tester,
          keyDefOf(CalcKeyId.variableX).shiftLegend!,
          140,
        );
        // 가로로 왼쪽 덩어리(쌓은 ∑)와 오른쪽 덩어리(채운 본문 칸)로 갈린다.
        final columns = runsOf(ink.map((p) => p.$1));
        expect(columns, hasLength(2), reason: '$columns');
        final (stackLeft, stackRight) = columns.first;
        final (boxLeft, boxRight) = columns.last;
        final stack = ink.where((p) => p.$1 <= stackRight).toList();
        final body = ink.where((p) => p.$1 >= boxLeft).toList();
        // 쌓은 덩어리는 세로로 셋(위 칸·∑·아래 칸)으로 갈린다.
        final rows = runsOf(stack.map((p) => p.$2));
        expect(rows, hasLength(3), reason: '$rows');
        final [over, sigma, under] = rows;
        (int, int) widthOf((int, int) run) {
          final xs = stack
              .where((p) => p.$2 >= run.$1 && p.$2 <= run.$2)
              .map((p) => p.$1);
          return (xs.reduce(math.min), xs.reduce(math.max));
        }

        final sigmaHeight = sigma.$2 - sigma.$1 + 1;
        final (sigmaL, sigmaR) = widthOf(sigma);
        for (final limit in [over, under]) {
          // 사진: 끝 칸 9×4px · ∑ 7×7px — 칸은 ∑보다 넓고 높이는 ∑의 약 4/7이다.
          final (l, r) = widthOf(limit);
          expect(r - l, greaterThan(sigmaR - sigmaL), reason: '$limit');
          expect(
            sigmaHeight / (limit.$2 - limit.$1 + 1),
            inInclusiveRange(1.5, 2.1),
            reason: '$limit',
          );
          expect(
            (l + r) / 2,
            moreOrLessEquals((sigmaL + sigmaR) / 2, epsilon: 2),
          );
        }
        // 끝 칸은 빈 칸(가운데가 비었다), 본문 칸은 채운 칸(가운데가 칠해졌다).
        final inkSet = ink.toSet();
        for (final limit in [over, under]) {
          final (l, r) = widthOf(limit);
          final centre = ((l + r) ~/ 2, (limit.$1 + limit.$2) ~/ 2);
          expect(inkSet.contains(centre), isFalse, reason: '빈 끝 칸 $limit');
        }
        // 본문 칸: 사진 8×4px — 납작하고, 세로 가운데가 ∑ 가운데와 같다.
        final bodyRows = runsOf(body.map((p) => p.$2));
        expect(bodyRows, hasLength(1));
        final (bodyTop, bodyBottom) = bodyRows.single;
        expect(boxRight - boxLeft, greaterThan(bodyBottom - bodyTop));
        expect(
          inkSet.contains((
            (boxLeft + boxRight) ~/ 2,
            (bodyTop + bodyBottom) ~/ 2,
          )),
          isTrue,
          reason: '채운 본문 칸',
        );
        expect(
          (bodyTop + bodyBottom) / 2,
          moreOrLessEquals((sigma.$1 + sigma.$2) / 2, epsilon: 2),
        );
        expect(stackLeft, lessThan(boxLeft));
      },
    );

    testWidgets('그린 log 각인: 밑 칸 아래끝이 기준선(l의 아래끝)이고 g의 내림 획까지 내려가지 않는다 (사진)', (
      tester,
    ) async {
      final logBase =
          (keyDefOf(CalcKeyId.logBase).mainLegend as LegendRow).children.first;
      final ink = await inkPixels(tester, logBase, 140);
      final columns = runsOf(ink.map((p) => p.$1));
      // l · o · g · 밑 칸 — 맨 왼쪽(l)과 맨 오른쪽(밑 칸)의 아래끝을 비교한다.
      expect(columns.length, greaterThanOrEqualTo(3), reason: '$columns');
      int bottomOf((int, int) col) => ink
          .where((p) => p.$1 >= col.$1 && p.$1 <= col.$2)
          .map((p) => p.$2)
          .reduce(math.max);
      final lBottom = bottomOf(columns.first);
      final boxBottom = bottomOf(columns.last);
      final deepest = ink.map((p) => p.$2).reduce(math.max); // g의 내림 획
      expect(boxBottom, moreOrLessEquals(lBottom.toDouble(), epsilon: 2));
      expect(deepest - boxBottom, greaterThan(140 * 0.15));
    });

    // ── 칸 모양 (#186 — 실물 키패드 근접 사진, 사용자 결정 "모든 칸 사진 비율로") ──

    /// [ink]의 경계 상자 (left, top, right, bottom — 픽셀, 양 끝 포함)
    (int, int, int, int) boundsOf(Iterable<(int, int)> ink) => (
      ink.map((p) => p.$1).reduce(math.min),
      ink.map((p) => p.$2).reduce(math.min),
      ink.map((p) => p.$1).reduce(math.max),
      ink.map((p) => p.$2).reduce(math.max),
    );

    double aspectOf((int, int, int, int) b) =>
        (b.$3 - b.$1 + 1) / (b.$4 - b.$2 + 1);

    testWidgets('칸 하나만 그리면 잉크의 가로/세로 비가 자리별 사진 비다 (모든 모양)', (tester) async {
      for (final shape in LegendBoxShape.values) {
        for (final filled in [true, false]) {
          final ink = await inkPixels(
            tester,
            LegendBox(shape, filled: filled),
            200,
          );
          expect(
            aspectOf(boundsOf(ink)),
            moreOrLessEquals(
              CalcTheme.keyLegendBoxAspectRatio(shape),
              epsilon: 0.04 * CalcTheme.keyLegendBoxAspectRatio(shape),
            ),
            reason: '$shape filled: $filled',
          );
        }
      }
    });

    testWidgets(
      '빈 칸 테두리는 모든 모양에서 칸 짧은 변의 1/4이고, 구멍이 칸의 절반이다 (#206 사진 0.24~0.31)',
      (tester) async {
        for (final shape in LegendBoxShape.values) {
          final ink = await inkPixels(
            tester,
            LegendBox(shape, filled: false),
            200,
          );
          final (left, top, right, bottom) = boundsOf(ink);
          final width = right - left + 1;
          final height = bottom - top + 1;
          final short = math.min(width, height);
          final wall = short * CalcTheme.keyLegendBoxStrokeRatio;
          // 가운데 가로줄·세로줄 단면: 벽 둘과 그 사이 구멍
          final midY = (top + bottom) ~/ 2;
          final midX = (left + right) ~/ 2;
          final across = runsOf(
            ink.where((p) => p.$2 == midY).map((p) => p.$1),
          );
          final down = runsOf(ink.where((p) => p.$1 == midX).map((p) => p.$2));
          for (final (name, runs, length) in [
            ('가로', across, width),
            ('세로', down, height),
          ]) {
            expect(runs, hasLength(2), reason: '$shape $name $runs');
            for (final run in runs) {
              expect(
                run.$2 - run.$1 + 1,
                moreOrLessEquals(wall, epsilon: 1.5),
                reason: '$shape $name 벽',
              );
            }
            final hole = runs.last.$1 - runs.first.$2 - 1;
            expect(hole, closeTo(length - 2 * wall, 2), reason: '$shape $name');
          }
          // 짧은 변 방향의 구멍은 칸의 절반 (#169 R2 — 작은 각인에서도 빈 칸이 메워지지 않는다)
          final shortRuns = width <= height ? across : down;
          expect(
            (shortRuns.last.$1 - shortRuns.first.$2 - 1) / short,
            moreOrLessEquals(0.5, epsilon: 0.03),
            reason: '$shape',
          );
        }
      },
    );

    test('비가 1인 칸은 글꼴 칸 ◼와 폭·잉크 높이가 같고, 좌우 여백은 번들 글꼴 ◼의 여백이다', () async {
      // 정사각형 자리(x^◼)는 #186 전의 글꼴 칸과 같은 자리·폭을 차지한다 — 칸 모양을 바꿔도 이웃 글자 간격이 그대로다.
      const square = LegendBox(LegendBoxShape.powerExponent, filled: true);
      expect(
        CalcTheme.keyLegendBoxAspectRatio(LegendBoxShape.powerExponent),
        1.0,
      );
      for (final style in [
        CalcTheme.keyMainLabelStyle,
        CalcTheme.keyShiftLabelStyle,
      ]) {
        final drawn = KeyLegendView.emMetrics(square, style);
        final glyph = KeyLegendView.emMetrics(const LegendText('◼'), style);
        expect(
          drawn.size.width,
          moreOrLessEquals(glyph.size.width, epsilon: 0.002),
        );
        expect(drawn.inkTop, moreOrLessEquals(glyph.inkTop, epsilon: 1e-6));
        expect(drawn.inkBottom, moreOrLessEquals(0, epsilon: 1e-6));
      }
      for (final file in [
        'NotoSansMono-SemiBold.ttf',
        'NotoSansMono-Medium.ttf',
      ]) {
        final data = await rootBundle.load('assets/fonts/$file');
        final x = readGlyphXBounds(data, '◼'.runes.single)!;
        // 고정폭 글꼴의 글자 폭 0.6em (bundled_font_test가 확인)
        expect(
          x.xMin,
          moreOrLessEquals(CalcTheme.keyLegendBoxSideBearing, epsilon: 0.003),
          reason: file,
        );
        expect(
          0.6 - x.xMax,
          moreOrLessEquals(CalcTheme.keyLegendBoxSideBearing, epsilon: 0.003),
          reason: file,
        );
      }
    });

    testWidgets(
      '그린 log 진수 칸: 기준선에서 l 윗끝까지 서고, 폭은 높이의 약 절반이며, 밑 칸에 거의 붙는다 (사진 13×26px)',
      (tester) async {
        const fontSize = 140.0;
        final ink = await inkPixels(
          tester,
          keyDefOf(CalcKeyId.logBase).mainLegend,
          fontSize,
        );
        final columns = runsOf(ink.map((p) => p.$1));
        final l = boundsOf(
          ink.where(
            (p) => p.$1 >= columns.first.$1 && p.$1 <= columns.first.$2,
          ),
        );
        final baseline = l.$4; // l의 아래끝
        // 칸은 열 구간이 아니라 높이 띠로 찾는다 — 사진처럼 두 칸이 맞닿아 한 열 구간이 되어도 찾을 수 있다(R2).
        // g 윗끝(0.52em)·밑 칸 윗끝(약 0.32em)보다 높고 진수 칸 위 벽(l 윗끝 0.743em(#156 Saira)에서 칸 폭 약 0.37em의 1/4
        // ≈ 0.093em 아래까지, #206)보다 낮은 띠에는 l과 진수 칸 왼쪽·오른쪽 벽만 있다.
        final high = runsOf(
          ink
              .where(
                (p) =>
                    p.$2 < baseline - fontSize * 0.56 &&
                    p.$2 > baseline - fontSize * 0.63,
              )
              .map((p) => p.$1),
        );
        expect(high, hasLength(3), reason: 'l·진수 칸 두 벽 $high');
        final argumentLeft = high[1].$1;
        final argument = boundsOf(ink.where((p) => p.$1 >= argumentLeft));
        expect(argument.$2, moreOrLessEquals(l.$2.toDouble(), epsilon: 2));
        expect(argument.$4, moreOrLessEquals(l.$4.toDouble(), epsilon: 2));
        expect(aspectOf(argument), inInclusiveRange(0.45, 0.55));
        // 밑 칸 오른쪽 끝: 밑 칸 높이 띠에서 진수 칸 왼쪽에 있는 잉크의 오른쪽 끝
        final baseRight = ink
            .where(
              (p) =>
                  p.$1 < argumentLeft &&
                  p.$2 < baseline - fontSize * 0.05 &&
                  p.$2 > baseline - fontSize * 0.2,
            )
            .map((p) => p.$1)
            .reduce(math.max);
        // 사진은 두 칸이 0~1px로 맞닿는다. 진수 칸은 왼쪽 여백이 없어 밑 칸의 오른쪽 여백(첨자 크기의 0.059em
        // ≈ 0.04em)만 남는다 — 양쪽에 여백을 두면 약 0.1em이 벌어진다. 맞닿아도(틈 0) 통과한다.
        expect(argumentLeft - baseRight - 1, lessThan(fontSize * 0.05));
      },
    );

    testWidgets(
      '그린 ∫ 각인: 본문 칸은 약 2:1이고 사진 높이이며, 아래 끝 칸은 ∫ 기울기를 따라 위 끝 칸보다 왼쪽이다 (사진)',
      (tester) async {
        const fontSize = 140.0;
        final ink = await inkPixels(
          tester,
          keyDefOf(CalcKeyId.integral).mainLegend,
          fontSize,
        );
        // 위 끝 칸 위끝은 ∫ 잉크 위끝(0.893em)에 맞으므로, 잉크 맨 위에서 기준선을 구한다.
        final (_, inkTop, _, inkBottom) = boundsOf(ink);
        final baseline = inkTop + fontSize * KeyLegendView.glyphInk['∫']!.$2;
        // 칸은 높이 띠로 찾는다(R2 — 열 구간은 칸이 맞닿으면 합쳐진다).
        List<(int, int)> runsIn(bool Function(int y) inBand) {
          final runs = runsOf(ink.where((p) => inBand(p.$2)).map((p) => p.$1));
          expect(runs.length, greaterThanOrEqualTo(2), reason: '$runs');
          return runs;
        }

        // 본문 칸 높이 띠(끝 칸과 겹치지 않는 0.12~0.3em): ∫ 줄기와 본문 칸
        final bodyLeft = runsIn(
          (y) =>
              y < baseline - fontSize * 0.12 && y > baseline - fontSize * 0.3,
        ).last.$1;
        final body = boundsOf(ink.where((p) => p.$1 >= bodyLeft));
        expect(aspectOf(body), moreOrLessEquals(25 / 12, epsilon: 0.1));
        expect(
          body.$4 - body.$2 + 1,
          moreOrLessEquals(
            fontSize * CalcTheme.keyLegendIntegralOperandHeight,
            epsilon: 2,
          ),
        );
        // 위·아래 끝 칸 띠: ∫ 머리·꼬리와 끝 칸
        final upperRuns = runsIn((y) => y < inkTop + fontSize * 0.25);
        final lowerRuns = runsIn((y) => y > inkBottom - fontSize * 0.2);
        final upper = upperRuns.last;
        final lower = lowerRuns.last;
        // 사진: 아래 칸이 위 칸보다 9px(약 0.27em) 왼쪽
        expect(
          upper.$1 - lower.$1,
          moreOrLessEquals(
            fontSize * CalcTheme.keyLegendIntegralSubscriptShift,
            epsilon: 3,
          ),
        );
        // 아래 끝 칸은 ∫ 꼬리와 떨어져 있다. 사진의 사이는 약 0.15em이고, 번들 ∫는 아래쪽이 좁아 앱은 약 0.28em이다
        // (차이는 CalcTheme "2차원 각인 배치" 절에 적었다) — 더 벌어지지 않게 위쪽도 묶는다.
        final tail = lowerRuns[lowerRuns.length - 2];
        expect(
          lower.$1 - tail.$2 - 1,
          inInclusiveRange(fontSize * 0.05, fontSize * 0.32),
        );
        // 위 끝 칸과 본문 칸은 사진에서 맞닿는다 — 끝 칸 오른쪽 여백만 남는다.
        expect(bodyLeft - upper.$2 - 1, lessThan(fontSize * 0.05));
      },
    );

    testWidgets(
      '그린 분수 키 각인: 분자·분모 칸이 가로로 길고(사진 25×14px), 가로줄이 칸보다 사진만큼 길다(약 1.46배)',
      (tester) async {
        final ink = await inkPixels(
          tester,
          keyDefOf(CalcKeyId.fraction).mainLegend,
          140,
        );
        final rows = runsOf(ink.map((p) => p.$2));
        expect(rows, hasLength(3), reason: '분자·가로줄·분모 $rows');
        (int, int, int, int) rowBounds((int, int) row) =>
            boundsOf(ink.where((p) => p.$2 >= row.$1 && p.$2 <= row.$2));
        for (final row in [rows.first, rows.last]) {
          expect(
            aspectOf(rowBounds(row)),
            moreOrLessEquals(25 / 14, epsilon: 0.1),
          );
        }
        final part = rowBounds(rows.first);
        final bar = rowBounds(rows[1]);
        expect(
          (bar.$3 - bar.$1 + 1) / (part.$3 - part.$1 + 1),
          moreOrLessEquals(1.46, epsilon: 0.02),
        );
        // 두께·간격 (#206): 사진(칸 높이 14px 대비) 가로줄 4.9px ≈ 0.35, 간격 2.4~2.5px ≈ 0.17, 분모 테두리 3.4~4.0px
        // ≈ 0.26, 각인 전체 37.9px ≈ 2.7
        final box = (part.$4 - part.$2 + 1).toDouble();
        double ofBox(int pixels) => pixels / box;
        expect(ofBox(rows[1].$2 - rows[1].$1 + 1), closeTo(4.9 / 14, 0.04));
        expect(ofBox(rows[1].$1 - rows[0].$2 - 1), closeTo(2.45 / 14, 0.04));
        expect(ofBox(rows[2].$1 - rows[1].$2 - 1), closeTo(2.45 / 14, 0.04));
        expect(
          ofBox(rows.last.$2 - rows.first.$1 + 1),
          closeTo(37.9 / 14, 0.1),
        );
        final den = rowBounds(rows.last);
        final denColumn = runsOf(
          ink
              .where((p) => p.$1 == (den.$1 + den.$3) ~/ 2 && p.$2 >= den.$2)
              .map((p) => p.$2),
        );
        expect(denColumn, hasLength(2), reason: '분모 위·아래 벽 $denColumn');
        for (final wall in denColumn) {
          expect(ofBox(wall.$2 - wall.$1 + 1), closeTo(0.26, 0.03));
        }
      },
    );

    testWidgets('굵은 근호에서도 지수(∛◼의 3, ◼√◻의 지수 칸)·피개법수는 근호와 떨어져 있다 (#206 R1)', (
      tester,
    ) async {
      // 잉크 픽셀의 8방향 연결 성분 수 — 지수·근호·피개법수가 서로 닿지 않으면 3이다(∛의 3은 한 획이다).
      int components(List<(int, int)> ink) {
        final remaining = ink.toSet();
        var count = 0;
        while (remaining.isNotEmpty) {
          count++;
          final stack = [remaining.first];
          remaining.remove(stack.first);
          while (stack.isNotEmpty) {
            final (x, y) = stack.removeLast();
            for (var dx = -1; dx <= 1; dx++) {
              for (var dy = -1; dy <= 1; dy++) {
                if (remaining.remove((x + dx, y + dy))) {
                  stack.add((x + dx, y + dy));
                }
              }
            }
          }
        }
        return count;
      }

      for (final legend in [
        keyDefOf(CalcKeyId.sqrt).shiftLegend!,
        keyDefOf(CalcKeyId.power).shiftLegend!,
      ]) {
        // 큰 글자와 실제 크기대(각인 약 9dp × 기기 배율 2.625 ≈ 24px)
        for (final fontSize in [140.0, 24.0]) {
          final ink = await inkPixels(tester, legend, fontSize);
          expect(components(ink), 3, reason: '${legend.plainText} $fontSize');
        }
      }
    });

    testWidgets(
      '그린 √ 각인: 근호 가로줄 두께는 피개법수 칸 높이의 약 0.3이다 (#206 사진 4.7px / 15.7px)',
      (tester) async {
        const fontSize = 140.0;
        final ink = await inkPixels(
          tester,
          keyDefOf(CalcKeyId.sqrt).mainLegend,
          fontSize,
        );
        final (_, _, right, inkBottom) = boundsOf(ink);
        // 오른쪽 끝 근처 세로 단면: 근호 가로줄 → 간격 → 채운 피개법수 칸
        final x = right - (fontSize * 0.25).round();
        final column = runsOf(ink.where((p) => p.$1 == x).map((p) => p.$2));
        expect(column, hasLength(2), reason: '근호 가로줄·피개법수 칸 $column');
        final bar = column.first.$2 - column.first.$1 + 1;
        final box = column.last.$2 - column.last.$1 + 1;
        expect(bar / box, closeTo(4.7 / 15.7, 0.04));
        expect(
          bar,
          moreOrLessEquals(
            fontSize * CalcTheme.keyLegendRadicalStroke,
            epsilon: 2,
          ),
        );
        // 아래 꼭짓점 잉크는 선 두께와 상관없이 칸 아래끝보다 약 0.065em 아래다(사진 약 2px ≈ 0.06em, #206 R1 —
        // 선을 굵게 한 만큼 더 내려가지 않는다).
        expect(
          inkBottom - column.last.$2,
          moreOrLessEquals(fontSize * 0.065, epsilon: 2),
        );
      },
    );

    /// [legend]의 입력 칸을 #186 전처럼 글꼴 칸(`◼`·`◻`)으로 바꾼 각인 (∑ 칸은 #169부터 직접 그렸으므로 그대로)
    KeyLegend glyphBoxes(KeyLegend legend) => switch (legend) {
      LegendText() => legend,
      LegendBox(:final shape, :final glyph) =>
        shape == LegendBoxShape.sumLimit || shape == LegendBoxShape.sumOperand
            ? legend
            : LegendText(glyph),
      LegendRow(:final children) => LegendRow([
        for (final c in children) glyphBoxes(c),
      ]),
      LegendScript(
        :final base,
        :final superscript,
        :final subscript,
        :final subscriptOnBaseline,
      ) =>
        LegendScript(
          glyphBoxes(base),
          superscript: superscript == null ? null : glyphBoxes(superscript),
          subscript: subscript == null ? null : glyphBoxes(subscript),
          subscriptOnBaseline: subscriptOnBaseline,
        ),
      LegendLimits() => legend,
      LegendFraction(:final numerator, :final denominator) => LegendFraction(
        glyphBoxes(numerator),
        glyphBoxes(denominator),
      ),
      LegendRadical(:final radicand, :final index) => LegendRadical(
        glyphBoxes(radicand),
        index: index == null ? null : glyphBoxes(index),
      ),
    };

    test('칸 모양을 바꿔도 모든 2차원 각인의 높이·잉크 위아래 끝은 글꼴 칸일 때와 같다 — 각인 높이 예산이 그대로다', () {
      for (final (k, legend, style) in _twoDimensional()) {
        final now = KeyLegendView.emMetrics(legend, style);
        final before = KeyLegendView.emMetrics(glyphBoxes(legend), style);
        final reason = '${k.id.name} ${legend.plainText}';
        expect(
          now.size.height,
          moreOrLessEquals(before.size.height),
          reason: reason,
        );
        expect(now.inkTop, moreOrLessEquals(before.inkTop), reason: reason);
        expect(
          now.inkBottom,
          moreOrLessEquals(before.inkBottom),
          reason: reason,
        );
      }
    });

    test('칸 모양으로 넓어진 메인 각인도 SHIFT보다 좁고, log◼◻는 글꼴 칸일 때보다 좁다', () {
      const style = CalcTheme.keyMainLabelStyle;
      double width(KeyLegend l) => KeyLegendView.emSize(l, style).width;
      final shift = width(const LegendText('SHIFT'));
      for (final k in allKeys) {
        if (k.mainLegend.isPlain) continue;
        expect(
          width(k.mainLegend),
          lessThan(shift / 1.05),
          reason: k.mainLegend.plainText,
        );
      }
      final integral = keyDefOf(CalcKeyId.integral).mainLegend;
      expect(width(integral), moreOrLessEquals(2.08, epsilon: 0.03));
      final log = keyDefOf(CalcKeyId.logBase).mainLegend;
      expect(width(log), lessThan(width(glyphBoxes(log))));
    });

    test(
      '2차원 각인이 있는 키는 키패드 통일 글자 크기의 폭 기준을 정하지 않는다 — 제품 규칙으로 5% 이상 여유 (배열 둘)',
      () {
        // 통일 글자 크기는 가장 좁게 들어가는 라벨이 정한다(`KeypadMetrics.compute` 2단계 — 메인 SHIFT·ALPHA, 각인
        // Ran#·RanInt 쌍). 칸을 넓힌 각인(∫◻◻◼ 등)이 그 자리를 차지하면 키패드 전체 글자가 작아진다. 각인 한도는
        // 그린 키캡 폭(#220)에 비례하고 메인 한도는 키캡 테두리(상수)만큼 어긋나지만, 2차원 메인 각인과 SHIFT·ALPHA가 모두 함수부
        // 키라 비교에는 영향이 없다 — 배열마다 한 크기로 본다(함수부·숫자부 셀 너비 비가 배열마다 다르다).
        bool twoDimensionalMain(CalcKeyDef d) => !d.mainLegend.isPlain;
        bool twoDimensionalLegend(CalcKeyDef d) =>
            !(d.shiftLegend?.isPlain ?? true) ||
            !(d.alphaLegend?.isPlain ?? true);
        for (final m in [
          KeypadMetrics.compute(const Size(400, 560), TextScaler.noScaling),
          KeypadMetrics.compute(
            const Size(1000, 420),
            TextScaler.noScaling,
            arrangement: KeypadArrangement.wide,
          ),
        ]) {
          limits([bool Function(CalcKeyDef)? where]) =>
              KeypadMetrics.debugWidthLimits(m, where: where);
          final all = limits();
          final mainOnly = limits(twoDimensionalMain);
          final legendOnly = limits(twoDimensionalLegend);
          // 고른 키가 없으면 한도가 무한대라 아래 비교가 공허하게 통과한다(R2) — 유한한지 먼저 본다.
          for (final v in [
            all.main,
            all.legend,
            mainOnly.main,
            legendOnly.legend,
          ]) {
            expect(v.isFinite, isTrue, reason: '${m.arrangement}');
          }
          final reason = '${m.arrangement}';
          expect(mainOnly.main, greaterThan(all.main * 1.05), reason: reason);
          expect(
            legendOnly.legend,
            greaterThan(all.legend * 1.05),
            reason: reason,
          );
        }
      },
    );
  });

  group('키 버튼에서 (#155 체크리스트)', () {
    testWidgets('이슈 표의 모든 각인이 2차원 각인 위젯으로 그려지고 한 줄 표기 Text는 없다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 390, height: 520, child: CalcKeypad())),
      );
      for (final (k, legend, _) in _twoDimensional()) {
        expect(findLegend(legend), findsOneWidget, reason: legend.plainText);
        expect(
          find.text(legend.plainText),
          findsNothing,
          reason: '${k.id.name}: 한 줄 표기가 화면에 남았다',
        );
      }
    });

    testWidgets('스크린리더 문구는 그려진 모양과 무관하게 지금 음성 라벨 그대로다', (tester) async {
      const strings = KoSemanticStrings();
      final handle = tester.ensureSemantics();
      final ids = {for (final (k, _, _) in _twoDimensional()) k.id};
      useKoreanLocale(tester);
      for (final id in ids) {
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 80,
              height: 90,
              child: CalcKeyButton(keyDef: keyDefOf(id), onPressed: (_) {}),
            ),
          ),
        );
        final node = tester.getSemantics(find.byType(CalcKeyButton));
        expect(node.label, strings.keyButton(id), reason: id.name);
        expect(node.hint, strings.keyButtonHint(id), reason: id.name);
        // 각인 기호(칸·위첨자)를 읽지 않는다 — 각인 위젯은 의미 트리에 아무것도 더하지 않는다.
        for (final text in [node.label, node.hint]) {
          expect(
            text,
            isNot(matches(RegExp('[◼◻^²³⁻¹ˣ√∛]'))),
            reason: '${id.name}: $text',
          );
        }
      }
      handle.dispose();
    });

    for (final scale in [1.0, 1.3]) {
      for (final size in const [
        Size(320, 420),
        Size(390, 520),
        Size(600, 700),
      ]) {
        testWidgets(
          '${size.width}×${size.height} 글자 배율 $scale: 2차원 각인이 키캡·각인 띠에 줄지 않고 들어간다',
          (tester) async {
            // 각인은 키캡·각인 띠 안의 FittedBox(scaleDown)에 들어 있어, 넘치면 상자가 아니라 축소 비율로 드러난다.
            // 화면상 높이(getRect)가 배치 높이(getSize)와 같으면 줄지 않고 그대로 들어간 것이다.
            await tester.pumpWidget(
              _host(
                SizedBox.fromSize(size: size, child: const CalcKeypad()),
                textScale: scale,
              ),
            );
            for (final (k, legend, _) in _twoDimensional()) {
              final f = find.descendant(
                of: find.byWidgetPredicate(
                  (w) => w is CalcKeyButton && w.keyDef.id == k.id,
                ),
                matching: findLegend(legend),
              );
              expect(
                tester.getRect(f).height,
                moreOrLessEquals(tester.getSize(f).height, epsilon: 0.01),
                reason: '${k.id.name} ${legend.plainText}',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('그린 분수 가로줄·근호 선은 최소 두께로 굵어져도 각인 상자 안에 있다', (tester) async {
      // 선은 글자 크기가 작으면 CalcTheme.keyLegendMinStroke로 굵게 칠한다(#155 R1 m8). 굵어진 선(반 두께 포함)이
      // 상자 밖에 그려지면 키캡·각인 띠 경계를 넘는다.
      for (final fontSize in [3.2, 3.5, 4.0, 6.0, 9.0, 20.0]) {
        for (final (k, legend, style) in _twoDimensional()) {
          await tester.pumpWidget(
            _host(
              KeyLegendView(
                legend: legend,
                style: style.copyWith(fontSize: fontSize),
              ),
            ),
          );
          final render = tester.renderObject<RenderKeyLegend>(
            find.byType(KeyLegendView),
          );
          final canvas = TestRecordingCanvas();
          render.paint(TestRecordingPaintingContext(canvas), Offset.zero);
          final box = (Offset.zero & render.size).inflate(1e-6);
          final reason = '${k.id.name} ${legend.plainText} @$fontSize';
          for (final call in canvas.invocations) {
            final drawn = switch (call.invocation.memberName) {
              #drawRect => call.invocation.positionalArguments[0] as Rect,
              // 선 두께의 절반만큼 위아래·왼쪽으로 넓힌다. 오른쪽 끝은 가로줄의 butt 끝이라 넓어지지 않는다.
              #drawPath => () {
                final b = (call.invocation.positionalArguments[0] as Path)
                    .getBounds();
                final half =
                    (call.invocation.positionalArguments[1] as Paint)
                        .strokeWidth /
                    2;
                return Rect.fromLTRB(
                  b.left - half,
                  b.top - half,
                  b.right,
                  b.bottom + half,
                );
              }(),
              _ => null,
            };
            if (drawn == null) continue;
            expect(
              box.contains(drawn.topLeft) && box.contains(drawn.bottomRight),
              isTrue,
              reason: '$reason: $drawn ⊄ $box',
            );
          }
        }
      }
    });
  });
}
