import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/layout_log.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

import '../support/screen_arrangement.dart';

/// 키패드 첫 행과 위 시스템 제스처 영역(알림창 끌어내리기) — #172.
///
/// 위 제스처 영역이 본체 윗변 아래로 들어오는 기기([CalcTheme.screenTopGestureDepth] > 0)에서, 키패드가 본체 윗변 가까이
/// 오는 배치(손 쪽 패널이 짧은 책 자세)는 키패드를 그 영역 아래에 둔다. 그래서 첫 행도 누르는 순간 입력된다(#50의 보류는
/// 제스처 영역에서 시작한 터치에만 걸린다). 다른 배치는 본체 위에 활성 LCD·위 띠가 있어 키패드가 영역에서 멀고, 영역이
/// 깊어도 배치가 바뀌지 않는다(본체 위 여백을 넓히지 않는다).
///
/// 값의 출처: "실측"은 [CalcTheme.screenTopGestureDepth] 문서의 에뮬레이터 실측이다. 접힘선 창의 깊은 위 제스처 영역(36.2·44·56
/// 등)은 실측이 없는 가정값이다 — 에뮬레이터에서 깊이가 0보다 큰 접힘선 창을 만들지 못했다(실기기 확인은 #177). 36.2는 실측한
/// 가장 깊은 깊이(4.2dp)를 이 창의 인셋에 옮긴 값이다.

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

