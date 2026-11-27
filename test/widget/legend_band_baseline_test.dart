import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/key_legend_view.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';

/// 각인 띠의 글자 각인(`Text`)과 2차원 각인([KeyLegendView])의 그린 기준선 (#252).
///
/// 두 위젯은 같은 줄 상자([keyLabelStrut])를 쓰지만, #252 전에는 앱 화면의 `Text`만 Material 3 테마의 줄 간격 배분(`even`)을
/// 받아 기준선이 줄 상자 위에서 약 0.888em(2차원 각인은 0.785em)이었고, `Text`는 그 기준선을 정수 dp로 반올림한 곳에 글자를
/// 그렸다. 그래서 아래 정렬한 SHIFT·ALPHA 각인 띠에서 같은 키의 SHIFT `sin⁻¹`(2차원 각인)과 ALPHA `D`(`Text`)의 그린 기준선이
/// 360×800 폰에서 0.50dp, 800×1280 태블릿에서 1.37dp 어긋났다. 테마 없는 환경에서 재는 `key_legend_view_test.dart`의 기준선
/// 검사는 이 차이를 잡지 못하므로, 실제 앱([AltCalcApp])을 띄워 잰다.
///
/// 그린 기준선은 `Text`면 글자 상자(`RenderParagraph`) 위끝 + 보고한 기준선을 정수로 반올림한 거리(SkParagraph가 글자를 그리는
/// 곳 — [InkCenteredLabel] 설명), 2차원 각인이면 보고한 기준선이다. 감싸는 [DrawnBaselineLabel]이 보고하는 값은 쓰지 않고 글자
/// 상자에서 따로 잰다. 이 반올림 모델 자체는 "그린 픽셀" 그룹이 픽셀로 확인한다.

/// 각인 띠에 그린 각인 하나 (전역 좌표, dp)
typedef _BandLegend = ({
  CalcKeyId id,
  String text,
  bool plain,

  /// 글자를 실제로 그리는 기준선 (글자 상자에서 잰 값)
  double drawnBaseline,

  /// 띠 안의 자리 — 감싼 `Text`면 [DrawnBaselineLabel]의 상자, 아니면 각인 위젯의 상자
  Rect slot,

  /// 자리 위끝에서 보고한 기준선까지 (줄이기 전 dp)
  double slotBaseline,

  /// `FittedBox` 등이 줄인 비율
  double scale,

  /// 배율 반영 글자 크기 (dp)
  double fontSize,
  TextStyle style,
});

/// [box]의 전역 상자와 `FittedBox` 등이 줄인 비율
(Rect, double) _globalRect(RenderBox box) {
  final rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  return (rect, rect.height / box.size.height);
}

/// 그린 `Text`와 같은 글자·줄 상자·줄 간격 배분으로 보고한 기준선을 다시 잰다 (`main_legend_ink_center_test.dart`와 같은 방법)
double _paragraphBaseline(RenderParagraph p) {
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    strutStyle: p.strutStyle,
    textHeightBehavior: p.textHeightBehavior,
    maxLines: p.maxLines,
  )..layout();
  final b = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  painter.dispose();
  return b;
}

/// 글자 크기 [fontSize](배율 반영)인 각인 줄 상자의 기준선 아래 깊이 — 테마 없는 `TextPainter`로 잰다(`KeypadMetrics`·
/// [KeyLegendView]가 재는 방식). 앱의 `Text`가 테마의 줄 간격 배분을 받으면 이 값과 달라진다.
double _lineDescent(TextStyle style, double fontSize) {
  final sized = style.copyWith(fontSize: fontSize);
  final painter = TextPainter(
    text: TextSpan(text: ' ', style: sized),
    strutStyle: keyLabelStrut(sized),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final descent =
      painter.height -
      painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  painter.dispose();
  return descent;
}

Finder _button(CalcKeyId id) =>
    find.byWidgetPredicate((w) => w is CalcKeyButton && w.keyDef.id == id);

/// [id] 키 버튼의 각인 띠(SHIFT·ALPHA, 원형 버튼 위 인쇄)에 그린 각인들. 메인 각인([InkCenteredLabel] 안)은 뺀다.
List<_BandLegend> _bandLegends(WidgetTester tester, CalcKeyId id) {
  final found = <_BandLegend>[];
  void visit(RenderObject node) {
    if (node is RenderInkCenteredLabel) return;
    if (node is RenderParagraph) {
      final parent = node.parent;
      expect(
        parent,
        isA<RenderDrawnBaselineLabel>(),
        reason:
            '$id 각인 띠의 Text "${node.text.toPlainText()}"는 DrawnBaselineLabel로 감싸야 한다',
      );
      final (rect, scale) = _globalRect(node);
      final b = _paragraphBaseline(node);
      final style = node.text.style!;
      found.add((
        id: id,
        text: node.text.toPlainText(),
        plain: true,
        drawnBaseline: rect.top + b.roundToDouble() * scale,
        slot: _globalRect(parent! as RenderBox).$1,
        slotBaseline: b,
        scale: scale,
        fontSize: node.textScaler.scale(style.fontSize!),
        style: style,
      ));
      return;
    }
    if (node is RenderKeyLegend) {
      final (rect, scale) = _globalRect(node);
      found.add((
        id: id,
        text: node.legend.plainText,
        plain: node.legend is LegendText,
        drawnBaseline: rect.top + node.debugBaseline * scale,
        slot: rect,
        slotBaseline: node.debugBaseline,
        scale: scale,
        fontSize: node.textScaler.scale(node.style.fontSize!),
        style: node.style,
      ));
      return;
    }
    node.visitChildren(visit);
  }

  tester.renderObject(_button(id)).visitChildren(visit);
  return found;
}

Future<void> _pumpApp(
  WidgetTester tester,
  Size size,
  double textScale, {
  double pixelRatio = 2,
}) async {
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = size * pixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const ProviderScope(child: AltCalcApp()));
  await tester.pumpAndSettle();
}

