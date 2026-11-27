import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/handedness_dialog.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_launcher.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/cursor_pad_labels.dart';
import '../support/korean_locale.dart';
import '../support/screen_arrangement.dart';
import '../support/touch_metrics.dart';

/// 화면 배치(위아래·가로형·접힘선 기준)와 손잡이 설정 (#24, #25, #141, #142). 가로형 자체의 배치는
/// `landscape_layout_test`, 짧은 창은 `short_window_test`.

/// 폴더블 내부 화면의 세로 접힘선 (펼친 상태)
const _verticalFold = DisplayFeature(
  bounds: Rect.fromLTWH(640, 0, 0, 800),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));

/// 설정 키(ON, #190) — 누르면 설정 대화상자가 열린다
final _settings = find.byKey(CalcKeyButton.keycapKeyOf(settingsKey));

/// 설정 대화상자의 보이는 면 (대화상자 위젯 자체는 화면 전체를 덮는다)
final _dialogSurface = find
    .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
    .first;

Finder _option(Handedness h) => find.byKey(HandednessDialog.optionKeyOf(h));

/// [size] 창으로 [CalculatorScreen]을 띄운다. [handedness]를 주면 저장소에 그 값을 넣고 시작한다.
/// 저장소와 상태 컨테이너를 돌려준다. 같은 테스트에서 다시 부르면 창 크기만 바꿔 다시 그린다.
Future<(ProviderContainer, SharedPreferences)> _pump(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
  double textScale = 1.0,
  Handedness? handedness,
  List<DisplayFeature> displayFeatures = const [],
  ProviderContainer? container,
  bool highContrast = false,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  // 대화상자 경로(Navigator)는 화면 위쪽에서 빌드되어 View의 MediaQuery를 본다 — 실제 앱처럼 View에도
  // 접힘 정보를 넣어 `DisplayFeatureSubScreen`이 쓰게 한다.
  tester.view.displayFeatures = displayFeatures;
  addTearDown(tester.view.resetDisplayFeatures);
  SharedPreferences.setMockInitialValues({
    if (handedness != null)
      HandednessNotifier.storageKey: handedness.storageValue,
  });
  final prefs = await SharedPreferences.getInstance();
  if (container == null) {
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
            textScaler: TextScaler.linear(textScale),
            displayFeatures: displayFeatures,
            highContrast: highContrast,
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return (container, prefs);
}

void main() {
  _hingeLayoutTests();
  group('위아래 배치로 남는 창', () {
    for (final size in const [
      Size(800, 1280), // 태블릿 세로 (방향 고정이 무시된 경우)
      Size(678, 1024), // iPad Split View 절반
      Size(768, 768), // 정사각형 창
      Size(390, 844),
      // 짧은 창(키 28dp 미만)이지만 가로형의 키가 더 작아 위아래 배치로 남는다 (#38, #142)
      Size(320, 480),
    ]) {
      testWidgets('${size.width}×${size.height}: 왼손잡이 설정이어도 위아래 배치다', (
        tester,
      ) async {
        await _pump(tester, size: size, handedness: Handedness.left);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(_lcd).bottom,
          lessThanOrEqualTo(tester.getRect(_keypad).top),
        );
        expect(isStackedArrangement(tester), isTrue);
      });
    }

    testWidgets('접힘선이 창을 가로지르면 창 크기와 무관하게 접힘선 기준으로 나눈다 (#25)', (tester) async {
      await _pump(
        tester,
        size: const Size(1280, 800),
        displayFeatures: const [_verticalFold],
      );
      // 오른손잡이: 접힘선(x = 640) 왼쪽 LCD, 오른쪽 키패드
      expect(tester.getRect(_lcd).right, lessThanOrEqualTo(640));
      expect(tester.getRect(_keypad).left, greaterThanOrEqualTo(640));
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
    });
  });

  group('위아래 배치: LCD·키패드가 본체 폭 전체를 쓴다 (#141)', () {
    // (창, 인셋, LCD 높이) — 폭 상한(#92의 480dp)이 없어 태블릿 세로도 남는 높이 없이 LCD는 목표 비율, 키패드는 나머지
    // 전부다([CalcTheme] "화면 배치" 절). LCD는 본체 윗변부터다(#190 — 상단 띠가 없다).
    const windows = [
      // 12.9인치 iPad 세로: 본체 1008×1306 (1366 − 24 − 20 − 화면 여백 8×2)
      (Size(1024, 1366), EdgeInsets.only(top: 24, bottom: 20), 1306 * 0.28),
      // 10인치 Android 세로: 본체 784×1192 (1280 − 24 − 48 − 16)
      (Size(800, 1280), EdgeInsets.only(top: 24, bottom: 48), 1192 * 0.28),
      // 정사각형 창: 본체 752×752
      (Size(768, 768), EdgeInsets.zero, 752 * 0.28),
    ];

    for (final (size, padding, lcdHeight) in windows) {
      for (final handedness in Handedness.values) {
        testWidgets('${size.width}×${size.height}·${handedness.name}', (
          tester,
        ) async {
          await _pump(
            tester,
            size: size,
            padding: padding,
            handedness: handedness,
          );
          expect(tester.takeException(), isNull);
          final lcd = tester.getRect(_lcd);
          final keypad = tester.getRect(_keypad);
          final bodyTop = padding.top + CalcTheme.screenPadding;
          final left = padding.left + CalcTheme.screenPadding;
          final right = size.width - padding.right - CalcTheme.screenPadding;

          // LCD와 키패드가 본체 폭 전체다(손잡이와 무관).
          for (final r in [lcd, keypad]) {
            expect(r.left, moreOrLessEquals(left), reason: '$r');
            expect(r.right, moreOrLessEquals(right), reason: '$r');
          }
          expect(lcd.height, moreOrLessEquals(lcdHeight));
          expect(lcd.top, moreOrLessEquals(bodyTop));
          expect(
            keypad.top - lcd.bottom,
            moreOrLessEquals(CalcTheme.screenLcdKeypadGap),
          );
          expect(
            keypad.bottom,
            moreOrLessEquals(
              size.height - padding.bottom - CalcTheme.screenPadding,
            ),
          );
          expect(isStackedArrangement(tester), isTrue);
        });
      }
    }

    // 폰·폴더블 커버 화면·정사각형 창 — LCD는 본체 폭 그대로다.
    for (final size in const [
      Size(320, 568),
      Size(390, 844),
      Size(430, 932),
      Size(440, 956), // iPhone Pro Max
      Size(344, 882),
      // 정사각형 창 — 가로형보다 세로형의 키가 크다 (#142)
      Size(600, 600),
    ]) {
      testWidgets('${size.width}×${size.height}: LCD 폭 = 본체 폭', (tester) async {
        await _pump(tester, size: size);
        final lcd = tester.getRect(_lcd);
        final keypad = tester.getRect(_keypad);
        final bodyWidth = size.width - 2 * CalcTheme.screenPadding;
        expect(lcd.width, moreOrLessEquals(bodyWidth));
        expect(keypad.width, moreOrLessEquals(bodyWidth));
        expect(lcd.center.dx, moreOrLessEquals(size.width / 2));
      });
    }

    testWidgets('좌우 인셋이 비대칭이면 LCD·키패드가 창이 아니라 본체 폭 전체를 쓴다', (tester) async {
      // 오른쪽 내비게이션 바 48 → 본체 x 8 ~ 544 (폭 536). 가로 폰(844×390)처럼 가로로 넓은 창은 가로형이 되므로
      // (#142) 위아래 배치로 남는 정사각형 창을 쓴다.
      const size = Size(600, 600);
      const padding = EdgeInsets.only(right: 48);
      await _pump(tester, size: size, padding: padding);
      expect(tester.takeException(), isNull);
      expect(isStackedArrangement(tester), isTrue);
      for (final r in [tester.getRect(_lcd), tester.getRect(_keypad)]) {
        expect(r.left, moreOrLessEquals(8), reason: '$r');
        expect(r.right, moreOrLessEquals(600 - 48 - 8), reason: '$r');
      }
    });
  });

  group('테이블톱 배치: LCD 폭 상한 고정값 (#92)', () {
    // Galaxy Z Fold 내부 가로 반 접힘 841×673, 인셋 24/24: 본체 825 폭, 접힘선 336.5(본체 304.5).
    // 상한 전 LCD 825×296.5 → 480×274.3. 키패드는 넓은 배열로 아래 절반 폭을 다 쓰고(825dp, #80), LCD는 넓히지
    // 않는다(근거는 `CalcTheme.screenTabletopLcdMaxWidth` — #143까지). LCD 손 쪽 끝이 키패드 바깥 끝과 맞는다.
    for (final handedness in Handedness.values) {
      testWidgets('Fold 가로 반 접힘·${handedness.name}', (tester) async {
        await _pump(
          tester,
          size: const Size(841, 673),
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          handedness: handedness,
          displayFeatures: [
            _halfOpenedAt(const Rect.fromLTWH(0, 336.5, 841, 0)),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
        final lcd = tester.getRect(_lcd);
        final keypad = tester.getRect(_keypad);
        expect(keypad.width, moreOrLessEquals(825));
        expect(
          tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement,
          KeypadArrangement.wide,
        );
        expect(lcd.size.width, moreOrLessEquals(480));
        // LCD는 위 절반 높이 전체다(본체 윗변 32 ~ 접힘선 위 간격, #190).
        expect(lcd.top, moreOrLessEquals(24 + 8));
        expect(lcd.bottom, moreOrLessEquals(336.5 - 8));
        if (handedness.keypadOnRight) {
          expect(lcd.right, moreOrLessEquals(833));
          expect(lcd.right, moreOrLessEquals(keypad.right));
        } else {
          expect(lcd.left, moreOrLessEquals(8));
          expect(lcd.left, moreOrLessEquals(keypad.left));
        }
      });
    }
  });

  testWidgets(
    '12.9인치 iPad를 돌려도 LCD 줄 글자 크기는 크게 바뀌지 않는다 (#71 — #141 뒤로는 LCD 폭이 회전마다 바뀐다)',
    (tester) async {
      // #141 전에는 위아래·좌우 모두 LCD가 480dp라 크기가 같았다. 폭 상한을 푼 뒤로 세로는 1008×362, 가로는 가로형의
      // 활성 LCD 655×374.5(블록 폭의 실물 비율 높이, #142 R2)다. 줄 글자(세로 54.1·가로 54.7dp)는 회전해도 10% 안에서 움직인다.
      const padding = EdgeInsets.only(top: 24, bottom: 20);
      double lineFont() => DefaultTextStyle.of(
        tester.element(find.byKey(const ValueKey('lcd-input-text'))),
      ).style.fontSize!;
      final (container, _) = await _pump(
        tester,
        size: const Size(1024, 1366),
        padding: padding,
      );
      expect(isStackedArrangement(tester), isTrue);
      final portrait = lineFont();
      await _pump(
        tester,
        size: const Size(1366, 1024),
        padding: padding,
        container: container,
      );
      expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
      expect(lineFont(), moreOrLessEquals(portrait, epsilon: portrait * 0.1));
    },
  );

  group('키패드 폭 상한 없음 (#141)', () {
    for (final size in const [
      Size(800, 1280),
      Size(1366, 1024),
      Size(2000, 1400),
      // 폴더블 내부 화면(위아래 배치) — 예전에는 키패드 폭 약 674 → 480dp로 줄였다
      Size(690, 829),
    ]) {
      testWidgets(
        '${size.width}×${size.height}: 키패드는 받은 폭을 다 쓰고 세로로 길어지지 않는다',
        (tester) async {
          await _pump(tester, size: size);
          final keypad = tester.getRect(_keypad);
          final bodyWidth = size.width - 2 * CalcTheme.screenPadding;
          // 세로 창은 위아래 배치, 가로 창은 가로형(넓은 배열, #142) — 어느 쪽이든 본체 폭 전체다.
          final arrangement = tester
              .widget<CalcKeypad>(find.byType(CalcKeypad))
              .arrangement;
          expect(
            arrangement,
            size.height > size.width
                ? KeypadArrangement.standard
                : KeypadArrangement.wide,
          );
          expect(keypad.width, moreOrLessEquals(bodyWidth));
          expect(
            keypad.height,
            lessThanOrEqualTo(
              KeypadMetrics.fitSize(
                    Size(keypad.width, double.infinity),
                    arrangement,
                  ).height +
                  0.01,
            ),
          );
        },
      );
    }
  });

  group('넓은 키패드 배열의 테이블톱 (#80)', () {
    // Fold 가로 반 접힘 — 넓은 배열이 아래 절반 폭을 다 쓴다.
    const foldSize = Size(841, 673);
    const foldInset = EdgeInsets.only(top: 24, bottom: 24);
    final foldHalfOpened = _halfOpenedAt(const Rect.fromLTWH(0, 336.5, 841, 0));

    for (final (name, size, hingeY, keypadMoves) in [
      ('Fold 가로(넓은 배열이 폭을 다 씀)', foldSize, 336.5, false),
      ('세로로 긴 대화면 716×1200(실물 배열)', const Size(716, 1200), 600.0, true),
      // 블록 폭이 상한에 걸려 키패드(988.8dp)가 아래 절반(994dp)보다 5.2dp 좁다 — 손잡이로 5.2dp만 움직인다 (#80 R2)
      ('반 접힌 폭 1010(넓은 배열이 거의 다 씀)', const Size(1010, 700), 350.0, false),
      // 넓은 창: 넓은 배열 키패드 옆에 남는 폭이 커서(1200 → 195dp) 손잡이로 옮겨 간다
      ('반 접힌 폭 1200(넓은 배열 옆 자리)', const Size(1200, 800), 424.0, true),
    ]) {
      testWidgets('$name: 키패드가 옮겨 가지 않으면 대화상자에 그 안내를 보인다 (#80 R1)', (
        tester,
      ) async {
        await _pump(
          tester,
          size: size,
          padding: foldInset,
          displayFeatures: [
            _halfOpenedAt(Rect.fromLTWH(0, hingeY, size.width, 0)),
          ],
        );
        expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
        final before = tester.getRect(_keypad);
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        expect(
          find.byKey(HandednessDialog.noteKey),
          keypadMoves ? findsNothing : findsOneWidget,
        );
        // 안내대로인지: 손잡이를 바꿨을 때 키패드가 실제로 옮겨 가는지
        await tester.tap(_option(Handedness.left));
        await tester.pumpAndSettle();
        final after = tester.getRect(_keypad);
        // 옮겨 가지 않음 = 크기 그대로·가로 이동이 나란히 놓은 영역 사이 간격(16dp) 미만 (`_Body`의 판정과 같은 기준)
        final shift = (after.left - before.left).abs();
        expect(after.size, before.size);
        expect(
          shift < CalcTheme.screenPanelGap,
          !keypadMoves,
          reason: '$before → $after',
        );
      });
    }

    testWidgets('손잡이를 바꿔도 넓은 배열 키패드는 다시 빌드되지 않는다', (tester) async {
      final (container, _) = await _pump(
        tester,
        size: foldSize,
        padding: foldInset,
        displayFeatures: [foldHalfOpened],
      );
      expect(
        tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement,
        KeypadArrangement.wide,
      );
      final keypadWidget = tester.element(find.byType(CalcKeypad)).widget;
      container.read(handednessProvider.notifier).set(Handedness.left);
      await tester.pump();
      expect(container.read(handednessProvider), Handedness.left);
      expect(
        identical(tester.element(find.byType(CalcKeypad)).widget, keypadWidget),
        isTrue,
      );
    });

    testWidgets('반 접기 ↔ 펴기로 넓은 배열 ↔ 실물 배열이 바뀌어도 키 상태가 유지된다', (tester) async {
      final (container, _) = await _pump(
        tester,
        size: foldSize,
        padding: foldInset,
        displayFeatures: [foldHalfOpened],
      );
      KeypadArrangement arrangementNow() =>
          tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement;
      expect(arrangementNow(), KeypadArrangement.wide);
      Finder button(CalcKeyId id) => find.byWidgetPredicate(
        (w) => w is CalcKeyButton && w.keyDef.id == id,
      );
      final states = {
        for (final id in [CalcKeyId.shift, CalcKeyId.num7, CalcKeyId.equals])
          id: tester.state(button(id)),
      };
      // 7을 누른 채로 편다 → 위아래 배치(실물 배열). 키 element·State가 그대로라 누른 채인 키가 이어진다.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.num7))),
      );
      await tester.pump();
      await _pump(
        tester,
        size: foldSize,
        padding: foldInset,
        displayFeatures: [_foldAt(const Rect.fromLTWH(0, 336.5, 841, 0))],
        container: container,
      );
      expect(isStackedArrangement(tester), isTrue);
      expect(arrangementNow(), KeypadArrangement.standard);
      for (final e in states.entries) {
        expect(
          identical(tester.state(button(e.key)), e.value),
          isTrue,
          reason: e.key.name,
        );
      }
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(container.read(calcProvider).lastInput?.id, CalcKeyId.num7);
    });
  });

  group('손잡이 설정 UI', () {
    testWidgets(
      '설정 키(ON) → 왼손잡이: 숫자부와 활성 LCD가 왼쪽으로 옮겨지고 저장되며, 키 element는 그대로다 (#142)',
      (tester) async {
        final (container, prefs) = await _pump(
          tester,
          size: const Size(1280, 800),
        );
        Rect key(CalcKeyId id) =>
            tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id)));
        Finder button(CalcKeyId id) => find.byWidgetPredicate(
          (w) => w is CalcKeyButton && w.keyDef.id == id,
        );
        final num7State = tester.state(button(CalcKeyId.num7));
        final lcdElement = tester.element(_lcd);
        expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
        expect(key(CalcKeyId.num7).left, greaterThan(key(CalcKeyId.sin).right));
        final keypadBefore = tester.getRect(_keypad);

        await tester.tap(_settings);
        await tester.pumpAndSettle();
        expect(find.byType(HandednessDialog), findsOneWidget);
        // 테스트 기본 로캘(en_US) 문구
        expect(find.text('Keypad position'), findsOneWidget);
        expect(find.text('Right-handed'), findsOneWidget);
        expect(find.text('Left-handed'), findsOneWidget);

        // 고르면 바로 저장되고 뒤의 키패드가 옮겨진다. 대화상자는 열린 채로 남는다.
        await tester.tap(_option(Handedness.left));
        await tester.pumpAndSettle();
        expect(find.byType(HandednessDialog), findsOneWidget);
        expect(container.read(handednessProvider), Handedness.left);
        expect(prefs.getString(HandednessNotifier.storageKey), 'left');
        expect(key(CalcKeyId.num7).right, lessThan(key(CalcKeyId.sin).left));
        expect(tester.getRect(_lcd).left, moreOrLessEquals(keypadBefore.left));
        // 키패드 자리·크기는 그대로이고 블록 순서만 바뀐다 — 키 State가 유지된다.
        expect(tester.getRect(_keypad), keypadBefore);
        expect(
          identical(tester.state(button(CalcKeyId.num7)), num7State),
          isTrue,
        );
        expect(identical(tester.element(_lcd), lcdElement), isTrue);

        // 닫기 버튼으로 닫는다.
        await tester.tap(find.byKey(HandednessDialog.closeKey));
        await tester.pumpAndSettle();
        expect(find.byType(HandednessDialog), findsNothing);
        expect(container.read(handednessProvider), Handedness.left);
      },
    );

    testWidgets('현재 선택을 다시 고르면 아무것도 바뀌지 않는다', (tester) async {
      final (container, prefs) = await _pump(
        tester,
        size: const Size(1280, 800),
        handedness: Handedness.left,
      );
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      await tester.tap(_option(Handedness.left));
      await tester.pumpAndSettle();
      expect(find.byType(HandednessDialog), findsOneWidget);
      expect(container.read(handednessProvider), Handedness.left);
      expect(prefs.getString(HandednessNotifier.storageKey), 'left');
    });

    testWidgets('키보드: 화살표로 선택을 옮겨도 대화상자는 닫히지 않고, Esc로 닫는다', (tester) async {
      final (container, _) = await _pump(tester, size: const Size(1280, 800));
      await tester.tap(_settings);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.byType(HandednessDialog), findsOneWidget);
      expect(container.read(handednessProvider), Handedness.left);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.byType(HandednessDialog), findsOneWidget);
      expect(container.read(handednessProvider), Handedness.right);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(HandednessDialog), findsNothing);
    });

    testWidgets('바깥을 누르면 닫힌다', (tester) async {
      await _pump(tester, size: const Size(1280, 800));
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(HandednessDialog), findsNothing);
    });

    testWidgets('스크린리더: 설정 키 이름은 "Settings" 버튼이고, 선택지는 단일 선택 그룹과 선택 상태로 알려진다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        size: const Size(1280, 800),
        handedness: Handedness.left,
      );
      expect(
        tester.getSemantics(_settings),
        isSemantics(label: 'Settings', isButton: true, hasTapAction: true),
      );
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_option(Handedness.left)),
        isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true),
      );
      expect(
        tester.getSemantics(_option(Handedness.right)),
        isSemantics(isChecked: false, isInMutuallyExclusiveGroup: true),
      );
      handle.dispose();
    });

    testWidgets(
      '열린 채 창이 아주 낮아지면 닫기 버튼은 고정되고 제목·선택지가 함께 스크롤되며, 화살표로 옮긴 선택지는 화면 안으로 스크롤된다',
      (tester) async {
        const small = Size(700, 300);
        final (container, _) = await _pump(
          tester,
          size: const Size(1280, 800),
          textScale: 2.0,
        );
        await tester.tap(_settings);
        await tester.pumpAndSettle();

        // 멀티 윈도 등으로 창이 줄어든다 (대화상자는 열린 채)
        await _pump(tester, size: small, textScale: 2.0, container: container);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final window = Offset.zero & small;
        expect(
          window.contains(tester.getCenter(find.text('Keypad position'))),
          isTrue,
        );
        expect(
          find.byKey(HandednessDialog.closeKey).hitTestable(),
          findsOneWidget,
        );

        final scrollable = find
            .descendant(
              of: find.byType(HandednessDialog),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          greaterThan(0),
        );

        // 키보드: 첫 선택지로 포커스 → 아래 화살표 → 옮겨 간 선택지가 보이는 영역 안에 있다.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(container.read(handednessProvider), Handedness.left);
        final viewport = tester.getRect(scrollable).inflate(0.5);
        final option = tester.getRect(
          find.byKey(HandednessDialog.optionKeyOf(Handedness.left)),
        );
        expect(
          viewport.contains(option.topLeft) &&
              viewport.contains(option.bottomRight),
          isTrue,
          reason: 'viewport $viewport, option $option',
        );
      },
    );

    testWidgets('작은 대화면(960×600)·글자 배율 2.0에서도 대화상자가 넘치지 않고 선택된다', (
      tester,
    ) async {
      final (container, _) = await _pump(
        tester,
        size: const Size(960, 600),
        padding: const EdgeInsets.only(top: 24, bottom: 48),
        textScale: 2.0,
      );
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(_option(Handedness.left));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(container.read(handednessProvider), Handedness.left);
      // 닫기 버튼도 화면 안에 있어 누를 수 있다.
      expect(
        find.byKey(HandednessDialog.closeKey).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('한국어 기기에서는 설정 문구가 한국어다', (tester) async {
      useKoreanLocale(tester);
      final handle = tester.ensureSemantics();
      await _pump(tester, size: const Size(1280, 800));
      expect(tester.getSemantics(_settings), isSemantics(label: '설정'));
      handle.dispose();
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      expect(find.text('키패드 위치'), findsOneWidget);
      expect(find.text('오른손잡이'), findsOneWidget);
      expect(find.text('왼손잡이'), findsOneWidget);
      expect(find.text('닫기'), findsOneWidget);
    });
  });

  testWidgets('창 크기가 바뀌어 배치가 달라져도 계산기 상태는 유지된다', (tester) async {
    final (container, _) = await _pump(tester, size: const Size(1280, 800));
    await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.shift)));
    await tester.pump();
    expect(container.read(calcProvider).modifier, KeyModifier.shift);

    final keypadElement = tester.element(find.byType(CalcKeypad));
    final lcdElement = tester.element(_lcd);

    // 세로로 회전 (방향 고정이 무시된 경우) → 위아래 배치
    await _pump(tester, size: const Size(800, 1280), container: container);
    expect(isStackedArrangement(tester), isTrue);
    expect(
      tester.getRect(_lcd).bottom,
      lessThanOrEqualTo(tester.getRect(_keypad).top),
    );
    expect(container.read(calcProvider).modifier, KeyModifier.shift);
    // 두 배치가 같은 위젯 트리라 LCD·키패드 element가 그대로 유지된다
    // (키 눌림 상태·스크린리더 포커스가 회전으로 사라지지 않는다).
    expect(
      identical(tester.element(find.byType(CalcKeypad)), keypadElement),
      isTrue,
    );
    expect(identical(tester.element(_lcd), lcdElement), isTrue);

    // 다시 가로로 (가로형, #142)
    await _pump(tester, size: const Size(1280, 800), container: container);
    expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
    expect(identical(tester.element(_lcd), lcdElement), isTrue);
    expect(
      identical(tester.element(find.byType(CalcKeypad)), keypadElement),
      isTrue,
    );
    await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.sin)));
    await tester.pump();
    expect(container.read(calcProvider).modifier, KeyModifier.none);
    expect(container.read(calcProvider).lastInput?.layer, KeyLayer.shift);
  });
}

