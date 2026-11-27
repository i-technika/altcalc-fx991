import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

/// 키 터치 치수 측정 도구 (테스트 공용).

/// 커서 패드 [sector] 그림 구역에 들어가는 가장 큰 원의 지름 (0.5dp 격자 근사, dp).
double inscribedDiameter(CursorPadGeometry g, CursorPadSector sector) =>
    polygonInscribedDiameter(
      g.sectorPolygon(sector),
      (p) => g.sectorAt(p) == sector,
    );

/// 커서 패드 [sector] 터치 영역(셀 [bounds], 패드 로컬 좌표)에 들어가는 가장 큰 원의 지름 (#64, dp).
double hitInscribedDiameter(
  CursorPadGeometry g,
  CursorPadSector sector,
  Rect bounds,
) => polygonInscribedDiameter(
  g.hitPolygon(sector, bounds),
  (p) => g.hitSectorAt(p, bounds) == sector,
);

/// 다각형 [polygon](멤버십 판정 [inside])에 들어가는 가장 큰 원의 지름 (0.5dp 격자 근사, dp).
/// 영역 안 각 표본 점에서 다각형 경계까지의 최소 거리 중 최댓값의 두 배다.
double polygonInscribedDiameter(
  List<Offset> polygon,
  bool Function(Offset) inside,
) {
  double distanceToEdge(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  final bounds = (Path()..addPolygon(polygon, true)).getBounds();
  var best = 0.0;
  for (var x = bounds.left; x <= bounds.right; x += 0.5) {
    for (var y = bounds.top; y <= bounds.bottom; y += 0.5) {
      final p = Offset(x, y);
      if (!inside(p)) continue;
      var nearest = double.infinity;
      for (var i = 0; i < polygon.length; i++) {
        nearest = math.min(
          nearest,
          distanceToEdge(p, polygon[i], polygon[(i + 1) % polygon.length]),
        );
      }
      best = math.max(best, nearest);
    }
  }
  return best * 2;
}

/// 커서 패드 ▲·▼ 터치 영역 내접원 지름 하한 — 넓은 셀(패드가 [CalcTheme.cursorPadMaxAspectRatio]에서 멈춘 셀), 함수 키(sin)
/// 터치 높이 대비 (#159, 사용자 결정). 측정은 0.965~0.980배다(가장 낮은 곳은 412×430 창).
const double cursorPadWideUpDownInscribedMinRatio = 0.95;

/// 커서 패드 ▲·▼ 터치 영역 내접원 지름 하한 — 보통 셀, 함수 키(sin) 터치 높이 대비 (#159).
/// 측정은 0.945~0.980배다. 가장 낮은 곳은 화면 320×568·390×844(0.945·0.946)와 키패드 393×560·412×640(0.947)이다.
/// 넓은 셀의 하한([cursorPadWideUpDownInscribedMinRatio])보다 낮다. 즉 넓은 셀의 ▲·▼가 보통 셀보다 누르기 어렵지 않다.
/// 함수 키가 각인 띠까지 넓히지 않는 큰 키(키캡 48dp 이상)에서는 1.3배 이상이라 이 하한에 닿지 않는다.
const double cursorPadUpDownInscribedMinRatio = 0.94;

/// 커서 패드 ◀·▶ 터치 영역 내접원 지름 하한 — 함수 키(sin) 터치 높이 대비 (#159). 측정은 1.07배 이상이고, 셀이 넓을수록 커진다.
const double cursorPadLeftRightInscribedMinRatio = 1.0;

/// 화면에 그려진 함수 키(sin)의 터치 높이 (dp) — 각인 띠까지 넓히면 셀 높이, 아니면 키캡 높이다.
double functionKeyTouchHeight(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (w) => w is CalcKeyButton && w.keyDef.id == CalcKeyId.sin,
  );
  final cell = tester.getSize(finder);
  return tester.widget<CalcKeyButton>(finder).extendHitAreaToLegend
      ? cell.height
      : cell.height * (1 - CalcTheme.keyLegendHeightRatio);
}

/// 화면의 커서 패드 방향 키 터치 영역 내접원 지름이 함수 키(sin) 터치 높이 × 하한 이상인지 확인한다 (#159).
/// ▲·▼는 [upDownMinRatio], ◀·▶는 [cursorPadLeftRightInscribedMinRatio]를 쓴다.
void expectCursorPadInscribedVersusFunctionKey(
  WidgetTester tester, {
  required double upDownMinRatio,
  required String reason,
}) {
  final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
  final cell = tester.getRect(find.byType(CursorPad));
  final touch = functionKeyTouchHeight(tester);
  final g = CursorPadGeometry(pad.size);
  final bounds = cell.shift(-pad.topLeft);
  for (final sector in CursorPadSector.values) {
    final vertical =
        sector == CursorPadSector.up || sector == CursorPadSector.down;
    expect(
      hitInscribedDiameter(g, sector, bounds),
      greaterThanOrEqualTo(
        touch *
            (vertical ? upDownMinRatio : cursorPadLeftRightInscribedMinRatio),
      ),
      reason: '${sector.name} 내접원 $reason (sin 터치 높이 $touch)',
    );
  }
}
