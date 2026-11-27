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

/// 다각형 [polygon](멤버십 판정 [inside])에 들어가는 가장 큰 원의 지름 (dp).
/// 영역 안 각 표본 점에서 다각형 경계까지의 최소 거리 중 최댓값의 두 배다.
///
/// 0.5dp 격자로 후보를 찾은 뒤, 가장 좋은 후보 몇 개의 주변(±0.5dp)을 0.05dp 격자로 다시 잰다 (#159 R2).
/// 0.5dp 격자만 쓰면 지름을 최대 약 0.7dp 작게 잰다. 그러면 대칭인 ▲·▼가 서로 다르게 나오고(412×430 창 0.965·0.981배,
/// 참값은 0.982·0.984배), 테마 상수가 조금만 바뀌어도 격자 위상이 달라져 하한 검사가 흔들린다.
/// 다시 잰 뒤의 오차는 약 0.07dp 이하다.
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

  // 영역 밖이면 -1, 안이면 경계까지의 최소 거리
  double clearance(Offset p) {
    if (!inside(p)) return -1;
    var nearest = double.infinity;
    for (var i = 0; i < polygon.length; i++) {
      nearest = math.min(
        nearest,
        distanceToEdge(p, polygon[i], polygon[(i + 1) % polygon.length]),
      );
    }
    return nearest;
  }

  const coarse = 0.5;
  const fine = 0.05;
  // 거친 격자에서 놓친 정도(격자 대각선의 절반, 약 0.35dp) 안의 후보만 다시 잰다.
  const slack = coarse * math.sqrt2 / 2;
  const refineCount = 8;

  final bounds = (Path()..addPolygon(polygon, true)).getBounds();
  final candidates = <(Offset, double)>[];
  for (var x = bounds.left; x <= bounds.right; x += coarse) {
    for (var y = bounds.top; y <= bounds.bottom; y += coarse) {
      final p = Offset(x, y);
      final c = clearance(p);
      if (c >= 0) candidates.add((p, c));
    }
  }
  if (candidates.isEmpty) return 0;
  candidates.sort((a, b) => b.$2.compareTo(a.$2));
  var best = candidates.first.$2;
  final threshold = best - slack;
  for (final (center, value) in candidates.take(refineCount)) {
    if (value < threshold) break;
    for (var dx = -coarse; dx <= coarse + 1e-9; dx += fine) {
      for (var dy = -coarse; dy <= coarse + 1e-9; dy += fine) {
        best = math.max(best, clearance(center + Offset(dx, dy)));
      }
    }
  }
  return best * 2;
}

/// 커서 패드 ▲·▼ 터치 영역 내접원 지름 하한 — 함수 키(sin) 터치 높이 대비 (#159, 사용자 결정).
/// 보통 셀과 넓은 셀(패드가 [CalcTheme.cursorPadMaxAspectRatio]에서 멈춘 셀)에 같은 기준을 쓴다.
/// 측정값은 다음과 같다(0.05dp로 다시 잰 값, R2).
/// - 보통 셀: 0.956~0.982배. 가장 낮은 곳은 셀 비 1.3인 셀이다(390×844·412×915·410×380·360×300 창 등 — #190 뒤
///   410×400은 위아래 배치가 되어 0.985배다).
/// - 넓은 셀: 0.981~0.985배.
/// - 큰 키(함수 키가 각인 띠까지 넓히지 않는 키캡 48dp 이상 — 800×1280·1280×800·1024×1366 창 등): 1.33~1.36배.
const double cursorPadUpDownInscribedMinRatio = 0.95;

/// 커서 패드 ◀·▶ 터치 영역 내접원 지름 하한 — 함수 키(sin) 터치 높이 대비 (#159).
/// 측정은 1.078배(360×300 창) 이상이고, 셀이 넓을수록 커진다.
const double cursorPadLeftRightInscribedMinRatio = 1.0;

/// 화면의 커서 패드 터치·시맨틱 영역의 기준 사각형 — 셀(`CursorPad` 상자)에 둘레 키 사이 간격 몫(`CursorPad.gapInsets`)을
/// 더한 것 (#236). 방향별 터치 경로([CursorPadGeometry.hitPolygon])·시맨틱 영역의 `bounds`로 쓴다.
Rect cursorPadTouchCell(WidgetTester tester) {
  final finder = find.byType(CursorPad);
  return tester
      .widget<CursorPad>(finder)
      .gapInsets
      .inflateRect(tester.getRect(finder));
}

/// 화면에 그려진 함수 키(sin)의 셀 기준 터치 높이 (dp) — 각인 띠까지 넓히면 셀 높이, 아니면 키캡 높이다.
///
/// 셀 둘레 키 사이 간격 몫(#236)은 **빼고** 잰다. 커서 패드 방향 키도 같은 간격 몫을 받으므로, 커서 패드 기준(#159 —
/// 방향 키 내접원 ≥ 이 높이 × 하한)은 간격 몫을 뺀 값끼리 견준다. 실제 터치 높이는 [functionKeyHitHeight]다.
double functionKeyTouchHeight(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (w) => w is CalcKeyButton && w.keyDef.id == CalcKeyId.sin,
  );
  final cell = tester.getSize(finder);
  final button = tester.widget<CalcKeyButton>(finder);
  return button.extendHitAreaToLegend
      ? cell.height
      : cell.height - button.legendBandHeightFor(cell.height);
}

/// 화면에 그려진 함수 키(sin)의 실제 터치 높이 (dp) — [functionKeyTouchHeight]에 터치 영역이 받는 위아래 간격 몫(#236)을
/// 더한다(셀 전체를 터치 영역으로 쓰는 키만 받는다, `CalcKeyButton.hitGapInsets`).
double functionKeyHitHeight(WidgetTester tester) {
  final button = tester.widget<CalcKeyButton>(
    find.byWidgetPredicate(
      (w) => w is CalcKeyButton && w.keyDef.id == CalcKeyId.sin,
    ),
  );
  return functionKeyTouchHeight(tester) + button.hitGapInsets.vertical;
}

/// 화면의 커서 패드 방향 키 터치 영역 내접원 지름이 함수 키(sin) 터치 높이 × 하한 이상인지 확인한다 (#159).
/// ▲·▼는 [cursorPadUpDownInscribedMinRatio], ◀·▶는 [cursorPadLeftRightInscribedMinRatio]를 쓴다.
void expectCursorPadInscribedVersusFunctionKey(
  WidgetTester tester, {
  required String reason,
}) {
  final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
  final cell = cursorPadTouchCell(tester);
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
            (vertical
                ? cursorPadUpDownInscribedMinRatio
                : cursorPadLeftRightInscribedMinRatio),
      ),
      reason: '${sector.name} 내접원 $reason (sin 터치 높이 $touch)',
    );
  }
}