/// 폴더블 화면: 창 크기, 시스템 인셋, 접힘 정보 (화면 좌표)
typedef _Foldable = (String, Size, EdgeInsets, DisplayFeature);

/// View(대화상자 경로가 보는 화면)에도 [padding] 인셋을 넣는다. [_pump]는 화면 MediaQuery에만 인셋을 넣으므로,
/// 대화상자 위치가 Navigator의 인셋으로 절반 폭을 재는 테스트는 이것을 함께 부른다.
void _setViewPadding(WidgetTester tester, EdgeInsets padding) {
  final ratio = tester.view.devicePixelRatio;
  tester.view.padding = FakeViewPadding(
    left: padding.left * ratio,
    top: padding.top * ratio,
    right: padding.right * ratio,
    bottom: padding.bottom * ratio,
  );
  addTearDown(tester.view.resetPadding);
}

DisplayFeature _foldAt(
  Rect bounds, {
  DisplayFeatureType? type,
  DisplayFeatureState state = DisplayFeatureState.postureFlat,
}) => DisplayFeature(
  bounds: bounds,
  type: type ?? DisplayFeatureType.fold,
  state: state,
);

/// 반 접은 상태의 접힘선
DisplayFeature _halfOpenedAt(Rect bounds) =>
    _foldAt(bounds, state: DisplayFeatureState.postureHalfOpened);

