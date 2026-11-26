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
///
/// 값의 출처: "실측"은 [CalcTheme.screenBottomMargin] 문서의 에뮬레이터 실측이고, "인셋 0 / 제스처 32"는
/// 에뮬레이터로 만들 수 없어 실측하지 못한 가정이다(내비게이션 힌트를 숨긴 제스처 내비게이션 등, 실기기 확인은 #118).

/// 화면 크기·인셋·제스처 영역·화면 특징을 지정해 [CalculatorScreen]을 띄운다.
/// [viewPadding]을 주지 않으면 [padding]과 같다(키보드 없음).
Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  required Size size,
  required EdgeInsets padding,
  required EdgeInsets gesture,
  EdgeInsets? viewPadding,
  EdgeInsets viewInsets = EdgeInsets.zero,
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
            viewPadding: viewPadding ?? padding,
            viewInsets: viewInsets,
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

/// 제스처 내비게이션의 제스처 영역 (실측: 좌우 뒤로가기 29.71, 아래 32)
const _gestureNav = EdgeInsets.fromLTRB(29.71, 24, 29.71, 32);

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
    // (이름, 창, 인셋, 제스처 영역, 화면 특징, 기대 배치, 기대 키패드 아래 끝)
    // 기대값은 창 높이 − 아래 인셋 − 아래 여백을 손으로 적은 숫자다(규칙 함수로 계산하지 않는다).
    const cases =
        <
          (
            String,
            Size,
            EdgeInsets,
            EdgeInsets,
            List<DisplayFeature>,
            DrawnArrangement,
            double,
          )
        >[
          (
            'API 36 폰 제스처 내비게이션 (실측 24/32)',
            Size(411.43, 914.29),
            EdgeInsets.only(top: 24, bottom: 24),
            _gestureNav,
            [],
            DrawnArrangement.stacked,
            914.29 - 24 - 8, // 여백 8 — 본체 아래 끝이 제스처 영역 윗변(882.29)과 같다
          ),
          (
            'API 33 폰 (edge-to-edge 아님, 실측 0/8)',
            Size(411.43, 890.29),
            EdgeInsets.only(top: 48.76),
            EdgeInsets.fromLTRB(29.71, 60.95, 29.71, 8),
            [],
            DrawnArrangement.stacked,
            890.29 - 0 - 8, // 여백 8 — 본체 아래 끝이 제스처 영역 윗변(882.29)과 같다
          ),
          (
            '폰 (인셋 0 / 제스처 32, 미실측 가정)',
            Size(411.43, 914.29),
            EdgeInsets.only(top: 24),
            _gestureNav,
            [],
            DrawnArrangement.stacked,
            914.29 - 0 - 32, // 여백 32
          ),
          (
            '태블릿 가로 좌우 분할 (인셋 0 / 제스처 32, 미실측 가정)',
            Size(1280, 800),
            EdgeInsets.only(top: 24),
            _gestureNav,
            [],
            DrawnArrangement.sideBySide,
            800 - 0 - 32,
          ),
          (
            'Pixel Fold 내부 세로 접힘선 (실측 32/32)',
            Size(841, 701),
            EdgeInsets.only(top: 28.19, bottom: 32),
            EdgeInsets.fromLTRB(29.71, 28.19, 29.71, 32),
            [_verticalFold],
            DrawnArrangement.sideBySide,
            701 - 32 - 8,
          ),
          (
            'Pixel Fold 내부 세로 접힘선 (인셋 0 / 제스처 32, 미실측 가정)',
            Size(841, 701),
            EdgeInsets.only(top: 28.19),
            EdgeInsets.fromLTRB(29.71, 28.19, 29.71, 32),
            [_verticalFold],
            DrawnArrangement.sideBySide,
            701 - 0 - 32,
          ),
          (
            'Pixel Fold 내부 테이블톱 (인셋 0 / 제스처 32, 미실측 가정)',
            Size(841, 701),
            EdgeInsets.only(top: 28.19),
            EdgeInsets.fromLTRB(29.71, 28.19, 29.71, 32),
            [_horizontalHalfOpened],
            DrawnArrangement.tabletop,
            701 - 0 - 32,
          ),
        ];

    for (final (name, size, padding, gesture, features, arrangement, bottom)
        in cases) {
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
        // 키패드(본체 아래 끝)는 인셋 + 아래 여백 위에서 끝나고, 그 끝은 제스처 영역 윗변보다 아래로 가지 않는다.
        expect(_keypad(tester).bottom, moreOrLessEquals(bottom, epsilon: 0.01));
        expect(_keypad(tester).bottom, lessThanOrEqualTo(zoneTop + 0.01));
        expect(_lowestKeycapBottom(tester), lessThanOrEqualTo(zoneTop));
      });
    }

    // 3버튼(폰)·작업 표시줄(태블릿 가로 좌우 분할): 제스처 영역이 시스템 바 안이라 배치가 바뀌지 않는다.
    for (final size in const [Size(411.43, 914.29), Size(1280, 800)]) {
      testWidgets('인셋이 제스처 영역과 같으면 제스처 영역이 없을 때와 배치가 같다 — $size', (
        tester,
      ) async {
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
        expect(
          _keypad(tester).bottom,
          moreOrLessEquals(size.height - 48 - 8, epsilon: 0.01),
        );
      });
    }

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
        moreOrLessEquals(24, epsilon: 0.01), // 32 − 화면 여백 8
      );
    });

    testWidgets('키보드가 떠도(padding 아래 0) 키보드와 무관한 인셋으로 판단해 여백을 넓히지 않는다', (
      tester,
    ) async {
      // 실측 24/32 폰에 키보드 100dp — padding.bottom은 0이 되고 viewPadding.bottom은 24로 남는다.
      const size = Size(411.43, 914.29);
      await _pumpScreen(
        tester,
        size: size,
        padding: const EdgeInsets.only(top: 24),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
        viewInsets: const EdgeInsets.only(bottom: 100),
        gesture: _gestureNav,
      );
      expect(tester.takeException(), isNull);
      // Scaffold가 키보드 높이만큼 본체를 줄이고, 아래 여백은 화면 여백 그대로다(32 − 24 = 8).
      expect(
        _keypad(tester).bottom,
        moreOrLessEquals(914.29 - 100 - 8, epsilon: 0.01),
      );
    });
  });

  group('맨 아래 행은 누르는 순간 입력된다', () {
    // 인셋 0 / 제스처 32(미실측 가정) — 예전 규칙(아래 여백 8dp 고정)이면 맨 아래 행 키캡의 아래 일부가
    // 제스처 영역에 들어가 손을 뗄 때 입력됐다. 실측 24/32는 본체 아래 끝이 영역 윗변과 맞닿는 경우다.
    const cases = <(String, Size, EdgeInsets, List<DisplayFeature>)>[
      ('위아래 배치, 인셋 0', Size(411.43, 914.29), EdgeInsets.only(top: 24), []),
      (
        '위아래 배치, 실측 24/32',
        Size(411.43, 914.29),
        EdgeInsets.only(top: 24, bottom: 24),
        [],
      ),
      ('좌우 분할, 인셋 0', Size(1280, 800), EdgeInsets.only(top: 24), []),
      (
        '테이블톱, 인셋 0',
        Size(841, 701),
        EdgeInsets.only(top: 28.19),
        [_horizontalHalfOpened],
      ),
    ];
    for (final (name, size, padding, features) in cases) {
      testWidgets(name, (tester) async {
        final container = await _pumpScreen(
          tester,
          size: size,
          padding: padding,
          gesture: _gestureNav,
          displayFeatures: features,
        );
        final lowest = _lowestKeycapBottom(tester);
        final row = _bottomRow(tester, lowest);
        expect(row, hasLength(greaterThanOrEqualTo(5)));
        var count = container.read(calcProvider).inputCount;
        var pressed = 0;
        for (final id in row) {
          final r = tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id)));
          // 좌우 뒤로가기 영역은 따로 보류된다(#50) — 그 밖의 가로 위치에서, 키캡 아래 끝 바로 위를 누른다.
          // 키캡 폭이 뒤로가기 영역(29.71dp)보다 넓어 모든 키에 그런 위치가 있다.
          final x = r.center.dx.clamp(
            _gestureNav.left + 1,
            size.width - _gestureNav.right - 1,
          );
          expect(x, inInclusiveRange(r.left, r.right), reason: '$id');
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
          pressed++;
        }
        expect(pressed, row.length);
      });
    }
  });
}
