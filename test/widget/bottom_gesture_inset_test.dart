import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/layout_log.dart';
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
/// 맨 아래 행도 누르는 순간 입력된다. 규칙 함수 자체는 `test/unit/calc_theme_test.dart`가 검사한다.
///
/// 값의 출처: "실측"은 [CalcTheme.screenBottomMargin] 문서의 에뮬레이터 실측이고, "인셋 0 / 제스처 32"는
/// 에뮬레이터로 만들 수 없어 실측하지 못한 가정이다(내비게이션 힌트를 숨긴 제스처 내비게이션 등, 실기기 확인은 #177).

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

/// 가로형 폴더블 내부(841×701)를 세로로 돌려(701×841) 반 접은 가로 접힘선 — 테이블톱 배치
const _horizontalHalfOpened = DisplayFeature(
  bounds: Rect.fromLTWH(0, 420.5, 701, 0),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureHalfOpened,
);

/// 제스처 내비게이션의 제스처 영역 (실측: 좌우 뒤로가기 29.71, 아래 32)
const _gestureNav = EdgeInsets.fromLTRB(29.71, 24, 29.71, 32);

void main() {
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
            '태블릿 가로 가로형 (인셋 0 / 제스처 32, 미실측 가정)',
            Size(1280, 800),
            EdgeInsets.only(top: 24),
            _gestureNav,
            [],
            DrawnArrangement.landscape,
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
            '가로 접힘선 테이블톱 701×841 (인셋 0 / 제스처 32, 미실측 가정)',
            Size(701, 841),
            EdgeInsets.only(top: 28.19),
            EdgeInsets.fromLTRB(29.71, 28.19, 29.71, 32),
            [_horizontalHalfOpened],
            DrawnArrangement.tabletop,
            841 - 0 - 32,
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

    // 3버튼(폰, 위아래 배치)·작업 표시줄(태블릿 가로, 가로형 #142): 제스처 영역이 시스템 바 안이라 배치가 바뀌지 않는다.
    for (final (size, arrangement) in const [
      (Size(411.43, 914.29), DrawnArrangement.stacked),
      (Size(1280, 800), DrawnArrangement.landscape),
    ]) {
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
        expect(drawnArrangementOf(tester), arrangement);
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

    testWidgets('키보드가 떠도(padding 아래 0) 실측 24/32 폰의 여백은 화면 여백 그대로다', (
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

    testWidgets('키보드가 제스처 영역보다 높으면 인셋 0 / 제스처 32 폰도 여백을 넓히지 않는다', (
      tester,
    ) async {
      // 키보드(100dp)가 본체 아래를 가려 키패드는 이미 제스처 영역(아래 32dp)보다 위에 있다.
      const size = Size(411.43, 914.29);
      await _pumpScreen(
        tester,
        size: size,
        padding: const EdgeInsets.only(top: 24),
        viewInsets: const EdgeInsets.only(bottom: 100),
        gesture: _gestureNav,
      );
      expect(tester.takeException(), isNull);
      expect(
        _keypad(tester).bottom,
        moreOrLessEquals(914.29 - 100 - 8, epsilon: 0.01),
      );
    });
  });

  group('맨 아래 행은 누르는 순간 입력된다', () {
    // 인셋 0 / 제스처 32(미실측 가정) — 예전 규칙(아래 여백 8dp 고정)이면 맨 아래 행 키캡의 아래 일부가
    // 제스처 영역에 들어가 손을 뗄 때 입력됐다. 실측 24/32는 본체 아래 끝이 영역 윗변과 맞닿는 경우다.
    const cases =
        <(String, Size, EdgeInsets, EdgeInsets, List<DisplayFeature>)>[
          (
            '위아래 배치, 인셋 0',
            Size(411.43, 914.29),
            EdgeInsets.only(top: 24),
            _gestureNav,
            [],
          ),
          (
            '위아래 배치, 실측 24/32',
            Size(411.43, 914.29),
            EdgeInsets.only(top: 24, bottom: 24),
            _gestureNav,
            [],
          ),
          (
            '위아래 배치, 실측 API 33 0/8',
            Size(411.43, 890.29),
            EdgeInsets.only(top: 48.76),
            EdgeInsets.fromLTRB(29.71, 60.95, 29.71, 8),
            [],
          ),
          (
            '가로형, 인셋 0',
            Size(1280, 800),
            EdgeInsets.only(top: 24),
            _gestureNav,
            [],
          ),
          (
            '세로 접힘선 좌우 배치, 인셋 0',
            Size(841, 701),
            EdgeInsets.only(top: 28.19),
            EdgeInsets.fromLTRB(29.71, 28.19, 29.71, 32),
            [_verticalFold],
          ),
          (
            '테이블톱, 인셋 0',
            Size(701, 841),
            EdgeInsets.only(top: 28.19),
            EdgeInsets.fromLTRB(29.71, 28.19, 29.71, 32),
            [_horizontalHalfOpened],
          ),
        ];
    for (final (name, size, padding, gesture, features) in cases) {
      testWidgets(name, (tester) async {
        final container = await _pumpScreen(
          tester,
          size: size,
          padding: padding,
          gesture: gesture,
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
            gesture.left + 1,
            size.width - gesture.right - 1,
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

  testWidgets(
    '진단 로그 (#118): 화면이 시스템 인셋·제스처 영역을 남기고, 가장자리 키의 보류·확정·취소와 안쪽 키의 즉시 입력을 남긴다',
    (tester) async {
      final printed = <String>[];
      LayoutLog.enable(sink: printed.add, frameTimings: false);
      addTearDown(LayoutLog.disable);
      // Pixel Tablet(API 36) 제스처 내비게이션 임시 작업 표시줄 실측값 — 가로형 배치
      const size = Size(1280, 800);
      const gesture = EdgeInsets.fromLTRB(30, 24, 30, 32);
      final container = await _pumpScreen(
        tester,
        size: size,
        padding: const EdgeInsets.only(top: 24, bottom: 32),
        gesture: gesture,
      );
      expect(printed.where((l) => l.contains(' 시스템 영역: ')), [
        startsWith(
          '${LayoutLog.prefix} 시스템 영역: 창 1280x800, 인셋 0/24/0/32, '
          '시스템 바 0/24/0/32, 제스처 영역 30/24/30/32 @',
        ),
      ]);

      // 오른쪽 끝 열의 AC (오른손잡이 가로형 숫자부의 바깥쪽 열)
      final ac = tester.getRect(
        find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.ac)),
      );
      expect(ac.right, greaterThan(size.width - gesture.right));
      expect(ac.center.dx, lessThan(size.width - gesture.right));
      List<String> keyLines() => [
        for (final l in printed)
          if (l.startsWith('${LayoutLog.prefix} 키 '))
            l.substring('${LayoutLog.prefix} 키 '.length).split(' @').first,
      ];
      String at(Offset p) => '(${p.dx.round()},${p.dy.round()})';

      // 좌표는 소수 첫째 자리까지 적힌다 — 정수 좌표만 눌러 비교한다
      final edge = Offset(
        (ac.right - 2).floorToDouble(),
        ac.center.dy.roundToDouble(),
      );
      final hold = await tester.startGesture(edge);
      await tester.pump();
      expect(container.read(calcProvider).inputCount, 0);
      await hold.up();
      await tester.pump();
      expect(container.read(calcProvider).inputCount, 1);

      final back = await tester.startGesture(edge);
      await back.cancel(); // 시스템 뒤로가기가 가로챈 경우
      await tester.pump();

      final swipe = await tester.startGesture(edge);
      final inward = Offset((ac.left - 20).roundToDouble(), edge.dy);
      await swipe.moveTo(inward);
      await swipe.up();
      await tester.pump();

      final middle = Offset(
        ac.center.dx.roundToDouble(),
        ac.center.dy.roundToDouble(),
      );
      await tester.tapAt(middle);
      await tester.pump();
      expect(container.read(calcProvider).inputCount, 2);
      expect(keyLines(), [
        '보류(제스처 영역): ac ${at(edge)}',
        '입력(뗄 때): ac ${at(edge)}',
        '보류(제스처 영역): ac ${at(edge)}',
        '취소(보류 버림): ac ${at(edge)}',
        '보류(제스처 영역): ac ${at(edge)}',
        '버림(벗어남): ac ${at(inward)}',
        '입력(누를 때): ac ${at(middle)}',
      ]);
    },
  );
}
