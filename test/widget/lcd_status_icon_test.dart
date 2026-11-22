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

/// 직접 그리는 상태 아이콘(#57)이 같은 줄 글자와 같은 높이·기준선에 그려지는지, 실제 번들 글꼴로
/// 그린 픽셀을 재서 확인한다.

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

/// 슬롯 안에서 잰 잉크 경계 (슬롯 왼쪽 위 기준 dp, 이미지 1px = 1dp)
typedef _Ink = ({double top, double bottom, double left, double right});

/// 실제 번들 글꼴로 상태 표시줄을 [fontSize]·[scale]로 그리고, 슬롯마다 잉크 경계를 잰다.
Future<Map<LcdIndicatorSlot, _Ink?>> _measure(
  WidgetTester tester, {
  required double fontSize,
  required double scale,
}) async {
  tester.view.physicalSize = const Size(2400, 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 2400,
              child: LcdStatusBar(
                status: _allOn,
                style: CalcTheme.lcdStatusStyle.copyWith(fontSize: fontSize),
                textScaler: TextScaler.linear(scale),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final (bytes, width) = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (data!, image.width);
  }))!;

  // 흰 배경 위에 진한 활성 색(#2A2A2A)이 절반 이상 덮인 픽셀
  bool inked(int x, int y) => bytes.getUint8((y * width + x) * 4) < 140;

  final result = <LcdIndicatorSlot, _Ink?>{};
  for (final slot in LcdIndicatorSlot.values) {
    final rect = tester.getRect(find.byKey(ValueKey(slot)));
    int? top, bottom, left, right;
    for (var y = rect.top.floor(); y < rect.bottom.ceil(); y++) {
      for (var x = rect.left.floor(); x < rect.right.ceil(); x++) {
        if (!inked(x, y)) continue;
        if (top == null || y < top) top = y;
        if (bottom == null || y + 1 > bottom) bottom = y + 1;
        if (left == null || x < left) left = x;
        if (right == null || x + 1 > right) right = x + 1;
      }
    }
    result[slot] = top == null
        ? null
        : (
            top: top - rect.top,
            bottom: bottom! - rect.top,
            left: left! - rect.left,
            right: right! - rect.left,
          );
  }
  return result;
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

  for (final scale in [1.0, 1.3]) {
    testWidgets(
      '아이콘 잉크는 같은 줄 대문자(E)의 높이 띠 안에 있고 칸 수만큼의 폭 안에 그려진다 (글자 배율 $scale)',
      (tester) async {
        const fontSize = 60.0;
        final ink = await _measure(tester, fontSize: fontSize, scale: scale);
        final letter = ink[LcdIndicatorSlot.engineering]!;
        const tolerance = 1.5; // 안티에일리어싱
        for (final slot in LcdIndicatorSlot.values) {
          if (slot.icon == null) continue;
          final icon = ink[slot];
          expect(icon, isNotNull, reason: '${slot.name}이 그려지지 않았다');
          final reason =
              '${slot.name} 잉크 ${icon!.top}~${icon.bottom}, '
              'E ${letter.top}~${letter.bottom}';
          // 기준선 아래로 내려가지 않고, 대문자 높이를 넘지 않는다.
          expect(
            icon.bottom,
            lessThanOrEqualTo(letter.bottom + tolerance),
            reason: reason,
          );
          expect(
            icon.top,
            greaterThanOrEqualTo(letter.top - tolerance),
            reason: reason,
          );
          // 기준선까지 내려온다 (공중에 뜨지 않는다).
          expect(
            icon.bottom,
            greaterThanOrEqualTo(letter.bottom - tolerance),
            reason: reason,
          );
          // 슬롯 폭 안에 그린다.
          final slotWidth = tester.getSize(find.byKey(ValueKey(slot))).width;
          expect(icon.left, greaterThanOrEqualTo(0), reason: reason);
          expect(icon.right, lessThanOrEqualTo(slotWidth), reason: reason);
        }
        // 근호·이중선은 대문자 높이까지 올라가고, →x는 x높이까지다.
        for (final slot in [LcdIndicatorSlot.math, LcdIndicatorSlot.disp]) {
          expect(
            ink[slot]!.top,
            lessThanOrEqualTo(letter.top + tolerance),
            reason: slot.name,
          );
        }
        final xTop =
            letter.bottom - fontSize * scale * CalcTheme.lcdStatusXHeightRatio;
        expect(
          ink[LcdIndicatorSlot.store]!.top,
          closeTo(xTop, tolerance),
          reason: '→x의 위쪽은 x높이',
        );
      },
    );
  }

  testWidgets('켜진 아이콘은 켜진 색, 꺼진 아이콘은 꺼진 색으로 그린다', (tester) async {
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
