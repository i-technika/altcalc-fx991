import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/key_legend_view.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';
import '../support/ttf_cmap.dart';

/// 메인 각인 세로 위치 (#230, [CalcTheme] "메인 각인 세로 위치" 절):
/// - 기준선 글자가 있는 각인은 대문자·숫자 잉크 가운데를, 없는 각인은 자기 잉크 가운데를 키캡 면 세로 가운데에 둔다.
/// - 실제로 그린 픽셀에서 잰 잉크 가운데 / 키캡 면 비가 실물 키패드 근접 사진과 맞는다(폰·태블릿, 글자 배율 1.0·1.3).
/// - 내림 글자(g)·2차원 각인(분수·∫)을 포함해 모든 메인 각인의 잉크가 키캡 면 안에 그려진다.

/// 실물 키패드 근접 사진(가이드 폴더의 키패드 사진 2048×1363)에서 잰 잉크 가운데 / 키캡 면 비 — 면 위끝(윗테두리 안쪽)부터
/// 잉크 위끝·아래끝 가운데까지를 면 높이(옆면 앞까지)로 나눈 값. 흰 키는 키 가장자리 띠의 밝기 반값 문턱, 검정 키는 테두리
/// 골에서 면을 정했다(±1px — 면 높이 55~81px의 약 ±0.015). OPTN·CALC·STO는 면 윤곽이 본체와 구별되지 않아 재지 못했다.
const _photoInkCenter = <CalcKeyId, double>{
  // 함수부 (면 높이 약 55px)
  CalcKeyId.integral: 0.518,
  CalcKeyId.variableX: 0.509,
  CalcKeyId.fraction: 0.509,
  CalcKeyId.sqrt: 0.491,
  CalcKeyId.square: 0.482,
  CalcKeyId.power: 0.491,
  CalcKeyId.logBase: 0.546,
  CalcKeyId.ln: 0.500,
  CalcKeyId.negative: 0.500,
  CalcKeyId.degMinSec: 0.536,
  CalcKeyId.reciprocal: 0.527,
  CalcKeyId.sin: 0.519,
  CalcKeyId.cos: 0.565,
  CalcKeyId.tan: 0.500,
  CalcKeyId.eng: 0.518,
  CalcKeyId.parenOpen: 0.536,
  CalcKeyId.parenClose: 0.527,
  CalcKeyId.sdToggle: 0.536,
  CalcKeyId.mPlus: 0.546,
  // 숫자부 (면 높이 약 81px). 사진 키패드의 소수점은 `,`라 뺀다(CLAUDE.md — EN판과 다른 각인).
  CalcKeyId.num7: 0.488,
  CalcKeyId.num8: 0.469,
  CalcKeyId.num9: 0.481,
  CalcKeyId.del: 0.494,
  CalcKeyId.ac: 0.519,
  CalcKeyId.num4: 0.488,
  CalcKeyId.num5: 0.494,
  CalcKeyId.num6: 0.476,
  CalcKeyId.multiply: 0.512,
  CalcKeyId.divide: 0.494,
  CalcKeyId.num1: 0.500,
  CalcKeyId.num2: 0.506,
  CalcKeyId.num3: 0.512,
  CalcKeyId.add: 0.525,
  CalcKeyId.subtract: 0.518,
  CalcKeyId.num0: 0.528,
  CalcKeyId.exp10: 0.506,
  CalcKeyId.ans: 0.543,
  CalcKeyId.equals: 0.531,
};

/// 사진에서 면 윤곽이 또렷한 흰 키 — 숫자 0~9
const _photoDigits = [
  CalcKeyId.num0,
  CalcKeyId.num1,
  CalcKeyId.num2,
  CalcKeyId.num3,
  CalcKeyId.num4,
  CalcKeyId.num5,
  CalcKeyId.num6,
  CalcKeyId.num7,
  CalcKeyId.num8,
  CalcKeyId.num9,
];

/// 사진에서 면 윤곽이 또렷한 흰 키 — 연산 기호
const _photoOperators = [
  CalcKeyId.multiply,
  CalcKeyId.divide,
  CalcKeyId.add,
  CalcKeyId.subtract,
  CalcKeyId.equals,
];

