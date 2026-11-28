import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';

/// 키캡 크기를 실물 fx-991EX에 맞춘 규칙 (#220, [CalcTheme] "키캡 크기 (#220)" 절):
/// - 각인 띠는 모든 구역이 함수부 띠와 같은 높이다 — 숫자부 셀이 높은 몫은 키캡이 받는다.
/// - 키캡은 셀 가운데에 구역별 가로/세로 비 상한까지 좁혀 그리되 셀 폭의 [CalcTheme.keyCapMinWidthRatio] 아래로는 줄이지
///   않는다. 터치 영역은 셀 폭 그대로다.

final _numberIds = {for (final r in numberRows) ...r.map((d) => d.id)};

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

Finder _button(CalcKeyId id) =>
    find.byWidgetPredicate((w) => w is CalcKeyButton && w.keyDef.id == id);

Future<void> _pumpScreen(
  WidgetTester tester,
  Size size,
  EdgeInsets padding, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
}

/// [id] 키의 SHIFT·ALPHA 각인(키캡 위 각인 띠의 `FittedBox` — 평문·2차원 모두)이 셀 폭 안에 있고, 따로 줄지 않았는지
/// 확인한다 (#220 R1·R2 — 좁힌 키캡에서도 통일 글자 크기 그대로 그린다. #264부터 각인은 그린 키캡에 맞춰 놓되 긴 각인 쌍은
/// 실물처럼 키캡 밖 셀 폭까지 쓴다 — 키캡 안에 놓이는 자리는 `legend_band_alignment_test.dart`가 본다).
void _expectLegendsInsideCellUnscaled(WidgetTester tester, CalcKeyId id) {
  final cap = tester.getRect(_keycap(id));
  final cell = tester.getRect(_button(id));
  final boxes = find.descendant(
    of: _button(id),
    matching: find.byType(FittedBox),
  );
  for (final e in boxes.evaluate()) {
    final box = tester.getRect(find.byWidget(e.widget));
    if (box.bottom > cap.top + 0.01) continue; // 키캡 안 메인 라벨
    final reason = '${id.name} 각인 $box (셀 $cell)';
    expect(box.left, greaterThanOrEqualTo(cell.left - 0.01), reason: reason);
    expect(box.right, lessThanOrEqualTo(cell.right + 0.01), reason: reason);
    final render = e.renderObject! as RenderFittedBox;
    final child = render.child!.size;
    expect(
      child.width,
      lessThanOrEqualTo(render.size.width + 0.01),
      reason: reason,
    );
    expect(
      child.height,
      lessThanOrEqualTo(render.size.height + 0.01),
      reason: reason,
    );
  }
}

/// 화면에 그린 키패드의 치수
KeypadMetrics _drawnMetrics(WidgetTester tester) {
  final keypad = tester.widget<CalcKeypad>(find.byType(CalcKeypad));
  return KeypadMetrics.compute(
    tester.getSize(find.byKey(const ValueKey('calc-keypad'))),
    TextScaler.noScaling,
    arrangement: keypad.arrangement,
  );
}

/// 그린 키캡의 가로/세로 비 (키캡 위젯 상자 — 눌림 여유·옆면 제외)
double _aspectOf(WidgetTester tester, CalcKeyId id) {
  final cap = tester.getSize(_keycap(id));
  return cap.width / cap.height;
}

