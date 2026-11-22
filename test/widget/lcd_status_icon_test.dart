import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_status_icon.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';

/// 직접 그리는 상태 아이콘(#57)을 실제 번들 글꼴로 그린 **픽셀**로 검증한다.
/// - 아이콘 잉크가 같은 줄 대문자(E)의 높이 띠 안, 슬롯 경계 안에 있는지 (슬롯 밖까지 넓혀 스캔)
/// - 모양(근호 윗선이 칸을 덮음, 연필, ‖ 두 획, 화살표·x)이 실제로 그려지는지
/// - 꺼진 색·켜짐↔꺼짐 전환이 픽셀에 반영되는지

/// 모든 표시기가 켜진 상태
const _allOn = LcdStatus(
  shift: true,
  alpha: true,
  memory: true,
  store: true,
  numberFormat: NumberDisplayFormat.fix,
  engineering: true,
  complex: ComplexResultIndicator.polar,
  historyUp: true,
  historyDown: true,
  disp: true,
);

/// 캡처한 화면. 좌표는 논리 dp로 받는다.
class _Shot {
  final ByteData bytes;
  final int width;
  final int height;
  final double dpr;

  const _Shot(this.bytes, this.width, this.height, this.dpr);

  /// (x, y) dp 위치 물리 픽셀의 빨강 값 (흰 배경 255, 활성 색 #2A2A2A = 42)
  int red(int px, int py) => bytes.getUint8((py * width + px) * 4);

  /// 진한 활성 색이 절반 이상 덮인 물리 픽셀
  bool inked(int px, int py) => red(px, py) < 140;

  /// dp 사각형 안에 잉크가 있는지
  bool anyInk(Rect r) {
    for (var py = (r.top * dpr).floor(); py < (r.bottom * dpr).ceil(); py++) {
      for (var px = (r.left * dpr).floor(); px < (r.right * dpr).ceil(); px++) {
        if (px >= 0 && px < width && py >= 0 && py < height && inked(px, py)) {
          return true;
        }
      }
    }
    return false;
  }

  /// dp 사각형 안의 가장 어두운 빨강 값
  int darkest(Rect r) {
    var min = 255;
    for (var py = (r.top * dpr).floor(); py < (r.bottom * dpr).ceil(); py++) {
      for (var px = (r.left * dpr).floor(); px < (r.right * dpr).ceil(); px++) {
        final v = red(px, py);
        if (v < min) min = v;
      }
    }
    return min;
  }

  /// dp 사각형 안 잉크 경계 (dp). 잉크가 없으면 `null`.
  Rect? inkBounds(Rect r) {
    int? top, bottom, left, right;
    for (var py = (r.top * dpr).floor(); py < (r.bottom * dpr).ceil(); py++) {
      for (var px = (r.left * dpr).floor(); px < (r.right * dpr).ceil(); px++) {
        if (px < 0 || px >= width || py < 0 || py >= height) continue;
        if (!inked(px, py)) continue;
        if (top == null || py < top) top = py;
        if (bottom == null || py + 1 > bottom) bottom = py + 1;
        if (left == null || px < left) left = px;
        if (right == null || px + 1 > right) right = px + 1;
      }
    }
    if (top == null) return null;
    return Rect.fromLTRB(left! / dpr, top / dpr, right! / dpr, bottom! / dpr);
  }

  /// dp 가로줄 [y]에서 [r] 범위의 잉크 구간 수
  int inkRuns(double y, Rect r) {
    final py = (y * dpr).floor();
    var runs = 0;
    var inside = false;
    for (var px = (r.left * dpr).floor(); px < (r.right * dpr).ceil(); px++) {
      final on = inked(px, py);
      if (on && !inside) runs++;
      inside = on;
    }
    return runs;
  }
}

Widget _bar(LcdStatus status, TextStyle style, double scale, bool material) {
  final bar = ColoredBox(
    color: const Color(0xFFFFFFFF),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 2400,
        child: LcdStatusBar(
          status: status,
          style: style,
          textScaler: TextScaler.linear(scale),
        ),
      ),
    ),
  );
  // material: 앱처럼 MaterialApp·Scaffold의 기본 글자 스타일(줄 높이 1.43 등)을 상속시킨다.
  return material
      ? MaterialApp(home: Scaffold(body: bar))
      : Directionality(textDirection: TextDirection.ltr, child: bar);
}

