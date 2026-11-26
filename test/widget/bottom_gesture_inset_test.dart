import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/screen_arrangement.dart';

/// 맨 아래 키 행과 아래 시스템 제스처 영역(홈 제스처) — #63.
///
/// 맨 아래 광고 슬롯이 없어져(#141) 키패드가 본체 아래 끝까지 내려온다. 본체 아래 여백은
/// [CalcTheme.screenBottomMargin]이라, 어느 배치에서든 키가 아래 제스처 영역에 닿지 않고
/// 맨 아래 행도 누르는 순간 입력된다.

/// 화면 크기·인셋·제스처 영역·화면 특징을 지정해 [CalculatorScreen]을 띄운다.
Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  required Size size,
  required EdgeInsets padding,
  required EdgeInsets gesture,
  List<DisplayFeature> displayFeatures = const [],
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  tester.view.displayFeatures = displayFeatures;
  addTearDown(tester.view.resetDisplayFeatures);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
            systemGestureInsets: gesture,
            displayFeatures: displayFeatures,
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return container;
}

/// 그려진 키캡 50개 중 가장 아래 끝
double _lowestKeycapBottom(WidgetTester tester) {
  var lowest = double.negativeInfinity;
  for (final id in CalcKeyId.values) {
    final f = find.byKey(CalcKeyButton.keycapKeyOf(id));
    if (f.evaluate().isEmpty) continue;
    final r = tester.getRect(f);
    if (r.bottom > lowest) lowest = r.bottom;
  }
  return lowest;
}

/// 가장 아래 끝이 [lowest]인 키캡 (맨 아래 행)
List<CalcKeyId> _bottomRow(WidgetTester tester, double lowest) => [
  for (final id in CalcKeyId.values)
    if (find.byKey(CalcKeyButton.keycapKeyOf(id)).evaluate().isNotEmpty &&
        (tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id))).bottom -
                    lowest)
                .abs() <
            0.5)
      id,
];

Rect _keypad(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('calc-keypad')));