void main() {
  // 각인 폭·축소는 실제 글꼴로 잰다 (키캡 치수는 글꼴과 무관하다)
  setUpAll(loadBundledFonts);

  group('keyCapFaceWidth', () {
    test('키캡이 상한보다 납작하지 않으면 셀 폭 그대로다', () {
      expect(
        keyCapFaceWidth(cellWidth: 50, faceHeight: 30, maxAspectRatio: 1.85),
        50,
      );
    });

    test('납작하면 가로/세로 비 상한까지 줄인다', () {
      expect(
        keyCapFaceWidth(cellWidth: 60, faceHeight: 30, maxAspectRatio: 1.85),
        closeTo(55.5, 1e-9),
      );
    });

    test('셀 폭의 하한 비율 아래로는 줄이지 않는다', () {
      expect(
        keyCapFaceWidth(cellWidth: 100, faceHeight: 20, maxAspectRatio: 1.49),
        closeTo(100 * CalcTheme.keyCapMinWidthRatio, 1e-9),
      );
    });

    test('음수·0 입력에서 음수가 되지 않는다', () {
      expect(
        keyCapFaceWidth(cellWidth: -5, faceHeight: 10, maxAspectRatio: 1.85),
        0,
      );
      expect(
        keyCapFaceWidth(cellWidth: 40, faceHeight: -3, maxAspectRatio: 1.85),
        closeTo(40 * CalcTheme.keyCapMinWidthRatio, 1e-9),
      );
    });
  });

  group('KeypadMetrics 각인 띠·키캡 (#220)', () {
    for (final (size, arrangement) in [
      (const Size(344, 458.7), KeypadArrangement.standard),
      (const Size(304, 400), KeypadArrangement.standard),
      (const Size(784, 910.5), KeypadArrangement.standard),
      (const Size(825, 234.5), KeypadArrangement.wide),
    ]) {
      test(
        '$size ${arrangement.name}: 모든 구역의 각인 띠가 함수부 띠와 같고, 숫자부 키캡이 남는 높이를 받는다',
        () {
          final m = KeypadMetrics.compute(
            size,
            TextScaler.noScaling,
            arrangement: arrangement,
          );
          expect(
            m.legendBandHeight,
            closeTo(m.functionKeyHeight * CalcTheme.keyLegendHeightRatio, 1e-9),
          );
          expect(
            m.functionCapHeight,
            closeTo(m.functionKeyHeight - m.legendBandHeight, 1e-9),
          );
          expect(
            m.numberCapHeight,
            closeTo(m.numberKeyHeight - m.legendBandHeight, 1e-9),
          );
          // 숫자부 키캡이 셀 비율 띠(#220 전)보다 높다
          expect(
            m.numberCapHeight,
            greaterThan(
              m.numberKeyHeight * (1 - CalcTheme.keyLegendHeightRatio),
            ),
          );
          expect(m.functionCapWidth, lessThanOrEqualTo(m.functionKeyWidth));
          expect(m.numberCapWidth, lessThanOrEqualTo(m.numberKeyWidth));
        },
      );
    }
  });

  group('화면에 그린 키캡 (#220)', () {
    // (창, 인셋) — 폰·작은 폰·21:9 폰·태블릿 세로·가로형·Fold 내부
    const cases = [
      (Size(360, 800), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(320, 568), EdgeInsets.only(top: 20)),
      (Size(412, 915), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(800, 1280), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(800, 360), EdgeInsets.only(top: 24)),
      (Size(841, 701), EdgeInsets.only(top: 24, bottom: 32)),
      // 키패드가 실물 비보다 넓은 창 — 폭 하한에 걸린다 (#220 R1)
      (Size(1024, 1366), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(600, 960), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(673, 841), EdgeInsets.zero),
      (Size(360, 520), EdgeInsets.only(top: 24)),
      (Size(2000, 400), EdgeInsets.zero),
    ];
    for (final (size, padding) in cases) {
      testWidgets('$size: 각인 띠가 구역과 무관하게 같고, 키캡은 셀 가운데에 비 상한·폭 하한 규칙대로 그린다', (
        tester,
      ) async {
        await _pumpScreen(tester, size, padding);
        final m = _drawnMetrics(tester);
        for (final def in allKeys) {
          if (def.category == KeyCategory.cursor ||
              def.face == KeyFace.roundButton) {
            continue;
          }
          final number = _numberIds.contains(def.id);
          final cell = tester.getRect(_button(def.id));
          final cap = tester.getRect(_keycap(def.id));
          final reason = def.id.name;
          // 키캡 윗변 = 셀 윗변 + 함수부 각인 띠 (숫자부도 같다)
          expect(
            cap.top - cell.top,
            closeTo(m.legendBandHeight, 0.01),
            reason: reason,
          );
          // 셀 가운데
          expect(cap.center.dx, closeTo(cell.center.dx, 0.01), reason: reason);
          // 폭 = 구역 규칙 (키패드 치수와 같은 값)
          expect(
            cap.width,
            closeTo(number ? m.numberCapWidth : m.functionCapWidth, 0.01),
            reason: reason,
          );
          final maxAspect = number
              ? CalcTheme.keyCapNumberMaxAspectRatio
              : CalcTheme.keyCapMaxAspectRatio;
          final atFloor =
              (cap.width - cell.width * CalcTheme.keyCapMinWidthRatio).abs() <
              0.01;
          expect(
            cap.width / cap.height <= maxAspect + 1e-6 || atFloor,
            isTrue,
            reason:
                '$reason: ${cap.width}×${cap.height} (셀 폭 ${cell.width}) — 비 상한 또는 폭 하한',
          );
          expect(
            cap.width,
            greaterThanOrEqualTo(
              cell.width * CalcTheme.keyCapMinWidthRatio - 0.01,
            ),
            reason: reason,
          );
          // 실물보다 세로로 길지 않고, #220 전 규칙(셀 폭 키캡·셀 높이 비율 띠)보다 납작하지 않다
          final aspect = cap.width / cap.height;
          expect(
            aspect,
            greaterThanOrEqualTo(maxAspect - 1e-3),
            reason: reason,
          );
          final oldCap =
              cell.height * (1 - CalcTheme.keyLegendHeightRatio) -
              CalcTheme.keyPressedOffset;
          expect(
            aspect,
            lessThanOrEqualTo(cell.width / oldCap + 1e-6),
            reason: reason,
          );
          _expectLegendsInsideCellUnscaled(tester, def.id);
        }
      });
    }

    // 글자 배율 1.3(키 글자 배율 상한)에서도 각인이 셀 폭 안에 따로 줄지 않고 들어간다 — 작은 폰·짧은 창·넓은 배열·초광폭
    for (final (size, padding) in const [
      (Size(320, 568), EdgeInsets.only(top: 20)),
      (Size(360, 520), EdgeInsets.only(top: 24)),
      (Size(800, 360), EdgeInsets.only(top: 24)),
      (Size(2000, 400), EdgeInsets.zero),
    ]) {
      testWidgets('$size·글자 배율 1.3: 각인이 셀 폭 안에 축소 없이 들어간다', (tester) async {
        await _pumpScreen(tester, size, padding, textScale: 1.3);
        for (final def in allKeys) {
          if (def.category == KeyCategory.cursor ||
              def.face == KeyFace.roundButton) {
            continue;
          }
          _expectLegendsInsideCellUnscaled(tester, def.id);
        }
      });
    }

    // CalcTheme "키캡 크기 (#220)" 절의 결과 표 — 바꾸면 그 절도 고친다.
    const measured = [
      // (창, 인셋, 함수 키캡 가로/세로, 숫자 키캡 가로/세로)
      (Size(360, 800), EdgeInsets.only(top: 24, bottom: 48), 1.85, 1.55),
      (Size(320, 568), EdgeInsets.only(top: 20), 1.86, 1.69),
      (Size(800, 1280), EdgeInsets.only(top: 24, bottom: 48), 1.93, 1.76),
      (Size(800, 360), EdgeInsets.only(top: 24), 2.18, 1.86),
      (Size(841, 701), EdgeInsets.only(top: 24, bottom: 32), 1.85, 1.49),
      (Size(1024, 1366), EdgeInsets.only(top: 24, bottom: 20), 2.20, 2.01),
      (Size(600, 960), EdgeInsets.only(top: 24, bottom: 48), 2.13, 1.94),
      (Size(360, 520), EdgeInsets.only(top: 24), 2.35, 2.13),
      (Size(2000, 400), EdgeInsets.zero, 4.14, 3.54),
    ];
    for (final (size, padding, function, number) in measured) {
      testWidgets('$size 실측: 함수 키캡 $function, 숫자 키캡 $number', (tester) async {
        await _pumpScreen(tester, size, padding);
        expect(_aspectOf(tester, CalcKeyId.sin), closeTo(function, 0.01));
        expect(_aspectOf(tester, CalcKeyId.optn), closeTo(function, 0.01));
        expect(_aspectOf(tester, CalcKeyId.num7), closeTo(number, 0.01));
        expect(_aspectOf(tester, CalcKeyId.equals), closeTo(number, 0.01));
      });
    }

    testWidgets(
      '600×960: 숫자부 키캡이 48dp를 넘어 숫자부 터치가 키캡뿐이고(50.3dp), 가장 낮은 터치가 된다 (#220 R1)',
      (tester) async {
        await _pumpScreen(
          tester,
          const Size(600, 960),
          const EdgeInsets.only(top: 24, bottom: 48),
        );
        final m = _drawnMetrics(tester);
        final seven = tester.widget<CalcKeyButton>(_button(CalcKeyId.num7));
        final sin = tester.widget<CalcKeyButton>(_button(CalcKeyId.sin));
        expect(seven.extendHitAreaToLegend, isFalse);
        expect(sin.extendHitAreaToLegend, isTrue);
        final numberTouch = m.numberKeyHeight - m.legendBandHeight;
        expect(numberTouch, closeTo(50.3, 0.05));
        expect(
          numberTouch,
          greaterThanOrEqualTo(CalcTheme.keyMinTouchTargetHeight),
        );
        expect(numberTouch, lessThan(m.functionKeyHeight));
        expect(
          KeypadMetrics.minKeyTouchHeightOf(
            tester.getSize(find.byKey(const ValueKey('calc-keypad'))),
            KeypadArrangement.standard,
          ),
          closeTo(numberTouch, 0.01),
        );
      },
    );

    testWidgets('터치 영역의 세로 경계: 각인 띠까지 넓히지 않는 키는 띠 아래부터, 넓히는 키는 셀 위부터다', (
      tester,
    ) async {
      // 함수부 키캡은 48dp 미만(띠까지 넓힘), 숫자부 키캡은 48dp 이상(키캡만)인 키패드
      const size = Size(520, 650);
      final pressed = <CalcKeyId>[];
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: size),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: size,
                child: CalcKeypad(onKeyPressed: pressed.add),
              ),
            ),
          ),
        ),
      );
      final m = KeypadMetrics.compute(size, TextScaler.noScaling);
      expect(m.extendFunctionHitArea, isTrue);
      expect(m.extendNumberHitArea, isFalse);
      Future<bool> hits(CalcKeyId id, double y) async {
        pressed.clear();
        await tester.tapAt(Offset(tester.getRect(_button(id)).center.dx, y));
        await tester.pump(const Duration(milliseconds: 200));
        return pressed.contains(id);
      }

      for (final id in [CalcKeyId.num7, CalcKeyId.multiply]) {
        final cell = tester.getRect(_button(id));
        final bandBottom = cell.top + m.legendBandHeight;
        expect(await hits(id, bandBottom - 0.5), isFalse, reason: id.name);
        expect(await hits(id, bandBottom + 0.5), isTrue, reason: id.name);
      }
      for (final id in [CalcKeyId.sin, CalcKeyId.optn]) {
        final cell = tester.getRect(_button(id));
        expect(await hits(id, cell.top + 0.5), isTrue, reason: id.name);
      }
    });

    testWidgets('키캡 옆 빈 곳(셀 안)을 눌러도 그 키가 입력된다 — 터치 영역은 셀 폭 그대로다', (
      tester,
    ) async {
      final pressed = <CalcKeyId>[];
      tester.view.physicalSize =
          const Size(344, 458.7) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(344, 458.7)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 344,
                height: 458.7,
                child: CalcKeypad(onKeyPressed: pressed.add),
              ),
            ),
          ),
        ),
      );
      for (final id in [CalcKeyId.num7, CalcKeyId.multiply, CalcKeyId.sin]) {
        final cell = tester.getRect(_button(id));
        final cap = tester.getRect(_keycap(id));
        // 전제: 키캡이 셀보다 좁다(숫자부는 폭 하한까지 줄었다)
        if (_numberIds.contains(id)) {
          expect(cap.left - cell.left, greaterThan(3), reason: id.name);
        }
        pressed.clear();
        await tester.tapAt(Offset(cell.left + 0.5, cap.center.dy));
        await tester.tapAt(Offset(cell.right - 0.5, cap.center.dy));
        expect(pressed, [id, id], reason: id.name);
      }
    });
  });
}
