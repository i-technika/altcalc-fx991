import 'dart:math' as math;

import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

/// 키 터치 치수 측정 도구 (테스트 공용).

/// 커서 패드 [sector] 구역에 들어가는 가장 큰 원의 지름 (0.5dp 격자 근사, dp).
/// 구역 안 각 표본 점에서 구역 다각형 경계까지의 최소 거리 중 최댓값의 두 배다.
double inscribedDiameter(CursorPadGeometry g, CursorPadSector sector) {
  final polygon = g.sectorPolygon(sector);
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
      if (g.sectorAt(p) != sector) continue;
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