/// 지금 화면의 모든 키 각인 띠를 검사하고 띠 각인 글자 크기를 돌려준다.
///
/// 같은 행(키 버튼 위끝이 같은 키들 — 측정한 각인 위치가 아니라 키 배치로 묶는다)의 띠마다:
/// 1. 모든 각인의 자리 아래끝이 같다(아래 정렬).
/// 2. 각인 글자는 자리가 보고한 기준선에 그려진다(`Text` 반올림 보정 — [DrawnBaselineLabel]).
/// 3. 한 줄 아래로 넘치지 않는 각인은 기준선 아래 깊이가 테마 없는 줄 상자의 깊이와 같다 — 그래서 그린 기준선이 모두 같다
///    (줄 간격 배분 고정 — [keyLabelStrut]).
/// 4. 넘치는 2차원 각인(`d/dx◼`·`∑◻◻◼`)은 넘친 만큼만 올라가고 그 양은 글자 크기의 0.08배 + 0.5dp 미만이다([KeyLegendView]
///    "크기·기준선" 절의 의도한 배치 — 실물 대조는 후속 이슈).
/// 띠 각인은 줄어들지 않는다 — 줄이면 아래 정렬에서 기준선이 올라가므로, 줄어드는 창이 생기면 기대값을 정해 이 검사를 넓힌다.
double _expectBandBaselines(WidgetTester tester) {
  final rows = <double, List<_BandLegend>>{};
  for (final button in tester.widgetList<CalcKeyButton>(
    find.byType(CalcKeyButton),
  )) {
    final id = button.keyDef.id;
    final top = (tester.getRect(_button(id)).top * 100).round() / 100;
    rows.putIfAbsent(top, () => []).addAll(_bandLegends(tester, id));
  }
  final all = rows.values.expand((r) => r).toList();
  expect(all, isNotEmpty);
  final fontSize = all.first.fontSize;

  var mixedRows = 0;
  for (final row in rows.values.where((r) => r.isNotEmpty)) {
    final bottom = row.first.slot.bottom;
    final baseline = bottom - _lineDescent(row.first.style, fontSize);
    for (final l in row) {
      final what = '${l.id} "${l.text}"';
      expect(
        l.fontSize,
        moreOrLessEquals(fontSize, epsilon: 1e-6),
        reason: what,
      );
      expect(
        l.scale,
        moreOrLessEquals(1.0, epsilon: 1e-6),
        reason: '$what 줄어듦',
      );
      expect(
        l.slot.bottom,
        moreOrLessEquals(bottom, epsilon: 0.01),
        reason: '$what 아래끝',
      );
      expect(
        l.drawnBaseline,
        moreOrLessEquals(l.slot.top + l.slotBaseline, epsilon: 0.01),
        reason: '$what 글자가 보고한 기준선에 그려지는지',
      );
      if (l.drawnBaseline >= baseline - 0.01) {
        expect(
          l.drawnBaseline,
          moreOrLessEquals(baseline, epsilon: 0.01),
          reason: '$what 띠 기준선',
        );
      } else {
        expect(l.plain, isFalse, reason: '$what 글자 각인은 넘치지 않는다');
        expect(
          baseline - l.drawnBaseline,
          // em 치수의 넘침(0.08em 미만) + 줄 상자 높이의 정수 반올림으로 줄 상자 깊이가 줄어드는 몫(최대 0.5dp)
          lessThan(0.08 * fontSize + 0.5),
          reason: '$what 넘친 만큼 올라간 거리',
        );
      }
    }
    final level = row.where((l) => l.drawnBaseline >= baseline - 0.01);
    if (level.any((l) => l.plain) && level.any((l) => !l.plain)) mixedRows++;
  }

  // 이슈의 실측 대상(sin·cos 키 — SHIFT 2차원 각인·ALPHA 글자 각인)이 같은 띠 기준선 검사에 들어 있어야 한다.
  for (final id in [CalcKeyId.sin, CalcKeyId.cos]) {
    final legends = all.where((l) => l.id == id).toList();
    expect(
      legends.map((l) => l.plain),
      containsAll([true, false]),
      reason: '$id',
    );
    expect(
      legends.last.drawnBaseline,
      moreOrLessEquals(legends.first.drawnBaseline, epsilon: 0.01),
      reason: '$id 두 각인',
    );
  }
  expect(mixedRows, greaterThan(0));
  return fontSize;
}

