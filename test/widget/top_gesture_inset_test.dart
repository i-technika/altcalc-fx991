import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../support/screen_arrangement.dart';

/// 키패드와 위 시스템 제스처 영역(알림창 끌어내리기) — #172, #285.
///
/// 모든 배치에서 본체 윗변에는 LCD(최소 [CalcTheme.screenLcdMinHeight])가 오고 키패드는 그 아래라, 위 제스처 영역이 깊어도
/// 키패드가 영역에서 멀고 배치가 바뀌지 않는다. #285 전에는 손 쪽 패널이 짧은 책 자세의 키패드가 본체 윗변 가까이 와서, 영역이
/// 깊은 기기에서는 키패드를 영역 아래에 뒀다(#172, `CalcTheme.screenTopGestureDepth` — #285에서 책 자세를 태블릿 가로형처럼
/// 바꾸며 없앴다).
///
/// 값의 출처: "실측"은 에뮬레이터 실측(#63·#118)이다. 접힘선 창의 깊은 위 제스처 영역(56 등)은 실측이 없는 가정값이다 — 실기기
/// 확인은 #177.

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

Rect _keypad(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('calc-keypad')));

/// 세로 접힘선 (창 높이 전체, x = [x])
DisplayFeature _verticalFold(double x, double height) => DisplayFeature(
  bounds: Rect.fromLTWH(x, 0, 0, height),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

/// 좌우 뒤로가기 영역 (실측 29.71) + 위 영역 [top]
EdgeInsets _gestureWithTop(double top) =>
    EdgeInsets.fromLTRB(29.71, top, 29.71, 0);

void main() {
  group('다른 배치는 위 제스처 영역이 깊어도 바뀌지 않는다 (키패드가 영역에서 멀다)', () {
    // (이름, 창, 인셋, 깊은 위 제스처 영역, 화면 특징, 기대 배치)
    final cases =
        <
          (
            String,
            Size,
            EdgeInsets,
            double,
            List<DisplayFeature>,
            DrawnArrangement,
          )
        >[
          (
            'API 33 폰 위아래 배치 (실측 48.76 / 60.95)',
            const Size(411.43, 890.29),
            const EdgeInsets.only(top: 48.76),
            60.95,
            const [],
            DrawnArrangement.stacked,
          ),
          (
            'Pixel Fold 커버 위아래 배치 (실측 41.9 / 54.1)',
            const Size(411.43, 797),
            const EdgeInsets.only(top: 41.9, bottom: 24),
            54.1,
            const [],
            DrawnArrangement.stacked,
          ),
          (
            '태블릿 가로 가로형 (인셋 24 / 위 제스처 56, 가정)',
            const Size(1280, 800),
            const EdgeInsets.only(top: 24, bottom: 32),
            56,
            const [],
            DrawnArrangement.landscape,
          ),
          (
            '짧은 창 가로형 640×360 (접힘선 없음, 인셋 24 / 위 제스처 56, 가정)',
            const Size(640, 360),
            const EdgeInsets.only(top: 24),
            56,
            const [],
            DrawnArrangement.landscape,
          ),
          (
            'Pixel Fold 내부 책 자세 (인셋 28.19 / 위 제스처 56, 가정)',
            const Size(841, 701),
            const EdgeInsets.only(top: 28.19, bottom: 32),
            56,
            [_verticalFold(420.5, 701)],
            DrawnArrangement.sideBySide,
          ),
          (
            '짧은 창 책 자세 640×360 (접힘선 x=320, 인셋 24 / 위 제스처 56, 가정 — #285 전에는 키패드가 본체 윗변부터였다)',
            const Size(640, 360),
            const EdgeInsets.only(top: 24),
            56,
            [_verticalFold(320, 360)],
            DrawnArrangement.sideBySide,
          ),
          (
            '가로 접힘선 701×841 (인셋 28.19 / 위 제스처 56, 가정)',
            const Size(701, 841),
            const EdgeInsets.only(top: 28.19, bottom: 32),
            56,
            const [
              DisplayFeature(
                bounds: Rect.fromLTWH(0, 420.5, 701, 0),
                type: DisplayFeatureType.fold,
                state: DisplayFeatureState.postureFlat,
              ),
            ],
            DrawnArrangement.tabletop,
          ),
        ];
    for (final (name, size, padding, topGesture, features, arrangement)
        in cases) {
      testWidgets(name, (tester) async {
        await _pumpScreen(
          tester,
          size: size,
          padding: padding,
          gesture: _gestureWithTop(padding.top),
          displayFeatures: features,
        );
        final without = _keypad(tester);
        await _pumpScreen(
          tester,
          size: size,
          padding: padding,
          gesture: _gestureWithTop(topGesture),
          displayFeatures: features,
        );
        expect(tester.takeException(), isNull);
        expect(drawnArrangementOf(tester), arrangement);
        expect(_keypad(tester), without);
        // 키패드 윗변은 본체 윗변에서 LCD 최소 높이 + 간격 넘게 아래라, 위 제스처 영역에서 멀다.
        expect(
          _keypad(tester).top,
          greaterThanOrEqualTo(
            padding.top +
                CalcTheme.screenPadding +
                CalcTheme.screenLcdMinHeight +
                CalcTheme.screenLcdKeypadGap -
                0.01,
          ),
        );
        expect(_keypad(tester).top, greaterThan(topGesture + 60));
      });
    }
  });
}