const _verticalFold = DisplayFeature(
  bounds: Rect.fromLTWH(420.5, 0, 0, 701),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

const _horizontalHalfOpened = DisplayFeature(
  bounds: Rect.fromLTWH(0, 336.5, 841, 0),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureHalfOpened,
);

void main() {
  group('아래 여백 규칙 (CalcTheme.screenBottomMargin)', () {
    test('실측한 기기들은 화면 여백 그대로다 (#63)', () {
      // (인셋, 제스처 영역) — CalcTheme.screenBottomMargin 문서의 실측값
      for (final (padding, gesture) in const [
        (24.0, 32.0), // API 36 폰, 제스처 내비게이션
        (48.0, 48.0), // 같은 폰, 3버튼
        (32.0, 32.0), // API 36 Pixel Fold 내부
        (0.0, 8.0), // API 33 폰, 제스처 내비게이션(edge-to-edge 아님)
        (34.0, 0.0), // iOS — 제스처 영역을 전달하지 않는다
        (0.0, 0.0),
      ]) {
        expect(
          CalcTheme.screenBottomMargin(
            bottomPadding: padding,
            bottomGestureInset: gesture,
          ),
          CalcTheme.screenPadding,
          reason: '인셋 $padding / 제스처 $gesture',
        );
      }
    });

    test('제스처 영역이 인셋보다 화면 여백 넘게 깊으면 그 차이만큼 넓힌다', () {
      expect(
        CalcTheme.screenBottomMargin(bottomPadding: 0, bottomGestureInset: 32),
        32,
      );
      expect(
        CalcTheme.screenBottomMargin(bottomPadding: 24, bottomGestureInset: 48),
        24,
      );
      // 본체 아래 끝(화면 높이 − 인셋 − 여백)이 언제나 제스처 영역 윗변(화면 높이 − 제스처 영역) 이상 위에 있고,
      // 여백은 화면 여백보다 작아지지 않는다.
      for (final padding in [0.0, 8.0, 24.0, 48.0]) {
        for (final gesture in [0.0, 8.0, 24.0, 32.0, 40.0, 64.0]) {
          final margin = CalcTheme.screenBottomMargin(
            bottomPadding: padding,
            bottomGestureInset: gesture,
          );
          expect(margin, greaterThanOrEqualTo(CalcTheme.screenPadding));
          expect(padding + margin, greaterThanOrEqualTo(gesture));
        }
      }
    });
  });

  group('맨 아래 키 행이 아래 제스처 영역 밖에 있다', () {
    // (이름, 창, 인셋, 제스처 영역, 화면 특징, 기대 배치)
    final cases =
        <
          (
            String,
            Size,
            EdgeInsets,
            EdgeInsets,
            List<DisplayFeature>,
            DrawnArrangement,
          )
        >[
          (
            'API 36 폰 제스처 내비게이션 (실측 24/32)',
            const Size(411.43, 914.29),
            const EdgeInsets.only(top: 24, bottom: 24),
            const EdgeInsets.fromLTRB(29.71, 24, 29.71, 32),
            const [],
            DrawnArrangement.stacked,
          ),
          (
            'API 33 폰 (edge-to-edge 아님, 실측 0/8)',
            const Size(411.43, 890.29),
            const EdgeInsets.only(top: 48.76),
            const EdgeInsets.fromLTRB(29.71, 60.95, 29.71, 8),
            const [],
            DrawnArrangement.stacked,
          ),
          (
            '내비게이션 힌트를 숨긴 폰 (인셋 0, 제스처 32)',
            const Size(411.43, 914.29),
            const EdgeInsets.only(top: 24),
            const EdgeInsets.fromLTRB(29.71, 24, 29.71, 32),
            const [],
            DrawnArrangement.stacked,
          ),
          (
            '태블릿 가로 좌우 분할 (인셋 0, 제스처 32)',
            const Size(1280, 800),
            const EdgeInsets.only(top: 24),
            const EdgeInsets.fromLTRB(29.71, 24, 29.71, 32),
            const [],
            DrawnArrangement.sideBySide,
          ),
          (
            'Pixel Fold 내부 세로 접힘선 (인셋 0, 제스처 32)',
            const Size(841, 701),
            const EdgeInsets.only(top: 28.19),
            const EdgeInsets.fromLTRB(29.71, 28.19, 29.71, 32),
            const [_verticalFold],
            DrawnArrangement.sideBySide,
          ),
          (
            'Pixel Fold 내부 테이블톱 (인셋 0, 제스처 32)',
            const Size(841, 701),
            const EdgeInsets.only(top: 28.19),
            const EdgeInsets.fromLTRB(29.71, 28.19, 29.71, 32),
            const [_horizontalHalfOpened],
            DrawnArrangement.tabletop,
          ),
        ];

    for (final (name, size, padding, gesture, features, arrangement) in cases) {
      testWidgets(name, (tester) async {
        await _pumpScreen(
          tester,
          size: size,
          padding: padding,
          gesture: gesture,
          displayFeatures: features,
        );
        expect(tester.takeException(), isNull);
        expect(drawnArrangementOf(tester), arrangement);
        final zoneTop = size.height - gesture.bottom;
        final margin = CalcTheme.screenBottomMargin(
          bottomPadding: padding.bottom,
          bottomGestureInset: gesture.bottom,
        );
        // 키패드(본체 아래 끝)는 인셋 + 아래 여백 위에서 끝나고, 그 끝은 제스처 영역 윗변보다 아래로 가지 않는다.
        expect(
          _keypad(tester).bottom,
          moreOrLessEquals(
            size.height - padding.bottom - margin,
            epsilon: 0.01,
          ),
        );
        expect(_keypad(tester).bottom, lessThanOrEqualTo(zoneTop + 0.01));
        expect(_lowestKeycapBottom(tester), lessThanOrEqualTo(zoneTop));
      });
    }

    testWidgets('인셋이 제스처 영역과 같으면(3버튼) 제스처 영역이 없을 때와 배치가 같다', (tester) async {
      const size = Size(411.43, 914.29);
      const padding = EdgeInsets.only(top: 24, bottom: 48);
      await _pumpScreen(
        tester,
        size: size,
        padding: padding,
        gesture: EdgeInsets.zero,
      );
      final without = _keypad(tester);
      await _pumpScreen(
        tester,
        size: size,
        padding: padding,
        gesture: const EdgeInsets.only(top: 24, bottom: 48),
      );
      expect(_keypad(tester), without);
    });

    testWidgets('인셋 없이 제스처 영역만 깊으면 키패드가 그만큼만 위로 물러난다', (tester) async {
      const size = Size(411.43, 914.29);
      const padding = EdgeInsets.only(top: 24);
      await _pumpScreen(
        tester,
        size: size,
        padding: padding,
        gesture: EdgeInsets.zero,
      );
      final without = _keypad(tester);
      await _pumpScreen(
        tester,
        size: size,
        padding: padding,
        gesture: const EdgeInsets.only(top: 24, bottom: 32),
      );
      final withGesture = _keypad(tester);
      expect(
        without.bottom - withGesture.bottom,
        moreOrLessEquals(32 - CalcTheme.screenPadding, epsilon: 0.01),
      );
    });
  });

  group('맨 아래 행은 누르는 순간 입력된다', () {
    // 인셋 없이 제스처 영역만 32dp인 폰 — 예전 규칙(아래 여백 8dp 고정)이면 맨 아래 행 키캡의 아래 일부가
    // 제스처 영역에 들어가 손을 뗄 때 입력됐다.
    for (final (name, padding, gesture) in const [
      (
        '인셋 0 / 제스처 32',
        EdgeInsets.only(top: 24),
        EdgeInsets.fromLTRB(29.71, 24, 29.71, 32),
      ),
      (
        '실측 24 / 32',
        EdgeInsets.only(top: 24, bottom: 24),
        EdgeInsets.fromLTRB(29.71, 24, 29.71, 32),
      ),
    ]) {
      testWidgets(name, (tester) async {
        const size = Size(411.43, 914.29);
        final container = await _pumpScreen(
          tester,
          size: size,
          padding: padding,
          gesture: gesture,
        );
        final lowest = _lowestKeycapBottom(tester);
        final row = _bottomRow(tester, lowest);
        expect(row, isNotEmpty);
        var count = container.read(calcProvider).inputCount;
        for (final id in row) {
          final r = tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id)));
          // 좌우 뒤로가기 영역은 따로 보류된다(#50) — 그 밖의 가로 위치에서, 키캡 아래 끝 바로 위를 누른다.
          final x = r.center.dx.clamp(
            gesture.left + 1,
            size.width - gesture.right - 1,
          );
          if (x < r.left || x > r.right) continue;
          final touch = await tester.startGesture(Offset(x, r.bottom - 1));
          await tester.pump();
          // 손을 떼기 전에 이미 입력됐다.
          expect(
            container.read(calcProvider).inputCount,
            count + 1,
            reason: '$id',
          );
          expect(container.read(calcProvider).lastInput?.id, id);
          await touch.up();
          await tester.pump();
          count = container.read(calcProvider).inputCount;
        }
      });
    }
  });
}
