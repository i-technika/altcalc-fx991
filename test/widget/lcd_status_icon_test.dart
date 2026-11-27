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
/// - 모양(근호 윗선 아래에 매달린 ⊏, 연필, ‖ 반전 상자의 두 획, 화살표·상자 안 x, 상자 안 글자)이 실제로 그려지는지
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

  /// dp 세로줄 [x]에서 [top]~[bottom] 범위의 잉크 구간 수
  int inkRunsVertical(double x, double top, double bottom) {
    final px = (x * dpr).floor();
    var runs = 0;
    var inside = false;
    for (var py = (top * dpr).floor(); py < (bottom * dpr).ceil(); py++) {
      final on = inked(px, py);
      if (on && !inside) runs++;
      inside = on;
    }
    return runs;
  }

  /// 물리 픽셀이 배경에 가깝게 밝은지 (흰 배경 255, 진한 색 42 — 절반보다 밝음)
  bool _light(int px, int py) => red(px, py) > 170;

  /// dp 가로 [left]~[right] 사이에, [top]~[bottom] 전체가 밝은 세로 열이 하나라도 있는지
  bool hasGapColumn(double left, double right, double top, double bottom) {
    for (var px = (left * dpr).ceil(); px < (right * dpr).floor(); px++) {
      var clear = true;
      for (var py = (top * dpr).floor(); py < (bottom * dpr).ceil(); py++) {
        if (!_light(px, py)) {
          clear = false;
          break;
        }
      }
      if (clear) return true;
    }
    return false;
  }

  /// dp 세로 [top]~[bottom] 사이에, [left]~[right] 전체가 밝은 가로 줄이 하나라도 있는지
  bool hasGapRow(double top, double bottom, double left, double right) {
    for (var py = (top * dpr).ceil(); py < (bottom * dpr).floor(); py++) {
      var clear = true;
      for (var px = (left * dpr).floor(); px < (right * dpr).ceil(); px++) {
        if (!_light(px, py)) {
          clear = false;
          break;
        }
      }
      if (clear) return true;
    }
    return false;
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
    testWidgets('아이콘 잉크는 같은 줄 대문자 E의 높이 띠·슬롯 경계 안에 있고 기준선에 닿는다 '
        '(글자 $fontSize, 배율 $scale, 화면 ${dpr}x, 앱 스타일 $material, 줄 높이 $height)', (
      tester,
    ) async {
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
        letter.height / (fontSize * scale * CalcTheme.lcdStatusCapHeightRatio),
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
      // →x: 굵은 화살표는 대문자 높이 띠 가운데에 대칭이고 머리가 몸통보다 높다. x는 한 칸 폭 상자 안에 있다 —
      // 상자는 띠를 채우고, 왼쪽 변 가운데가 열려 화살표 끝이 들어간다. 가운데 줄은 화살표 끝·x·오른쪽 변 세 구간이다.
      // 가로(#183): 잉크 전체는 lcdStatusStoreInkCells칸(상자 한 칸 + 상자 밖 화살표)이고 2칸 슬롯 가운데에 놓인다.
      final store = _slotRect(tester, LcdIndicatorSlot.store);
      // 슬롯 안 좌표(계산값): 슬롯이 줄면 가운데 기준으로 같은 비율로 준다. [u]는 줄기 전 슬롯 왼쪽에서 잰 dp.
      final advance = store.width / 2;
      final cell = advance - CalcTheme.lcdStatusStyle.letterSpacing!;
      double storeX(double u) =>
          store.left + store.width * (1 - shrink) / 2 + u * shrink;
      const inkCells = CalcTheme.lcdStatusStoreInkCells;
      final boxLeft = storeX(advance + (inkCells / 2 - 1) * cell);
      double col1X(double fraction) => boxLeft + cell * shrink * fraction;
      final storeInk = shot.inkBounds(
        _scanRect(tester, LcdIndicatorSlot.store),
      )!;
      expect(
        storeInk.width,
        closeTo(inkCells * cell * shrink, reach),
        reason: '→x 잉크 $storeInk — 상자 한 칸 + 화살표',
      );
      expect(
        storeInk.center.dx,
        closeTo(store.center.dx, reach),
        reason: '→x 잉크 $storeInk는 슬롯 $store 가운데에 놓인다',
      );
      // 상자 왼쪽 변(짧은 변)의 안티에일리어싱이 섞이지 않도록 물리 1px 앞까지만 화살표로 본다.
      final arrow = shot.inkBounds(
        Rect.fromLTRB(store.left, store.top, boxLeft - 1 / dpr, store.bottom),
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
      final boxed = Rect.fromLTRB(
        boxLeft,
        store.top,
        store.right,
        store.bottom,
      );
      final box = shot.inkBounds(boxed)!;
      expect(box.top, closeTo(letter.top, reach), reason: 'x 상자 $box');
      expect(box.bottom, closeTo(letter.bottom, reach), reason: 'x 상자 $box');
      expect(box.right, closeTo(col1X(1), reach), reason: 'x 상자 $box는 한 칸 폭이다');
      final cap = letter.height;
      double capY(double fraction) => letter.top + cap * fraction;
      // x 잉크: 화살표 끝(12%)·왼쪽 짧은 변(0~17%)·오른쪽 변(83%~)·위아래 변과 그 안티에일리어싱 밖의 안쪽만 본다
      // (x는 가로 약 26~74%, 세로 약 29~71%).
      final xInk = shot.inkBounds(
        Rect.fromLTRB(col1X(0.22), capY(0.25), col1X(0.78), capY(0.75)),
      )!;
      expect(
        xInk.center.dy,
        closeTo(letter.center.dy, reach),
        reason: 'x $xInk',
      );
      // x는 줄인 글자다(x높이 × →x의 x 비율). 글자가 물리 30px 미만이면 힌팅이 x높이를 픽셀 단위로 올려 맞추므로
      // 크기 비교는 하지 않는다(아래 테두리 간격 검사는 한다).
      if (fontSize * scale * dpr >= 30) {
        expect(
          xInk.height,
          closeTo(xHeight * CalcTheme.lcdStatusStoreXRatio, reach),
          reason: 'x $xInk',
        );
      }
      // x는 테두리에 붙지 않는다(붙으면 ⊠처럼 보인다, #160 리뷰 R1·R2): x와 오른쪽 변 사이, x와 윗변 사이에
      // 배경이 보이는 열·줄이 하나는 있다. 구간 수 대신 밝기로 보므로 안티에일리어싱에 덜 민감하다.
      final borderLeft = col1X(1) - stroke * shrink;
      expect(
        shot.hasGapColumn(xInk.right, borderLeft, xInk.top, xInk.bottom),
        isTrue,
        reason: 'x $xInk, 오른쪽 변 $borderLeft',
      );
      expect(
        shot.hasGapRow(
          letter.top + stroke * shrink,
          xInk.top,
          xInk.left,
          xInk.right,
        ),
        isTrue,
        reason: 'x $xInk, 윗변',
      );

      // √▭✎: 칸 오른쪽 위 짧은 변·연필·아랫변이 서로 떨어져 있다 — 짧은 변 한가운데 세로줄을 위에서 아래로
      // 훑으면 [윗변+짧은 변], [연필], [아랫변] 세 덩어리가 배경으로 나뉜다(#160 리뷰 R2).
      final mathSlot = _slotRect(tester, LcdIndicatorSlot.math);
      final mathAdvance = mathSlot.width / 3;
      final mathCol1 =
          mathSlot.left +
          mathSlot.width * (1 - shrink) / 2 +
          mathAdvance * shrink;
      final stubX =
          mathCol1 +
          (mathAdvance - CalcTheme.lcdStatusStyle.letterSpacing!) *
              shrink *
              0.9 -
          stroke * shrink / 2;
      expect(
        shot.inkRunsVertical(stubX, letter.top + cap * 0.3, letter.bottom),
        3,
        reason: '짧은 변 세로줄 x=$stubX',
      );
    });
  }

  testWidgets('아이콘 모양: 근호 윗선 아래에 칸(⊏)이 매달려 비었고, 연필은 촉을 칸의 열린 오른쪽에 넣고 오른쪽 위로 '
      '기울고, ‖는 반전 상자의 밝은 두 획 (#160)', (tester) async {
    const fontSize = 60.0;
    final shot = await _render(tester, _allOn, fontSize: fontSize);
    final e = shot.inkBounds(_slotRect(tester, LcdIndicatorSlot.engineering))!;
    final stroke = fontSize * CalcTheme.lcdStatusIconStrokeRatio;
    final cap = e.height;

    // √▭✎ (3칸): 첫째 칸 = √, 둘째 칸 = 칸(⊏), 셋째 칸 = 연필 몸통 (연필 촉은 둘째 칸 안)
    final math = _slotRect(tester, LcdIndicatorSlot.math);
    final third = math.width / 3;

    /// [column]째 칸에서 가로 [l]~[r](칸 폭 비율), 세로 [t]~[b](위에서 잰 대문자 높이 비율)
    Rect area(int column, double l, double t, double r, double b) =>
        Rect.fromLTRB(
          math.left + third * (column + l),
          e.top + cap * t,
          math.left + third * (column + r),
          e.top + cap * b,
        );
    final radicalBox = area(0, 0, 0, 2, 1);
    // 윗선: 대문자 윗선 줄에서 근호 꼭대기부터 한 구간이 둘째 칸 대부분까지 이어진다.
    final topRow = e.top + stroke / 2;
    expect(shot.inkRuns(topRow, radicalBox), 1);
    expect(shot.longestRun(topRow, radicalBox), greaterThan(third * 0.8));
    // 칸은 윗선 아래에 띄워 매달렸다 — 대문자 높이 20% 줄에서 둘째 칸은 비었다.
    expect(shot.anyInk(area(1, 0, 0.19, 1, 0.21)), isFalse, reason: '윗선과 칸 사이');
    // 칸 윗변(30%)·아랫변(기준선)은 둘째 칸 폭 대부분을 덮는다.
    expect(
      shot.longestRun(e.top + cap * 0.3 + stroke / 2, area(1, 0, 0, 1, 1)),
      greaterThan(third * 0.6),
      reason: '칸 윗변',
    );
    expect(
      shot.longestRun(e.bottom - stroke / 2, area(1, 0, 0, 1, 1)),
      greaterThan(third * 0.6),
      reason: '칸 아랫변',
    );
    // 칸 안쪽은 비었다.
    expect(shot.anyInk(area(1, 0.3, 0.5, 0.55, 0.8)), isFalse, reason: '칸 안');
    // 근호: 아래쪽 30% 줄에서 첫째 칸에 두 획(왼쪽 획은 대문자 높이 절반쯤에서 시작)
    expect(shot.inkRuns(e.bottom - cap * 0.3, area(0, 0, 0, 1, 1)), 2);

    // 연필: 촉은 칸의 열린 오른쪽 아래에 들어가고, 몸통은 셋째 칸 오른쪽 위로 뻗는다.
    expect(
      shot.anyInk(area(1, 0.6, 0.65, 0.9, 0.85)),
      isTrue,
      reason: '칸 안의 촉',
    );
    expect(shot.anyInk(area(2, 0.65, 0, 1, 0.35)), isTrue, reason: '오른쪽 위');
    // 기준선까지 내려오지 않는다(셋째 칸 아래 15% 띠가 비었다). 셋째 칸 왼쪽 위·오른쪽 아래도 비었다 —
    // 촉에서 오른쪽 위 모서리로 기운 대각선이다.
    expect(shot.anyInk(area(2, 0, 0.85, 1, 1)), isFalse, reason: '아래 띠');
    expect(shot.anyInk(area(2, 0, 0, 0.25, 0.25)), isFalse, reason: '왼쪽 위');
    expect(shot.anyInk(area(2, 0.65, 0.65, 1, 1)), isFalse, reason: '오른쪽 아래');

    // ‖ (1칸) — 반전 상자: 대문자 높이 가운데 줄에서 어두운 구간 셋(왼쪽·가운데·오른쪽) 사이로 밝은 두 획.
    // 위아래 가장자리 줄은 상자가 이어진다(획은 상자 위아래를 뚫지 않는다).
    final disp = _slotRect(tester, LcdIndicatorSlot.disp);
    expect(shot.inkRuns(e.center.dy, disp), 3);
    expect(shot.inkRuns(e.top + 1, disp), 1);
    expect(shot.inkRuns(e.bottom - 1, disp), 1);
    // 밝은 두 획은 칸의 37%·63%에 있고 배경까지 밝다(지운 자리). 그 사이·바깥은 어둡다.
    int redAt(double fraction) => shot.red(
      (disp.left + disp.width * fraction).floor(),
      e.center.dy.floor(),
    );
    expect(redAt(0.37), greaterThan(240), reason: '왼쪽 획');
    expect(redAt(0.63), greaterThan(240), reason: '오른쪽 획');
    for (final dark in [0.15, 0.5, 0.85]) {
      expect(redAt(dark), lessThan(100), reason: '어두운 곳 $dark');
    }
  });

  // (글자 크기, 화면 배율) — 크게, 그리고 실제 크기(폰 LCD 상태 글자 ~10dp, 3x 화면)에서 상자가 글자 모양으로
  // 지워지는지. 6dp·2x는 이슈가 든 작은 끝(상태 글자 6~10dp)이다. 이 검사는 지운 구멍이 남는지만 본다 —
  // 6dp·2x에서는 구멍이 남아도 글자를 알아보기는 어렵다(한계는 `LcdIndicatorSlot` 문서).
  for (final (fontSize, dpr) in [
    (60.0, 1.0),
    (10.0, 3.0),
    (8.0, 2.625),
    (6.0, 2.0),
  ]) {
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
        // 위아래 가장자리 줄은 상자로 꽉 차 있다(글자가 상자 가장자리를 뚫지 않는다). 6~8dp에서는 글자 위아래
        // 여백(상자 높이의 1/7)이 1~2물리 픽셀이라 안티에일리어싱이 섞여 이 검사를 하지 않는다.
        if (fontSize >= 10) {
          expect(shot.inkRuns(box.top + px, rect), 1, reason: reason);
          expect(shot.inkRuns(box.bottom - px, rect), 1, reason: reason);
        }
        // 가운데 줄은 글자 획 자리가 비어 구간이 둘 이상으로 나뉜다.
        expect(
          shot.inkRuns(box.center.dy, rect),
          greaterThanOrEqualTo(2),
          reason: reason,
        );
        // 비운 자리는 배경(흰색)까지 밝다 — 글자를 LCD 배경색(빨강 213)으로 칠한 것이 아니라 상자를 지웠다.
        // 상자 안쪽(가장자리 1물리 픽셀 제외) 전체에서 가장 밝은 픽셀을 본다.
        var brightest = 0;
        for (
          var y = (box.top * dpr).ceil() + 1;
          y < (box.bottom * dpr).floor() - 1;
          y++
        ) {
          for (
            var x = (box.left * dpr).ceil() + 1;
            x < (box.right * dpr).floor() - 1;
            x++
          ) {
            brightest = math.max(brightest, shot.red(x, y));
          }
        }
        // 작은 크기에서는 획이 1~3물리 픽셀이라 안티에일리어싱이 섞인다 — 그래도 LCD 배경색(213)으로 칠한 것보다는 밝다.
        expect(
          brightest,
          greaterThan(fontSize >= 60 ? 240 : 213),
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

  testWidgets('반전 상자 글자: 치수를 넘겨받은 채 색만 바뀌어도 다시 그리고, 글자 크기 없는 스타일로 단독 사용해도 '
      '그린다 (#160)', (tester) async {
    tester.view.physicalSize = const Size(200, 100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final metrics = LcdStatusIconMetrics.of(
      CalcTheme.lcdStatusStyle.copyWith(fontSize: 60),
      TextScaler.noScaling,
      84,
    );
    Widget boxed(Widget child) => RepaintBoundary(
      key: _boundaryKey,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 60, height: 84, child: child),
          ),
        ),
      ),
    );
    const area = Rect.fromLTWH(0, 0, 60, 84);
    // 상태 표시줄처럼 치수를 미리 넘긴다 — 재레이아웃 없이 색만 바뀌는 경로(shouldRepaint).
    await tester.pumpWidget(
      boxed(
        LcdStatusBoxedLetter(
          letter: 'D',
          color: CalcTheme.lcdStatusActive,
          metrics: metrics,
        ),
      ),
    );
    expect((await _capture(tester, 1)).anyInk(area), isTrue);
    await tester.pumpWidget(
      boxed(
        LcdStatusBoxedLetter(
          letter: 'D',
          color: CalcTheme.lcdStatusInactive,
          metrics: metrics,
        ),
      ),
    );
    expect((await _capture(tester, 1)).anyInk(area), isFalse);
    // 치수 없이, 글자 크기 없는 스타일로 단독 사용 — 자기 크기에서 치수를 계산해 그린다.
    // (글꼴은 번들 글꼴로 지정한다 — 테스트 기본 글꼴은 글자가 꽉 찬 사각형이라 상자를 모두 지운다.)
    await tester.pumpWidget(
      boxed(
        const LcdStatusBoxedLetter(
          letter: 'D',
          color: CalcTheme.lcdStatusActive,
          style: TextStyle(fontFamily: CalcTheme.monoFontFamily),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect((await _capture(tester, 1)).anyInk(area), isTrue);
  });

  testWidgets('반전 상자 글자: 켜짐↔꺼짐이 바뀌면 같은 자리에서 다시 그린다 (#160)', (tester) async {
    const fontSize = 60.0;
    var shot = await _render(
      tester,
      const LcdStatus(shift: true),
      fontSize: fontSize,
    );
    final rect = _slotRect(tester, LcdIndicatorSlot.shift);
    expect(shot.anyInk(rect), isTrue);
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
    expect(shot.anyInk(rect), isFalse);
    expect(shot.darkest(rect), lessThan(255), reason: '꺼진 색으로 그리기는 한다');
  });

  testWidgets(
    '굵은 글씨 설정: 반전 상자 글자는 늘 굵게 그려 그대로고, →x의 x도 테두리에 붙지 않도록 그대로다 (#160)',
    (tester) async {
      const fontSize = 60.0;

      /// [rect] 안의 진한 물리 픽셀 수
      int inkCount(_Shot shot, Rect rect) {
        var n = 0;
        for (var y = rect.top.floor(); y < rect.bottom.ceil(); y++) {
          for (var x = rect.left.floor(); x < rect.right.ceil(); x++) {
            if (shot.inked(x, y)) n++;
          }
        }
        return n;
      }

      Future<_Shot> render(bool bold) async {
        tester.view.physicalSize = const Size(2400, 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(boldText: bold),
            child: RepaintBoundary(
              key: _boundaryKey,
              child: _bar(
                _allOn,
                CalcTheme.lcdStatusStyle.copyWith(fontSize: fontSize),
                1.0,
                false,
              ),
            ),
          ),
        );
        return _capture(tester, 1.0);
      }

      final normal = await render(false);
      final store = _slotRect(tester, LcdIndicatorSlot.store);
      // x만 보도록 x 상자(한 칸 폭, 슬롯 가운데에서 왼쪽으로 1/4칸부터 — #183)의 안쪽(테두리 제외)을 센다.
      // 이 크기(60dp, 배율 1)에서는 글자가 줄지 않는다.
      final cell = store.width / 2 - CalcTheme.lcdStatusStyle.letterSpacing!;
      final boxLeft =
          store.center.dx + (CalcTheme.lcdStatusStoreInkCells / 2 - 1) * cell;
      final xArea = Rect.fromLTRB(
        boxLeft + cell * 0.22,
        store.top + store.height * 0.3,
        boxLeft + cell * 0.78,
        store.bottom - store.height * 0.3,
      );
      final shift = _slotRect(tester, LcdIndicatorSlot.shift);
      final normalX = inkCount(normal, xArea);
      final normalShift = inkCount(normal, shift);
      final bold = await render(true);
      expect(inkCount(bold, xArea), normalX, reason: 'x는 그대로');
      expect(inkCount(bold, shift), normalShift, reason: '상자 글자는 그대로');
    },
  );
}
