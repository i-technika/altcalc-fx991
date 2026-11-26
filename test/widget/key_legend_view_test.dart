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
    test('2차원 각인의 모든 글자가 표에 있다', () {
      final missing = {
        for (final (_, legend, _) in _twoDimensional())
          for (final piece in legend.texts)
            for (final ch in piece.text.split(''))
              if (!KeyLegendView.glyphInk.containsKey(ch)) ch,
      };
      expect(missing, isEmpty, reason: '표에 없으면 한 줄 상자를 잉크로 봐 배치가 성겨진다');
    });

    test('표의 값은 번들 글꼴의 glyf 잉크 범위와 0.012em 안에서 같다 (각인에 쓰는 굵기 모두)', () async {
      // 메인 각인은 SemiBold, SHIFT·ALPHA 각인은 Medium이다. ∫·∑는 대체 글꼴 Noto Sans Math에만 있다.
      final fonts = {
        'SemiBold': await rootBundle.load(
          'assets/fonts/NotoSansMono-SemiBold.ttf',
        ),
        'Medium': await rootBundle.load('assets/fonts/NotoSansMono-Medium.ttf'),
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
      for (final MapEntry(key: ch, value: (yMin, yMax))
          in KeyLegendView.glyphInk.entries) {
        final code = ch.runes.single;
        final sources = readCmap(fonts['Medium']!).containsKey(code)
            ? fonts.entries.toList()
            : [MapEntry('Math', math)];
        for (final MapEntry(key: weight, value: data) in sources) {
          final bounds = readGlyphYBounds(data, code)!;
          expect(
            yMin,
            moreOrLessEquals(bounds.yMin, epsilon: 0.012),
            reason: '$ch $weight yMin',
          );
          expect(
            yMax,
            moreOrLessEquals(bounds.yMax, epsilon: 0.012),
            reason: '$ch $weight yMax',
          );
        }
      }
    });
  });

  group('크기·기준선', () {
    testWidgets('글자만 있는 각인의 emSize는 같은 스타일 Text(strut 고정)의 크기와 같다', (
      tester,
    ) async {
      const style = CalcTheme.keyShiftLabelStyle;
      // `log`는 내림 글자 g가 한 줄 아래로 나가지만 Text처럼 한 줄 상자만 쓴다.
      for (final text in ['SOLVE', 'A', '⇔', 'log']) {
        await tester.pumpWidget(
          _host(
            Text(
              text,
              style: style.copyWith(fontSize: 100),
              strutStyle: StrutStyle.fromTextStyle(
                style.copyWith(fontSize: 100),
                forceStrutHeight: true,
              ),
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
    testWidgets('분수는 분자·가로줄·분모, 근호는 선과 피개법수, 첨자는 글자 둘로 그린다', (tester) async {
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
          ..paragraph()
          ..rect(color: const Color(0xFF123456))
          ..paragraph(),
      );
      expect(
        await draw(keyDefOf(CalcKeyId.sqrt).mainLegend),
        paints
          ..path(color: const Color(0xFF123456), style: PaintingStyle.stroke)
          ..paragraph(),
      );
      expect(
        await draw(keyDefOf(CalcKeyId.square).mainLegend),
        paints
          ..paragraph()
          ..paragraph(),
      );
    });

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
          ..paragraph()
          ..rect(color: const Color(0xFFFFFFFF))
          ..paragraph(),
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

  group('∑·log 각인 (#169 — Quick Start Guide 1쪽 제품 사진 대조)', () {
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
        // 본문 칸: 사진 8×4px — 납작하고, 세로 가운데가 ∑ 가운데와 같다.
        final bodyRows = runsOf(body.map((p) => p.$2));
        expect(bodyRows, hasLength(1));
        final (bodyTop, bodyBottom) = bodyRows.single;
        expect(boxRight - boxLeft, greaterThan(bodyBottom - bodyTop));
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
      for (final fontSize in [4.0, 6.0, 9.0, 20.0]) {
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
