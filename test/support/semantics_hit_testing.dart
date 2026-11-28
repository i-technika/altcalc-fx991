import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

/// 엔진 브리지의 터치 탐색 판정을 흉내 낸다 — Android `AccessibilityBridge.SemanticsNode.hitTest`,
/// iOS `SemanticsObject search:` (#203). [point]는 [node]의 부모 좌표다(루트면 물리 픽셀).
///
/// 영역은 왼쪽·위 변을 넣고 오른쪽·아래 변을 뺀다. 숨은(isHidden) 자식은 건너뛰고, 자식을 히트 테스트 순서
/// (위에 그린 것부터)로 찾는다. 닿은 자식이 없으면 초점을 받을 수 있는 노드일 때 자신을 돌려준다.
///
/// 엔진과 다른 점(이 앱의 키패드 트리에서는 결과가 같다):
/// - 초점 조건은 라벨·값·힌트·동작 유무만 본다. Android `isFocusable`의 `IS_FOCUSABLE`·`FOCUSABLE_FLAGS`·
///   `SCOPES_ROUTE`·`IS_ACCESSIBILITY_FOCUS_BLOCKED`와 스크롤 동작 제외, iOS의 implicitScrolling+hidden 조건은
///   흉내 내지 않는다.
/// - 숨은 자식 건너뛰기는 Android만 한다(iOS `search:`는 건너뛰지 않는다).
/// - 영역은 각 노드 좌표에서 반열린 사각형으로 본다(Android와 같다). iOS는 변환된 사각형을 감싸는 축 정렬 사각형
///   (`globalRect`)과 `CGRectContainsPoint`로 본다 — 회전 없는 이 트리에서는 같다.
/// - 루트 노드는 변환이 없고 rect가 물리 픽셀이다(기기 배율은 루트 자식의 변환에 있다). 그래서 [point]를
///   물리 픽셀로 주면 된다.
SemanticsNode? semanticsHitTest(SemanticsNode node, Offset point) {
  var local = point;
  final transform = node.transform;
  if (transform != null) {
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) return null;
    local = MatrixUtils.transformPoint(inverse, point);
  }
  final r = node.rect;
  if (local.dx < r.left ||
      local.dx >= r.right ||
      local.dy < r.top ||
      local.dy >= r.bottom) {
    return null;
  }
  // inverseHitTest 순서(그리는 순서)를 뒤집으면 히트 테스트 순서다.
  final children = node.debugListChildrenInOrder(
    DebugSemanticsDumpOrder.inverseHitTest,
  );
  for (final child in children.reversed) {
    if (child.getSemanticsData().flagsCollection.isHidden) continue;
    final hit = semanticsHitTest(child, local);
    if (hit != null) return hit;
  }
  final data = node.getSemanticsData();
  final focusable =
      data.label.isNotEmpty ||
      data.value.isNotEmpty ||
      data.hint.isNotEmpty ||
      data.actions != 0;
  return focusable ? node : null;
}

/// 화면의 커서 패드(하나) 셀을 1.5dp 격자로 짚어, 터치 탐색이 닿는 노드가
/// 화면 모양 명세([CursorPadGeometry.screenSemanticSectorAt]) 방향의 노드인지 본다 (#203·#259). 시맨틱이 켜져 있고 한국어 로캘이어야 한다.
/// 네 방향이 모두 한 번 이상 나와야 한다.
///
/// 셀 둘레 간격 몫(#236)도 짚는다. 그곳의 기대 방향은 셀 변에 닿은 변만 늘린 방향별 영역
/// ([CursorPad.inflateOnCellEdges])을 쌓은 순서의 위부터 찾은 것이다 — 묶는 노드의 경계가 간격 몫까지 넓지 않으면
/// 엔진 터치 탐색이 간격의 자식에 닿지 못해 실패한다.
void expectCursorPadTouchExplorationMatchesSpec(
  WidgetTester tester, {
  String reason = '',
}) {
  final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
  // 셀 안만 짚는다 — 방향 나눔은 셀 기준이다. 셀 둘레 간격 몫(#236)의 시맨틱 영역은 키패드 테스트가 따로 본다.
  final cell = tester.getRect(find.byType(CursorPad));
  final bounds = cell.shift(-pad.topLeft);
  final g = CursorPadGeometry(pad.size);
  final labels = {
    for (final s in CursorPadSector.values)
      s: const KoSemanticStrings().keyButton(CursorPad.defOf(s).id),
  };
  var root = tester.getSemantics(find.byType(CursorPad));
  while (root.parent != null) {
    root = root.parent!;
  }
  final dpr = tester.view.devicePixelRatio;
  final seen = <CursorPadSector>{};
  // 화면 커서 패드와 같은 값(셀 둘레 간격 몫 #236, ◀·▶ 폭 목표 #259)으로 판정한다
  final pad0 = tester.widget<CursorPad>(find.byType(CursorPad));
  // 격자를 셀 변·영역 경계에서 조금 비켜 둔다(경계 위 점은 부동소수 오차로 갈릴 수 있다).
  for (var x = cell.left + 0.37; x < cell.right; x += 1.5) {
    for (var y = cell.top + 0.41; y < cell.bottom; y += 1.5) {
      final p = Offset(x, y);
      final want = g.screenSemanticSectorAt(
        p - pad.topLeft,
        bounds,
        pad0.gapInsets,
      );
      expect(want, isNotNull, reason: '$reason $p');
      seen.add(want!);
      final node = semanticsHitTest(root, p * dpr);
      expect(node?.label, labels[want], reason: '$reason $p');
    }
  }
  expect(seen, CursorPadSector.values.toSet(), reason: reason);

  // 셀 둘레 간격 몫 (#236)
  final touch = pad0.gapInsets.inflateRect(cell);
  Rect areaOf(CursorPadSector s) => CursorPad.inflateOnCellEdges(
    g
        .screenSemanticRect(s, bounds, pad0.gapInsets)
        .shift(pad.topLeft - cell.topLeft),
    cell.size,
    pad0.gapInsets,
  ).shift(cell.topLeft);
  var ring = 0;
  for (var x = touch.left + 0.37; x < touch.right; x += 1.5) {
    for (var y = touch.top + 0.41; y < touch.bottom; y += 1.5) {
      final p = Offset(x, y);
      if (cell.contains(p)) continue;
      CursorPadSector? want;
      for (final s in CursorPadGeometry.semanticStackOrder.reversed) {
        if (areaOf(s).contains(p)) {
          want = s;
          break;
        }
      }
      expect(want, isNotNull, reason: '$reason 간격 몫 $p');
      final node = semanticsHitTest(root, p * dpr);
      expect(node?.label, labels[want], reason: '$reason 간격 몫 $p');
      ring++;
    }
  }
  if (pad0.gapInsets != EdgeInsets.zero) {
    expect(ring, greaterThan(0), reason: '$reason 간격 몫 표본');
  }
}
