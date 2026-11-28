import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/release_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
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
///
/// 한 줄 상자 아래로 잉크가 넘치는 2차원 각인(`d/dx◼`·`∑◻◻◼`)은 이웃과 기준선을 함께 쓰지 않는다 (#260). 실물은 그 각인의 잉크
/// 아래끝(분모 `dx`·아래 끝 칸)을 이웃 각인 기준선에 두고 같은 키의 짝 각인 `:`도 함께 올려 인쇄한다([CalcTheme] "2차원 각인 배치"
/// 절의 사진 실측). 앱도 그렇게 올린다([KeyLegendView.bandLifts]) — #260 전에는 아래 정렬만 해, 넘친 만큼만
/// (글자 배율 1.3에서 360×800 폰 0.94dp·800×1280 태블릿 1.20dp) 올라가고 분모·아래 끝 칸이 키캡 위끝에 닿아 있었다. #260은
/// 각인 띠 위쪽 여유까지만 올려 폰에서는 다 올라가지 못했고, #264부터는 키 사이 세로 간격까지 써서 키패드의 모든 창에서 다
/// 올라간다([_Raise.full]). 여유만큼만·올리지 못한 경우([_Raise.partial]·[_Raise.none])는 키패드 밖의 키 버튼에만 남는다.

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

  /// 2차원 각인이면 그 각인 (글자 각인은 `null`)
  KeyLegend? legend,

  /// 각인을 놓을 수 있는 자리의 위끝 (전역 좌표, dp) — 키 버튼의 각인 띠 위끝에서 키 사이 세로 간격만큼 위(#264. 키패드 밖의
  /// 키 버튼은 간격 몫이 없어 띠 위끝 그대로다)
  double bandTop,

  /// 아래 정렬한 각인 줄 상자의 아래끝 (전역 좌표, dp) — 키캡 위끝([keycapTop])에서 키 버튼의 `legendBaseLift`만큼 위(#264.
  /// 올리지 않는 키 버튼은 키캡 위끝 그대로다)
  double bandBottom,

  /// 키캡 위끝 = 각인 띠 아래끝 (전역 좌표, dp)
  double keycapTop,
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
  final button = tester.widget<CalcKeyButton>(_button(id));
  final cell = tester.getRect(_button(id));
  final keycapTop = cell.top + button.legendBandHeightFor(cell.height);
  final bandTop =
      cell.top - (button.hitShape == null ? 2 * button.gapInsets.top : 0.0);
  final bandBottom = keycapTop - button.legendBaseLift;
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
        legend: null,
        bandTop: bandTop,
        bandBottom: bandBottom,
        keycapTop: keycapTop,
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
        legend: node.legend,
        bandTop: bandTop,
        bandBottom: bandBottom,
        keycapTop: keycapTop,
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

  /// 각인 띠에 인쇄할 기능 (#267) — 기본은 앱 그대로(배포 목록). 실물 인쇄 전체를 보려면 [allKeyFeatures]를 준다.
  Set<KeyFeature>? released,
}) async {
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = size * pixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      // override는 늘 둔다 — 한 테스트 안에서 값을 바꿔 다시 띄울 수 있게(override를 나중에 더하는 것은 받지 않는다)
      overrides: [
        releasedKeyFeaturesProvider.overrideWithValue(
          released ?? releasedKeyFeatures,
        ),
      ],
      child: const AltCalcApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// 넘치는 각인을 띠에서 올린 결과 (#260)
enum _Raise {
  /// 잉크 아래끝이 띠 기준선(이웃 각인 기준선)에 있다 — 실물과 같은 자리
  full,

  /// 띠 위쪽 여유가 모자라 각인 위끝이 띠 위끝에 닿을 때까지만 올렸다 — 잉크 아래끝은 띠 기준선과 띠 아래끝 사이다
  partial,

  /// 각인이 띠를 꽉 채워 올리지 못했다 — 아래 정렬 그대로(#260 전과 같다. 넘친 깊이만큼만 이웃보다 위)
  none,
}

/// 지금 화면의 모든 키 각인 띠를 검사하고, 띠 각인 글자 크기와 넘치는 각인(한 줄 표기)별 올린 결과를 돌려준다.
///
/// 같은 행(키 버튼 위끝이 같은 키들 — 측정한 각인 위치가 아니라 키 배치로 묶는다)의 띠마다:
/// 1. 각인 글자는 자리가 보고한 기준선에 그려진다(`Text` 반올림 보정 — [DrawnBaselineLabel]).
/// 2. 한 줄 아래로 넘치는 각인([KeyLegendView.overhangsLine])이 없는 키의 각인은 모두 자리 아래끝이 띠 아래끝이고(아래 정렬),
///    기준선 아래 깊이가 테마 없는 줄 상자의 깊이와 같다 — 그래서 그린 기준선이 모두 띠 기준선으로 같다(줄 간격 배분 고정 —
///    [keyLabelStrut]).
/// 3. 넘치는 각인은 [_overflowingLegends]뿐이다. 그 각인이 있는 키는(#260):
///    - 키의 모든 각인(짝 각인 `:` 포함)이 그린 기준선을 함께 쓰고, 띠 기준선보다 위다.
///    - 넘치는 각인의 잉크 아래끝(잉크 범위 표로 잰 em 치수 × 글자 크기)이 띠 기준선에 있거나([_Raise.full]), 띠 위쪽 여유가
///      모자라 각인 위끝이 띠 위끝에 닿아 있고 잉크 아래끝은 띠 기준선과 띠 아래끝 사이에 있다([_Raise.partial] — 자리 아래끝까지
///      띠 아래끝이면 [_Raise.none]).
///    - 어느 각인도 띠 밖으로 나가지 않는다.
/// 띠 각인은 줄어들지 않는다 — 줄이면 아래 정렬에서 기준선이 올라가므로, 줄어드는 창이 생기면 기대값을 정해 이 검사를 넓힌다.
(double, Map<String, _Raise>) _expectBandBaselines(WidgetTester tester) {
  // 행 — 키 버튼 위끝을 정렬해 앞 키와 0.01dp 안이면 같은 행으로 묶는다(반올림 구간 경계에서 갈리지 않게)
  final tops = [
    for (final button in tester.widgetList<CalcKeyButton>(
      find.byType(CalcKeyButton),
    ))
      (button.keyDef.id, tester.getRect(_button(button.keyDef.id)).top),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  // 행마다 키별 각인 묶음
  final rows = <List<List<_BandLegend>>>[];
  double? lastTop;
  for (final (id, top) in tops) {
    if (lastTop == null || top - lastTop > 0.01) rows.add([]);
    lastTop = top;
    final legends = _bandLegends(tester, id);
    if (legends.isNotEmpty) rows.last.add(legends);
  }
  final all = rows.expand((r) => r).expand((k) => k).toList();
  expect(all, isNotEmpty);
  final fontSize = all.first.fontSize;

  bool overhangs(_BandLegend l) =>
      l.legend != null && KeyLegendView.overhangsLine(l.legend!, l.style);

  var mixedRows = 0;
  final raised = <String, _Raise>{};
  for (final row in rows.where((r) => r.isNotEmpty)) {
    final bottom = row.first.first.bandBottom;
    final baseline = bottom - _lineDescent(row.first.first.style, fontSize);
    final level = <_BandLegend>[];
    for (final key in row) {
      for (final l in key) {
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
          l.bandBottom,
          moreOrLessEquals(bottom, epsilon: 0.01),
          reason: '$what 띠 아래끝',
        );
        expect(
          l.drawnBaseline,
          moreOrLessEquals(l.slot.top + l.slotBaseline, epsilon: 0.01),
          reason: '$what 글자가 보고한 기준선에 그려지는지',
        );
        expect(
          l.slot.top,
          greaterThanOrEqualTo(l.bandTop - 0.01),
          reason: '$what 띠 위로 나감',
        );
        expect(
          l.slot.bottom,
          lessThanOrEqualTo(bottom + 0.01),
          reason: '$what 띠 아래로 나감',
        );
      }
      final over = key.where(overhangs).toList();
      if (over.isEmpty) {
        for (final l in key) {
          final what = '${l.id} "${l.text}"';
          expect(
            l.slot.bottom,
            moreOrLessEquals(bottom, epsilon: 0.01),
            reason: '$what 아래끝',
          );
          expect(
            l.drawnBaseline,
            moreOrLessEquals(baseline, epsilon: 0.01),
            reason: '$what 띠 기준선',
          );
        }
        level.addAll(key);
        continue;
      }
      // 넘치는 각인이 있는 키 (#260)
      final o = over.single;
      final what = '${o.id} "${o.text}"';
      expect(
        _overflowingLegends,
        contains(o.text),
        reason: '$what 넘치지 않아야 할 각인',
      );
      for (final l in key) {
        expect(
          l.drawnBaseline,
          moreOrLessEquals(o.drawnBaseline, epsilon: 0.01),
          reason: '$what 와 짝 각인 "${l.text}"의 기준선',
        );
      }
      final inkBottom =
          o.drawnBaseline -
          KeyLegendView.emMetrics(o.legend!, o.style).inkBottom * fontSize;
      if ((inkBottom - baseline).abs() <= 0.01) {
        raised[o.text] = _Raise.full;
        expect(o.drawnBaseline, lessThan(baseline - 0.01), reason: '$what 올림');
      } else {
        final none = bottom - o.slot.bottom <= 0.01;
        raised[o.text] = none ? _Raise.none : _Raise.partial;
        // 여유가 없으면 아래 정렬 그대로다 — 넘친 깊이만큼만 위이고, 줄 상자 높이 반올림으로 한 줄 상자가 잉크보다 깊은 글자
        // 크기에서는 이웃과 같은 기준선이다(R2). 어느 쪽이든 띠 기준선보다 아래로 내려가지는 않는다.
        expect(
          o.drawnBaseline,
          none ? lessThanOrEqualTo(baseline + 0.01) : lessThan(baseline - 0.01),
          reason: '$what 올림',
        );
        expect(
          o.slot.top,
          moreOrLessEquals(o.bandTop, epsilon: 0.01),
          reason:
              '$what 잉크 아래끝이 띠 기준선보다 ${inkBottom - baseline}dp 아래인데 띠 위에 여유가 남았다',
        );
        expect(
          inkBottom,
          inInclusiveRange(baseline, bottom + 0.01),
          reason: '$what 잉크 아래끝',
        );
      }
    }
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
  // 넘치는 각인은 줄 상자 높이 반올림과 상관없이(em 치수 판정) 어느 창에서나 둘 다 올린다.
  expect(raised.keys, unorderedEquals(_overflowingLegends.keys));
  return (fontSize, raised);
}

/// 각인 띠에서 한 줄 상자 아래로 잉크가 넘치는 각인 (한 줄 표기 → 각인) — 분모·아래 끝 칸이 기준선 아래로 내려간다.
/// 그 밖의 각인이 넘치면 띠 기준선 검사가 실패한다.
///
/// 이 각인이 있는 키(∫·x)는 각인을 키 사이 세로 간격의 위 키 쪽 절반까지 올릴 수 있다(#264). 두 키 모두 위 키가 원형 버튼
/// (MENU·SETUP)이라 그 셀 아래쪽이 비어 있다 — 키캡(그림자가 셀 아래로 번진다) 아래의 키에 넘치는 각인이 생기면 올리는
/// 한도를 다시 정해야 한다("넘치는 각인이 있는 키의 위 키는 원형 버튼이다" 검사).
final Map<String, KeyLegend> _overflowingLegends = {
  for (final id in CalcKeyId.values)
    if (keyDefOf(id).printedShiftLegend case final l?
        when l.plainText == 'd/dx◼' || l.plainText.startsWith('∑'))
      l.plainText: l,
};

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

/// 영역 [area] 안에서 색 [ink]로 그린 잉크의 세로 범위 (위끝, 아래끝 — 이미지 좌표 dp, 픽셀 이하 보간).
///
/// 바탕색은 영역 맨 위 픽셀 행의 평균이다(잉크가 없는 행이어야 한다). [_pixelInkBottom]과 같은 방식으로 행마다 잉크 비율을
/// 재고, 잉크가 있는 첫 행·마지막 행의 비율로 끝을 보간한다.
(double, double) _pixelInkSpan(
  ByteData data,
  int width,
  double pixelRatio,
  Rect area,
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

  final x0 = (area.left * pixelRatio).ceil();
  final x1 = (area.right * pixelRatio).floor();
  final y0 = (area.top * pixelRatio).ceil();
  final y1 = (area.bottom * pixelRatio).floor() - 1;
  var (br, bg, bb) = (0.0, 0.0, 0.0);
  for (var x = x0; x < x1; x++) {
    final (r, g, b) = rgb(x, y0);
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

  double? top;
  double? bottom;
  for (var y = y0; y <= y1; y++) {
    final c = coverage(y);
    if (c <= 0.15) continue;
    // 바탕색을 잰 맨 위 행에는 잉크가 없어야 한다 (있으면 바탕색이 틀렸다)
    if (y == y0) fail('영역 맨 위 행에 잉크가 있다: $area');
    top ??= (y + 1 - c) / pixelRatio;
    bottom = (y + c) / pixelRatio;
  }
  if (top == null || bottom == null) fail('잉크를 찾지 못했다: $area');
  return (top, bottom);
}

void main() {
  setUpAll(loadBundledFonts);

  group('실제 앱의 각인 띠 기준선', () {
    // (이름, 창, 글자 배율 1.3이 띠 글자를 키우는지, `d/dx◼`를 올린 결과 — 글자 배율 1.0·1.3) — 세로 폰·태블릿과 가로형(넓은 배열).
    // 넘치는 각인(#260)을 사진과 같은 자리까지 올리려면 각인 위쪽 여유가 넘친 잉크 깊이(약 0.28em) 이상이어야 한다.
    // #264 전에는 각인이 각인 띠 안에만 놓여 폰은 여유만큼만 올라갔다(360×800 `d/dx◼` 잉크 아래끝이 띠 기준선보다 0.98dp
    // 아래, 가로 폰 글자 배율 1.3은 올리지 못했다). #264부터 각인은 키 사이 세로 간격까지 쓸 수 있어, 아래 창 모두 사진과
    // 같은 자리(잉크 아래끝이 이웃 각인 기준선)까지 올라간다.
    for (final (name, size, scales, raise, scaledRaise) in const [
      ('폰 360×800', Size(360, 800), true, _Raise.full, _Raise.full),
      ('작은 폰 320×568', Size(320, 568), true, _Raise.full, _Raise.full),
      ('태블릿 800×1280', Size(800, 1280), true, _Raise.full, _Raise.full),
      ('가로 폰 800×360', Size(800, 360), false, _Raise.full, _Raise.full),
      ('가로 태블릿 1280×800', Size(1280, 800), false, _Raise.full, _Raise.full),
    ]) {
      testWidgets('$name 글자 배율 1.0·1.3: 같은 행 각인 띠의 글자 각인과 2차원 각인은 그린 기준선이 같고, '
          '한 줄 아래로 넘치는 각인은 짝 각인과 함께 띠 위쪽 여유만큼 올라가 있다', (tester) async {
        // `d/dx◼`(가장 높은 SHIFT 각인)의 결과를 고정한다. `∑◻◻◼`는 조금 낮아 여유가 조금 더 있다 — 사진과 같은 자리인지만
        // `d/dx◼`와 같아야 한다.
        void expectRaise(Map<String, _Raise> raised, _Raise expected) {
          expect(raised['d/dx◼'], expected, reason: '$raised');
          expect(
            raised['∑◻◻◼'] == _Raise.full,
            expected == _Raise.full,
            reason: '$raised',
          );
        }

        await _pumpApp(tester, size, 1.0);
        final (base, baseRaised) = _expectBandBaselines(tester);
        expectRaise(baseRaised, raise);
        await _pumpApp(tester, size, 1.3);
        final (scaled, scaledRaised) = _expectBandBaselines(tester);
        expectRaise(scaledRaised, scaledRaise);
        // 세로 창은 글자 배율이 띠 글자 크기를 실제로 바꿔야 배율 검사가 뜻이 있다
        if (scales) expect(scaled, greaterThan(base + 0.1));

        // 실물 인쇄 전체(#267 — 배포 전이라 숨긴 Base-N의 파랑 각인·괄호, `QR`까지 그린 화면)에서도 같다. 숨긴 각인은
        // 띠 글자 크기를 바꾸지 않는다
        await _pumpApp(tester, size, 1.0, released: allKeyFeatures);
        expect(find.text('DEC'), findsOneWidget);
        final (full, fullRaised) = _expectBandBaselines(tester);
        expectRaise(fullRaised, raise);
        expect(full, moreOrLessEquals(base, epsilon: 1e-9));
        await _pumpApp(tester, size, 1.3, released: allKeyFeatures);
        final (fullScaled, fullScaledRaised) = _expectBandBaselines(tester);
        expectRaise(fullScaledRaised, scaledRaise);
        expect(fullScaled, moreOrLessEquals(scaled, epsilon: 1e-9));
      });
    }
  });

  group('그린 픽셀', () {
    // (창, 픽셀 비, 글자 배율) — `Text`의 반올림 차(띠 각인을 옮긴 거리)가 0.3dp 넘는 구성만 쓴다(#252 R2 — 차가 작으면 보정이
    // 없어도 허용 오차 안이라 검사가 구별하지 못한다). 폰 +0.49dp·600×960 −0.49dp로 옮기는 방향도 서로 반대다(#264에서 각인
    // 글자 크기가 바뀌어 구성을 다시 골랐다).
    for (final (size, pixelRatio, scale) in const [
      (Size(360, 800), 3.0, 1.3),
      (Size(600, 960), 2.0, 1.3),
    ]) {
      {
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
            final moved = tester
                .renderObject<RenderDrawnBaselineLabel>(
                  find.descendant(
                    of: _button(CalcKeyId.sin),
                    matching: find.byType(DrawnBaselineLabel),
                  ),
                )
                .shift;
            expect(moved.abs(), greaterThan(0.3), reason: '옮긴 거리 $moved');
            final palette = CalcPalette.of(
              tester.element(_button(CalcKeyId.sin)),
            );
            double bottom(_BandLegend l, Color ink) =>
                _pixelInkBottom(
                  data,
                  image.width,
                  pixelRatio,
                  l.slot.shift(-origin),
                  ink,
                ) +
                origin.dy;
            final shiftBottom = bottom(shift, palette.shiftLabel);
            final alphaBottom = bottom(alpha, palette.alphaLabel);
            image.dispose();
            // s의 둥근 아래끝(−0.008em — #264부터 각인 글자가 커서 태블릿은 약 0.2dp)과 픽셀 보간 오차 0.15dp — 보정이
            // 없으면 옮긴 거리(0.49dp)만큼 더 어긋난다
            expect(
              shiftBottom,
              moreOrLessEquals(
                alphaBottom,
                epsilon: 0.008 * shift.fontSize + 0.15,
              ),
              reason: 'sin⁻¹ $shiftBottom · D $alphaBottom',
            );
            // 평평한 아래끝 글자 D의 잉크 아래끝 = 그린 기준선 (반올림 모델 확인 — "보고한 기준선에 그린다"는 반대 모델이면
            // 옮긴 거리만큼 어긋난다)
            expect(
              alphaBottom,
              moreOrLessEquals(alpha.drawnBaseline, epsilon: 0.15),
              reason: 'D 잉크 $alphaBottom · 기준선 ${alpha.drawnBaseline}',
            );
          },
        );
      }
    }
  });

  group('그린 픽셀 — 모드 전용 각인의 괄호 (#266)', () {
    // 괄호(`LegendBracketPainter`)는 글자와 따로 그린다 — 글자를 실제로 그린 기준선에 걸쳐 있는지 픽셀로 본다.
    // 앞의 두 구성은 위 "그린 픽셀" 그룹과 같다(`Text`를 옮겨 그리는 거리가 0.3dp를 넘는 구성 — 괄호가 옮긴 뒤의 글자 자리를
    // 기준으로 삼으면 그만큼 어긋나 허용 오차 0.2dp를 넘는다).
    // (창, 픽셀 비, 글자 배율, `Text`를 옮긴 거리가 커야 하는 구성인지)
    for (final (size, pixelRatio, scale, moved) in const [
      (Size(360, 800), 3.0, 1.3, true),
      (Size(600, 960), 2.0, 1.3, true),
      (Size(800, 1280), 2.0, 1.0, false),
    ]) {
      // (키, 괄호 안 각인, 실물 치수가 그대로 그려지는지) — sin 키 `D`(파란 괄호)와 ENG 키 `∠`(보라 괄호, 높이 1.33배)
      for (final (id, text) in const [
        (CalcKeyId.sin, 'D'),
        (CalcKeyId.eng, '∠'),
      ]) {
        testWidgets(
          '$size·픽셀 비 $pixelRatio·글자 배율 $scale: ${id.name} 키 $text의 괄호가 그린 기준선을 실물 비율로 걸친다',
          (tester) async {
            // sin 키 `D`의 파란 괄호(Base-N)는 배포 전이라 숨긴다(#267) — 실물 인쇄 전체를 그려 놓고 본다.
            // ENG 키 `∠`의 보라 괄호(Complex)는 배포 목록 그대로의 화면에서 본다.
            await _pumpApp(
              tester,
              size,
              scale,
              pixelRatio: pixelRatio,
              released: id == CalcKeyId.sin ? allKeyFeatures : null,
            );
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
            final legend = _bandLegends(
              tester,
              id,
            ).singleWhere((l) => l.text == text);
            final brackets = find.descendant(
              of: _button(id),
              matching: find.byType(LegendBrackets),
            );
            final box = tester.getRect(brackets);
            final widget = tester.widget<LegendBrackets>(brackets);
            if (moved) {
              final shift = tester
                  .renderObject<RenderDrawnBaselineLabel>(
                    find.descendant(
                      of: brackets,
                      matching: find.byType(DrawnBaselineLabel),
                    ),
                  )
                  .shift;
              expect(shift.abs(), greaterThan(0.3), reason: '옮긴 거리 $shift');
            }
            final palette = CalcPalette.of(tester.element(_button(id)));
            final fontSize = legend.fontSize;
            final hook = fontSize * CalcTheme.keyLegendBracketHook;
            // 왼쪽 괄호(상자 왼쪽 끝의 가로 획 폭)와 오른쪽 괄호의 세로 범위 — 줄 상자 위끝부터 키캡 위끝까지 훑는다
            (double, double) span(double left) {
              final (top, bottom) = _pixelInkSpan(
                data,
                image.width,
                pixelRatio,
                Rect.fromLTRB(
                  left,
                  box.top,
                  left + hook,
                  legend.keycapTop,
                ).shift(-origin),
                widget.color,
              );
              return (top + origin.dy, bottom + origin.dy);
            }

            expect(
              widget.color,
              id == CalcKeyId.eng ? palette.complexLabel : palette.baseNLabel,
            );
            final (leftTop, leftBottom) = span(box.left);
            final (rightTop, rightBottom) = span(box.right - hook);
            image.dispose();
            final reason =
                '왼쪽 $leftTop~$leftBottom · 오른쪽 $rightTop~$rightBottom · 기준선 ${legend.drawnBaseline} · '
                '글자 $fontSize · 키캡 위끝 ${legend.keycapTop}';
            const eps = 0.2; // 픽셀 보간 오차
            // 두 괄호의 높이가 같다
            expect(
              leftTop,
              moreOrLessEquals(rightTop, epsilon: eps),
              reason: reason,
            );
            expect(
              leftBottom,
              moreOrLessEquals(rightBottom, epsilon: eps),
              reason: reason,
            );
            // 위끝: 그린 기준선 위 실물 비율 (`∠`는 글리프 배율만큼 높다)
            final heightScale = id == CalcKeyId.eng
                ? CalcTheme.keyGlyphScale('∠')
                : 1.0;
            expect(
              legend.drawnBaseline - leftTop,
              moreOrLessEquals(
                fontSize * CalcTheme.keyLegendBracketRise * heightScale,
                epsilon: eps,
              ),
              reason: reason,
            );
            // 아래끝: 그린 기준선 아래 실물 비율 — 키캡 위끝 가까이에서는 그 앞에서 멈춘다. `∠`는 모든 화면에서 멈춘다
            // (CalcTheme "모드 전용 각인의 괄호" 절 — 실물 치수가 그대로 그려지는 깊이는 painter 단위 테스트가 고정한다)
            final drop = leftBottom - legend.drawnBaseline;
            final full =
                fontSize * CalcTheme.keyLegendBracketDrop * heightScale;
            final room =
                legend.keycapTop -
                legend.drawnBaseline -
                fontSize * CalcTheme.keyLegendBracketKeyGap;
            expect(
              drop,
              moreOrLessEquals(full < room ? full : room, epsilon: eps),
              reason: reason,
            );
            if (id == CalcKeyId.eng) {
              expect(room, lessThan(full - eps), reason: reason);
            }
            expect(drop, greaterThan(0.5 * full), reason: reason);
            expect(leftBottom, lessThan(legend.keycapTop), reason: reason);
          },
        );
      }
    }
  });

  group('그린 픽셀 — 넘치는 각인 (#260)', () {
    // 태블릿(띠에 여유가 있는 창): 실물처럼 `d/dx◼`의 분모 `dx` 아래끝과 `∑◻◻◼`의 아래 끝 칸 아래끝이 같은 행 `SOLVE`의 잉크
    // 아래끝(기준선)과 같은 높이에 그려지고, 짝 각인 `:`은 그만큼 올라가 있다.
    testWidgets(
      '800×1280: d/dx◼의 dx·∑ 아래 끝 칸의 잉크 아래끝이 같은 행 SOLVE의 기준선에 있고, 짝 각인 :도 올라가 있다',
      (tester) async {
        const pixelRatio = 2.0;
        await _pumpApp(
          tester,
          const Size(800, 1280),
          1.0,
          pixelRatio: pixelRatio,
        );
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
        final palette = CalcPalette.of(tester.element(_button(CalcKeyId.calc)));
        _BandLegend only(CalcKeyId id, bool Function(_BandLegend l) test) =>
            _bandLegends(tester, id).singleWhere(test);
        final solve = only(CalcKeyId.calc, (l) => l.text == 'SOLVE');
        final derivative = only(CalcKeyId.integral, (l) => l.text == 'd/dx◼');
        final colon = only(CalcKeyId.integral, (l) => l.text == ':');
        final sum = only(CalcKeyId.variableX, (l) => l.text.startsWith('∑'));
        // 넘치는 각인은 잉크가 자리 아래끝까지 내려가므로, 바탕색을 재는 맨 아래 픽셀 행이 잉크 아래에 오게 자리를 띠
        // 아래끝까지 넓힌다(올린 뒤라 그 사이는 비어 있다).
        double bottom(_BandLegend l, Color ink) =>
            _pixelInkBottom(
              data,
              image.width,
              pixelRatio,
              Rect.fromLTRB(
                l.slot.left,
                l.slot.top,
                l.slot.right,
                l.keycapTop,
              ).shift(-origin),
              ink,
            ) +
            origin.dy;
        final solveBottom = bottom(solve, palette.shiftLabel);
        final derivativeBottom = bottom(derivative, palette.shiftLabel);
        final sumBottom = bottom(sum, palette.shiftLabel);
        final colonBottom = bottom(colon, palette.alphaLabel);
        image.dispose();
        // S·O의 둥근 아래끝(−0.008em)·d의 둥근 아래끝과 픽셀 보간 오차를 합쳐 0.25dp — #260 전에는 dx 아래끝이 SOLVE 기준선보다
        // 한 줄 상자 깊이(11dp 글자에서 약 2.4dp)만큼 아래였다
        expect(
          derivativeBottom,
          moreOrLessEquals(solveBottom, epsilon: 0.25),
          reason: 'dx $derivativeBottom · SOLVE $solveBottom',
        );
        expect(
          sumBottom,
          moreOrLessEquals(solveBottom, epsilon: 0.25),
          reason: '∑ 아래 끝 칸 $sumBottom · SOLVE $solveBottom',
        );
        // `:`의 아래 점 아래끝(= 올린 기준선)은 d/dx◼의 잉크 깊이(0.278em ≈ 3.1dp)만큼 SOLVE 기준선보다 위다
        final inkDepth =
            -KeyLegendView.emMetrics(
              derivative.legend!,
              derivative.style,
            ).inkBottom *
            derivative.fontSize;
        expect(inkDepth, greaterThan(2.5));
        expect(
          solveBottom - colonBottom,
          moreOrLessEquals(inkDepth, epsilon: 0.3),
          reason: ': $colonBottom · SOLVE $solveBottom',
        );
      },
    );

    // 폰: #264부터 각인이 키 사이 간격까지 쓸 수 있어 폰에서도 태블릿처럼 다 올라간다(#264 전에는 각인 위끝이 띠 위끝에
    // 닿을 때까지만 올라가 `dx`가 SOLVE 기준선보다 0.98dp 아래였다). 넘치는 각인은 상자 아래끝이 잉크 아래끝이므로, 그린 `dx`
    // 아래끝이 각인 상자 아래끝(잉크 범위 표가 아니라 배치에서 잰 값)에 있는지 픽셀로 본다 — 잉크 범위 표가 틀리면 띠 기준선
    // 검사(표로 잰 잉크 아래끝)는 함께 틀려도 이 검사는 어긋난다.
    testWidgets(
      '360×800·픽셀 비 3: d/dx◼의 dx 잉크 아래끝이 각인 상자 아래끝이고, 키캡 위끝에서 띄운 SOLVE 기준선에 있다',
      (tester) async {
        const pixelRatio = 3.0;
        await _pumpApp(
          tester,
          const Size(360, 800),
          1.0,
          pixelRatio: pixelRatio,
        );
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
        final palette = CalcPalette.of(tester.element(_button(CalcKeyId.calc)));
        final solve = _bandLegends(
          tester,
          CalcKeyId.calc,
        ).singleWhere((l) => l.text == 'SOLVE');
        final derivative = _bandLegends(
          tester,
          CalcKeyId.integral,
        ).singleWhere((l) => l.text == 'd/dx◼');
        double bottom(_BandLegend l) =>
            _pixelInkBottom(
              data,
              image.width,
              pixelRatio,
              Rect.fromLTRB(
                l.slot.left,
                l.slot.top,
                l.slot.right,
                l.keycapTop,
              ).shift(-origin),
              palette.shiftLabel,
            ) +
            origin.dy;
        final solveBottom = bottom(solve);
        final derivativeBottom = bottom(derivative);
        image.dispose();
        expect(
          derivativeBottom,
          moreOrLessEquals(derivative.slot.bottom, epsilon: 0.2),
          reason: 'dx $derivativeBottom · 상자 아래끝 ${derivative.slot.bottom}',
        );
        // S·O·d의 둥근 아래끝과 픽셀 보간 오차를 합쳐 0.25dp
        expect(
          derivativeBottom,
          moreOrLessEquals(solveBottom, epsilon: 0.25),
          reason: 'dx $derivativeBottom · SOLVE $solveBottom',
        );
        // 기준선은 키캡 위끝에서 행 간격의 0.1만큼 위다 (360×800 약 4.6dp — #264 전에는 줄 상자 깊이 약 1.9dp)
        expect(derivative.keycapTop - solveBottom, inInclusiveRange(4.2, 5.0));
        // 각인 띠 위끝을 넘어 키 사이 간격에 그려지되, 위 키와의 간격 안이다
        expect(derivative.slot.top, greaterThanOrEqualTo(derivative.bandTop));
      },
    );
  });

  test('넘치는 각인이 있는 키의 위 키는 원형 버튼이다 (#264 — 위 키 쪽 간격까지 올려도 키캡·그림자와 겹치지 않는다)', () {
    // 키 버튼과 같은 판정으로 모은다 — SHIFT·ALPHA 각인 가운데 하나라도 한 줄 아래로 넘치는 키.
    // 명세 전체(실물 인쇄)를 본다 — 배포 전이라 숨긴 각인(#267)이 되살아날 때도 이 불변식이 지켜져야 한다
    final overhanging = [
      for (final def in allKeys)
        if ([
          (def.printedShiftLegend, CalcTheme.keyShiftLabelStyle),
          (def.alphaLegend, CalcTheme.keyAlphaLabelStyle),
        ].any((e) => e.$1 != null && KeyLegendView.overhangsLine(e.$1!, e.$2)))
          def,
    ];
    // 모드 전용 각인(#266)에는 넘치는 각인이 없다 — 키 버튼은 각인 띠 목록 전체로 판정한다
    expect([
      for (final def in allKeys)
        if (def.printedBandLegends.any(
          (b) => KeyLegendView.overhangsLine(b.legend, bandLegendStyle(b)),
        ))
          def.id,
    ], overhanging.map((d) => d.id));
    expect(
      overhanging.map((d) => d.printedShiftLegend?.plainText),
      unorderedEquals(_overflowingLegends.keys),
    );
    // 화면의 열 맞춤 — 상단 조작부 두 행(왼쪽 2열·커서 패드 2열·오른쪽 2열)과 함수부가 한 블록이다. 숫자부는 구역 사이
    // 간격으로 떨어진 다른 블록이라 위 키가 없는 것으로 본다.
    final block = <List<CalcKeyDef?>>[
      for (final (r, left) in controlLeftRows.indexed)
        [...left, null, null, ...controlRightRows[r]],
      ...functionRows,
    ];
    for (final def in overhanging) {
      final where = [
        for (final (r, row) in block.indexed)
          for (final (c, cell) in row.indexed)
            if (cell?.id == def.id) (r, c),
      ];
      if (where.length != 1 || where.single.$1 == 0) {
        fail(
          '${def.id.name}: 넘치는 각인이 있는 키가 상단 조작부·함수부 블록의 둘째 행 아래에 있지 않다 '
          '($where) — 위 키 쪽 간격까지 올려도 되는지(CalcKeyButton의 legendFullReach) 다시 정해야 한다',
        );
      }
      final (row, column) = where.single;
      final above = block[row - 1][column];
      expect(
        above?.face,
        KeyFace.roundButton,
        reason:
            '${def.id.name} 위 키 ${above?.id.name} — 키캡이면 그림자가 셀 아래로 번져 올린 각인과 겹칠 수 있다',
      );
    }
  });

  group('각인 기준선과 키캡 사이 (#264)', () {
    // 실물은 키 위 각인이 키에 붙어 있지 않다 — 각인 줄을 띠 아래끝에서 올려 기준선을 키캡 위끝에서 함수부 행 간격의
    // [CalcTheme.keyLegendBaselineGapRatio]만큼 띄운다. 모든 키가 같은 거리라 구역이 달라도(숫자부는 키캡이 더 높다) 같다.
    // 각인 글자 크기를 정할 때 올릴 자리를 먼저 떼므로 글자 배율 1.3에서도 같은 거리다 — 짧은 창·넓은 배열의 낮은 키패드
    // (360×420·640×300)는 떼지 않으면 올림이 0이 된다(#264 R1).
    for (final (name, size) in const [
      ('폰 360×800', Size(360, 800)),
      ('작은 폰 320×568', Size(320, 568)),
      ('태블릿 800×1280', Size(800, 1280)),
      ('가로 폰 800×360', Size(800, 360)),
      ('가로 태블릿 1280×800', Size(1280, 800)),
      ('짧은 창 360×420', Size(360, 420)),
      ('낮은 가로 창 640×300', Size(640, 300)),
      ('Fold 내부 841×701', Size(841, 701)),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$name 글자 배율 $scale: 키 위 각인의 기준선이 키캡 위끝에서 같은 거리만큼 떠 있다', (
          tester,
        ) async {
          await _pumpApp(tester, size, scale);
          final keypad = tester.widget<CalcKeypad>(find.byType(CalcKeypad));
          final m = KeypadMetrics.compute(
            tester.getSize(find.byKey(const ValueKey('calc-keypad'))),
            TextScaler.linear(scale),
            arrangement: keypad.arrangement,
          );
          final target =
              m.functionRowHeight * CalcTheme.keyLegendBaselineGapRatio;
          expect(m.legendBaselineGap, moreOrLessEquals(target));
          final gaps = <String, double>{};
          for (final button in tester.widgetList<CalcKeyButton>(
            find.byType(CalcKeyButton),
          )) {
            expect(
              button.legendBaseLift,
              moreOrLessEquals(m.legendBaseLift),
              reason: button.keyDef.id.name,
            );
            final legends = _bandLegends(tester, button.keyDef.id);
            // 한 줄 아래로 넘치는 각인이 있는 키는 짝 각인(`:`)까지 함께 더 올린다 (#260) — 위 그룹이 본다
            if (legends.any(
              (l) =>
                  l.legend != null &&
                  KeyLegendView.overhangsLine(l.legend!, l.style),
            )) {
              continue;
            }
            for (final l in legends) {
              gaps['${l.id.name} "${l.text}"'] = l.keycapTop - l.drawnBaseline;
              // 키 사이 세로 간격의 자기 몫(절반) 안이다 — 위 키 쪽 절반으로 넘어가지 않는다
              final cellTop = tester.getRect(_button(l.id)).top;
              expect(
                l.slot.top,
                greaterThanOrEqualTo(cellTop - button.gapInsets.top - 0.01),
                reason: '${l.id.name} "${l.text}"',
              );
            }
          }
          // 원형 버튼 위 인쇄·SHIFT·ALPHA 각인, 함수부·숫자부가 모두 들어 있다
          expect(gaps.length, greaterThan(40));
          final first = gaps.values.first;
          for (final MapEntry(:key, :value) in gaps.entries) {
            expect(value, moreOrLessEquals(first, epsilon: 0.01), reason: key);
          }
          // #264 전에는 줄 상자 깊이(약 0.215em)뿐이었다 — 지금은 글자 배율과 상관없이 목표 거리다
          final depth = _lineDescent(
            CalcTheme.keyShiftLabelStyle,
            TextScaler.linear(scale).scale(m.legendFontSize),
          );
          expect(first, moreOrLessEquals(target, epsilon: 0.01));
          expect(first, greaterThan(depth * 1.5), reason: '$first · 깊이 $depth');
        });
      }
    }
  });

  group('키패드 밖의 키 버튼 (#260 R1)', () {
    // 키패드는 각인이 줄지 않는 글자 크기를 주지만, 따로 쓰는 키 버튼(미리보기 등)은 좁으면 `FittedBox`가 각인을 줄인다.
    // 올린 거리도 각인과 함께 줄어야 줄어든 각인이 띠 위로 나가지 않는다.
    testWidgets('좁은 ∫ 키: 줄어든 d/dx◼·:도 띠 안에 있고 d/dx◼는 띠 아래끝에서 올라가 있다', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 14,
              height: 90,
              child: CalcKeyButton(
                keyDef: keyDefOf(CalcKeyId.integral),
                // 띠(90 × 0.28 = 25.2dp)에 여유가 넉넉한 글자 크기 — 기본값(띠 높이 × 0.94, #264)이면 d/dx◼가 띠를 꽉 채운다
                legendFontSize: 11,
                onPressed: (_) {},
              ),
            ),
          ),
        ),
      );
      final legends = _bandLegends(tester, CalcKeyId.integral);
      expect(legends.map((l) => l.text), ['d/dx◼', ':']);
      final derivative = legends.first;
      expect(derivative.scale, lessThan(0.9), reason: '줄어드는 폭이어야 한다');
      for (final l in legends) {
        expect(
          l.slot.top,
          greaterThanOrEqualTo(l.bandTop - 0.01),
          reason: l.text,
        );
        expect(
          l.slot.bottom,
          lessThanOrEqualTo(l.bandBottom + 0.01),
          reason: l.text,
        );
      }
      // 띠(90 × 0.28 = 25.2dp)에 여유가 넉넉하다 — 줄어든 각인의 한 줄 상자 깊이(줄이기 전 깊이 × 줄인 비율)만큼 올라가 있다
      final lifted = derivative.bandBottom - derivative.slot.bottom;
      expect(
        lifted,
        moreOrLessEquals(
          _lineDescent(derivative.style, derivative.fontSize) *
              derivative.scale,
          epsilon: 0.01,
        ),
      );
    });
  });

  group('키패드 밖의 키 버튼: 올리는 한도 (#264 R1)', () {
    // 키패드는 올리는 거리를 자기 몫(띠 + 간격의 절반) 안으로 정해 주지만, 따로 쓰는 키 버튼에 큰 값을 주어도 넘치지 않는
    // 각인은 자기 몫까지만, 넘치는 각인이 있는 키만 간격 전체까지 올린다.
    const gapTop = 4.0;
    Future<List<_BandLegend>> pump(WidgetTester tester, CalcKeyId id) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 80,
              height: 60,
              child: CalcKeyButton(
                keyDef: keyDefOf(id),
                legendFontSize: 9,
                legendBaseLift: 100,
                gapInsets: const EdgeInsets.only(top: gapTop),
                onPressed: (_) {},
              ),
            ),
          ),
        ),
      );
      return _bandLegends(tester, id);
    }

    testWidgets('넘치는 각인이 없는 키(sin⁻¹ · D)는 띠 위로 간격의 절반까지만 올린다', (tester) async {
      final legends = await pump(tester, CalcKeyId.sin);
      final cellTop = tester.getRect(_button(CalcKeyId.sin)).top;
      expect(legends, hasLength(2));
      for (final l in legends) {
        expect(l.scale, moreOrLessEquals(1.0, epsilon: 1e-6), reason: l.text);
        expect(
          l.slot.top,
          greaterThanOrEqualTo(cellTop - gapTop - 0.01),
          reason: l.text,
        );
      }
      // 가장 높은 각인(sin⁻¹)이 한도에 닿아 있다 — 올리는 거리가 실제로 잘렸다
      expect(
        legends.map((l) => l.slot.top).reduce((a, b) => a < b ? a : b),
        moreOrLessEquals(cellTop - gapTop, epsilon: 0.01),
      );
    });

    testWidgets('넘치는 각인이 있는 키(d/dx◼ · :)는 간격 전체까지 올린다', (tester) async {
      final legends = await pump(tester, CalcKeyId.integral);
      final cellTop = tester.getRect(_button(CalcKeyId.integral)).top;
      final top = legends
          .map((l) => l.slot.top)
          .reduce((a, b) => a < b ? a : b);
      expect(top, lessThan(cellTop - gapTop - 0.5));
      expect(top, greaterThanOrEqualTo(cellTop - 2 * gapTop - 0.01));
    });
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