/// 키패드의 모든 키(커서 패드 제외)가 터치 하한 이상이고, 커서 패드 방향 키도 하한을 지키는지 확인한다.
/// 커서 패드는 세로 폰 화면 테스트와 같은 규칙이다: 터치 영역(셀까지 넓힌 것, #64) 내접원이 ◀·▶는 하한 이상,
/// 실물처럼 좁은 ▲·▼는 하한의 95% 이상(#65).
void _expectTouchTargets(
  WidgetTester tester, {
  double floor = CalcTheme.keyTouchHeightFloor,
}) {
  var lowest = double.infinity;
  for (final b in tester.widgetList<CalcKeyButton>(
    find.byType(CalcKeyButton),
  )) {
    if (b.keyDef.category == KeyCategory.cursor) continue;
    final cell = tester.getSize(find.byWidget(b));
    final touch = b.extendHitAreaToLegend
        ? cell.height
        : cell.height * (1 - CalcTheme.keyLegendHeightRatio);
    if (touch < lowest) lowest = touch;
    expect(touch, greaterThanOrEqualTo(floor), reason: b.keyDef.id.name);
  }
  // 배치 판정에 쓰는 계산값이 실제로 그린 키의 최소 터치 높이와 같다 (그린 구역 배열 기준, #80).
  expect(
    KeypadMetrics.minKeyTouchHeightOf(
      tester.getSize(_keypad),
      tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement,
    ),
    moreOrLessEquals(lowest, epsilon: 0.01),
  );
  final padRect = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
  final cell = tester.getRect(find.byType(CursorPad));
  final pad = CursorPadGeometry(padRect.size);
  final bounds = cell.shift(-padRect.topLeft); // 패드 로컬 좌표의 셀
  for (final sector in CursorPadSector.values) {
    final vertical =
        sector == CursorPadSector.up || sector == CursorPadSector.down;
    expect(
      hitInscribedDiameter(pad, sector, bounds),
      greaterThanOrEqualTo(floor * (vertical ? 0.95 : 1.0)),
      reason: sector.name,
    );
  }
  // 방향 라벨은 허브에 덮이지 않고 줄지 않는다(넓은 배열·분할 배치 포함, #65).
  expectCursorPadLabelsClearOfHub(tester);
}

/// [rect]가 접힘선 [hinge]와 그 양쪽 간격([CalcTheme.screenHingeMargin]) 띠에 걸치지 않는지 (화면 좌표)
bool _clearOfHinge(Rect rect, Rect hinge, {required bool vertical}) {
  const m = CalcTheme.screenHingeMargin;
  const eps = 0.01;
  return vertical
      ? rect.right <= hinge.left - m + eps || rect.left >= hinge.right + m - eps
      : rect.bottom <= hinge.top - m + eps ||
            rect.top >= hinge.bottom + m - eps;
}