/// 열 [x]에서 [from]부터 0.25dp씩 내려가며 눌러 [id] 키가 처음 반응하는 화면 y와 그 진단 로그 첫 줄(머리말 뺌)을 돌려준다.
/// 로그를 켜고 끈다. 반응한 누름은 바로 뗀다. [probeOnly]면 반응한 누름을 취소해 입력하지 않는다.
Future<({double y, String line})> _topmostHit(
  WidgetTester tester,
  CalcKeyId id,
  double x,
  double from, {
  bool probeOnly = false,
}) async {
  final printed = <String>[];
  LayoutLog.enable(sink: printed.add, frameTimings: false);
  try {
    for (var y = from; y < from + 40; y += 0.25) {
      printed.clear();
      final touch = await tester.startGesture(Offset(x, y));
      await tester.pump();
      final lines = [
        for (final l in printed)
          if (l.startsWith('${LayoutLog.prefix} 키 '))
            l.substring('${LayoutLog.prefix} 키 '.length),
      ];
      if (probeOnly) {
        await touch.cancel();
      } else {
        await touch.up();
      }
      await tester.pump();
      if (lines.isEmpty) continue;
      expect(lines.first, contains(': ${id.name} '), reason: 'y=$y');
      return (y: y, line: lines.first);
    }
    fail('$id: $from부터 40dp 안에서 눌리지 않았다');
  } finally {
    LayoutLog.disable();
  }
}

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
        (24.0, double.nan, 0.0), // 비유한 값은 0
        (double.nan, 40.0, 0.0),
        (0.0, double.infinity, 0.0),
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
          final printed = <String>[];
          LayoutLog.enable(sink: printed.add, frameTimings: false);
          addTearDown(LayoutLog.disable);
          // 대조: 같은 화면에서 오른쪽 뒤로가기 영역에 든 ON 키 바깥쪽 끝은 보류된다 — 제스처 영역 판정이 살아 있다.
          // (취소로 끝내 설정 대화상자를 열지 않는다.)
          final on = _keycap(tester, settingsKey);
          expect(on.right, greaterThan(_shortBookSize.width - 29.71));
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
          // 첫 행 키마다 가장 위의 터치 지점(각인 띠까지 넓힌 터치 영역의 윗변 — 키캡보다 위)을 눌러도 보류 없이 누르는 순간
          // 입력된다. 진단 로그의 키 입력 단계로 본다(SHIFT·ALPHA는 입력 수를 늘리지 않는 모디파이어다). ON은 설정을 여므로
          // 마지막에 누른다.
          for (final id in const [
            CalcKeyId.shift,
            CalcKeyId.alpha,
            CalcKeyId.cursorUp,
            CalcKeyId.menu,
            settingsKey,
          ]) {
            final r = _keycap(tester, id);
            final hit = await _topmostHit(tester, id, r.center.dx, keypad.top);
            expect(hit.y, greaterThanOrEqualTo(topGesture), reason: '$id');
            expect(
              hit.line,
              startsWith('입력(누를 때): ${id.name} '),
              reason: '$id',
            );
            if (id == CalcKeyId.shift) {
              // 각인 띠까지 넓힌 키는 키캡 위에서도 눌린다 — 키캡만 눌러서는 이 부분을 보지 못한다.
              expect(hit.y, lessThan(r.top), reason: '$id');
            }
          }
        },
      );
    }

    testWidgets('영역이 깊어진 만큼만 키패드가 낮아지고, 키는 쓸 수 있는 크기 이상 일반 하한 이하다', (
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
      final touch = KeypadMetrics.minKeyTouchHeightOf(
        withGesture.size,
        KeypadArrangement.standard,
      );
      expect(touch, greaterThanOrEqualTo(CalcTheme.keyTouchHeightUsableMin));
      expect(touch, lessThanOrEqualTo(CalcTheme.keyTouchHeightFloor));
      expect(find.byKey(WindowTooSmallNotice.noticeKey), findsNothing);
    });

    // 깊이만큼 비우면 키가 쓸 수 있는 크기(16dp)보다 작아지는 낮은 창 (#172 R1): 쓸 수 있는 크기를 지키는 만큼만 비운다 —
    // 안내 화면이 뜨는 창 높이가 깊이와 무관하다. 그 대신 첫 행 위쪽은 영역에 남아 손을 뗄 때 입력된다.
    for (final topGesture in [36.2, 56.0]) {
      testWidgets('위 제스처 영역 $topGesture: 쓸 수 있는 크기 경계가 깊이 0과 같다 (창 높이 쓸기)', (
        tester,
      ) async {
        bool usable() =>
            find.byKey(WindowTooSmallNotice.noticeKey).evaluate().isEmpty;
        var sawShortBook = false;
        for (var h = 220.0; h <= 270; h += 1) {
          final size = Size(640, h);
          final f = _verticalFold(320, h);
          await _pumpScreen(
            tester,
            size: size,
            padding: _shortBookPadding,
            gesture: _gestureWithTop(24),
            displayFeatures: [f],
          );
          final base = usable();
          // 안내 중에는 키패드가 숨어 찾을 수 없다.
          final baseKeypad = base ? _keypad(tester) : null;
          final baseDrawn = base ? drawnArrangementOf(tester) : null;
          await _pumpScreen(
            tester,
            size: size,
            padding: _shortBookPadding,
            gesture: _gestureWithTop(topGesture),
            displayFeatures: [f],
          );
          expect(usable(), base, reason: 'h=$h');
          if (!base) continue;
          expect(drawnArrangementOf(tester), baseDrawn, reason: 'h=$h');
          if (baseDrawn != DrawnArrangement.sideBySide) continue;
          sawShortBook = true;
          final keypad = _keypad(tester);
          // 키패드 윗변은 깊이 0일 때보다 위로 가지 않고, 영역 아랫변보다 아래로도 가지 않는다(필요한 만큼만 비운다).
          expect(
            keypad.top,
            greaterThanOrEqualTo(baseKeypad!.top - 0.01),
            reason: 'h=$h',
          );
          expect(
            keypad.top,
            lessThanOrEqualTo(topGesture + 0.01),
            reason: 'h=$h',
          );
          expect(
            KeypadMetrics.minKeyTouchHeightOf(
              keypad.size,
              KeypadArrangement.standard,
            ),
            greaterThanOrEqualTo(CalcTheme.keyTouchHeightUsableMin),
            reason: 'h=$h',
          );
        }
        expect(sawShortBook, isTrue);
      });
    }

    testWidgets('쓸 수 있는 크기를 지키려고 덜 비운 창은 첫 행 위쪽이 보류된다 (판정 대조)', (tester) async {
      // 640×236, 위 제스처 영역 56(깊이 24): 깊이만큼 비우면 키가 16dp 미만이라 덜 비운다.
      const size = Size(640, 236);
      await _pumpScreen(
        tester,
        size: size,
        padding: _shortBookPadding,
        gesture: _gestureWithTop(56),
        displayFeatures: [_verticalFold(320, 236)],
      );
      expect(find.byKey(WindowTooSmallNotice.noticeKey), findsNothing);
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
      final keypad = _keypad(tester);
      expect(keypad.top, lessThan(56));
      final hit = await _topmostHit(
        tester,
        CalcKeyId.menu,
        _keycap(tester, CalcKeyId.menu).center.dx,
        keypad.top,
        probeOnly: true,
      );
      expect(hit.y, lessThan(56));
      expect(hit.line, startsWith('보류(제스처 영역): menu '));
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
