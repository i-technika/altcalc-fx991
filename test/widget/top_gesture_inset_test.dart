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

/// 키패드 첫 행과 위 시스템 제스처 영역(알림창 끌어내리기) — #172.
///
/// 위 제스처 영역이 본체 윗변 아래로 들어오는 기기([CalcTheme.screenTopGestureDepth] > 0)에서, 키패드가 본체 윗변 가까이
/// 오는 배치(손 쪽 패널이 짧은 책 자세)는 키패드를 그 영역 아래에 둔다. 그래서 첫 행도 누르는 순간 입력된다(#50의 보류는
/// 제스처 영역에서 시작한 터치에만 걸린다). 다른 배치는 본체 위에 활성 LCD·위 띠가 있어 키패드가 영역에서 멀고, 영역이
/// 깊어도 배치가 바뀌지 않는다(본체 위 여백을 넓히지 않는다).
///
/// 값의 출처: "실측"은 [CalcTheme.screenTopGestureDepth] 문서의 에뮬레이터 실측이고, 분할 화면 창의 깊은 위 제스처 영역은
/// 그 실측(API 33 폰 48.8 / 61.0 — 차이 12.2)을 접힘선 창에 옮긴 가정이다(실기기 확인은 #177).

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

Rect _keycap(WidgetTester tester, CalcKeyId id) =>
    tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id)));

