import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/device_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/screen_arrangement.dart';

/// 접힘선 2개(펼친 트라이폴드) 화면은 접힘선을 무시하고 태블릿과 같은 배치로 그린다 (#144).
/// 규칙은 `FormFactor.arrangementOf` "트라이폴드" 절. 화면 크기·접힘선 위치는 이슈의 가정 값(실기기 미확인)이다.

/// 펼친 트라이폴드 가로 화면 (가정: 960×704dp)
const _landscape = Size(960, 704);

/// 세로로 돌린 화면
const _portrait = Size(704, 960);

/// 상태 표시줄·제스처 핸들 (미리보기 트라이폴드 프리셋과 같은 근사)
const _padding = EdgeInsets.only(top: 24, bottom: 24);

/// 가로 화면의 세로 접힘선 2개 (x=320·640)
List<DisplayFeature> _verticalFolds(DisplayFeatureState state) => [
  for (final x in [320.0, 640.0])
    DisplayFeature(
      bounds: Rect.fromLTWH(x, 0, 0, _landscape.height),
      type: DisplayFeatureType.fold,
      state: state,
    ),
];

/// 세로로 돌린 화면의 가로 접힘선 2개 (y=640·320 — 반시계 방향으로 돌린 순서)
List<DisplayFeature> _horizontalFolds(DisplayFeatureState state) => [
  for (final y in [640.0, 320.0])
    DisplayFeature(
      bounds: Rect.fromLTWH(0, y, _portrait.width, 0),
      type: DisplayFeatureType.fold,
      state: state,
    ),
];

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));

/// [size] 창·[features] 접힘 정보로 [CalculatorScreen]을 띄운다. [foldable]은 폴더블 기기 여부
/// (`foldableDeviceProvider` — 실제 앱은 시작 판정·화면 정보로 정한다)이고, 바꿀 수 있게 그대로 넘긴다.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size size,
  required List<DisplayFeature> features,
  ValueListenable<bool>? foldable,
  Handedness handedness = Handedness.right,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({
    HandednessNotifier.storageKey: handedness.storageValue,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (foldable != null) foldableDeviceProvider.overrideWithValue(foldable),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(_app(container, size: size, features: features));
  return container;
}

Widget _app(
  ProviderContainer container, {
  required Size size,
  required List<DisplayFeature> features,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: _padding,
        viewPadding: _padding,
        displayFeatures: features,
      ),
      child: const CalculatorScreen(),
    ),
  ),
);

/// LCD·키패드 위치 (화면 좌표)
({Rect lcd, Rect keypad}) _rects(WidgetTester tester) =>
    (lcd: tester.getRect(_lcd), keypad: tester.getRect(_keypad));

void main() {
  group('펼친 트라이폴드: 접힘선 없는 창과 같은 배치', () {
    for (final state in [
      DisplayFeatureState.postureFlat,
      DisplayFeatureState.postureHalfOpened,
    ]) {
      for (final foldable in [true, false]) {
        for (final handedness in Handedness.values) {
          final name = '${state.name}·폴더블=$foldable·${handedness.name}';

          testWidgets('가로 960×704 ($name): 가로형이고, 접힘선 없는 같은 창과 위치가 같다', (
            tester,
          ) async {
            // 접힘선 없는 태블릿 창의 배치 (기준)
            await _pump(
              tester,
              size: _landscape,
              features: const [],
              handedness: handedness,
            );
            final free = _rects(tester);

            await _pump(
              tester,
              size: _landscape,
              features: _verticalFolds(state),
              foldable: ValueNotifier(foldable),
              handedness: handedness,
            );
            expect(tester.takeException(), isNull);
            expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));
            expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
            final r = _rects(tester);
            expect(r.lcd, free.lcd);
            expect(r.keypad, free.keypad);
            // 두 접힘선 모두 키패드 위를 지나간다 — 접힘선을 무시했다
            for (final x in [320.0, 640.0]) {
              expect(r.keypad.left, lessThan(x));
              expect(r.keypad.right, greaterThan(x));
            }
          });

          testWidgets('세로로 돌림 704×960 ($name): 세로형이고, 접힘선 없는 같은 창과 위치가 같다', (
            tester,
          ) async {
            await _pump(
              tester,
              size: _portrait,
              features: const [],
              handedness: handedness,
            );
            final free = _rects(tester);

            await _pump(
              tester,
              size: _portrait,
              features: _horizontalFolds(state),
              foldable: ValueNotifier(foldable),
              handedness: handedness,
            );
            expect(tester.takeException(), isNull);
            expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));
            expect(drawnArrangementOf(tester), DrawnArrangement.stacked);
            final r = _rects(tester);
            expect(r.lcd, free.lcd);
            expect(r.keypad, free.keypad);
            // 아래쪽 접힘선(y=640)이 키패드 위를 지나간다
            expect(r.keypad.top, lessThan(640));
            expect(r.keypad.bottom, greaterThan(640));
          });
        }
      }
    }
  });

  testWidgets(
    '시작 직후 접힘 정보가 오기 전에는 위아래 배치이고, 접힘선 2개가 오면 그 프레임에 가로형으로 바뀐다 (입력 유지)',
    (tester) async {
      final foldable = ValueNotifier(true);
      final container = await _pump(
        tester,
        size: _landscape,
        features: const [],
        foldable: foldable,
      );
      // 폴더블 기기의 깜빡임 방지 규칙(#25) — 접힘 정보가 오기 전
      expect(drawnArrangementOf(tester), DrawnArrangement.stacked);
      await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.num8)));
      await tester.pump();
      final inputs = container.read(calcProvider).inputCount;
      expect(inputs, greaterThan(0));

      await tester.pumpWidget(
        _app(
          container,
          size: _landscape,
          features: _verticalFolds(DisplayFeatureState.postureFlat),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
      expect(container.read(calcProvider).inputCount, inputs);
    },
  );

  testWidgets(
    '두 장에 걸친 분할 창(640×704, 둘째 접힘선이 창 가장자리)은 접힘선 1개 규칙 — 가운데 접힘선 기준 좌우 배치',
    (tester) async {
      const window = Size(640, 704);
      await _pump(
        tester,
        size: window,
        features: [
          for (final x in [320.0, 640.0])
            DisplayFeature(
              bounds: Rect.fromLTWH(x, 0, 0, window.height),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureFlat,
            ),
        ],
        foldable: ValueNotifier(true),
      );
      expect(tester.takeException(), isNull);
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
      final r = _rects(tester);
      // 키패드(오른손 — 오른쪽 절반)와 LCD가 가운데 접힘선을 넘지 않는다
      expect(r.keypad.left, greaterThanOrEqualTo(320));
      expect(r.lcd.right, lessThanOrEqualTo(320));
    },
  );
}