/// 키캡 위 각인 띠의 자리 [slot] 안에서, 색 [ink]로 그린 글자 잉크의 아래끝 (이미지 좌표 dp, 픽셀 이하 보간).
///
/// 바탕색은 자리의 맨 아래 픽셀 행 평균이다 — 기준선 아래 줄 상자 깊이(약 0.215em)에는 내림 획이 없는 글자(D·s·i·n)의 잉크가
/// 없다. 픽셀마다 바탕 → 잉크 색 쪽으로 얼마나 칠해졌는지(0~1)를 재고, 행마다 그 최댓값을 행의 잉크 비율로 본다. 잉크가 있는
/// 마지막 행이 r이고 그 행 비율이 c이면 잉크 아래끝은 (r + c) 물리 픽셀이다(평평한 아래끝 글자는 마지막 행이 위쪽부터 c만큼
/// 칠해진다).
double _pixelInkBottom(
  ByteData data,
  int width,
  double pixelRatio,
  Rect slot,
  Color ink,
) {
  (double, double, double) rgb(int x, int y) {
    final i = (y * width + x) * 4;
    return (
      data.getUint8(i).toDouble(),
      data.getUint8(i + 1).toDouble(),
      data.getUint8(i + 2).toDouble(),
    );
  }

  final x0 = (slot.left * pixelRatio).ceil();
  final x1 = (slot.right * pixelRatio).floor();
  final y0 = (slot.top * pixelRatio).ceil();
  final y1 = (slot.bottom * pixelRatio).floor() - 1;
  var (br, bg, bb) = (0.0, 0.0, 0.0);
  for (var x = x0; x < x1; x++) {
    final (r, g, b) = rgb(x, y1);
    br += r;
    bg += g;
    bb += b;
  }
  final n = (x1 - x0).toDouble();
  (br, bg, bb) = (br / n, bg / n, bb / n);
  final (dr, dg, db) = (ink.r * 255 - br, ink.g * 255 - bg, ink.b * 255 - bb);
  final norm = dr * dr + dg * dg + db * db;
  double coverage(int y) {
    var best = 0.0;
    for (var x = x0; x < x1; x++) {
      final (r, g, b) = rgb(x, y);
      final c = ((r - br) * dr + (g - bg) * dg + (b - bb) * db) / norm;
      if (c > best) best = c;
    }
    return best.clamp(0.0, 1.0);
  }

  for (var y = y1; y >= y0; y--) {
    final c = coverage(y);
    if (c > 0.15) return (y + c) / pixelRatio;
  }
  fail('잉크를 찾지 못했다: $slot');
}