/// 세로 접힘선 (창 높이 전체, x = [x])
DisplayFeature _verticalFold(double x, double height) => DisplayFeature(
  bounds: Rect.fromLTWH(x, 0, 0, height),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

/// 손 쪽 패널이 짧은 책 자세 창 (#143 R1) — 640×360 창, 접힘선 x=320, 상태 표시줄 24
const _shortBookSize = Size(640, 360);
const _shortBookPadding = EdgeInsets.only(top: 24);

/// 좌우 뒤로가기 영역 (실측 29.71) + 위 영역 [top]
EdgeInsets _gestureWithTop(double top) =>
    EdgeInsets.fromLTRB(29.71, top, 29.71, 0);

void main() {
  group('위 제스처 영역 깊이 규칙 (screenTopGestureDepth)', () {
    test('실측한 기기 — 인셋과 같거나 화면 여백 안이면 0, 넘으면 그 초과분', () {
      // (인셋, 위 제스처 영역, 깊이) — CalcTheme.screenTopGestureDepth 문서의 실측값
      for (final (inset, gesture, depth) in const [
        (24.0, 24.0, 0.0), // API 36 Pixel Tablet
        (28.19, 28.19, 0.0), // API 36 Pixel Fold 내부
        (41.9, 54.1, 4.2), // API 36 Pixel Fold 커버(카메라 구멍)
        (48.76, 60.95, 4.19), // API 33 폰(edge-to-edge 아님)
        (47.0, 0.0, 0.0), // iOS — 제스처 영역을 전달하지 않는다
        (0.0, 0.0, 0.0),
        (0.0, 8.0, 0.0), // 화면 여백과 같으면 본체 윗변이 영역 아랫변
      ]) {
        expect(
          CalcTheme.screenTopGestureDepth(
            topInset: inset,
            topGestureInset: gesture,
          ),
          moreOrLessEquals(depth, epsilon: 0.001),
          reason: '인셋 $inset / 제스처 $gesture',
        );
      }
    });

    test('본체 윗변 + 깊이가 언제나 제스처 영역 아랫변 이상이고, 깊이는 음수가 아니다', () {
      for (final inset in [0.0, 8.0, 24.0, 48.0]) {
        for (final gesture in [0.0, 8.0, 24.0, 32.0, 40.0, 64.0]) {
          final depth = CalcTheme.screenTopGestureDepth(
            topInset: inset,
            topGestureInset: gesture,
          );
          expect(depth, greaterThanOrEqualTo(0));
          expect(
            inset + CalcTheme.screenPadding + depth,
            greaterThanOrEqualTo(gesture),
          );
        }
      }
    });
  });

  group('손 쪽 패널이 짧은 책 자세: 키패드가 위 제스처 영역 아래에서 시작한다', () {
    final fold = _verticalFold(320, _shortBookSize.height);

    testWidgets('위 제스처 영역이 인셋과 같으면(실측 API 36) 키패드가 본체 윗변부터다', (tester) async {
      await _pumpScreen(
        tester,
        size: _shortBookSize,
        padding: _shortBookPadding,
        gesture: _gestureWithTop(24),
        displayFeatures: [fold],
      );
      expect(tester.takeException(), isNull);
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
      // 키패드는 손 쪽 패널 높이 전체 — 화면 y = 인셋 + 화면 여백
      expect(_keypad(tester).top, moreOrLessEquals(24 + 8, epsilon: 0.01));
    });

    for (final topGesture in [36.2, 44.0, 56.0]) {
      testWidgets(
        '위 제스처 영역 $topGesture (인셋 24): 키패드 윗변 = 영역 아랫변, 첫 행은 누르는 순간 입력',
        (tester) async {
          final container = await _pumpScreen(
            tester,
            size: _shortBookSize,
            padding: _shortBookPadding,
            gesture: _gestureWithTop(topGesture),
            displayFeatures: [fold],
          );
          expect(tester.takeException(), isNull);
          expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
          final keypad = _keypad(tester);
          expect(keypad.top, moreOrLessEquals(topGesture, epsilon: 0.01));
          // 키패드는 여전히 본체 아래에 붙는다(아래 여백 8).
          expect(
            keypad.bottom,
            moreOrLessEquals(_shortBookSize.height - 8, epsilon: 0.01),
          );
          // 첫 행 키캡 위쪽 끝 바로 아래를 눌러도 보류 없이 누르는 순간 입력된다(진단 로그의 키 입력 단계로 본다 — SHIFT·ALPHA는
          // 계산기 입력 수를 늘리지 않는 모디파이어다).
          final printed = <String>[];
          LayoutLog.enable(sink: printed.add, frameTimings: false);
          addTearDown(LayoutLog.disable);
          for (final id in const [
            CalcKeyId.shift,
            CalcKeyId.alpha,
            CalcKeyId.menu,
          ]) {
            final r = _keycap(tester, id);
            expect(r.top, greaterThanOrEqualTo(topGesture), reason: '$id');
            printed.clear();
            final touch = await tester.startGesture(
              Offset(r.center.dx, r.top + 0.5),
            );
            await tester.pump();
            expect(printed, [
              startsWith('${LayoutLog.prefix} 키 입력(누를 때): ${id.name} '),
            ], reason: '$id');
            await touch.up();
            await tester.pump();
          }
          // 대조: 같은 화면에서 오른쪽 뒤로가기 영역에 든 ON 키 바깥쪽 끝은 보류된다 — 제스처 영역 판정이 살아 있다.
          // (취소로 끝내 설정 대화상자를 열지 않는다.)
          final on = _keycap(tester, settingsKey);
          expect(on.right, greaterThan(_shortBookSize.width - 29.71));
          printed.clear();
          final edge = await tester.startGesture(
            Offset(on.right - 1, on.center.dy),
          );
          await tester.pump();
          expect(printed, [
            startsWith(
              '${LayoutLog.prefix} 키 보류(제스처 영역): ${settingsKey.name} ',
            ),
          ]);
          await edge.cancel();
          await tester.pump();
          expect(container.read(calcProvider).inputCount, 0);
        },
      );
    }

    testWidgets('영역이 깊어진 만큼만 키패드가 낮아진다 (키 크기는 일반 하한 아래 그대로 쓸 수 있는 크기)', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        size: _shortBookSize,
        padding: _shortBookPadding,
        gesture: _gestureWithTop(24),
        displayFeatures: [fold],
      );
      final without = _keypad(tester);
      await _pumpScreen(
        tester,
        size: _shortBookSize,
        padding: _shortBookPadding,
        gesture: _gestureWithTop(44),
        displayFeatures: [fold],
      );
      final withGesture = _keypad(tester);
      // 44 − 24 − 화면 여백 8 = 12dp. 키패드는 높이에 묶여 있어 그만큼 낮아지고 본체 아래·손 쪽 패널 왼쪽에 그대로 붙는다.
      expect(
        without.height - withGesture.height,
        moreOrLessEquals(12, epsilon: 0.01),
      );
      expect(withGesture.bottom, moreOrLessEquals(without.bottom));
      expect(withGesture.left, moreOrLessEquals(without.left));
    });

    testWidgets('진단 로그: 배치 줄이 키패드 위치를 화면 좌표로 남긴다 (#172)', (tester) async {
      final printed = <String>[];
      LayoutLog.enable(sink: printed.add, frameTimings: false);
      addTearDown(LayoutLog.disable);
      await _pumpScreen(
        tester,
        size: _shortBookSize,
        padding: _shortBookPadding,
        gesture: _gestureWithTop(44),
        displayFeatures: [fold],
      );
      final keypad = _keypad(tester);
      String n2(double v) =>
          v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
      final lines = printed.where((l) => l.contains(' 배치: ')).toList();
      expect(lines, hasLength(1));
      expect(
        lines.single,
        contains(
          '키패드 ${n2(keypad.left)},${n2(keypad.top)}-'
          '${n2(keypad.right)},${n2(keypad.bottom)}, ',
        ),
      );
      expect(lines.single, contains('키패드 ${n2(keypad.left)},44-'));
    });
  });

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
        // 키패드 윗변은 본체 윗변에서 활성 LCD 최소 높이 + 간격 넘게 아래라, 위 제스처 영역에서 멀다.
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
        expect(_keypad(tester).top, greaterThan(topGesture + 80));
      });
    }
  });
}