final _boundaryKey = GlobalKey();

/// 상태 표시줄을 그려 캡처한다.
Future<_Shot> _render(
  WidgetTester tester,
  LcdStatus status, {
  required double fontSize,
  double scale = 1.0,
  double dpr = 1.0,
  bool material = false,
  double? height,
}) async {
  tester.view.physicalSize = Size(2400 * dpr, 200 * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final style = CalcTheme.lcdStatusStyle.copyWith(
    fontSize: fontSize,
    height: height,
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: _bar(status, style, scale, material),
    ),
  );
  return _capture(tester, dpr);
}

Future<_Shot> _capture(WidgetTester tester, double dpr) async {
  final boundary =
      _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return _Shot(data!, image.width, image.height, dpr);
  }))!;
}

Rect _slotRect(WidgetTester tester, LcdIndicatorSlot slot) =>
    tester.getRect(find.byKey(ValueKey(slot)));

/// 슬롯과 이웃 슬롯 사이 간격의 가운데까지 넓힌 스캔 범위 (세로는 화면 전체)
Rect _scanRect(WidgetTester tester, LcdIndicatorSlot slot) {
  final values = LcdIndicatorSlot.values;
  final rect = _slotRect(tester, slot);
  final left = slot.index == 0
      ? 0.0
      : (_slotRect(tester, values[slot.index - 1]).right + rect.left) / 2;
  final right = slot.index == values.length - 1
      ? 2400.0
      : (rect.right + _slotRect(tester, values[slot.index + 1]).left) / 2;
  return Rect.fromLTRB(left, 0, right, 200);
}

/// 글꼴 파일 OS/2 테이블의 (sxHeight, sCapHeight) / unitsPerEm
Future<(double, double)> _os2Heights(String asset) async {
  final data = await rootBundle.load(asset);
  final tables = <String, int>{};
  for (var i = 0; i < data.getUint16(4); i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes([
      for (var j = 0; j < 4; j++) data.getUint8(record + j),
    ]);
    tables[tag] = data.getUint32(record + 8);
  }
  final unitsPerEm = data.getUint16(tables['head']! + 18);
  final os2 = tables['OS/2']!;
  expect(data.getUint16(os2), greaterThanOrEqualTo(2), reason: 'OS/2 v2 이상');
  return (
    data.getInt16(os2 + 86) / unitsPerEm,
    data.getInt16(os2 + 88) / unitsPerEm,
  );
}