void main() {
  setUpAll(loadBundledFonts);

  group('실제 앱의 각인 띠 기준선', () {
    const sizes = {
      '폰 360×800': Size(360, 800),
      '태블릿 800×1280': Size(800, 1280),
    };
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      testWidgets('$name 글자 배율 1.0·1.3: 같은 행 각인 띠의 글자 각인과 2차원 각인은 그린 기준선이 같다', (
        tester,
      ) async {
        await _pumpApp(tester, size, 1.0);
        final base = _expectBandBaselines(tester);
        await _pumpApp(tester, size, 1.3);
        final scaled = _expectBandBaselines(tester);
        // 글자 배율이 띠 글자 크기를 실제로 바꾸는 창이어야 배율 검사가 뜻이 있다
        expect(scaled, greaterThan(base + 0.1));
      });
    }
  });

  group('그린 픽셀', () {
    // (창, 픽셀 비) — 폰(Android 흔한 픽셀 비 3)·태블릿 세로
    for (final (size, pixelRatio) in const [
      (Size(360, 800), 3.0),
      (Size(800, 1280), 2.0),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '$size·픽셀 비 $pixelRatio·글자 배율 $scale: sin 키 SHIFT sin⁻¹과 ALPHA D의 잉크 아래끝이 같고 '
          '그린 기준선에 있다',
          (tester) async {
            await _pumpApp(tester, size, scale, pixelRatio: pixelRatio);
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
            final legends = _bandLegends(tester, CalcKeyId.sin);
            final shift = legends.singleWhere((l) => !l.plain);
            final alpha = legends.singleWhere((l) => l.text == 'D');
            double bottom(_BandLegend l, Color ink) =>
                _pixelInkBottom(
                  data,
                  image.width,
                  pixelRatio,
                  l.slot.shift(-origin),
                  ink,
                ) +
                origin.dy;
            final shiftBottom = bottom(shift, CalcTheme.shiftLabel);
            final alphaBottom = bottom(alpha, CalcTheme.alphaLabel);
            image.dispose();
            // s의 둥근 아래끝(−0.008em)과 픽셀 보간 오차를 합쳐 0.25dp — #252 전 차이(폰 0.5dp·태블릿 1.4dp)보다 작다
            expect(
              shiftBottom,
              moreOrLessEquals(alphaBottom, epsilon: 0.25),
              reason: 'sin⁻¹ $shiftBottom · D $alphaBottom',
            );
            // 평평한 아래끝 글자 D의 잉크 아래끝 = 그린 기준선 (반올림 모델 확인)
            expect(
              alphaBottom,
              moreOrLessEquals(alpha.drawnBaseline, epsilon: 0.25),
              reason: 'D 잉크 $alphaBottom · 기준선 ${alpha.drawnBaseline}',
            );
          },
        );
      }
    }
  });

  group('DrawnBaselineLabel', () {
    // 18.62dp: 기준선(약 0.785em)이 정수가 아닌 글자 크기 (#230 폰 숫자 크기)
    final style = CalcTheme.keyShiftLabelStyle.copyWith(fontSize: 18.62);

    Future<RenderDrawnBaselineLabel> pump(
      WidgetTester tester,
      Widget child,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: DrawnBaselineLabel(child: child)),
        ),
      );
      return tester.renderObject<RenderDrawnBaselineLabel>(
        find.byType(DrawnBaselineLabel),
      );
    }

    testWidgets('Text는 반올림 차만큼 옮겨 보고한 기준선에 그리고, 크기·보고한 기준선은 그대로다', (
      tester,
    ) async {
      final render = await pump(
        tester,
        Text('D', style: style, strutStyle: keyLabelStrut(style)),
      );
      final child = render.child! as RenderParagraph;
      final b = _paragraphBaseline(child);
      expect((b - b.roundToDouble()).abs(), greaterThan(0.05));
      expect(
        render.shift,
        moreOrLessEquals(b - b.roundToDouble(), epsilon: 1e-9),
      );
      expect(render.size, child.size);
      final constraints = BoxConstraints.loose(const Size(400, 400));
      expect(render.getDryLayout(constraints), child.getDryLayout(constraints));
      expect(
        render.getDryBaseline(constraints, TextBaseline.alphabetic),
        moreOrLessEquals(b, epsilon: 1e-6),
      );
      // 글자 상자 위끝 + 반올림 기준선(그린 곳) = 감싼 상자 위끝 + 보고한 기준선
      expect(
        child.localToGlobal(Offset.zero).dy + b.roundToDouble(),
        moreOrLessEquals(
          render.localToGlobal(Offset.zero).dy + b,
          epsilon: 1e-6,
        ),
      );
    });

    testWidgets('2차원 각인은 보고한 기준선에 그리므로 옮기지 않는다', (tester) async {
      final render = await pump(
        tester,
        KeyLegendView(
          legend: keyDefOf(CalcKeyId.sin).shiftLegend!,
          style: style,
        ),
      );
      expect(render.shift, 0.0);
    });

    testWidgets('Text가 RenderParagraph를 감싸개(Semantics)로 감싸도 반올림을 보정한다', (
      tester,
    ) async {
      final render = await pump(
        tester,
        Text(
          'D',
          style: style,
          strutStyle: keyLabelStrut(style),
          semanticsLabel: 'D',
        ),
      );
      expect(render.child, isNot(isA<RenderParagraph>()));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final b = _paragraphBaseline(paragraph);
      expect(
        render.shift,
        moreOrLessEquals(b - b.roundToDouble(), epsilon: 1e-9),
      );
      expect(render.shift, isNot(0.0));
    });
  });
}