/// 키캡에 메인 각인을 그리는 키 — 원형 버튼(SHIFT·ALPHA·MENU·ON, 각인은 본체에)과 커서 패드(반쪽 키캡 안의 라벨 자리,
/// #65)를 뺀 키
final List<CalcKeyDef> _keycapKeys = [
  for (final def in allKeys)
    if (def.face != KeyFace.roundButton && def.category != KeyCategory.cursor)
      def,
];

/// 잉크가 대문자·숫자 높이가 아니어서 기준선을 맞추면 잉크 가운데가 면 가운데에서 벗어나는 각인 — 위첨자(x²·x⁻¹·×10ˣ),
/// 내림 글자(log◼▯), 높은 소문자·x높이 글자(sin·cos·tan·ln), 소수점. 실물도 이 각인들은 기준선을 함께 쓴다.
/// (x⁻¹는 실물 x가 대문자 높이의 큰 x라 위첨자가 덜 높아 사진 0.527과 0.05 넘게 차이 나므로 사진 대조에서 뺀다 —
/// 각인 모양 차이이고 배치 차이가 아니다.)
const _offCenterByDesign = {
  CalcKeyId.square,
  CalcKeyId.reciprocal,
  CalcKeyId.exp10,
  CalcKeyId.logBase,
  CalcKeyId.sin,
  CalcKeyId.cos,
  CalcKeyId.tan,
  CalcKeyId.ln,
  CalcKeyId.dot,
};

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

Finder _label(CalcKeyId id) =>
    find.descendant(of: _keycap(id), matching: find.byType(InkCenteredLabel));

/// 각인 글자 [ch]를 실제로 그리는 번들 글꼴 — 키 버튼의 글자 조각 규칙(`keyLabelSpan`)과 대체 글꼴 순서
/// ([CalcTheme.keyFontFallback])를 따른다. 연산 기호 각인은 Noto Sans Mono Medium이다.
class _Fonts {
  final ByteData saira;
  final ByteData mono;
  final ByteData monoMedium;
  final ByteData math;
  final ByteData italic;

  _Fonts(this.saira, this.mono, this.monoMedium, this.math, this.italic);

  late final Set<int> _sairaCodes = readCmapCodePoints(saira);
  late final Set<int> _monoCodes = readCmapCodePoints(mono);

  /// [legend](글자만 있는 각인)의 세로 잉크 범위 (em, 기준선 위가 +)
  (double, double) inkOf(LegendText legend) {
    final text = legend.text;
    var bottom = double.infinity;
    var top = double.negativeInfinity;
    for (var i = 0; i < text.length; i++) {
      final code = text[i].runes.single;
      final font = CalcTheme.isKeyOperatorLegend(legend)
          ? monoMedium
          : CalcTheme.isKeyVariableLetter(text, i)
          ? italic
          : CalcTheme.isKeyMathSymbol(text[i])
          ? math
          : _sairaCodes.contains(code)
          ? saira
          : _monoCodes.contains(code)
          ? mono
          : math;
      final y = readGlyphYBounds(font, code)!;
      bottom = bottom < y.yMin ? bottom : y.yMin;
      top = top > y.yMax ? top : y.yMax;
    }
    return (bottom, top);
  }
}

/// 그린 각인 하나의 세로 위치 (전역 좌표, dp)
typedef _Drawn = ({
  Rect face,
  double baselineY,
  double referenceY,
  double inkTopY,
  double inkBottomY,
});