void main() {
  setUpAll(loadBundledFonts);

  test('아이콘 높이 비율은 상태 표시 글꼴(SemiBold)의 x높이·대문자 높이와 같다', () async {
    expect(
      CalcTheme.lcdStatusStyle.fontWeight,
      FontWeight.w600,
      reason: '상태 표시 굵기가 바뀌면 아래 글꼴 파일도 바꾼다',
    );
    final (xHeight, capHeight) = await _os2Heights(
      'assets/fonts/NotoSansMono-SemiBold.ttf',
    );
    expect(CalcTheme.lcdStatusXHeightRatio, closeTo(xHeight, 1e-9));
    expect(CalcTheme.lcdStatusCapHeightRatio, closeTo(capHeight, 1e-9));
  });

  // (글자 크기, 배율, 화면 배율, 앱 기본 글자 스타일 상속, 줄 높이 지정)
  for (final (fontSize, scale, dpr, material, height) in [
    (60.0, 1.0, 1.0, false, null),
    (60.0, 1.3, 1.0, false, null),
    (60.0, 1.0, 1.0, true, null), // 앱처럼 줄 높이 1.43 상속 → 글자가 상자에 맞춰 줄어든다
    (60.0, 1.0, 1.0, false, 2.0), // 줄 높이를 크게 지정 → 글자가 크게 줄어든다
    (10.0, 1.0, 3.0, true, null), // 실제 크기 (폰 LCD 상태 글자 ~10dp, 3x 화면)
    (8.0, 1.3, 2.625, true, null),
  ]) {
    testWidgets(
      '아이콘 잉크는 같은 줄 대문자 E의 높이 띠·슬롯 경계 안에 있고 기준선에 닿는다 '
      '(글자 $fontSize, 배율 $scale, 화면 ${dpr}x, 앱 스타일 $material, 줄 높이 $height)',
      (tester) async {
        final shot = await _render(
          tester,
          _allOn,
          fontSize: fontSize,
          scale: scale,
          dpr: dpr,
          material: material,
          height: height,
        );
        final letter = shot.inkBounds(
          _slotRect(tester, LcdIndicatorSlot.engineering),
        )!;
        // 넘지 않음: 물리 1.5px (안티에일리어싱).
        // 닿음: 물리 2.5px — 글자는 그릴 때 기준선·대문자 높이가 픽셀 격자에 맞춰지고(힌팅·스냅)
        // 아이콘은 정확한 좌표로 그려져, 작은 크기에서 1~2px 차이가 난다(세로 기준 계산 자체는
        // 실제 Text 배치와 같다 — 앱 스타일에서 기준선·축소율 일치 확인).
        final tolerance = 1.5 / dpr;
        final reach = 2.5 / dpr;
        for (final slot in LcdIndicatorSlot.values) {
          if (slot.icon == null) continue;
          final rect = _slotRect(tester, slot);
          // 슬롯 밖(이웃 슬롯과의 간격)까지 넓혀 스캔한다.
          final ink = shot.inkBounds(_scanRect(tester, slot));
          expect(ink, isNotNull, reason: '${slot.name}이 그려지지 않았다');
          final reason = '${slot.name} 잉크 $ink, E $letter, 슬롯 $rect';
          // 기준선 아래로 내려가지 않고 대문자 높이를 넘지 않으며, 기준선까지 내려온다.
          expect(
            ink!.bottom,
            lessThanOrEqualTo(letter.bottom + tolerance),
            reason: reason,
          );
          expect(
            ink.bottom,
            greaterThanOrEqualTo(letter.bottom - reach),
            reason: reason,
          );
          expect(
            ink.top,
            greaterThanOrEqualTo(letter.top - tolerance),
            reason: reason,
          );
          // 슬롯 경계 안에 그린다.
          expect(
            ink.left,
            greaterThanOrEqualTo(rect.left - tolerance),
            reason: reason,
          );
          expect(
            ink.right,
            lessThanOrEqualTo(rect.right + tolerance),
            reason: reason,
          );
        }
        // 근호·이중선은 대문자 높이까지 올라간다.
        for (final slot in [LcdIndicatorSlot.math, LcdIndicatorSlot.disp]) {
          expect(
            shot.inkBounds(_scanRect(tester, slot))!.top,
            lessThanOrEqualTo(letter.top + reach),
            reason: slot.name,
          );
        }
      },
    );
  }

  testWidgets('아이콘 모양: 근호 윗선이 칸을 덮고, 3칸째 연필, ‖는 두 획, →와 x가 각 칸에 있다', (
    tester,
  ) async {
    const fontSize = 60.0;
    final shot = await _render(tester, _allOn, fontSize: fontSize);
    final e = shot.inkBounds(_slotRect(tester, LcdIndicatorSlot.engineering))!;
    final cap = e.height;
    const glyph = fontSize * CalcTheme.lcdStatusCharWidthRatio;
    final advance = glyph + CalcTheme.lcdStatusStyle.letterSpacing!;
    final stroke = fontSize * CalcTheme.lcdStatusIconStrokeRatio;

    // √▭✎ (3칸)
    final math = _slotRect(tester, LcdIndicatorSlot.math);
    final boxCenterX = math.left + advance * 1.4; // 칸(▭)의 가로 가운데
    Rect probe(double cx, double cy, [double r = 2]) =>
        Rect.fromLTRB(cx - r, cy - r, cx + r, cy + r);
    expect(
      shot.anyInk(probe(boxCenterX, e.top + stroke / 2)),
      isTrue,
      reason: '근호 윗선이 칸 위를 덮어야 한다',
    );
    expect(
      shot.anyInk(probe(boxCenterX, e.bottom - stroke / 2)),
      isTrue,
      reason: '칸 아랫변',
    );
    expect(
      shot.anyInk(probe(boxCenterX, e.bottom - cap * 0.3)),
      isFalse,
      reason: '칸 안쪽은 비어 있어야 한다',
    );
    expect(
      shot.anyInk(
        Rect.fromLTRB(
          math.left + advance * 2,
          e.top,
          math.left + advance * 2 + glyph,
          e.bottom,
        ),
      ),
      isTrue,
      reason: '3칸째에 연필이 있어야 한다',
    );

    // ‖ (1칸) — 대문자 높이 가운데 줄에서 잉크 구간이 둘
    final disp = _slotRect(tester, LcdIndicatorSlot.disp);
    expect(shot.inkRuns(e.center.dy, disp), 2);

    // →x (2칸) — 첫 칸 x높이 가운데에 화살표, 둘째 칸에 x 글자
    final store = _slotRect(tester, LcdIndicatorSlot.store);
    final xMid = e.bottom - fontSize * CalcTheme.lcdStatusXHeightRatio / 2;
    expect(
      shot.anyInk(probe(store.left + glyph * 0.5, xMid)),
      isTrue,
      reason: '화살표 몸통',
    );
    expect(
      shot.anyInk(
        Rect.fromLTRB(
          store.left + advance,
          e.top,
          store.left + advance + glyph,
          e.bottom,
        ),
      ),
      isTrue,
      reason: 'x 글자',
    );
    expect(
      shot.anyInk(probe(store.left + glyph * 0.5, e.top + stroke)),
      isFalse,
      reason: '화살표는 x높이 위로 올라가지 않는다',
    );
  });

  testWidgets('꺼진 아이콘은 배경과 거의 같은 색(4%)으로 그리고, 켜짐↔꺼짐이 바뀌면 다시 그린다', (
    tester,
  ) async {
    const fontSize = 60.0;
    // 켜짐: ‖만 켠다
    var shot = await _render(
      tester,
      const LcdStatus(disp: true),
      fontSize: fontSize,
    );
    final dispRect = _slotRect(tester, LcdIndicatorSlot.disp);
    final storeRect = _slotRect(tester, LcdIndicatorSlot.store);
    expect(shot.anyInk(dispRect), isTrue);
    // 꺼진 →x: 흰 배경 위 4% → 가장 어두운 픽셀도 배경(255)에 가깝다
    expect(shot.darkest(storeRect), greaterThan(235));
    expect(shot.darkest(storeRect), lessThan(255), reason: '꺼진 색으로 그리기는 한다');

    // 같은 위젯 트리에서 ‖를 끄면 다시 그려져 진한 잉크가 사라진다.
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: _bar(
          const LcdStatus(),
          CalcTheme.lcdStatusStyle.copyWith(fontSize: fontSize),
          1.0,
          false,
        ),
      ),
    );
    shot = await _capture(tester, 1.0);
    expect(shot.anyInk(dispRect), isFalse);
    expect(shot.darkest(dispRect), greaterThan(235));
  });

  testWidgets('아이콘 하나만 색이 바뀌어도 픽셀에 반영된다', (tester) async {
    tester.view.physicalSize = const Size(200, 100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget icon(Color color) => RepaintBoundary(
      key: _boundaryKey,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 60,
              height: 84,
              child: LcdStatusIcon(
                icon: LcdIndicatorIcon.multiStatement,
                color: color,
                style: CalcTheme.lcdStatusStyle.copyWith(fontSize: 60),
              ),
            ),
          ),
        ),
      ),
    );
    const area = Rect.fromLTWH(0, 0, 60, 84);
    await tester.pumpWidget(icon(CalcTheme.lcdStatusActive));
    expect((await _capture(tester, 1)).anyInk(area), isTrue);
    await tester.pumpWidget(icon(CalcTheme.lcdStatusInactive));
    expect((await _capture(tester, 1)).anyInk(area), isFalse);
  });

  testWidgets('글자 크기 없는 스타일을 넘겨도 기본 크기로 그린다', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 40,
            height: 20,
            child: LcdStatusIcon(
              icon: LcdIndicatorIcon.multiStatement,
              color: CalcTheme.lcdStatusActive,
              style: TextStyle(),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('켜진 아이콘은 켜진 색, 꺼진 아이콘은 꺼진 색을 받는다', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 600,
          child: LcdStatusBar(status: LcdStatus(disp: true)),
        ),
      ),
    );
    Color colorOf(LcdIndicatorIcon icon) =>
        tester.widget<LcdStatusIcon>(find.byKey(ValueKey(icon))).color;
    expect(colorOf(LcdIndicatorIcon.multiStatement), CalcTheme.lcdStatusActive);
    expect(colorOf(LcdIndicatorIcon.storeArrow), CalcTheme.lcdStatusInactive);
    expect(colorOf(LcdIndicatorIcon.mathInput), CalcTheme.lcdStatusActive);
  });
}
