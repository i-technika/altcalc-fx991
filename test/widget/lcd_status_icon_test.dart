import 'dart:math' as math;
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

/// 직접 그리는 상태 아이콘(#57)과 반전 상자 글자(#160)를 실제 번들 글꼴로 그린 **픽셀**로 검증한다.
/// - 잉크가 같은 줄 대문자(E)의 높이 띠 안, 슬롯 경계 안에 있는지 (슬롯 밖까지 넓혀 스캔)
/// - 모양(근호 윗선이 칸의 윗변, 연필, ‖ 반전 상자의 두 획, 화살표·상자 안 x, 상자 안 글자)이 실제로 그려지는지
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

  /// dp 가로줄 [y]에서 [r] 범위의 가장 긴 잉크 구간 길이 (dp)
  double longestRun(double y, Rect r) {
    final py = (y * dpr).floor();
    var best = 0;
    var current = 0;
    for (var px = (r.left * dpr).floor(); px < (r.right * dpr).ceil(); px++) {
      current = inked(px, py) ? current + 1 : 0;
      if (current > best) best = current;
    }
    return best / dpr;
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
        // 닿음: 물리 2px — 글자는 그릴 때 기준선·대문자 높이가 픽셀 격자에 맞춰지고(힌팅·스냅) 아이콘은
        // 정확한 좌표로 그려진다. 세로 기준 계산은 실제 Text 배치와 소수 셋째 자리까지 같고(R2 실측),
        // 잉크 끝 행 차이는 최대 1px였다(8dp×1.3·2.625x에서 E가 계산 기준선보다 약 1.6px 위에서 끝남).
        final tolerance = 1.5 / dpr;
        final reach = 2.0 / dpr;
        // 글자가 상자에 맞춰 줄어든 비율 — E의 잉크 높이(대문자 높이)로 잰다.
        final shrink = math.min(
          1.0,
          letter.height /
              (fontSize * scale * CalcTheme.lcdStatusCapHeightRatio),
        );
        final xHeight =
            letter.height *
            CalcTheme.lcdStatusXHeightRatio /
            CalcTheme.lcdStatusCapHeightRatio;
        final stroke =
            letter.height /
            CalcTheme.lcdStatusCapHeightRatio *
            CalcTheme.lcdStatusIconStrokeRatio;
        for (final slot in LcdIndicatorSlot.values) {
          if (slot.icon == null && !slot.boxed) continue;
          // 꺼진 상자 글자(R·G — 각도 단위는 하나만 켜진다)는 진한 잉크가 없다.
          if (_allOn.indicatorFor(slot) == null) continue;
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
          // 슬롯 경계 안 — 글자가 줄면 아이콘도 같은 비율로 줄어 슬롯 가운데에 놓인다.
          final inner = rect.width * (1 - shrink) / 2;
          expect(
            ink.left,
            greaterThanOrEqualTo(rect.left + inner - tolerance),
            reason: reason,
          );
          expect(
            ink.right,
            lessThanOrEqualTo(rect.right - inner + tolerance),
            reason: reason,
          );
        }
        // 근호·상자(‖·→x의 x 상자·반전 상자 글자)는 대문자 높이까지 올라간다.
        for (final slot in [
          LcdIndicatorSlot.math,
          LcdIndicatorSlot.disp,
          LcdIndicatorSlot.store,
          for (final slot in LcdIndicatorSlot.values)
            if (slot.boxed && _allOn.indicatorFor(slot) != null) slot,
        ]) {
          expect(
            shot.inkBounds(_scanRect(tester, slot))!.top,
            lessThanOrEqualTo(letter.top + reach),
            reason: slot.name,
          );
        }
        // →x: 화살표는 대문자 높이 띠 가운데에 대칭이고(상자를 가리킨다) 머리가 몸통보다 높다.
        // x는 둘째 칸의 테두리 상자 안에 있다 — 상자는 띠를 채우고, 가운데 줄에서 왼쪽 변·x·오른쪽 변 세 구간이다.
        final store = _slotRect(tester, LcdIndicatorSlot.store);
        final half = store.center.dx;
        final arrow = shot.inkBounds(
          Rect.fromLTRB(store.left, store.top, half, store.bottom),
        )!;
        expect(
          arrow.center.dy,
          closeTo(letter.center.dy, reach),
          reason: '화살표 $arrow, 대문자 높이 가운데 ${letter.center.dy}',
        );
        expect(
          arrow.height,
          greaterThan(stroke * 2),
          reason: '화살표 머리가 몸통보다 높아야 한다',
        );
        final boxed = Rect.fromLTRB(half, store.top, store.right, store.bottom);
        final box = shot.inkBounds(boxed)!;
        expect(box.top, closeTo(letter.top, reach), reason: 'x 상자 $box');
        expect(box.bottom, closeTo(letter.bottom, reach), reason: 'x 상자 $box');
        // x 높이 가운데 줄: x의 두 획이 만나는 곳 — 상자 왼쪽 변, x, 오른쪽 변
        expect(shot.inkRuns(box.center.dy, boxed), 3, reason: 'x 상자 $box');
        // x는 상자 가운데에 상자보다 작게 놓인다(변 안쪽만 스캔).
        final xInk = shot.inkBounds(box.deflate(stroke * 1.2))!;
        expect(
          xInk.center.dy,
          closeTo(box.center.dy, reach),
          reason: 'x $xInk',
        );
        // x는 상자 높이 비율로 줄인 글자다(x높이 × 상자 안 글자 비율).
        expect(
          xInk.height,
          closeTo(xHeight * CalcTheme.lcdStatusBoxedLetterRatio, reach),
          reason: 'x $xInk',
        );
      },
    );
  }

  testWidgets('아이콘 모양: 근호 윗선이 칸의 윗변이 되고 칸은 비었으며, 연필은 촉을 칸 옆에 대고 오른쪽 위로 기울고, '
      '‖는 반전 상자의 밝은 두 획 (#160)', (tester) async {
    const fontSize = 60.0;
    final shot = await _render(tester, _allOn, fontSize: fontSize);
    final e = shot.inkBounds(_slotRect(tester, LcdIndicatorSlot.engineering))!;
    final stroke = fontSize * CalcTheme.lcdStatusIconStrokeRatio;

    // √▭✎ (3칸): 앞 두 칸 = √▭, 셋째 칸 = ✎
    final math = _slotRect(tester, LcdIndicatorSlot.math);
    final third = math.width / 3;
    final radicalBox = Rect.fromLTRB(
      math.left,
      e.top,
      math.left + third * 2,
      e.bottom,
    );
    // 윗선 줄: 잉크 구간 하나가 칸 너비(한 칸) 이상 이어진다 — 근호 윗선이 칸을 덮는다.
    final topRow = e.top + stroke / 2;
    expect(shot.inkRuns(topRow, radicalBox), 1);
    expect(shot.longestRun(topRow, radicalBox), greaterThan(third));
    // 윗선 바로 아래 줄: 근호 오른쪽 획 + 칸 왼쪽·오른쪽 변 = 구간 셋 — 칸이 윗선에 매달려 대문자
    // 높이 전체를 차지한다(실물 사진).
    expect(shot.inkRuns(e.top + stroke * 1.5, radicalBox), 3);
    // 아래쪽 30% 줄: 근호의 두 획(왼쪽 획은 대문자 높이 55%에서 시작) + 칸 왼쪽·오른쪽 변 = 구간 넷
    // (칸 안쪽은 비었다).
    expect(shot.inkRuns(e.bottom - e.height * 0.3, radicalBox), 4);
    // 칸 아랫변: 기준선 바로 위 줄에서 칸 폭 대부분이 이어진다.
    expect(
      shot.longestRun(e.bottom - stroke / 2, radicalBox),
      greaterThan(third * 0.6),
    );

    // 연필 (셋째 칸)
    final pencil = Rect.fromLTRB(
      math.left + third * 2,
      e.top,
      math.right,
      e.bottom,
    );
    Rect region(double l, double t, double r, double b) => Rect.fromLTRB(
      pencil.left + pencil.width * l,
      pencil.top + pencil.height * t,
      pencil.left + pencil.width * r,
      pencil.top + pencil.height * b,
    );
    // 오른쪽 위에 몸통, 왼쪽(대문자 높이의 아래 20~50%)에 촉
    expect(shot.anyInk(region(0.65, 0, 1, 0.35)), isTrue, reason: '오른쪽 위');
    expect(shot.anyInk(region(0, 0.5, 0.35, 0.8)), isTrue, reason: '왼쪽 촉');
    // 기준선까지 내려오지 않는다(아래 15% 띠가 비었다). 왼쪽 위(25%)·오른쪽 아래(35%)도 비었다 —
    // 연필이 칸 옆의 촉에서 오른쪽 위 모서리로 기운 대각선이다.
    expect(shot.anyInk(region(0, 0.85, 1, 1)), isFalse, reason: '아래 띠');
    expect(shot.anyInk(region(0, 0, 0.25, 0.25)), isFalse, reason: '왼쪽 위');
    expect(shot.anyInk(region(0.65, 0.65, 1, 1)), isFalse, reason: '오른쪽 아래');

    // ‖ (1칸) — 반전 상자: 대문자 높이 가운데 줄에서 어두운 구간 셋(왼쪽·가운데·오른쪽) 사이로 밝은 두 획.
    // 위아래 가장자리 줄은 상자가 이어진다(획은 상자 위아래를 뚫지 않는다).
    final disp = _slotRect(tester, LcdIndicatorSlot.disp);
    expect(shot.inkRuns(e.center.dy, disp), 3);
    expect(shot.inkRuns(e.top + 1, disp), 1);
    expect(shot.inkRuns(e.bottom - 1, disp), 1);
  });

  // (글자 크기, 화면 배율) — 크게, 그리고 실제 크기(폰 LCD 상태 글자 ~10dp, 3x 화면)에서 글자가 뭉개지지 않는지
  for (final (fontSize, dpr) in [(60.0, 1.0), (10.0, 3.0)]) {
    testWidgets('반전 상자 글자 S·A·D·R·G: 상자는 대문자 높이·한 칸이고, 글자 모양으로 비어 배경이 보인다 '
        '(글자 $fontSize, 화면 ${dpr}x, #160)', (tester) async {
      final shot = await _render(tester, _allOn, fontSize: fontSize, dpr: dpr);
      final e = shot.inkBounds(
        _slotRect(tester, LcdIndicatorSlot.engineering),
      )!;
      final px = 1 / dpr;
      // 켜진 상자: S·A (각도 단위는 기본값 D만 켜짐)
      for (final slot in [
        LcdIndicatorSlot.shift,
        LcdIndicatorSlot.alpha,
        LcdIndicatorSlot.angleDegree,
      ]) {
        final rect = _slotRect(tester, slot);
        final box = shot.inkBounds(rect)!;
        final reason = '${slot.name} 상자 $box, E $e';
        // 상자는 옆 글자와 같은 높이(대문자 높이 띠)다.
        expect(box.top, closeTo(e.top, 2 * px), reason: reason);
        expect(box.bottom, closeTo(e.bottom, 2 * px), reason: reason);
        // 위아래 가장자리 줄은 상자로 꽉 차 있다(글자가 상자 가장자리를 뚫지 않는다).
        expect(shot.inkRuns(box.top + px, rect), 1, reason: reason);
        expect(shot.inkRuns(box.bottom - px, rect), 1, reason: reason);
        // 가운데 줄은 글자 획 자리가 비어 구간이 둘 이상으로 나뉜다.
        expect(
          shot.inkRuns(box.center.dy, rect),
          greaterThanOrEqualTo(2),
          reason: reason,
        );
        // 비운 자리는 배경(흰색)까지 밝다 — 글자를 LCD 배경색(빨강 213)으로 칠한 것이 아니라 상자를 지웠다.
        var brightest = 0;
        final py = (box.center.dy * dpr).floor();
        for (
          var x = (box.left * dpr).ceil();
          x < (box.right * dpr).floor();
          x++
        ) {
          brightest = math.max(brightest, shot.red(x, py));
        }
        // 작은 크기에서는 획이 2~3물리 픽셀이라 가장자리 안티에일리어싱이 섞인다.
        expect(
          brightest,
          greaterThan(fontSize >= 60 ? 240 : 200),
          reason: reason,
        );
      }
      // 꺼진 상자(R·G)도 같은 자리에 흐리게 그린다.
      for (final slot in [
        LcdIndicatorSlot.angleRadian,
        LcdIndicatorSlot.angleGradian,
      ]) {
        final rect = _slotRect(tester, slot);
        expect(shot.anyInk(rect), isFalse, reason: slot.name);
        expect(shot.darkest(rect), lessThan(255), reason: slot.name);
        expect(shot.darkest(rect), greaterThan(235), reason: slot.name);
      }
    });
  }

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

  testWidgets('치수를 넘겨받은 아이콘은 색만 바뀌어도 다시 그린다 (shouldRepaint)', (tester) async {
    tester.view.physicalSize = const Size(200, 100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final metrics = LcdStatusIconMetrics.of(
      CalcTheme.lcdStatusStyle.copyWith(fontSize: 60),
      TextScaler.noScaling,
      84,
    );
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
              // 상태 표시줄처럼 치수를 미리 넘긴다 — 재레이아웃 없이 색만 바뀌는 경로(shouldRepaint).
              child: LcdStatusIcon(
                icon: LcdIndicatorIcon.multiStatement,
                color: color,
                metrics: metrics,
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