/// 폴더블 내부 화면의 접힘선 기준 배치 (#25)
void _hingeLayoutTests() {
  group('접힘선 기준 좌우 배치 (세로 접힘선, 책 자세)', () {
    final devices = <_Foldable>[
      // Galaxy Z Fold 내부 화면 (세로가 기본 방향)
      (
        'Fold 내부',
        const Size(673, 841),
        const EdgeInsets.only(top: 32, bottom: 24),
        _foldAt(const Rect.fromLTWH(336.5, 0, 0, 841)),
      ),
      // Pixel Fold 내부 화면 (가로가 기본 방향)
      (
        'Pixel Fold 내부',
        const Size(841, 701),
        const EdgeInsets.only(top: 24, bottom: 24),
        _foldAt(const Rect.fromLTWH(420.5, 0, 0, 701)),
      ),
      // 정사각형에 가까운 내부 화면 + 가로 화면 왼쪽 카메라 인셋
      (
        '정사각형 내부·왼쪽 인셋',
        const Size(778, 749),
        const EdgeInsets.only(left: 32, top: 24, bottom: 24),
        _foldAt(const Rect.fromLTWH(389, 0, 0, 749)),
      ),
      // 폭이 있는 물리 힌지 (두 화면 기기)
      (
        '물리 힌지',
        const Size(1114, 720),
        const EdgeInsets.only(top: 24, bottom: 24),
        _foldAt(
          const Rect.fromLTWH(540, 0, 34, 720),
          type: DisplayFeatureType.hinge,
        ),
      ),
    ];

    for (final (name, size, padding, fold) in devices) {
      for (final handedness in Handedness.values) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '$name ${size.width}×${size.height}·${handedness.name}·배율 $scale',
            (tester) async {
              await _pump(
                tester,
                size: size,
                padding: padding,
                textScale: scale,
                handedness: handedness,
                displayFeatures: [fold],
              );
              expect(tester.takeException(), isNull);
              expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));

              final hinge = fold.bounds;
              final lcd = tester.getRect(_lcd);
              final keypad = tester.getRect(_keypad);
              final settings = tester.getRect(_settings);

              // 어느 것도 접힘선(과 양쪽 간격)에 걸치지 않는다.
              for (final r in [lcd, keypad]) {
                expect(
                  _clearOfHinge(r, hinge, vertical: true),
                  isTrue,
                  reason: '$r',
                );
              }
              // 키패드(와 그 안의 설정 키)는 주로 쓰는 손 쪽 절반의 바깥 가장자리, LCD는 반대쪽 절반
              final right =
                  size.width - padding.right - CalcTheme.screenPadding;
              final left = padding.left + CalcTheme.screenPadding;
              if (handedness.keypadOnRight) {
                expect(keypad.left, greaterThanOrEqualTo(hinge.right));
                expect(keypad.right, moreOrLessEquals(right));
                expect(lcd.right, lessThanOrEqualTo(hinge.left));
                expect(lcd.left, greaterThanOrEqualTo(left - 0.01));
                expect(settings.left, greaterThanOrEqualTo(hinge.right));
              } else {
                expect(keypad.right, lessThanOrEqualTo(hinge.left));
                expect(keypad.left, moreOrLessEquals(left));
                expect(lcd.left, greaterThanOrEqualTo(hinge.right));
                expect(lcd.right, lessThanOrEqualTo(right + 0.01));
                expect(settings.right, lessThanOrEqualTo(hinge.left));
              }
              // LCD는 접힘선 쪽에 붙고(간격만 남긴다), 폭은 절반 패널 폭과 키패드 폭 × 상한 비율 중 작은 쪽 (#71)
              expect(
                handedness.keypadOnRight
                    ? hinge.left - lcd.right
                    : lcd.left - hinge.right,
                moreOrLessEquals(CalcTheme.screenHingeMargin),
              );
              final panel = handedness.keypadOnRight
                  ? hinge.left - CalcTheme.screenHingeMargin - left
                  : right - hinge.right - CalcTheme.screenHingeMargin;
              expect(
                lcd.width,
                moreOrLessEquals(
                  math.min(
                    panel,
                    keypad.width * CalcTheme.screenLcdMaxWidthRatio,
                  ),
                ),
              );
              // LCD는 본체 윗변부터(#190) 키패드 윗변 아래 폭 기준 최대 높이까지다. 설정 키는 키패드 안에서 눌린다.
              expect(
                lcd.top,
                moreOrLessEquals(padding.top + CalcTheme.screenPadding),
              );
              expect(
                lcd.bottom,
                moreOrLessEquals(
                  keypad.top +
                      math.min(
                        math.max(
                          lcd.width / CalcTheme.screenLcdMinAspectRatio,
                          CalcTheme.screenLcdMinHeight,
                        ),
                        keypad.height,
                      ),
                ),
              );
              expect(
                keypad.inflate(0.01).contains(settings.topLeft) &&
                    keypad.inflate(0.01).contains(settings.bottomRight),
                isTrue,
              );
              expect(_settings.hitTestable(), findsOneWidget);
              // 키패드는 손 쪽 절반 폭을 다 쓰고(#141 — 폭 상한 없음) 아래 인셋 위 화면 여백까지 내려온다.
              expect(
                keypad.width,
                moreOrLessEquals(
                  handedness.keypadOnRight
                      ? right - hinge.right - CalcTheme.screenHingeMargin
                      : hinge.left - CalcTheme.screenHingeMargin - left,
                ),
              );
              expect(
                keypad.bottom,
                moreOrLessEquals(
                  size.height - padding.bottom - CalcTheme.screenPadding,
                ),
              );
              // 절반 폭 키패드도 터치 하한을 지킨다 (글자 배율과 무관한 치수라 배율 1.0에서만 본다).
              if (scale == 1.0) _expectTouchTargets(tester);
            },
          );
        }
      }
    }

    testWidgets('키는 접힘선 기준 배치에서도 눌린다 (시스템 제스처 영역 계약 유지)', (tester) async {
      final (container, _) = await _pump(
        tester,
        size: const Size(673, 841),
        displayFeatures: [_foldAt(const Rect.fromLTWH(336.5, 0, 0, 841))],
      );
      await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.sin)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(container.read(calcProvider).lastInput?.id, CalcKeyId.sin);
    });
  });

  group('접힘선 기준 위아래 배치 (가로 접힘선, 테이블톱 자세)', () {
    final devices = <_Foldable>[
      // Galaxy Z Fold 내부 화면을 가로로 돌려 반 접음
      (
        'Fold 내부 가로·반 접힘',
        const Size(841, 673),
        const EdgeInsets.only(top: 24, bottom: 24),
        _halfOpenedAt(const Rect.fromLTWH(0, 336.5, 841, 0)),
      ),
      // Pixel Fold 내부 화면을 세로로 돌려 반 접음
      (
        'Pixel Fold 내부 세로·반 접힘',
        const Size(701, 841),
        const EdgeInsets.only(top: 32, bottom: 24),
        _halfOpenedAt(const Rect.fromLTWH(0, 420.5, 701, 0)),
      ),
      // Galaxy Z Flip 내부 화면을 반 접음 (Flex 모드)
      (
        'Flip 내부·반 접힘',
        const Size(411, 1006),
        const EdgeInsets.only(top: 32, bottom: 24),
        _halfOpenedAt(const Rect.fromLTWH(0, 503, 411, 0)),
      ),
    ];

    for (final (name, size, padding, fold) in devices) {
      for (final handedness in Handedness.values) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '$name ${size.width}×${size.height}·${handedness.name}·배율 $scale',
            (tester) async {
              await _pump(
                tester,
                size: size,
                padding: padding,
                textScale: scale,
                handedness: handedness,
                displayFeatures: [fold],
              );
              expect(tester.takeException(), isNull);
              expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));

              final hinge = fold.bounds;
              final lcd = tester.getRect(_lcd);
              final keypad = tester.getRect(_keypad);
              final settings = tester.getRect(_settings);

              for (final r in [lcd, keypad]) {
                expect(
                  _clearOfHinge(r, hinge, vertical: false),
                  isTrue,
                  reason: '$r',
                );
              }
              // LCD는 위 절반 높이 전체(본체 윗변 ~ 접힘선 쪽, #190), 키패드는 아래 절반
              expect(
                lcd.bottom,
                moreOrLessEquals(hinge.top - CalcTheme.screenHingeMargin),
              );
              expect(
                lcd.top,
                moreOrLessEquals(padding.top + CalcTheme.screenPadding),
              );
              expect(keypad.top, greaterThanOrEqualTo(hinge.bottom));
              // 키패드는 주로 쓰는 손 쪽 가장자리
              final right =
                  size.width - padding.right - CalcTheme.screenPadding;
              final left = padding.left + CalcTheme.screenPadding;
              // LCD 폭은 위 절반 폭과 LCD 최대 폭 중 작은 쪽이고, 키패드와 같은 쪽 가장자리에 붙는다 (#92).
              expect(
                lcd.width,
                moreOrLessEquals(
                  math.min(right - left, CalcTheme.screenTabletopLcdMaxWidth),
                ),
              );
              if (handedness.keypadOnRight) {
                expect(keypad.right, moreOrLessEquals(right));
                expect(lcd.right, moreOrLessEquals(right));
              } else {
                expect(keypad.left, moreOrLessEquals(left));
                expect(lcd.left, moreOrLessEquals(left));
              }
              // 설정 키(ON)는 아래 절반 키패드 안에서 눌린다 (#190).
              expect(
                keypad.inflate(0.01).contains(settings.topLeft) &&
                    keypad.inflate(0.01).contains(settings.bottomRight),
                isTrue,
              );
              expect(_settings.hitTestable(), findsOneWidget);
              // 전체 화면 기기의 반 접은 테이블톱은 넓은 키패드 배열(#80)로 일반 하한도 지킨다
              // (배치 판정은 완화된 하한 — #25 R2, #80 R1).
              if (scale == 1.0) {
                _expectTouchTargets(
                  tester,
                  floor: CalcTheme.keyTouchHeightFloor,
                );
              }
              // 키패드는 아래 절반 폭을 다 쓰고(#141) 아래 인셋 위 화면 여백까지 내려온다.
              expect(keypad.width, moreOrLessEquals(right - left));
              expect(
                keypad.bottom,
                moreOrLessEquals(
                  size.height - padding.bottom - CalcTheme.screenPadding,
                ),
              );
            },
          );
        }
      }
    }
  });

  testWidgets('내부 화면을 돌려 접힘선 방향이 바뀌어도 상태와 LCD·키패드 element가 유지된다', (
    tester,
  ) async {
    final (container, _) = await _pump(
      tester,
      size: const Size(673, 841),
      displayFeatures: [_foldAt(const Rect.fromLTWH(336.5, 0, 0, 841))],
    );
    await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.shift)));
    await tester.pump();
    final keypadElement = tester.element(find.byType(CalcKeypad));
    final lcdElement = tester.element(_lcd);

    // 가로로 돌려 반 접음 → 가로 접힘선 (테이블톱)
    await _pump(
      tester,
      size: const Size(841, 673),
      displayFeatures: [_halfOpenedAt(const Rect.fromLTWH(0, 336.5, 841, 0))],
      container: container,
    );
    expect(
      tester.getRect(_lcd).bottom,
      lessThanOrEqualTo(tester.getRect(_keypad).top),
    );
    expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
    expect(container.read(calcProvider).modifier, KeyModifier.shift);
    expect(
      identical(tester.element(find.byType(CalcKeypad)), keypadElement),
      isTrue,
    );
    expect(identical(tester.element(_lcd), lcdElement), isTrue);

    // 접음 → 커버 화면 (접힘 정보 없음) → 위아래 배치
    await _pump(tester, size: const Size(344, 882), container: container);
    expect(isStackedArrangement(tester), isTrue);
    expect(container.read(calcProvider).modifier, KeyModifier.shift);
    expect(
      identical(tester.element(find.byType(CalcKeypad)), keypadElement),
      isTrue,
    );
  });

  group('펼친 가로 접힘선은 나누지 않는다 (#25 R1)', () {
    for (final (name, size, fold) in [
      (
        'Fold 내부 가로',
        const Size(841, 673),
        const Rect.fromLTWH(0, 336.5, 841, 0),
      ),
      (
        'Pixel Fold 내부 세로',
        const Size(701, 841),
        const Rect.fromLTWH(0, 420.5, 701, 0),
      ),
      ('Flip 내부', const Size(411, 1006), const Rect.fromLTWH(0, 503, 411, 0)),
    ]) {
      testWidgets('$name ${size.width}×${size.height}: 위아래 배치, 키는 터치 하한 이상', (
        tester,
      ) async {
        await _pump(
          tester,
          size: size,
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          displayFeatures: [_foldAt(fold)],
        );
        expect(tester.takeException(), isNull);
        expect(isStackedArrangement(tester), isTrue);
        expect(
          tester.getRect(_lcd).bottom,
          lessThanOrEqualTo(tester.getRect(_keypad).top),
        );
        _expectTouchTargets(tester);
      });
    }

    testWidgets('본체에서 키가 터치 하한보다 낮아지는 비대칭 접힘선은 위아래 배치로 둔다 (#25 R2)', (
      tester,
    ) async {
      // 세로: 접힘선 오른쪽 281dp(창 좌표로는 사전 판정 통과) + 오른쪽 인셋 48 → 키패드 쪽이 217dp
      await _pump(
        tester,
        size: const Size(841, 701),
        padding: const EdgeInsets.only(top: 24, right: 48, bottom: 24),
        displayFeatures: [_foldAt(const Rect.fromLTWH(560, 0, 0, 701))],
      );
      expect(tester.takeException(), isNull);
      expect(isStackedArrangement(tester), isTrue);
      _expectTouchTargets(tester);

      // 가로 반 접힘: 아래쪽 352dp(창 좌표로는 사전 판정 통과) + 아래 인셋 260 → 접힘선 간격·화면 여백까지 빼면 키패드
      // 자리 높이 76dp. 넓은 배열(#80)로도 키가 테이블톱 하한보다 낮다(약 12.9dp). (#141 전에는 아래 인셋 200에
      // 광고 슬롯까지 빼 74dp였다 — 광고 슬롯이 빠져 인셋을 키웠다.)
      await _pump(
        tester,
        size: const Size(841, 673),
        padding: const EdgeInsets.only(top: 24, bottom: 260),
        displayFeatures: [_halfOpenedAt(const Rect.fromLTWH(0, 321, 841, 0))],
      );
      expect(tester.takeException(), isNull);
      // 테이블톱이 아니다 (위아래 배치보다 가로형의 키가 커 짧은 창 규칙으로 가로형 — #38 R1, #142)
      expect(
        drawnArrangementOf(tester),
        isNot(anyOf(DrawnArrangement.tabletop, DrawnArrangement.unknown)),
      );
    });

    testWidgets(
      '아래쪽 281dp·아래 인셋 48의 비대칭 가로 반 접힘은 넓은 키패드 배열로 테이블톱을 유지한다 (#80)',
      (tester) async {
        // 키패드 자리 825×155 — 실물 배열은 약 13dp라 #80 전에는 위아래 배치였다. 넓은 배열은 약 26dp.
        await _pump(
          tester,
          size: const Size(841, 673),
          padding: const EdgeInsets.only(top: 24, bottom: 48),
          displayFeatures: [_halfOpenedAt(const Rect.fromLTWH(0, 392, 841, 0))],
        );
        expect(tester.takeException(), isNull);
        expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
        expect(
          tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement,
          KeypadArrangement.wide,
        );
        expect(tester.getRect(_keypad).top, greaterThanOrEqualTo(392));
        _expectTouchTargets(
          tester,
          floor: CalcTheme.tabletopKeyTouchHeightFloor,
        );
      },
    );

    testWidgets('반 접은 Fold에 앱을 나란히 띄운 분할 창은 일반 하한 미만이어도 테이블톱을 유지한다 (#80 R1)', (
      tester,
    ) async {
      // 창 420×673(접힘선 y=336.5): 넓은 배열도 약 23dp로 일반 하한(28dp) 미만이고 위아래 배치(약 32.7dp)가 더 크지만,
      // 세워 둔 접힘선을 넘지 않도록 완화된 하한으로 테이블톱을 쓴다(#25·#80 R1 사용자 결정).
      await _pump(
        tester,
        size: const Size(420, 673),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        displayFeatures: [_halfOpenedAt(const Rect.fromLTWH(0, 336.5, 420, 0))],
      );
      expect(tester.takeException(), isNull);
      expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
      expect(tester.getRect(_keypad).top, greaterThanOrEqualTo(336.5));
      expect(tester.getRect(_lcd).bottom, lessThanOrEqualTo(336.5));
      _expectTouchTargets(tester, floor: CalcTheme.tabletopKeyTouchHeightFloor);
      final touch = KeypadMetrics.minKeyTouchHeightOf(
        tester.getSize(_keypad),
        tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement,
      );
      expect(touch, lessThan(CalcTheme.keyTouchHeightFloor));
    });

    testWidgets('Fold 가로 반 접힘·3버튼 내비게이션(아래 인셋 48)은 테이블톱 배치를 유지한다', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(841, 673),
        padding: const EdgeInsets.only(top: 24, bottom: 48),
        displayFeatures: [_halfOpenedAt(const Rect.fromLTWH(0, 336.5, 841, 0))],
      );
      expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
      expect(tester.getRect(_keypad).top, greaterThanOrEqualTo(336.5));
      _expectTouchTargets(tester, floor: CalcTheme.keyTouchHeightFloor);
    });

    testWidgets('접힘선이 인셋 안(창 가장자리)에 있으면 접힘선 기준으로 나누지 않는다', (tester) async {
      await _pump(
        tester,
        size: const Size(841, 701),
        padding: const EdgeInsets.only(left: 32, top: 24, bottom: 24),
        displayFeatures: [_foldAt(const Rect.fromLTWH(20, 0, 0, 701))],
      );
      expect(tester.takeException(), isNull);
      expect(isStackedArrangement(tester), isTrue);
      expect(tester.getRect(_lcd).width, greaterThan(300));
    });
  });

  testWidgets('디버그 검사: 화면이 원점에서 화면 전체를 채우지 않으면 접힘선 좌표 가정 위반을 보고한다', (
    tester,
  ) async {
    const size = Size(841, 701);
    const fold = DisplayFeature(
      bounds: Rect.fromLTWH(420.5, 0, 0, 701),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureFlat,
    );
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, displayFeatures: [fold]),
            // 화면을 왼쪽으로 40dp 밀어 넣는다 (가정 위반)
            child: Padding(
              padding: EdgeInsets.only(left: 40),
              child: CalculatorScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('본체 원점'));
  });

  group('접힘선 기준 배치의 설정 대화상자 (#25 R1)', () {
    testWidgets('물리 힌지·오른손잡이: 대화상자는 설정 키(ON)가 있는 키패드 쪽(오른쪽) 절반에 뜬다', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(1114, 720),
        handedness: Handedness.right,
        displayFeatures: [
          _foldAt(
            const Rect.fromLTWH(540, 0, 34, 720),
            type: DisplayFeatureType.hinge,
          ),
        ],
      );
      expect(tester.getRect(_settings).left, greaterThanOrEqualTo(574));
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      final dialog = tester.getRect(_dialogSurface);
      expect(dialog.left, greaterThanOrEqualTo(574));
    });

    testWidgets(
      '반 접은 세로 접힘선의 절반 폭(약 336dp)·글자 배율 2.0·오른손잡이: 오른쪽 절반에 넘치지 않고 뜨고 선택된다',
      (tester) async {
        final (container, _) = await _pump(
          tester,
          size: const Size(673, 841),
          padding: const EdgeInsets.only(top: 32, bottom: 24),
          textScale: 2.0,
          handedness: Handedness.right,
          displayFeatures: [
            _halfOpenedAt(const Rect.fromLTWH(336.5, 0, 0, 841)),
          ],
        );
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // 오른손잡이: 설정 키는 키패드와 함께 오른쪽 절반 → 대화상자도 오른쪽 절반 (anchor 없으면 왼쪽에 뜬다)
        expect(
          tester.getRect(_dialogSurface).left,
          greaterThanOrEqualTo(336.5),
        );
        await tester.tap(_option(Handedness.left));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(container.read(handednessProvider), Handedness.left);
      },
    );

    testWidgets('펼친 폭 0 세로 접힘선: 앱처럼 나눠 대화상자가 주름을 가로지르지 않는다', (tester) async {
      await _pump(
        tester,
        size: const Size(673, 841),
        padding: const EdgeInsets.only(top: 32, bottom: 24),
        displayFeatures: [_foldAt(const Rect.fromLTWH(336.5, 0, 0, 841))],
      );
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // 오른손잡이: 설정 키는 키패드와 함께 오른쪽 절반
      expect(tester.getRect(_dialogSurface).left, greaterThanOrEqualTo(336.5));
    });

    // 설정 키(ON)는 키패드 안이라 테이블톱에서는 늘 아래 절반이다 — Pixel Fold 세로(넓은 키패드 배열 #80)와
    // 세로로 긴 대화면(근사 716×1200, 실물 배열).
    for (final (name, size, hingeY) in [
      ('Pixel Fold 세로', const Size(701, 841), 420.5),
      ('세로로 긴 대화면', const Size(716, 1200), 600.0),
    ]) {
      testWidgets('반 접은 테이블톱($name): 대화상자는 설정 키가 있는 아래 절반에 뜬다', (tester) async {
        await _pump(
          tester,
          size: size,
          padding: const EdgeInsets.only(top: 32, bottom: 24),
          displayFeatures: [
            _halfOpenedAt(Rect.fromLTWH(0, hingeY, size.width, 0)),
          ],
        );
        expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
        bool sameHalf(Rect r) => r.top >= hingeY - 0.01;
        expect(sameHalf(tester.getRect(_settings)), isTrue);
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(sameHalf(tester.getRect(_dialogSurface)), isTrue);
      });
    }
  });

  group('대화상자를 연 채 손잡이를 바꾸면 대화상자는 연 자리에 남는다 (#94)', () {
    // 세로 접힘선 종류별: 앱만 나누는 펼친 폭 0 접힘선(대화상자 안쪽 `DisplayFeatureSubScreen`이 나눈다),
    // Flutter도 나누는 반 접힘·물리 힌지(`showDialog` 경로가 나눈다). 결정 근거는 [SettingsLauncher] 문서.
    final cases = <_Foldable>[
      (
        '펼친 폭 0 접힘선',
        const Size(673, 841),
        const EdgeInsets.only(top: 32, bottom: 24),
        _foldAt(const Rect.fromLTWH(336.5, 0, 0, 841)),
      ),
      (
        '반 접은 접힘선',
        const Size(673, 841),
        const EdgeInsets.only(top: 32, bottom: 24),
        _halfOpenedAt(const Rect.fromLTWH(336.5, 0, 0, 841)),
      ),
      (
        '물리 힌지',
        const Size(1114, 720),
        const EdgeInsets.only(top: 24, bottom: 24),
        _foldAt(
          const Rect.fromLTWH(540, 0, 34, 720),
          type: DisplayFeatureType.hinge,
        ),
      ),
    ];

    for (final (name, size, padding, fold) in cases) {
      for (final start in Handedness.values) {
        testWidgets('$name·${start.name}로 열기', (tester) async {
          final hinge = fold.bounds;
          final other = Handedness.values.firstWhere((h) => h != start);
          // 설정 키(ON)는 키패드 안이라 손잡이 쪽(키패드 쪽) 절반에 있다 (#190).
          bool onLeftHalf(Rect r) => r.right <= hinge.left + 0.01;
          bool onRightHalf(Rect r) => r.left >= hinge.right - 0.01;
          bool onButtonSideOf(Handedness h, Rect r) =>
              h.keypadOnRight ? onRightHalf(r) : onLeftHalf(r);

          final (container, _) = await _pump(
            tester,
            size: size,
            padding: padding,
            handedness: start,
            displayFeatures: [fold],
          );
          expect(onButtonSideOf(start, tester.getRect(_settings)), isTrue);
          await tester.tap(_settings);
          await tester.pumpAndSettle();
          final opened = tester.getRect(_dialogSurface);
          expect(onButtonSideOf(start, opened), isTrue, reason: '$opened');

          // 반대 손잡이를 고른다: 키패드(와 설정 키)는 반대쪽으로 옮겨 가고, 대화상자는 그 자리에 남는다
          // (대화상자가 접힘선을 넘지 않는다 — 연 자리가 한쪽 절반 안이다).
          await tester.tap(_option(other));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(container.read(handednessProvider), other);
          expect(onButtonSideOf(other, tester.getRect(_settings)), isTrue);
          expect(
            tester.getRect(_lcd).overlaps(opened),
            isTrue,
            reason: '옮겨 온 LCD는 대화상자 쪽 절반에 있다',
          );
          expect(tester.getRect(_dialogSurface), opened);

          // 키보드 화살표로 선택을 옮겨도(포커스 이동 = 선택) 대화상자는 건너뛰지 않는다.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          final focused = FocusManager.instance.primaryFocus!.context!;
          expect(
            find.ancestor(
              of: find.byElementPredicate((e) => identical(e, focused)),
              matching: find.byType(HandednessDialog),
            ),
            findsOneWidget,
          );
          for (final key in [
            LogicalKeyboardKey.arrowDown,
            LogicalKeyboardKey.arrowUp,
          ]) {
            final before = container.read(handednessProvider);
            await tester.sendKeyEvent(key);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(container.read(handednessProvider), isNot(before));
            expect(tester.getRect(_dialogSurface), opened, reason: '$key');
          }

          // 처음 손잡이로 되돌려도 그대로다. 닫았다가 다시 열면 지금 설정 키가 있는 절반에 뜬다.
          final now = container.read(handednessProvider);
          final back = now == start ? other : start;
          await tester.tap(_option(back));
          await tester.pumpAndSettle();
          expect(tester.getRect(_dialogSurface), opened);
          await tester.tap(find.byKey(HandednessDialog.closeKey));
          await tester.pumpAndSettle();
          expect(find.byType(HandednessDialog), findsNothing);
          await tester.tap(_settings);
          await tester.pumpAndSettle();
          final reopened = tester.getRect(_dialogSurface);
          expect(onButtonSideOf(back, reopened), isTrue, reason: '$reopened');
          expect(tester.takeException(), isNull);
        });
      }
    }

    // 손잡이에 따라 배치가 갈리는 비대칭 세로 접힘선. 키패드가 좁은 절반에 들어가지 못하는 손잡이는 위아래 배치,
    // 반대 손잡이는 접힘선 기준 배치(설정 키는 키패드 쪽 = 넓은 절반)다.
    // `_splitLikeApp`은 대화상자 경로(View)의 MediaQuery 인셋으로 절반을 재므로 View에도 같은 인셋을 넣는다
    // (넣지 않으면 실제 앱과 다른 절반을 잰다 — [_setViewPadding]).

    testWidgets(
      '비대칭 접힘선(펼친 폭 0): 한쪽 손잡이로는 위아래 배치라 대화상자는 배치가 바뀌어도 화면 전체에 그대로 뜬다 (#41·#129)',
      (tester) async {
        // x=560, 오른쪽 인셋 48 → 오른쪽 절반 233dp. 오른손잡이는 위아래 배치, 왼손잡이는 접힘선 기준 배치.
        const padding = EdgeInsets.only(top: 24, right: 48, bottom: 24);
        _setViewPadding(tester, padding);
        final (container, _) = await _pump(
          tester,
          size: const Size(841, 701),
          padding: padding,
          displayFeatures: [_foldAt(const Rect.fromLTWH(560, 0, 0, 701))],
        );
        expect(isStackedArrangement(tester), isTrue);
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        final opened = tester.getRect(_dialogSurface);
        expect(opened.left, lessThan(560)); // 좁은 절반에 갇히지 않았다
        final buttonBefore = tester.getRect(_settings);

        for (final h in [Handedness.left, Handedness.right]) {
          await tester.tap(_option(h));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(container.read(handednessProvider), h);
          expect(isStackedArrangement(tester), h == Handedness.right);
          if (h == Handedness.left) {
            expect(tester.getRect(_settings), isNot(buttonBefore));
          }
          expect(tester.getRect(_dialogSurface), opened, reason: '$h');
        }
      },
    );

    testWidgets('비대칭 접힘선(반 접힘): 손잡이를 바꿔 배치가 바뀌어도 대화상자는 연 절반에 남는다', (
      tester,
    ) async {
      // x=281, 왼쪽 인셋 48 → 왼쪽 절반 233dp. 왼손잡이는 위아래 배치(설정 키는 키패드 오른쪽 위), 오른손잡이는
      // 접힘선 기준 배치(키패드·설정 키는 오른쪽 넓은 절반).
      const hingeX = 281.0;
      const padding = EdgeInsets.only(left: 48, top: 24, bottom: 24);
      _setViewPadding(tester, padding);
      final (container, _) = await _pump(
        tester,
        size: const Size(841, 701),
        padding: padding,
        handedness: Handedness.left,
        displayFeatures: [
          _halfOpenedAt(const Rect.fromLTWH(hingeX, 0, 0, 701)),
        ],
      );
      expect(isStackedArrangement(tester), isTrue);
      expect(tester.getRect(_settings).left, greaterThanOrEqualTo(hingeX));
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      final opened = tester.getRect(_dialogSurface);
      expect(opened.left, greaterThanOrEqualTo(hingeX));

      await tester.tap(_option(Handedness.right));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(container.read(handednessProvider), Handedness.right);
      expect(isStackedArrangement(tester), isFalse);
      expect(tester.getRect(_settings).left, greaterThanOrEqualTo(hingeX));
      expect(tester.getRect(_dialogSurface), opened);

      await tester.tap(_option(Handedness.left));
      await tester.pumpAndSettle();
      expect(isStackedArrangement(tester), isTrue);
      expect(tester.getRect(_dialogSurface), opened);
    });

    // 반 접은 테이블톱: 설정 키는 키패드와 함께 늘 아래 절반이다. 손잡이를 바꾸면 키패드가 옮겨 가는 창에서는 같은 절반
    // 안에서 좌우로만 옮겨 가고, 키패드가 아래 절반 폭을 다 쓰는 창에서는 그대로다.
    for (final (name, size, hingeY, keypadMoves) in [
      // 실물 배열 키패드 옆에 자리가 남는다 (Pixel Fold 세로는 넓은 키패드 배열이 폭을 다 쓴다 — #80)
      ('키패드 옆 자리', const Size(716, 1200), 600.0, true),
      ('키패드가 폭을 다 씀', const Size(412, 915), 457.5, false),
    ]) {
      testWidgets('반 접은 테이블톱($name): 설정 키는 아래 절반 안에만 있고 대화상자는 그 자리다', (
        tester,
      ) async {
        bool sameHalf(Rect r) => r.top >= hingeY - 0.01;
        final (container, _) = await _pump(
          tester,
          size: size,
          padding: const EdgeInsets.only(top: 32, bottom: 24),
          displayFeatures: [
            _halfOpenedAt(Rect.fromLTWH(0, hingeY, size.width, 0)),
          ],
        );
        final buttonBefore = tester.getRect(_settings);
        expect(sameHalf(buttonBefore), isTrue, reason: '$buttonBefore');
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        final opened = tester.getRect(_dialogSurface);
        expect(sameHalf(opened), isTrue, reason: '$opened');

        await tester.tap(_option(Handedness.left));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(container.read(handednessProvider), Handedness.left);
        final button = tester.getRect(_settings);
        expect(button != buttonBefore, keypadMoves, reason: '$button');
        expect(sameHalf(button), isTrue, reason: '$button');
        expect(tester.getRect(_dialogSurface), opened);
      });
    }

    test(
      '하한 폭 이상인 세로 접힘선 절반에는 키패드가 폭으로 늘 들어간다 — 비대칭 배치의 LCD 쪽 절반은 하한보다 좁다',
      () {
        // 인셋을 뺀 절반 폭이 hingeMinPanelExtent일 때 키패드 자리 (화면 가장자리·접힘선 여백 제외).
        // 이 값에서 키가 터치 하한 이상이면, 손잡이에 따라 배치가 갈리는(한쪽 절반에 키패드가 못 들어가는) 화면의
        // 좁은 절반은 늘 하한보다 좁다 — `SettingsLauncher` "접힘선이 있을 때 대화상자 위치"의 전제.
        const region =
            FormFactor.hingeMinPanelExtent -
            CalcTheme.screenPadding -
            CalcTheme.screenHingeMargin;
        expect(
          KeypadMetrics.minKeyTouchHeightOf(
            const Size(region, double.infinity),
            KeypadArrangement.standard,
          ),
          greaterThanOrEqualTo(CalcTheme.keyTouchHeightFloor),
        );
      },
    );

    // 접힘선이 없으면 anchor가 위치에 영향이 없어 "따라가기"로 바꿔도 통과한다 — 여기서는 고른 뒤 닫히지 않고
    // 같은 자리에 남는지만 본다.
    testWidgets('가로형 배치(접힘선 없음): 고른 뒤에도 닫히지 않고 화면 가운데 같은 자리다', (tester) async {
      const size = Size(1280, 800);
      final (container, _) = await _pump(
        tester,
        size: size,
        padding: const EdgeInsets.only(top: 24, bottom: 48),
      );
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      final opened = tester.getRect(_dialogSurface);
      expect(opened.center.dx, moreOrLessEquals(size.width / 2));

      final lcdBefore = tester.getRect(_lcd);
      await tester.tap(_option(Handedness.left));
      await tester.pumpAndSettle();
      expect(container.read(handednessProvider), Handedness.left);
      expect(tester.getRect(_lcd), isNot(lcdBefore));
      expect(tester.getRect(_dialogSurface), opened);
    });
  });

  group('Flutter가 나누는 비대칭 접힘선의 좁은 하위 화면에 대화상자를 가두지 않는다 (#125)', () {
    // 대화상자 경로는 View의 MediaQuery를 본다 — 인셋·글자 배율을 View에도 넣어 실제 앱처럼 대화상자에 닿게 한다.
    void setView(WidgetTester tester, EdgeInsets padding, double textScale) {
      _setViewPadding(tester, padding);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    // 접힘선 앞쪽(왼쪽·위쪽) 하위 화면에 있는지, 뒤쪽(오른쪽·아래쪽)에 있는지
    bool before(Rect hinge, Rect r) => FormFactor.isVerticalHinge(hinge)
        ? r.right <= hinge.left + 0.01
        : r.bottom <= hinge.top + 0.01;
    bool after(Rect hinge, Rect r) => FormFactor.isVerticalHinge(hinge)
        ? r.left >= hinge.right - 0.01
        : r.top >= hinge.bottom - 0.01;

    // 창 841×701 (Pixel Fold 내부 가로 크기)과 701×841 (세로). 접힘선이 한쪽에 치우쳐 좁은 쪽이 인셋을 빼고
    // 대화상자 최소 크기(폭 360·높이 328dp)에 못 미친다.
    // (이름, 창, 인셋, 접힘선, 손잡이, 위아래 배치인지, 버튼이 앞쪽인지, 대화상자가 앞쪽인지)
    const wide = Size(841, 701);
    const tall = Size(701, 841);
    const rightInset = EdgeInsets.only(top: 24, right: 48, bottom: 24);
    const leftInset = EdgeInsets.only(left: 48, top: 24, bottom: 24);
    const portraitInset = EdgeInsets.only(top: 24, bottom: 48);
    final cases =
        <
          (
            String,
            Size,
            EdgeInsets,
            DisplayFeature,
            Handedness,
            bool,
            bool,
            bool,
          )
        >[
          // 이슈 재현: 오른쪽 절반 233dp라 위아래 배치, 설정 키(ON)는 키패드 오른쪽 위(좁은 절반)
          (
            '반 접힘·오른쪽 좁은 절반·위아래 배치',
            wide,
            rightInset,
            _halfOpenedAt(const Rect.fromLTWH(560, 0, 0, 701)),
            Handedness.right,
            true,
            false,
            true,
          ),
          (
            '물리 힌지·오른쪽 좁은 절반·위아래 배치',
            wide,
            rightInset,
            _foldAt(
              const Rect.fromLTWH(560, 0, 20, 701),
              type: DisplayFeatureType.hinge,
            ),
            Handedness.right,
            true,
            false,
            true,
          ),
          // 왼쪽 절반이 인셋을 빼고 282dp: 왼손잡이는 키패드(와 설정 키)가 그 좁은 절반에 들어가 접힘선 기준 배치다.
          (
            '반 접힘·왼쪽 좁은 절반·접힘선 기준 배치',
            wide,
            leftInset,
            _halfOpenedAt(const Rect.fromLTWH(330, 0, 0, 701)),
            Handedness.left,
            false,
            true,
            false,
          ),
          (
            '물리 힌지·왼쪽 좁은 절반·접힘선 기준 배치',
            wide,
            leftInset,
            _foldAt(
              const Rect.fromLTWH(330, 0, 20, 701),
              type: DisplayFeatureType.hinge,
            ),
            Handedness.left,
            false,
            true,
            false,
          ),
          // 같은 화면의 오른손잡이: 설정 키는 키패드와 함께 넓은 오른쪽 절반 — 원래부터 넓은 절반이다.
          (
            '반 접힘·왼쪽 좁은 절반·오른손잡이',
            wide,
            leftInset,
            _halfOpenedAt(const Rect.fromLTWH(330, 0, 0, 701)),
            Handedness.right,
            false,
            false,
            false,
          ),
          // 가로 접힘선: 위 절반이 낮아(인셋을 빼고 226·126dp) 위아래 배치. 설정 키는 키패드와 함께 넓은 아래 절반이다.
          for (final y in [250.0, 150.0])
            (
              '반 접은 가로 접힘선 y=$y·위쪽 낮은 절반·위아래 배치',
              tall,
              portraitInset,
              _halfOpenedAt(Rect.fromLTWH(0, y, 701, 0)),
              Handedness.right,
              true,
              false,
              false,
            ),
        ];

    for (final (
          name,
          size,
          padding,
          fold,
          handedness,
          stacked,
          buttonBefore,
          dialogBefore,
        )
        in cases) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('$name·${handedness.name}·글자 배율 $textScale', (
          tester,
        ) async {
          final hinge = fold.bounds;
          bool onExpectedSide(bool first, Rect r) =>
              first ? before(hinge, r) : after(hinge, r);
          setView(tester, padding, textScale);
          final (container, _) = await _pump(
            tester,
            size: size,
            padding: padding,
            textScale: textScale,
            handedness: handedness,
            displayFeatures: [fold],
          );
          expect(isStackedArrangement(tester), stacked);
          final button = tester.getRect(_settings);
          expect(
            onExpectedSide(buttonBefore, button),
            isTrue,
            reason: '$button',
          );

          await tester.tap(_settings);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // 글자 배율이 대화상자에 닿았다
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byType(HandednessDialog)),
            ).scale(10),
            moreOrLessEquals(10 * textScale),
          );
          final dialog = tester.getRect(_dialogSurface);
          expect(dialog.width, greaterThanOrEqualTo(280), reason: '$dialog');
          expect(
            onExpectedSide(dialogBefore, dialog),
            isTrue,
            reason: '$dialog',
          );
          final safe = padding.deflateRect(Offset.zero & size);
          expect(safe.intersect(dialog), dialog, reason: '인셋 안 $safe: $dialog');

          // 대화상자로 손잡이를 바꿀 수 있고, 배치가 바뀌어도 대화상자는 연 자리에 남는다 (#94).
          final other = Handedness.values.firstWhere((h) => h != handedness);
          await tester.tap(_option(other));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(container.read(handednessProvider), other);
          expect(tester.getRect(_dialogSurface), dialog);
        });
      }
    }

    // 경계: 설정 키 쪽 절반이 인셋을 빼고 카드 최소 폭 + 좌우 여백(280 + 40×2 = 360dp)이면 그 절반에(카드 정확히
    // 280dp — 가장 넘치기 쉬운 폭), 그보다 1dp 좁으면 반대쪽(넓은) 절반에 뜬다. 오른손잡이라 설정 키는 키패드 쪽인
    // 오른쪽 절반이다. 반 접힘(폭 0)·물리 힌지(폭 20)
    for (final width in [0.0, 20.0]) {
      for (final (rightHalf, stays) in [(360.0, true), (359.0, false)]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '경계: 접힘선 폭 ${width}dp·버튼 쪽 절반 ${rightHalf}dp·글자 배율 $textScale → '
            '${stays ? '그 절반' : '반대쪽 절반'}',
            (tester) async {
              final hinge = Rect.fromLTWH(
                wide.width - rightInset.right - rightHalf - width,
                0,
                width,
                701,
              );
              setView(tester, rightInset, textScale);
              await _pump(
                tester,
                size: wide,
                padding: rightInset,
                textScale: textScale,
                handedness: Handedness.right,
                displayFeatures: [
                  width == 0
                      ? _halfOpenedAt(hinge)
                      : _foldAt(hinge, type: DisplayFeatureType.hinge),
                ],
              );
              expect(isStackedArrangement(tester), isFalse);
              expect(after(hinge, tester.getRect(_settings)), isTrue);
              await tester.tap(_settings);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final dialog = tester.getRect(_dialogSurface);
              if (stays) {
                expect(after(hinge, dialog), isTrue, reason: '$dialog');
                expect(dialog.width, moreOrLessEquals(280));
              } else {
                expect(before(hinge, dialog), isTrue, reason: '$dialog');
                expect(dialog.width, greaterThan(280));
              }
            },
          );
        }
      }
    }

    // 높이 경계: 가로 접힘선 기준 배치(테이블톱)에서 설정 키 쪽 절반(키패드가 있는 아래 절반, #190)이 인셋을 빼고 카드 최소
    // 높이 + 위아래 여백(280 + 24×2 = 328dp)이면 그 절반에(카드 280dp 이하), 1dp 낮으면 위 절반에 뜬다.
    // 넓은 키패드 배열(#80)이 옆에 자리를 남기는 1200×800과 아래 절반 폭을 다 쓰는 701×841 두 창으로 본다.
    const wideTabletop = Size(1200, 800);
    for (final size in [wideTabletop, tall]) {
      for (final (half, stays) in [(328.0, true), (327.0, false)]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '높이 경계 ${size.width}×${size.height}: 설정 키 쪽 아래 절반 ${half}dp·글자 배율 $textScale → '
            '${stays ? '그 절반' : '위 절반'}',
            (tester) async {
              final hinge = Rect.fromLTWH(
                0,
                size.height - portraitInset.bottom - half,
                size.width,
                0,
              );
              setView(tester, portraitInset, textScale);
              await _pump(
                tester,
                size: size,
                padding: portraitInset,
                textScale: textScale,
                displayFeatures: [_halfOpenedAt(hinge)],
              );
              expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
              expect(after(hinge, tester.getRect(_settings)), isTrue);
              await tester.tap(_settings);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final dialog = tester.getRect(_dialogSurface);
              if (stays) {
                expect(after(hinge, dialog), isTrue, reason: '$dialog');
                expect(dialog.height, lessThanOrEqualTo(280.01));
              } else {
                expect(before(hinge, dialog), isTrue, reason: '$dialog');
              }
            },
          );
        }
      }
    }

    // 높이 기준([SettingsLauncher.dialogFallbackMinCardHeight])을 확인한다: 최소 크기 하위 화면(카드 280×280)에서
    // 큰 글자 배율에도 넘치지 않고 고정된 닫기 버튼이 보인다. 안내 글까지 보이는(가장 긴) 대화상자로 확인한다.
    for (final textScale in [1.0, 2.0]) {
      testWidgets('최소 크기 하위 화면(카드 280×280)·글자 배율 $textScale에서 넘치지 않는다', (
        tester,
      ) async {
        final region = SettingsLauncher.dialogMinRegionOf(
          const DialogThemeData(),
        );
        tester.view.physicalSize = region * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: const MaterialApp(
              home: Material(child: HandednessDialog(showLayoutNote: true)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(_dialogSurface), const Size(280, 280));
        expect(find.byKey(HandednessDialog.closeKey).hitTestable(), findsOne);
      });
    }

    group('기준점 계산 (dialogAnchorPointOf·dialogMinRegionOf)', () {
      const minRegion = Size(360, 328);
      MediaQueryData screenOf(
        Size size,
        List<DisplayFeature> features, {
        EdgeInsets padding = EdgeInsets.zero,
      }) => MediaQueryData(
        size: size,
        padding: padding,
        displayFeatures: features,
      );

      test('테마 값이 없으면 Material 기본값(최소 폭 280·여백 40/24)과 높이 280으로 본다', () {
        expect(
          SettingsLauncher.dialogMinRegionOf(const DialogThemeData()),
          minRegion,
        );
      });

      test('테마의 최소 크기·여백을 따른다 — 높이는 테마 최소 높이가 더 클 때만 그 값', () {
        expect(
          SettingsLauncher.dialogMinRegionOf(
            const DialogThemeData(
              constraints: BoxConstraints(minWidth: 200, minHeight: 400),
              insetPadding: EdgeInsets.all(10),
            ),
          ),
          const Size(220, 420),
        );
        expect(
          SettingsLauncher.dialogMinRegionOf(
            const DialogThemeData(
              constraints: BoxConstraints(),
              insetPadding: EdgeInsets.zero,
            ),
          ),
          const Size(0, 280),
        );
      });

      test('버튼 위치나 화면 정보를 모르면 그대로 돌려준다', () {
        final screen = screenOf(wide, [
          _halfOpenedAt(const Rect.fromLTWH(560, 0, 0, 701)),
        ]);
        expect(
          SettingsLauncher.dialogAnchorPointOf(screen, null, minRegion),
          isNull,
        );
        const anchor = Offset(700, 30);
        expect(
          SettingsLauncher.dialogAnchorPointOf(null, anchor, minRegion),
          anchor,
        );
      });

      test('네 하위 화면: 최소 크기를 넘는 곳 중 버튼에 가장 가까운 곳의 가운데이고, 접힘 정보 순서와 무관하다', () {
        // 1400×1000을 세로 힌지(x=400, 폭 20)·가로 힌지(y=300, 높이 20)로 4분할. 위 두 곳은 높이 300dp로 미달,
        // 아래 왼쪽(400×680)·아래 오른쪽(980×680)이 넘는다. 버튼은 위 왼쪽.
        const size = Size(1400, 1000);
        const anchor = Offset(100, 100);
        final vertical = _foldAt(
          const Rect.fromLTWH(400, 0, 20, 1000),
          type: DisplayFeatureType.hinge,
        );
        final horizontal = _foldAt(
          const Rect.fromLTWH(0, 300, 1400, 20),
          type: DisplayFeatureType.hinge,
        );
        for (final features in [
          [vertical, horizontal],
          [horizontal, vertical],
        ]) {
          expect(
            SettingsLauncher.dialogAnchorPointOf(
              screenOf(size, features),
              anchor,
              minRegion,
            ),
            const Rect.fromLTWH(0, 320, 400, 680).center,
            reason: '$features',
          );
        }
      });

      test('키보드 인셋(viewInsets)도 빼고 판정한다', () {
        // 가로 반 접힘 y=600, 버튼은 아래 절반(400dp): 키보드가 없으면 넘어 그대로, 키보드 100dp가 뜨면 아래
        // 절반이 300dp로 줄어 미달이라 위 절반(600dp)으로 옮긴다.
        const size = Size(700, 1000);
        final fold = _halfOpenedAt(const Rect.fromLTWH(0, 600, 700, 0));
        const anchor = Offset(600, 900); // 아래 절반 (400dp)
        expect(
          SettingsLauncher.dialogAnchorPointOf(
            screenOf(size, [fold]),
            anchor,
            minRegion,
          ),
          anchor,
        );
        expect(
          SettingsLauncher.dialogAnchorPointOf(
            MediaQueryData(
              size: size,
              viewInsets: const EdgeInsets.only(bottom: 100),
              displayFeatures: [fold],
            ),
            anchor,
            minRegion,
          ),
          const Offset(350, 300),
        );
      });

      test('Flutter가 나누지 않는 접힘선(펼친 폭 0 — 종류가 hinge여도)에서는 그대로다', () {
        const anchor = Offset(700, 30);
        for (final f in [
          _foldAt(const Rect.fromLTWH(560, 0, 0, 701)),
          _foldAt(
            const Rect.fromLTWH(560, 0, 0, 701),
            type: DisplayFeatureType.hinge,
          ),
        ]) {
          expect(
            SettingsLauncher.dialogAnchorPointOf(
              screenOf(wide, [f]),
              anchor,
              minRegion,
            ),
            anchor,
            reason: '${f.type}',
          );
        }
      });

      test('인셋을 뺀 크기로 판정한다', () {
        // 오른쪽 절반 380dp — 인셋 없이는 넘고, 오른쪽 인셋 48을 빼면 332dp라 못 미친다.
        const anchor = Offset(700, 30);
        final fold = _halfOpenedAt(const Rect.fromLTWH(461, 0, 0, 701));
        expect(
          SettingsLauncher.dialogAnchorPointOf(
            screenOf(wide, [fold]),
            anchor,
            minRegion,
          ),
          anchor,
        );
        expect(
          SettingsLauncher.dialogAnchorPointOf(
            screenOf(wide, [fold], padding: rightInset),
            anchor,
            minRegion,
          ),
          const Offset(230.5, 350.5),
        );
      });

      test('반대쪽도 최소 크기에 못 미치면 조금 더 넓어도 옮기지 않는다', () {
        // 왼쪽 330·오른쪽 350 (둘 다 360 미만)
        final screen = screenOf(const Size(680, 701), [
          _halfOpenedAt(const Rect.fromLTWH(330, 0, 0, 701)),
        ]);
        const anchor = Offset(100, 30);
        expect(
          SettingsLauncher.dialogAnchorPointOf(screen, anchor, minRegion),
          anchor,
        );
      });
    });
  });

  group('앱만 나누는 펼친 폭 0 세로 접힘선에서도 좁은 절반에 대화상자를 가두지 않는다 (#129)', () {
    // 왼손잡이·접힘선 기준 배치: 설정 키(ON)는 키패드와 함께 왼쪽 절반에 있다(#190). 대화상자 경로는 View의 MediaQuery를
    // 보므로 인셋·글자 배율을 View에도 넣는다.
    const wide = Size(841, 701);
    const leftInset = EdgeInsets.only(left: 48, top: 24, bottom: 24);
    const rightInset = EdgeInsets.only(top: 24, right: 48, bottom: 24);
    const noSideInset = EdgeInsets.only(top: 24, bottom: 24);
    bool onLeftOf(double x, Rect r) => r.right <= x + 0.01;
    bool onRightOf(double x, Rect r) => r.left >= x - 0.01;

    Future<ProviderContainer> pumpFold(
      WidgetTester tester, {
      required Size size,
      required EdgeInsets padding,
      required double hingeX,
      double textScale = 1.0,
      Handedness handedness = Handedness.left,
    }) async {
      _setViewPadding(tester, padding);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (container, _) = await _pump(
        tester,
        size: size,
        padding: padding,
        textScale: textScale,
        handedness: handedness,
        displayFeatures: [_foldAt(Rect.fromLTWH(hingeX, 0, 0, size.height))],
      );
      return container;
    }

    /// 대화상자가 [hingeX]의 [right] 쪽 절반(인셋 제외 영역) 가운데에, 그 영역에서 바깥 여백(좌우 40)을 뺀 폭 안에
    /// 최소 폭 이상으로 떴는지 — 절반이 반대쪽 인셋만큼 밀리거나 줄면(#129 R1) 가운데·폭이 어긋난다.
    void expectInHalf(
      Rect dialog, {
      required Size size,
      required EdgeInsets padding,
      required double hingeX,
      required bool right,
    }) {
      final safe = padding.deflateRect(Offset.zero & size);
      final half = right
          ? Rect.fromLTRB(hingeX, 0, size.width, size.height)
          : Rect.fromLTRB(0, 0, hingeX, size.height);
      final region = safe.intersect(half);
      expect(
        right ? onRightOf(hingeX, dialog) : onLeftOf(hingeX, dialog),
        isTrue,
        reason: '$dialog',
      );
      expect(
        dialog.center.dx,
        moreOrLessEquals(region.center.dx),
        reason: '$region $dialog',
      );
      expect(dialog.width, greaterThanOrEqualTo(280), reason: '$dialog');
      expect(
        dialog.width,
        lessThanOrEqualTo(region.width - 80 + 0.01),
        reason: '$region $dialog',
      );
    }

    // (창, 인셋, 접힘선 x, 설정 키 쪽 왼쪽 절반 폭(인셋 제외), 대화상자가 오른쪽 절반인지)
    final cases = <(Size, EdgeInsets, double, String, bool)>[
      // #129 측정 조건 — 설정 키 쪽 절반이 하한 이상·최소 크기 미만 (수정 전 카드 202·220·260dp)
      (wide, leftInset, 330, '282', true),
      (wide, noSideInset, 300, '300', true),
      (wide, noSideInset, 340, '340', true),
      // 하한(280)보다 좁지만 반대 손잡이로도 접힘선 기준 배치(키패드는 약 264dp까지 들어간다) — 주름을
      // 가로지르지 않고 반대쪽 절반 (R1)
      (wide, leftInset, 320, '272', true),
      // 반대쪽 가장자리 인셋이 대화상자 절반을 밀거나 줄이지 않는다 (R1 — 수정 전 카드 232dp)
      (wide, rightInset, 360, '360', false),
      (const Size(700, 701), leftInset, 340, '292', true),
    ];

    for (final (size, padding, hingeX, leftHalf, right) in cases) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          '${size.width}×${size.height}·접힘선 x=$hingeX·인셋 ${padding.left}/${padding.right}'
          '(설정 키 쪽 절반 ${leftHalf}dp)·글자 배율 $textScale → ${right ? '반대쪽' : '설정 키 쪽'} 절반, '
          '손잡이를 바꿔도 연 자리에 남는다',
          (tester) async {
            final container = await pumpFold(
              tester,
              size: size,
              padding: padding,
              hingeX: hingeX,
              textScale: textScale,
            );
            expect(isStackedArrangement(tester), isFalse);
            expect(onLeftOf(hingeX, tester.getRect(_settings)), isTrue);

            await tester.tap(_settings);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final opened = tester.getRect(_dialogSurface);
            expectInHalf(
              opened,
              size: size,
              padding: padding,
              hingeX: hingeX,
              right: right,
            );

            // 손잡이를 바꾸면 키패드·설정 키는 오른쪽으로 옮겨 가고 배치는 그대로 접힘선 기준 배치다. 대화상자는 연
            // 자리에 남는다 (#94).
            for (final h in [Handedness.right, Handedness.left]) {
              // 카드 280dp·글자 배율 2.0에서는 선택지가 스크롤 아래에 있을 수 있다.
              await tester.ensureVisible(_option(h));
              await tester.pumpAndSettle();
              await tester.tap(_option(h));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(container.read(handednessProvider), h);
              expect(isStackedArrangement(tester), isFalse, reason: '$h');
              expect(tester.getRect(_dialogSurface), opened, reason: '$h');
            }
          },
        );
      }
    }

    testWidgets('오른손잡이로 열면 설정 키 쪽(넓은 오른쪽) 절반에 그대로 뜬다', (tester) async {
      await pumpFold(
        tester,
        size: wide,
        padding: leftInset,
        hingeX: 330,
        handedness: Handedness.right,
      );
      expect(onRightOf(330, tester.getRect(_settings)), isTrue);
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectInHalf(
        tester.getRect(_dialogSurface),
        size: wide,
        padding: leftInset,
        hingeX: 330,
        right: true,
      );
    });

    // 경계: 설정 키 쪽 절반이 인셋을 빼고 최소 크기 폭(360dp)이면 그 절반에(카드 정확히 280dp), 1dp 좁으면 반대쪽
    // 절반에 뜬다.
    for (final (leftHalf, stays) in [(360.0, true), (359.0, false)]) {
      testWidgets(
        '경계: 설정 키 쪽 절반 ${leftHalf}dp → ${stays ? '그 절반' : '반대쪽 절반'}',
        (tester) async {
          final hingeX = leftInset.left + leftHalf;
          await pumpFold(
            tester,
            size: wide,
            padding: leftInset,
            hingeX: hingeX,
          );
          expect(isStackedArrangement(tester), isFalse);
          await tester.tap(_settings);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final dialog = tester.getRect(_dialogSurface);
          expectInHalf(
            dialog,
            size: wide,
            padding: leftInset,
            hingeX: hingeX,
            right: !stays,
          );
          if (stays) expect(dialog.width, moreOrLessEquals(280));
        },
      );
    }

    // 설정 키 쪽 하한: 반대쪽 절반도 최소 크기(360dp)에 못 미치면 설정 키 쪽 절반이 인셋을 빼고 280dp 이상일 때만 그
    // 절반이고, 그보다 좁으면 화면 전체다 (R2). 반대쪽 절반 340dp, 두 손잡이 모두 접힘선 기준 배치.
    for (final (leftHalf, split) in [
      (280.0, true),
      (279.0, false),
      (272.0, false),
    ]) {
      testWidgets(
        '하한: 설정 키 쪽 절반 ${leftHalf}dp·반대쪽 340dp → ${split ? '설정 키 쪽 절반' : '화면 전체'}',
        (tester) async {
          final hingeX = leftInset.left + leftHalf;
          final size = Size(hingeX + 340, 701);
          final container = await pumpFold(
            tester,
            size: size,
            padding: leftInset,
            hingeX: hingeX,
          );
          expect(isStackedArrangement(tester), isFalse);
          await tester.tap(_settings);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final dialog = tester.getRect(_dialogSurface);
          if (split) {
            expect(onLeftOf(hingeX, dialog), isTrue, reason: '$dialog');
            final region = Rect.fromLTRB(leftInset.left, 0, hingeX, 701);
            expect(dialog.center.dx, moreOrLessEquals(region.center.dx));
          } else {
            expect(dialog.left, lessThan(hingeX), reason: '$dialog');
            expect(dialog.right, greaterThan(hingeX), reason: '$dialog');
          }
          // 반대 손잡이로도 접힘선 기준 배치라 손잡이를 바꿔도 그 자리다 (#94).
          await tester.ensureVisible(_option(Handedness.right));
          await tester.pumpAndSettle();
          await tester.tap(_option(Handedness.right));
          await tester.pumpAndSettle();
          expect(container.read(handednessProvider), Handedness.right);
          expect(isStackedArrangement(tester), isFalse);
          expect(tester.getRect(_dialogSurface), dialog);
        },
      );
    }

    testWidgets('열린 채 인셋이 바뀌어 반대 손잡이로는 위아래 배치가 되면, 설정 키 쪽 절반에서 화면 전체로 옮겨 간다', (
      tester,
    ) async {
      // x=320·오른손잡이: 설정 키는 넓은 오른쪽 절반. 왼쪽 인셋 48이면 왼쪽 절반 272dp(두 손잡이 모두 접힘선 기준 배치)라
      // 그 절반에 뜬다. 왼쪽 인셋 64로 바뀌면 256dp라 왼손잡이는 위아래 배치 — 그린 배치·손잡이 적용 여부는 그대로이고
      // [SettingsLauncher.handednessKeepsArrangement]만 바뀐다.
      const hingeX = 320.0;
      final fold = _foldAt(const Rect.fromLTWH(hingeX, 0, 0, 701));
      final container = await pumpFold(
        tester,
        size: wide,
        padding: leftInset,
        hingeX: hingeX,
        handedness: Handedness.right,
      );
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      expect(onRightOf(hingeX, tester.getRect(_dialogSurface)), isTrue);

      const widerInset = EdgeInsets.only(left: 64, top: 24, bottom: 24);
      _setViewPadding(tester, widerInset);
      await _pump(
        tester,
        size: wide,
        padding: widerInset,
        displayFeatures: [fold],
        container: container,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(isStackedArrangement(tester), isFalse);
      final moved = tester.getRect(_dialogSurface);
      expect(moved.left, lessThan(hingeX), reason: '$moved');
      expect(moved.right, greaterThan(hingeX), reason: '$moved');
    });

    testWidgets(
      '반대 손잡이로는 위아래 배치가 되는 화면은 설정 키 쪽 절반이 넓어도 화면 전체에 띄워 그대로 남는다 (#94)',
      (tester) async {
        // x=300·왼쪽 인셋 48 → 왼쪽 절반 252dp: 키패드가 들어가지 못해 왼손잡이는 위아래 배치다. 오른손잡이의 설정 키는
        // 넓은 오른쪽 절반이지만, 그 절반에 띄우면 왼손잡이를 고를 때 화면 전체로 옮겨 가야 한다.
        final container = await pumpFold(
          tester,
          size: wide,
          padding: leftInset,
          hingeX: 300,
          handedness: Handedness.right,
        );
        expect(isStackedArrangement(tester), isFalse);
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        final opened = tester.getRect(_dialogSurface);
        expect(opened.left, lessThan(300));
        expect(opened.right, greaterThan(300));
        await tester.tap(_option(Handedness.left));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(container.read(handednessProvider), Handedness.left);
        expect(isStackedArrangement(tester), isTrue);
        expect(tester.getRect(_dialogSurface), opened);
      },
    );

    testWidgets(
      '양쪽 절반이 모두 최소 크기에 못 미치는 대칭 화면(Fold 내부 세로)은 설정 키 쪽 절반 그대로다 (#25)',
      (tester) async {
        const size = Size(673, 841);
        const padding = EdgeInsets.only(top: 32, bottom: 24);
        for (final h in Handedness.values) {
          await pumpFold(
            tester,
            size: size,
            padding: padding,
            hingeX: 336.5,
            handedness: h,
          );
          await tester.tap(_settings);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // 설정 키는 키패드 쪽 절반 — 대화상자도 그 절반 안(주름을 가로지르지 않는다)에 카드 256dp로 뜬다.
          final dialog = tester.getRect(_dialogSurface);
          expect(
            h.keypadOnRight
                ? onRightOf(336.5, dialog)
                : onLeftOf(336.5, dialog),
            isTrue,
            reason: '$h $dialog',
          );
          expect(dialog.width, moreOrLessEquals(336.5 - 80), reason: '$h');
          await tester.tap(find.byKey(HandednessDialog.closeKey));
          await tester.pumpAndSettle();
        }
      },
    );
  });

  group('CalcHingeSplitLayout · CalcTabletopLayout', () {
    void expectSane(Size body, List<Rect> rects, String reason) {
      final bounds = (Offset.zero & body).inflate(0.01);
      for (final r in rects) {
        expect(
          [r.left, r.top, r.width, r.height].every((v) => v.isFinite && v >= 0),
          isTrue,
          reason: '$reason $r',
        );
        expect(
          bounds.contains(r.topLeft) && bounds.contains(r.bottomRight),
          isTrue,
          reason: '$reason $r',
        );
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse, reason: '$reason $i×$j');
        }
      }
    }

    test('세로 접힘선: 본체 안, 겹침 없음, 접힘선 띠에 걸치지 않음 (극단 크기 포함)', () {
      for (final (body, hinge) in [
        (const Size(641, 761), const Rect.fromLTWH(320.5, 0, 0, 761)),
        (const Size(825, 637), const Rect.fromLTWH(412.5, 0, 0, 637)),
        (const Size(1098, 650), const Rect.fromLTWH(532, 0, 34, 650)),
        // 접힘선이 한쪽 끝에 치우친 창
        (const Size(800, 600), const Rect.fromLTWH(60, 0, 0, 600)),
        (const Size(800, 600), const Rect.fromLTWH(790, 0, 0, 600)),
        // 본체 밖 접힘선, 아주 작은 본체
        (const Size(800, 600), const Rect.fromLTWH(-20, 0, 0, 600)),
        (const Size(40, 40), const Rect.fromLTWH(20, 0, 0, 40)),
        (Size.zero, Rect.zero),
      ]) {
        for (final h in Handedness.values) {
          final l = CalcHingeSplitLayout.of(body, hinge, h);
          final reason = '$body $hinge $h $l';
          expectSane(body, [l.lcd, l.keypad], reason);
          final hingeInBody = hinge.left >= 0 && hinge.right <= body.width;
          if (hingeInBody) {
            for (final r in [l.lcd, l.keypad]) {
              if (r.isEmpty) continue;
              expect(
                _clearOfHinge(r, hinge, vertical: true),
                isTrue,
                reason: reason,
              );
            }
          }
        }
      }
    });

    test('세로 접힘선: 키패드는 손 쪽 절반을 다 쓰고, LCD는 키패드 폭으로 접힘선 쪽에 붙는다 (#71, #141)', () {
      // 두 화면 기기: 절반 패널이 524dp다. 예전에는 키패드가 480dp에서 멈춰 LCD–키패드 사이가 94dp였다.
      const body = Size(1098, 594);
      const hinge = Rect.fromLTWH(532, 0, 34, 594);
      for (final h in Handedness.values) {
        final l = CalcHingeSplitLayout.of(body, hinge, h);
        expect(l.keypad.width, moreOrLessEquals(524));
        expect(
          l.lcd.width,
          moreOrLessEquals(l.keypad.width * CalcTheme.screenLcdMaxWidthRatio),
        );
        if (h.keypadOnRight) {
          expect(
            l.lcd.right,
            moreOrLessEquals(hinge.left - CalcTheme.screenHingeMargin),
          );
        } else {
          expect(
            l.lcd.left,
            moreOrLessEquals(hinge.right + CalcTheme.screenHingeMargin),
          );
        }
      }
      // 고정값: LCD–키패드 사이는 접힘선 34 + 간격 8×2 = 50dp
      final r = CalcHingeSplitLayout.of(body, hinge, Handedness.right);
      expect(
        r.lcd,
        rectMoreOrLessEquals(const Rect.fromLTWH(0, 0, 524, 524 / 1.75)),
      );
      expect(
        r.keypad,
        rectMoreOrLessEquals(const Rect.fromLTWH(574, 0, 524, 594)),
      );
      expect(r.keypad.left - r.lcd.right, moreOrLessEquals(50));
      final l = CalcHingeSplitLayout.of(body, hinge, Handedness.left);
      expect(
        l.lcd,
        rectMoreOrLessEquals(const Rect.fromLTWH(574, 0, 524, 524 / 1.75)),
      );
    });

    test('세로 접힘선: 본체가 키패드보다 높으면 키패드 위 높이도 LCD가 받는다 (#190 — 상단 띠가 없다)', () {
      // 본체 641×761, 접힘선 320.5: 절반 312.5 → 키패드 312.5 × (312.5 / 0.75 = 416.7) — 위에 약 344dp가 남는다.
      const body = Size(641, 761);
      const hinge = Rect.fromLTWH(320.5, 0, 0, 761);
      final r = CalcHingeSplitLayout.of(body, hinge, Handedness.right);
      expect(r.keypad.height, moreOrLessEquals(312.5 / 0.75));
      expect(r.lcd.top, 0);
      // 아래끝은 키패드 윗변에서 폭 기준 최대 높이(하한 112) 아래다.
      expect(
        r.lcd.bottom,
        moreOrLessEquals(
          r.keypad.top + math.max(312.5 / 1.75, CalcTheme.screenLcdMinHeight),
        ),
      );
      // 본체 높이가 키패드와 같으면 LCD 윗변은 키패드 윗변이다(예전 배치와 같다).
      final flush = CalcHingeSplitLayout.of(
        Size(641, r.keypad.height),
        hinge,
        Handedness.right,
      );
      expect(flush.lcd.top, moreOrLessEquals(flush.keypad.top));
    });

    test('세로 접힘선: 음수·비유한 크기는 0으로 본다', () {
      for (final body in const [
        Size(double.nan, double.nan),
        Size(-10, -10),
        Size(double.infinity, 500),
      ]) {
        final l = CalcHingeSplitLayout.of(
          body,
          const Rect.fromLTWH(double.nan, 0, 0, 500),
          Handedness.right,
        );
        for (final r in [l.lcd, l.keypad]) {
          expect(
            [
              r.left,
              r.top,
              r.width,
              r.height,
            ].every((v) => v.isFinite && v >= 0),
            isTrue,
            reason: '$body $l',
          );
        }
      }
    });

    test('세로 접힘선: 왼손잡이 배치는 가운데 접힘선 기준 오른손잡이 배치의 좌우 대칭이다', () {
      const body = Size(825, 637);
      const hinge = Rect.fromLTWH(412.5, 0, 0, 637);
      final r = CalcHingeSplitLayout.of(body, hinge, Handedness.right);
      final l = CalcHingeSplitLayout.of(body, hinge, Handedness.left);
      Rect mirror(Rect x) => Rect.fromLTRB(
        body.width - x.right,
        x.top,
        body.width - x.left,
        x.bottom,
      );
      expect(l.lcd, mirror(r.lcd));
      expect(l.keypad, mirror(r.keypad));
    });

    test('가로 접힘선: 본체 안, 겹침 없음, 접힘선 띠에 걸치지 않음', () {
      for (final (body, hinge) in [
        (const Size(825, 593), const Rect.fromLTWH(0, 304.5, 825, 0)),
        (const Size(685, 777), const Rect.fromLTWH(0, 380.5, 685, 0)),
        (const Size(360, 700), const Rect.fromLTWH(0, 300, 360, 0)),
        (const Size(800, 600), const Rect.fromLTWH(0, 40, 800, 0)),
        (const Size(800, 600), const Rect.fromLTWH(0, 590, 800, 0)),
        (const Size(40, 40), const Rect.fromLTWH(0, 20, 40, 0)),
        (Size.zero, Rect.zero),
      ]) {
        for (final h in Handedness.values) {
          final l = CalcTabletopLayout.of(body, hinge, h);
          final reason = '$body $hinge $h $l';
          expectSane(body, [l.lcd, l.keypad], reason);
          for (final r in [l.lcd, l.keypad]) {
            if (r.isEmpty) continue;
            expect(
              _clearOfHinge(r, hinge, vertical: false),
              isTrue,
              reason: reason,
            );
          }
        }
      }
    });

    test('가로 접힘선: LCD는 위 절반 높이 전체다 (#190 — 상단 띠·위 절반 설정 버튼이 없다)', () {
      for (final (body, hinge) in const [
        (Size(360, 700), Rect.fromLTWH(0, 300, 360, 0)),
        (Size(825, 547), Rect.fromLTWH(0, 304.5, 825, 0)),
        (Size(540, 700), Rect.fromLTWH(0, 300, 540, 0)),
      ]) {
        for (final h in Handedness.values) {
          final l = CalcTabletopLayout.of(body, hinge, h);
          expect(l.lcd.top, 0, reason: '$body $h');
          expect(
            l.lcd.bottom,
            moreOrLessEquals(hinge.top - CalcTheme.screenHingeMargin),
            reason: '$body $h',
          );
        }
      }
    });

    test('가로 접힘선: LCD 폭 상한 (#92) — 넓은 위 절반에서 480dp, 키패드 쪽 가장자리', () {
      // 본체 520×662.5 (접힘선 304.5): 아래 절반 350 → 실물 배열 키패드 437.5dp(높이에 묶임), LCD는 480dp.
      // 넓은 배열(#80)은 폭에 묶여 키가 더 작다(28.6 < 29.75dp). 키패드 옆에 82.5dp가 남는다.
      const body = Size(520, 662.5);
      const hinge = Rect.fromLTWH(0, 304.5, 520, 0);
      final r = CalcTabletopLayout.of(body, hinge, Handedness.right);
      expect(r.keypadArrangement, KeypadArrangement.standard);
      expect(r.keypad.width, moreOrLessEquals(350 * 1.25));
      expect(r.lcd.width, CalcTheme.screenTabletopLcdMaxWidth);
      expect(r.lcd.height, moreOrLessEquals(304.5 - 8));
      expect(r.lcd.right, body.width);
      expect(r.lcd.bottom, moreOrLessEquals(304.5 - 8));
      // 왼손잡이는 좌우 대칭
      final l = CalcTabletopLayout.of(body, hinge, Handedness.left);
      Rect mirror(Rect x) => Rect.fromLTRB(
        body.width - x.right,
        x.top,
        body.width - x.left,
        x.bottom,
      );
      expect(l.lcd, mirror(r.lcd));
      expect(l.keypad, mirror(r.keypad));
    });

    test('가로 접힘선: 넓은 키패드 배열은 아래 절반 폭을 쓰고 LCD는 480dp 그대로다 (#80)', () {
      // Fold 가로 반 접힘 본체 825×547 (접힘선 304.5): 아래 절반 234.5 → 넓은 배열 825×234.5.
      const body = Size(825, 547);
      const hinge = Rect.fromLTWH(0, 304.5, 825, 0);
      for (final h in Handedness.values) {
        final l = CalcTabletopLayout.of(body, hinge, h);
        expect(l.keypadArrangement, KeypadArrangement.wide, reason: '$h');
        expect(l.keypad, const Rect.fromLTRB(0, 312.5, 825, 547), reason: '$h');
        expect(
          KeypadMetrics.minKeyTouchHeightOf(l.keypad.size, l.keypadArrangement),
          greaterThanOrEqualTo(CalcTheme.keyTouchHeightFloor),
        );
        expect(l.lcd.width, CalcTheme.screenTabletopLcdMaxWidth, reason: '$h');
        expect(l.lcd.height, moreOrLessEquals(304.5 - 8), reason: '$h');
        expect(
          h.keypadOnRight ? l.lcd.right : l.lcd.left,
          h.keypadOnRight ? l.keypad.right : l.keypad.left,
          reason: '$h',
        );
      }
    });
  });
}