/// [def] 키의 키캡 면과, 그린 각인의 기준 높이([mainLegendInkCenter])·잉크 위끝·아래끝 위치를 렌더 트리에서 잰다.
///
/// 글자 상자(자식) 위끝 + 그린 기준선 − 높이 × 글자 크기이고, `FittedBox`가 줄였으면 그 비율을 곱한다. 그린 기준선은
/// `Text`면 보고한 기준선을 정수로 반올림한 곳(SkParagraph가 글자를 그리는 곳 — [InkCenteredLabel]),
/// 2차원 각인이면 보고한 기준선이다.
_Drawn _measure(WidgetTester tester, CalcKeyDef def, _Fonts fonts) {
  final legend = def.mainLegend;
  final label = tester.renderObject<RenderInkCenteredLabel>(_label(def.id));
  final child = label.child!;
  final rect = MatrixUtils.transformRect(
    child.getTransformTo(null),
    Offset.zero & child.size,
  );
  final scale = rect.height / child.size.height;
  final reported = switch (child) {
    // 그린 Text와 같은 글자·줄 상자·줄 간격 배분으로 기준선을 다시 잰다
    RenderParagraph() => () {
      final painter = TextPainter(
        text: child.text,
        textDirection: child.textDirection,
        textScaler: child.textScaler,
        strutStyle: child.strutStyle,
        textHeightBehavior: child.textHeightBehavior,
        maxLines: child.maxLines,
      )..layout();
      final b = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      painter.dispose();
      return b;
    }(),
    RenderKeyLegend() => child.debugBaseline,
    _ => throw StateError('각인 라벨이 아니다: ${child.runtimeType}'),
  };
  final baseline = legend is LegendText ? reported.roundToDouble() : reported;
  final style = CalcTheme.keyMainLabelStyleFor(legend);
  final fontSize = child is RenderParagraph
      ? child.textScaler.scale(child.text.style!.fontSize!)
      : (child as RenderKeyLegend).textScaler.scale(child.style.fontSize!);
  final ink = legend is LegendText
      ? fonts.inkOf(legend)
      : () {
          final m = KeyLegendView.emMetrics(legend, style);
          return (m.inkBottom, m.inkTop);
        }();
  double y(double em) => rect.top + (baseline - em * fontSize) * scale;
  return (
    face: tester.getRect(_keycap(def.id)),
    baselineY: y(0),
    referenceY: y(mainLegendInkCenter(legend, style)),
    inkTopY: y(ink.$2),
    inkBottomY: y(ink.$1),
  );
}

/// 키캡 면 [face] 안에서 그린 잉크의 세로 범위를 픽셀로 잰다 (전역 dp). 면 테두리 안쪽 가로 76% 폭을 훑어, 면 바탕과
/// 밝기가 크게 다른(라벨 색) 픽셀이 있는 행의 처음·끝이다. 면 바탕은 훑는 영역에서 가장 흔한 밝기다 — 한 점을 고르면
/// 넓은 각인(OPTN 등)에서 그 점이 잉크 위에 떨어져 모든 행을 잉크로 볼 수 있다(#230 R2).
(double, double)? _pixelInk(
  ByteData data,
  int width,
  double pixelRatio,
  Rect face,
) {
  double lum(int x, int y) {
    final i = (y * width + x) * 4;
    return 0.299 * data.getUint8(i) +
        0.587 * data.getUint8(i + 1) +
        0.114 * data.getUint8(i + 2);
  }

  int px(double v) => (v * pixelRatio).round();
  final x0 = px(face.left + face.width * 0.12);
  final x1 = px(face.right - face.width * 0.12);
  final y0 = px(face.top + CalcTheme.keyBorderWidth + 1);
  final y1 = px(face.bottom - CalcTheme.keyBorderWidth - 1);
  final histogram = <int, int>{};
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      histogram.update(lum(x, y) ~/ 8, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final ground =
      histogram.entries.reduce((a, b) => a.value >= b.value ? a : b).key * 8 +
      4;
  int? first;
  int? last;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      if ((lum(x, y) - ground).abs() > 90) {
        first ??= y;
        last = y;
        break;
      }
    }
  }
  if (first == null) return null;
  return (first / pixelRatio, (last! + 1) / pixelRatio);
}

