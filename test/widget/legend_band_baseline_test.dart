import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/key_legend_view.dart';

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
/// 곳 — [InkCenteredLabel] 설명), 2차원 각인이면 보고한 기준선이다. 감싸는 [DrawnBaselineLabel]은 재는 데 쓰지 않는다 —
/// 그 위젯이 옮긴 결과를 글자 상자에서 따로 잰다.

/// 각인 띠에 그린 각인 하나 (전역 좌표, dp)
typedef _BandLegend = ({
  CalcKeyId id,
  String text,
  bool plain,
  double drawnBaseline,
  double bottom,
  double scale,

  /// 2차원 각인의 잉크가 한 줄 상자 아래로 넘어 상자가 아래로 커졌는지 — 아래 정렬 띠에서 그만큼 기준선이 올라가는 것은
  /// 의도한 배치다([KeyLegendView] "크기·기준선" 절)
  bool overflowsBelow,
});

/// [box](각인 라벨 렌더 객체)의 전역 상자와 `FittedBox` 등이 줄인 비율
(Rect, double) _globalRect(RenderBox box) {
  final rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  return (rect, rect.height / box.size.height);
}

/// 기준선 질의는 배치 밖에서 막혀 있다 — 프레임워크 테스트처럼 고유 크기 검사 중으로 표시하고 읽는다.
double _reportedBaseline(RenderBox box) {
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return box.getDistanceToBaseline(TextBaseline.alphabetic)!;
  } finally {
    RenderObject.debugCheckingIntrinsics = false;
  }
}

/// 글자 크기 [fontSize](배율 반영)인 각인 줄 상자의 기준선 아래 깊이 — [KeyLegendView]가 쓰는 줄 상자와 같다
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

/// [id] 키 버튼의 각인 띠(SHIFT·ALPHA, 원형 버튼 위 인쇄)에 그린 각인들. 메인 각인([InkCenteredLabel] 안)은 뺀다.
List<_BandLegend> _bandLegends(WidgetTester tester, CalcKeyId id) {
  final button = tester.renderObject(
    find.byWidgetPredicate((w) => w is CalcKeyButton && w.keyDef.id == id),
  );
  final found = <_BandLegend>[];
  void visit(RenderObject node) {
    if (node is RenderInkCenteredLabel) return;
    if (node is RenderParagraph) {
      final (rect, scale) = _globalRect(node);
      final drawn = _reportedBaseline(node).roundToDouble();
      // 띠 안의 자리(아래끝)는 글자를 옮겨 그리는 [DrawnBaselineLabel]의 상자다 — 글자 상자는 그 안에서 옮겨져 있다.
      final parent = node.parent;
      final slot = parent is RenderDrawnBaselineLabel
          ? _globalRect(parent).$1
          : rect;
      found.add((
        id: id,
        text: node.text.toPlainText(),
        plain: true,
        drawnBaseline: rect.top + drawn * scale,
        bottom: slot.bottom,
        scale: scale,
        overflowsBelow: false,
      ));
      return;
    }
    if (node is RenderKeyLegend) {
      final (rect, scale) = _globalRect(node);
      final baseline = _reportedBaseline(node);
      final fontSize = node.textScaler.scale(node.style.fontSize!);
      found.add((
        id: id,
        text: node.legend.plainText,
        plain: node.legend is LegendText,
        drawnBaseline: rect.top + baseline * scale,
        bottom: rect.bottom,
        scale: scale,
        overflowsBelow:
            node.size.height - baseline >
            _lineDescent(node.style, fontSize) + 0.01,
      ));
      return;
    }
    node.visitChildren(visit);
  }

  button.visitChildren(visit);
  return found;
}

Future<void> _pumpApp(WidgetTester tester, Size size, double textScale) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const ProviderScope(child: AltCalcApp()));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadBundledFonts);

  const sizes = {'폰 360×800': Size(360, 800), '태블릿 800×1280': Size(800, 1280)};

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        '$name 글자 배율 $textScale: 같은 각인 띠의 글자 각인과 2차원 각인은 그린 기준선이 같다',
        (tester) async {
          await _pumpApp(tester, size, textScale);
          final keys = tester
              .widgetList<CalcKeyButton>(find.byType(CalcKeyButton))
              .map((b) => b.keyDef)
              .toList();
          expect(keys, isNotEmpty);

          // 1. 원형 버튼 위 인쇄 줄(기준선 정렬 `Row`): 키마다 모든 각인의 그린 기준선이 같다.
          var roundChecked = 0;
          for (final def in keys.where((d) => d.face == KeyFace.roundButton)) {
            final parts = _bandLegends(tester, def.id);
            if (parts.length < 2) continue;
            roundChecked++;
            for (final part in parts) {
              expect(
                part.drawnBaseline,
                moreOrLessEquals(parts.first.drawnBaseline, epsilon: 0.01),
                reason: '${def.id} "${part.text}" — "${parts.first.text}"와 기준선',
              );
            }
          }
          expect(roundChecked, greaterThan(0), reason: '원형 버튼 인쇄 줄을 찾지 못했다');

          // 2. 아래 정렬한 SHIFT·ALPHA 각인 띠: 같은 띠(상자 아래끝이 같은 각인들 — 한 키 안과 같은 행의 이웃 키)에서
          //    줄이지 않았고 한 줄 아래로 넘치지 않는 각인은 그린 기준선이 같다.
          final band = [
            for (final def in keys.where((d) => d.face != KeyFace.roundButton))
              ..._bandLegends(
                tester,
                def.id,
              ).where((l) => l.scale > 0.999 && !l.overflowsBelow),
          ]..sort((a, b) => a.bottom.compareTo(b.bottom));
          final groups = <List<_BandLegend>>[];
          for (final legend in band) {
            if (groups.isEmpty ||
                legend.bottom - groups.last.last.bottom > 0.05) {
              groups.add([legend]);
            } else {
              groups.last.add(legend);
            }
          }
          var mixedGroups = 0;
          for (final group in groups) {
            if (group.any((l) => l.plain) && group.any((l) => !l.plain)) {
              mixedGroups++;
            }
            final reference = group.first;
            for (final legend in group) {
              expect(
                legend.drawnBaseline,
                moreOrLessEquals(reference.drawnBaseline, epsilon: 0.01),
                reason:
                    '${legend.id} "${legend.text}" — ${reference.id} '
                    '"${reference.text}"와 같은 띠의 기준선',
              );
            }
          }
          // 이슈의 실측 대상(sin·cos 키의 SHIFT 2차원 각인·ALPHA 글자 각인)이 검사에 들어 있어야 한다.
          for (final id in [CalcKeyId.sin, CalcKeyId.cos]) {
            final legends = band.where((l) => l.id == id).toList();
            expect(
              legends.map((l) => l.plain),
              containsAll([true, false]),
              reason: '$id의 두 각인이 검사에 들어 있어야 한다',
            );
          }
          expect(mixedGroups, greaterThan(0));
        },
      );
    }
  }
}