Future<void> _pumpApp(
  WidgetTester tester,
  Size size,
  double pixelRatio, {
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = size * pixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const ProviderScope(child: AltCalcApp()));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadBundledFonts);

  late _Fonts fonts;
  setUpAll(() async {
    Future<ByteData> load(String name) => rootBundle.load('assets/fonts/$name');
    fonts = _Fonts(
      await load('Saira-SemiBold.ttf'),
      await load('NotoSansMono-SemiBold.ttf'),
      await load('NotoSansMono-Medium.ttf'),
      await load('NotoSansMath-Regular.ttf'),
      await load('NotoSerif-BoldItalic.ttf'),
    );
  });

  group('맞춤 기준 (#230)', () {
    test(
      '기준선 각인이 아닌 메인 각인은 기호·칸과 x 키뿐이다 — 연산 기호·방향 키·x 키·(−)·°\'"·괄호·분수·근호·적분',
      () {
        expect(
          {
            for (final def in allKeys)
              if (!CalcTheme.hasKeyBaselineText(def.mainLegend)) def.id,
          },
          {
            CalcKeyId.multiply,
            CalcKeyId.divide,
            CalcKeyId.add,
            CalcKeyId.subtract,
            CalcKeyId.equals,
            CalcKeyId.cursorUp,
            CalcKeyId.cursorDown,
            CalcKeyId.cursorLeft,
            CalcKeyId.cursorRight,
            CalcKeyId.variableX,
            CalcKeyId.negative,
            CalcKeyId.degMinSec,
            CalcKeyId.parenOpen,
            CalcKeyId.parenClose,
            CalcKeyId.fraction,
            CalcKeyId.sqrt,
            CalcKeyId.integral,
          },
        );
        // 소수점은 숫자의 기준선에 놓이는 글자다 — 자기 잉크로 맞추면 키캡 가운데로 올라간다
        expect(CalcTheme.hasKeyBaselineText(const LegendText('.')), isTrue);
      },
    );

    test('자기 잉크로 맞추는 메인 각인의 글자는 모두 잉크 범위 표에 있다 (없으면 줄 상자 가운데로 맞춰진다)', () {
      for (final def in allKeys) {
        final legend = def.mainLegend;
        if (CalcTheme.hasKeyBaselineText(legend)) continue;
        for (final piece in legend.texts) {
          for (var i = 0; i < piece.text.length; i++) {
            final table = CalcTheme.isKeyVariableLetter(piece.text, i)
                ? KeyLegendView.variableGlyphInk
                : KeyLegendView.glyphInk;
            expect(
              table.containsKey(piece.text[i]),
              isTrue,
              reason: '${def.id.name}: ${piece.text[i]}',
            );
          }
        }
      }
    });

    test(
      '기준선 각인의 기준 높이는 각인 글꼴 대문자·숫자의 잉크 가운데다 (평평한 윗변·둥근 글자 모두 0.002em 안)',
      () {
        for (final ch in ['E', 'T', '7', '4', 'S', 'O', '0', '8']) {
          final y = readGlyphYBounds(fonts.saira, ch.runes.single)!;
          expect(
            (y.yMin + y.yMax) / 2,
            closeTo(CalcTheme.keyMainLegendInkCenter, 0.002),
            reason: ch,
          );
        }
      },
    );
  });

  group('그린 자리 (#230)', () {
    // 폰·작은 폰·태블릿 세로·가로형·Fold 내부·짧은 창
    const windows = [
      Size(360, 800),
      Size(320, 568),
      Size(800, 1280),
      Size(800, 360),
      Size(841, 701),
      Size(360, 520),
    ];
    for (final size in windows) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '$size·글자 배율 $scale: 모든 메인 각인의 기준 높이가 키캡 면 가운데이고, 잉크가 면 안에 있다',
          (tester) async {
            await _pumpApp(tester, size, 1, textScale: scale);
            for (final def in _keycapKeys) {
              final drawn = _measure(tester, def, fonts);
              final reason = '${def.id.name} ($size, $scale)';
              expect(
                drawn.referenceY,
                closeTo(drawn.face.center.dy, 0.01),
                reason: reason,
              );
              final inner = drawn.face.deflate(CalcTheme.keyBorderWidth);
              expect(drawn.inkTopY, greaterThan(inner.top), reason: reason);
              expect(drawn.inkBottomY, lessThan(inner.bottom), reason: reason);
            }
            // 방향 키(커서 패드 반쪽 키캡)는 허브·외곽선 사이 라벨 자리(#65) 가운데에 잉크를 둔다
            for (final row in [...controlLeftRows, ...controlRightRows]) {
              for (final def in row) {
                if (def.category != KeyCategory.cursor) continue;
                final area = tester.getRect(
                  find
                      .ancestor(
                        of: _label(def.id),
                        matching: find.byType(Center),
                      )
                      .first,
                );
                expect(
                  _measure(tester, def, fonts).referenceY,
                  closeTo(area.center.dy, 0.01),
                  reason: '${def.id.name} ($size, $scale)',
                );
              }
            }
          },
        );
      }
    }

    testWidgets(
      '함수부 같은 행의 기준선 각인은 기준선이 같다 — x⁻¹·sin·cos·tan, x²·x^◼·log◼▯·ln (실물처럼, #230 전에는 log가 약 1dp 위)',
      (tester) async {
        await _pumpApp(tester, const Size(360, 800), 1);
        for (final row in functionRows) {
          final baselines = {
            for (final def in row)
              if (CalcTheme.hasKeyBaselineText(def.mainLegend))
                def.id: _measure(tester, def, fonts).baselineY,
          };
          expect(baselines.length, greaterThanOrEqualTo(3));
          final first = baselines.values.first;
          for (final MapEntry(:key, :value) in baselines.entries) {
            expect(value, closeTo(first, 0.01), reason: key.name);
          }
        }
      },
    );

    testWidgets(
      'boxHeight를 주면 상자 높이만 줄고 잉크 가운데는 그대로 상자 가운데다 (#264 — 숫자부 연산 기호)',
      (tester) async {
        const legend = LegendText('×');
        const fontSize = 40.0;
        final style = CalcTheme.keyMainLabelStyleFor(legend)
            .copyWith(fontSize: fontSize);
        final inkCenter = mainLegendInkCenter(legend, style) * fontSize;
        final inkHeight = mainLegendInkHeight(legend, style) * fontSize;
        Future<RenderInkCenteredLabel> pump(double? boxHeight) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: InkCenteredLabel(
                  inkCenter: inkCenter,
                  boxHeight: boxHeight,
                  child: Text(
                    legend.text,
                    style: style,
                    strutStyle: keyLabelStrut(style),
                  ),
                ),
              ),
            ),
          );
          return tester.renderObject<RenderInkCenteredLabel>(
            find.byType(InkCenteredLabel),
          );
        }

        /// 상자 위끝에서 잉크 가운데까지 (그린 기준선 − 잉크 가운데 높이)
        double inkCenterInBox(RenderInkCenteredLabel render) {
          final child = render.child!;
          // 배치 밖에서는 dry 기준선으로 잰다 (배치 중에만 쓸 수 있는 조회 대신)
          final baseline = child.getDryBaseline(
            BoxConstraints.loose(const Size(400, 400)),
            TextBaseline.alphabetic,
          )!;
          return render.shift + drawnBaselineOf(child, baseline) - inkCenter;
        }

        final full = await pump(null);
        final fullSize = full.size;
        // 기호 잉크는 글자 크기의 절반쯤이다 — 줄 상자(글자 크기)보다 훨씬 낮다
        expect(inkHeight, inInclusiveRange(fontSize * 0.4, fontSize * 0.5));
        expect(fullSize.height, greaterThan(inkHeight * 1.8));
        expect(inkCenterInBox(full), moreOrLessEquals(fullSize.height / 2));

        final tight = await pump(inkHeight);
        expect(tight.size.width, fullSize.width);
        expect(tight.size.height, moreOrLessEquals(inkHeight));
        expect(inkCenterInBox(tight), moreOrLessEquals(inkHeight / 2));
        // dry 배치도 같은 크기·기준선을 보고한다
        final constraints = BoxConstraints.loose(const Size(400, 400));
        expect(tight.getDryLayout(constraints), tight.size);
        expect(
          tight.getDryBaseline(constraints, TextBaseline.alphabetic),
          moreOrLessEquals(
            tight.child!.getDryBaseline(constraints, TextBaseline.alphabetic)! +
                tight.shift,
            epsilon: 1e-9,
          ),
        );
        // intrinsic 높이도 줄인 상자 높이다
        expect(
          tight.getMaxIntrinsicHeight(double.infinity),
          moreOrLessEquals(inkHeight),
        );
        expect(
          tight.getMinIntrinsicHeight(double.infinity),
          moreOrLessEquals(inkHeight),
        );
        // 자식보다 높은 boxHeight는 상자를 키우지 않는다
        final loose = await pump(fullSize.height * 2);
        expect(loose.size, fullSize);
      },
    );

    testWidgets('dry 기준선은 실제 기준선과 같다 — 옮긴 거리를 함께 더한다 (글자·2차원 각인)', (
      tester,
    ) async {
      for (final legend in const <KeyLegend>[
        LegendText('7'),
        LegendText('°\'"'),
        LegendScript(LegendText('x'), superscript: LegendText('2')),
        LegendFraction(
          LegendBox(LegendBoxShape.fractionPart, filled: true),
          LegendBox(LegendBoxShape.fractionPart, filled: false),
        ),
      ]) {
        final style = CalcTheme.keyMainLabelStyleFor(legend)
            .copyWith(fontSize: 18.62);
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: InkCenteredLabel(
                inkCenter: mainLegendInkCenter(legend, style) * 18.62,
                child: legend is LegendText
                    ? Text(
                        legend.text,
                        style: style,
                        strutStyle: keyLabelStrut(style),
                      )
                    : KeyLegendView(legend: legend, style: style),
              ),
            ),
          ),
        );
        final render = tester.renderObject<RenderInkCenteredLabel>(
          find.byType(InkCenteredLabel),
        );
        final constraints = BoxConstraints.loose(const Size(400, 400));
        final dry = render.getDryBaseline(
          constraints,
          TextBaseline.alphabetic,
        )!;
        final childDry = render.child!.getDryBaseline(
          constraints,
          TextBaseline.alphabetic,
        )!;
        // 분수 키는 잉크가 상자 가운데라 옮기지 않는다 — 나머지는 옮긴 거리가 dry 기준선에 들어가는지 본다
        if (legend is! LegendFraction) {
          expect(render.shift, isNot(0.0), reason: legend.plainText);
        }
        expect(
          dry,
          closeTo(childDry + render.shift, 1e-9),
          reason: legend.plainText,
        );
      }
    });

    // 넓은 배열의 낮은 키패드(접힘선 기준 배치·짧은 가로 창)와 실물 배열의 작은 키패드 — 글자가 키캡 높이에 묶여
    // 각인이 면을 가장 많이 채우는 곳
    for (final (size, arrangement) in const [
      (Size(240, 320), KeypadArrangement.standard),
      (Size(320, 103.6), KeypadArrangement.wide),
      (Size(400, 129.4), KeypadArrangement.wide),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '키패드 $size(${arrangement.name})·글자 배율 $scale: 기준 높이가 면 가운데이고 내림 글자·분수·∫의 잉크가 면 안에 있다',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox.fromSize(
                      size: size,
                      child: CalcKeypad(arrangement: arrangement),
                    ),
                  ),
                ),
              ),
            );
            for (final def in _keycapKeys) {
              final drawn = _measure(tester, def, fonts);
              final reason = '${def.id.name} ($size, $scale)';
              expect(
                drawn.referenceY,
                closeTo(drawn.face.center.dy, 0.01),
                reason: reason,
              );
              final inner = drawn.face.deflate(CalcTheme.keyBorderWidth);
              expect(drawn.inkTopY, greaterThan(inner.top), reason: reason);
              expect(drawn.inkBottomY, lessThan(inner.bottom), reason: reason);
            }
          },
        );
      }
    }
  });

  group('실물 사진 대조 — 그린 픽셀의 잉크 가운데 / 키캡 면 비 (#230)', () {
    // 실물 사진처럼 그린 픽셀에서 면 안의 잉크 행을 찾아 잰다. 검사 1은 #230 전 상태(360×800 픽셀 비 3·배율 1.0에서 숫자 약
    // 0.528·연산 기호 약 0.541, 태블릿 × 약 0.529)를 모든 조건에서 잡는다. 2·3은 360×800 픽셀 비 3·배율 1.0에서 잡고(log◼▯ − ln
    // 약 0.012), 다른 조건에서는 허용폭 안일 수 있다. 4는 회귀를 잡지 못하는 사진 점검이다(#230 전 최대 차 0.043).
    // 1. 대문자·숫자·기호 각인은 0.5 − max(0.01, 1.5 물리 픽셀)~0.52 (사진 숫자·연산 기호·함수부 대문자 범위가 0.49~0.52 —
    //    잉크 위·아래 행이 안티에일리어싱으로 한 줄씩 달라지는 몫을 하한에 둔다)
    // 2. 면 윤곽이 또렷한 흰 키의 구역 평균이 사진 평균과 0.02 안 — 숫자 0~9(사진 0.494), 연산 기호 다섯(사진 0.516)
    // 3. 같은 행에서 기준선을 함께 써 잉크 가운데가 갈리는 짝의 비 차가 사진과 0.025 안(두 키의 1 물리 픽셀씩 — 함수 키 면
    //    약 27dp, 픽셀 비 2.625에서 각 약 0.014) — cos − sin(사진 0.046), log◼▯ − ln(사진 0.046). 각인마다 잉크를 가운데에
    //    두면 0, 기준선이 어긋나면(#230 전 log◼▯ − ln 0.012) 크게 달라진다
    // 4. 사진을 잰 모든 키가 사진 값과 0.06(사진 함수 키 면 55px의 3px + 앱 1 물리 픽셀) 안 — 사진은 아래 행일수록
    //    0.01~0.03 커지는 카메라 각도가 있어 앱보다 조금 큰 쪽으로 치우친다
    // (창, 픽셀 비) — 폰(Android 흔한 픽셀 비 3·2.625)·태블릿 세로
    for (final (size, pixelRatio) in const [
      (Size(360, 800), 3.0),
      (Size(360, 800), 2.625),
      (Size(800, 1280), 2.0),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$size·픽셀 비 $pixelRatio·글자 배율 $scale', (tester) async {
          await _pumpApp(tester, size, pixelRatio, textScale: scale);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find
                .descendant(
                  of: find.byType(AltCalcApp),
                  matching: find.byType(RepaintBoundary),
                )
                .first,
          );
          final origin = boundary.localToGlobal(Offset.zero);
          final image = (await tester.runAsync(
            () => boundary.toImage(pixelRatio: pixelRatio),
          ))!;
          final data = (await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!;
          final ratios = <CalcKeyId, double>{};
          final faceHeights = <CalcKeyId, double>{};
          for (final def in _keycapKeys) {
            final face = tester.getRect(_keycap(def.id)).shift(-origin);
            faceHeights[def.id] = face.height;
            final ink = _pixelInk(data, image.width, pixelRatio, face);
            if (ink == null) {
              // ignore: avoid_print
              print('no ink: ${def.id.name}');
              continue;
            }
            final (top, bottom) = ink;
            ratios[def.id] = ((top + bottom) / 2 - face.top) / face.height;
          }
          image.dispose();
          expect(ratios.keys, containsAll(_keycapKeys.map((d) => d.id)));
          for (final MapEntry(key: id, value: ratio) in ratios.entries) {
            final reason =
                '${id.name} ($size, $scale): ${ratio.toStringAsFixed(3)}';
            // 잉크가 대문자·숫자 높이인 각인(기준선 각인)과 자기 잉크로 맞추는 각인 — 실물처럼 면 가운데다
            if (!_offCenterByDesign.contains(id)) {
              final onePixel = 1.5 / (pixelRatio * faceHeights[id]!);
              expect(
                ratio,
                inInclusiveRange(0.5 - math.max(0.01, onePixel), 0.52),
                reason: reason,
              );
            }
            final photo = _photoInkCenter[id];
            if (photo == null || id == CalcKeyId.reciprocal) continue;
            expect(ratio, closeTo(photo, 0.06), reason: '$reason, 사진 $photo');
          }
          double mean(Iterable<CalcKeyId> ids, Map<CalcKeyId, double> of) =>
              ids.map((id) => of[id]!).reduce((a, b) => a + b) / ids.length;
          for (final group in [_photoDigits, _photoOperators]) {
            expect(
              mean(group, ratios),
              closeTo(mean(group, _photoInkCenter), 0.02),
              reason: '구역 평균 $group',
            );
          }
          for (final (lower, upper) in const [
            (CalcKeyId.cos, CalcKeyId.sin),
            (CalcKeyId.logBase, CalcKeyId.ln),
          ]) {
            expect(
              ratios[lower]! - ratios[upper]!,
              closeTo(_photoInkCenter[lower]! - _photoInkCenter[upper]!, 0.025),
              reason: '${lower.name} − ${upper.name}',
            );
          }
          // 소수점은 숫자 기준선에 놓인다 (자기 잉크로 맞추지 않는다)
          expect(ratios[CalcKeyId.dot], greaterThan(0.55));
        });
      }
    }
  });
}
