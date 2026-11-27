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
import 'package:itechnika_altcalc_fx991/presentation/providers/device_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/handedness_dialog.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/history_panel.dart';
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

/// 계산 기록 영역 — 기록 영역이 없는 배치에서는 보이지 않아(Offstage) 찾지 않는다
final _history = find.byType(HistoryPanel);

/// 폭·높이가 각각 [expected]와 [epsilon] 안인 크기
Matcher sizeMoreOrLessEquals(Size expected, {double epsilon = 1e-6}) =>
    predicate<Size>(
      (s) =>
          (s.width - expected.width).abs() <= epsilon &&
          (s.height - expected.height).abs() <= epsilon,
      'size within $epsilon of $expected',
    );

/// 그려진 키패드의 넓은 배열 숫자부가 왼쪽인지
bool _numbersOnLeft(WidgetTester tester) =>
    tester.widget<CalcKeypad>(find.byType(CalcKeypad)).numbersOnLeft;

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
      // 오른손잡이: 접힘선(x = 640) 왼쪽 계산 기록, 오른쪽 LCD·키패드 (책 자세, #143)
      expect(tester.getRect(_history).right, lessThanOrEqualTo(640));
      expect(tester.getRect(_lcd).left, greaterThanOrEqualTo(640));
      expect(tester.getRect(_keypad).left, greaterThanOrEqualTo(640));
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
    });
  });

  group('위아래 배치: LCD·키패드가 본체 폭 전체를 쓴다 (#141)', () {
    // (창, 인셋, LCD 높이) — 폭 상한(#92의 480dp)이 없어 태블릿 세로도 남는 높이 없이 LCD는 목표 비율(줄 글자 상한 높이까지,
    // #189), 키패드는 나머지 전부다([CalcTheme] "화면 배치" 절). LCD는 본체 윗변부터다(#190 — 상단 띠가 없다).
    final windows = [
      // 12.9인치 iPad 세로: 본체 1008×1306 (1366 − 24 − 20 − 화면 여백 8×2) — 목표 365.7이 상한 높이에서 멈춘다
      (
        const Size(1024, 1366),
        const EdgeInsets.only(top: 24, bottom: 20),
        LcdFontSizes.heightAtMaxLineFont,
      ),
      // 10인치 Android 세로: 본체 784×1192 (1280 − 24 − 48 − 16) — 목표 333.8도 상한 높이에서 멈춘다
      (
        const Size(800, 1280),
        const EdgeInsets.only(top: 24, bottom: 48),
        LcdFontSizes.heightAtMaxLineFont,
      ),
      // 정사각형 창: 본체 752×752
      (const Size(768, 768), EdgeInsets.zero, 752 * 0.28),
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

  group('Fold 가로 접힘선: 위 패널 = 기록 | 활성 LCD, 아래 패널 = 넓은 배열 (#143 고정값)', () {
    // Galaxy Z Fold 내부 가로 841×673, 인셋 24/24: 본체 825 폭, 접힘선 336.5(본체 304.5) — 위 패널 296.5.
    // 넓은 배열 블록 825 / 2.06 = 400.5. 활성 LCD는 숫자부 블록 위 400.5×228.8(블록 폭 / 1.75, 줄 글자 32.1dp)로
    // 접힘선 쪽에 붙고, 기록 영역은 함수부 블록 위 400.5×296.5(위 패널 높이 전체)다. #143 전(테이블톱 폭 상한)에는
    // LCD 480×273.5가 손 쪽 끝에 붙고 반대쪽은 빈 여백이었다. 펼침·반 접힘이 같은 배치다.
    for (final handedness in Handedness.values) {
      for (final state in const [
        DisplayFeatureState.postureHalfOpened,
        DisplayFeatureState.postureFlat,
      ]) {
        testWidgets('${handedness.name}·${state.name}', (tester) async {
          await _pump(
            tester,
            size: const Size(841, 673),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            handedness: handedness,
            displayFeatures: [
              _foldAt(const Rect.fromLTWH(0, 336.5, 841, 0), state: state),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
          final lcd = tester.getRect(_lcd);
          final keypad = tester.getRect(_keypad);
          final history = tester.getRect(_history);
          expect(
            keypad,
            rectMoreOrLessEquals(
              const Rect.fromLTRB(8, 374, 833, 641),
              epsilon: 0.1,
            ),
          );
          expect(
            tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement,
            KeypadArrangement.wide,
          );
          expect(_numbersOnLeft(tester), !handedness.keypadOnRight);
          const block = 825 / 2.06;
          expect(
            lcd.size,
            sizeMoreOrLessEquals(const Size(block, block / 1.75)),
          );
          expect(lcd.bottom, moreOrLessEquals(336.5 - 8));
          expect(history.size, sizeMoreOrLessEquals(const Size(block, 296.5)));
          expect(history.top, moreOrLessEquals(32));
          if (handedness.keypadOnRight) {
            expect(lcd.right, moreOrLessEquals(833));
            expect(history.left, moreOrLessEquals(8));
          } else {
            expect(lcd.left, moreOrLessEquals(8));
            expect(history.right, moreOrLessEquals(833));
          }
          expect(
            KeypadMetrics.minKeyTouchHeightOf(
              keypad.size,
              KeypadArrangement.wide,
            ),
            moreOrLessEquals(45.4, epsilon: 0.05),
          );
        });
      }
    }
  });

  testWidgets(
    '12.9인치 iPad를 돌려도 LCD 줄 글자 크기는 크게 바뀌지 않는다 (#71 — #141 뒤로는 LCD 폭이 회전마다 바뀐다)',
    (tester) async {
      // #141 전에는 위아래·좌우 모두 LCD가 480dp라 크기가 같았다. 폭 상한을 푼 뒤로 세로는 1008×273.5, 가로는 가로형의
      // 활성 LCD 655×273.5다(둘 다 줄 글자 상한 높이, #189). 줄 글자는 둘 다 상한 40dp라 회전해도 그대로다(#189 전 세로 54.1·
      // 가로 54.7dp — 10% 안에서 움직였다).
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

  group('가로 접힘선 배치의 손잡이 (#80, #143)', () {
    // Fold 가로 — 넓은 배열이 아래 패널 폭을 다 쓴다.
    const foldSize = Size(841, 673);
    const foldInset = EdgeInsets.only(top: 24, bottom: 24);
    final foldHalfOpened = _halfOpenedAt(const Rect.fromLTWH(0, 336.5, 841, 0));

    for (final (name, size, hingeY, numbersMove) in [
      // 넓은 배열: 키패드 자리는 그대로이고 숫자부(와 활성 LCD)가 손 쪽으로 옮겨 간다
      ('Fold 가로(넓은 배열)', foldSize, 336.5, true),
      ('반 접힌 폭 1200(넓은 배열)', const Size(1200, 800), 424.0, true),
      // 실물 배열: 키패드가 아래 패널 폭 전체라 손잡이로 아무것도 옮겨 가지 않는다
      ('세로로 긴 대화면 716×1200(실물 배열)', const Size(716, 1200), 600.0, false),
      ('Flip 내부 411×1006(실물 배열)', const Size(411, 1006), 503.0, false),
    ]) {
      testWidgets('$name: 손잡이로 옮겨 가는 것이 없으면 대화상자에 그 안내를 보인다 (#80 R1)', (
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
        final lcdBefore = tester.getRect(_lcd);
        final numbersBefore = _numbersOnLeft(tester);
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        expect(
          find.byKey(HandednessDialog.noteKey),
          numbersMove ? findsNothing : findsOneWidget,
        );
        // 안내대로인지: 손잡이를 바꿨을 때 키패드 자리는 그대로이고, 넓은 배열만 숫자부·활성 LCD가 옮겨 간다
        await tester.tap(_option(Handedness.left));
        await tester.pumpAndSettle();
        expect(tester.getRect(_keypad), before);
        expect(
          _numbersOnLeft(tester),
          numbersMove ? !numbersBefore : numbersBefore,
        );
        expect(tester.getRect(_lcd) == lcdBefore, !numbersMove);
      });
    }

    testWidgets('실물 배열(Flip 내부)은 손잡이를 바꿔도 키패드를 다시 빌드하지 않는다', (tester) async {
      final (container, _) = await _pump(
        tester,
        size: const Size(411, 1006),
        padding: foldInset,
        displayFeatures: [_halfOpenedAt(const Rect.fromLTWH(0, 503, 411, 0))],
      );
      expect(
        tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement,
        KeypadArrangement.standard,
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

    testWidgets(
      '펴기 ↔ 반 접기는 배치를 바꾸지 않고, 커버 화면(실물 배열)으로 바뀌어도 키 상태가 유지된다 (#143)',
      (tester) async {
        final (container, _) = await _pump(
          tester,
          size: foldSize,
          padding: foldInset,
          displayFeatures: [foldHalfOpened],
        );
        KeypadArrangement arrangementNow() =>
            tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement;
        expect(arrangementNow(), KeypadArrangement.wide);
        final rects = [
          tester.getRect(_lcd),
          tester.getRect(_keypad),
          tester.getRect(_history),
        ];
        Finder button(CalcKeyId id) => find.byWidgetPredicate(
          (w) => w is CalcKeyButton && w.keyDef.id == id,
        );
        final states = {
          for (final id in [CalcKeyId.shift, CalcKeyId.num7, CalcKeyId.equals])
            id: tester.state(button(id)),
        };
        // 7을 누른 채로 편다(살짝 꺾은 각도도 펼침으로 들어온다) → 같은 배치
        final gesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.num7)),
          ),
        );
        await tester.pump();
        await _pump(
          tester,
          size: foldSize,
          padding: foldInset,
          displayFeatures: [_foldAt(const Rect.fromLTWH(0, 336.5, 841, 0))],
          container: container,
        );
        expect([
          tester.getRect(_lcd),
          tester.getRect(_keypad),
          tester.getRect(_history),
        ], rects);
        // 접어 커버 화면으로 → 위아래 배치(실물 배열). 키 element·State가 그대로라 누른 채인 키가 이어진다.
        await _pump(
          tester,
          size: const Size(344, 882),
          padding: foldInset,
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
      },
    );
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
        : cell.height - b.legendBandHeightFor(cell.height);
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
  final pad = CursorPadGeometry(padRect.size);
  final bounds = cursorPadTouchCell(tester)
      .shift(-padRect.topLeft); // 패드 로컬 좌표의 셀
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
  group('접힘선 기준 좌우 배치 (세로 접힘선, 책 자세 — #143)', () {
    final devices = <_Foldable>[
      // Galaxy Z Fold 내부 화면 (세로가 기본 방향)
      (
        'Fold 내부',
        const Size(673, 841),
        const EdgeInsets.only(top: 32, bottom: 24),
        _foldAt(const Rect.fromLTWH(336.5, 0, 0, 841)),
      ),
      // Pixel Fold 내부 화면 (가로가 기본 방향, 인셋은 API 36 에뮬레이터 실측 — #118)
      (
        'Pixel Fold 내부',
        const Size(841, 701),
        const EdgeInsets.only(top: 28.2, bottom: 32),
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
      // 반 접은 책 자세 — 펼친 상태와 같은 배치다
      (
        'Fold 내부·반 접힘',
        const Size(673, 841),
        const EdgeInsets.only(top: 32, bottom: 24),
        _halfOpenedAt(const Rect.fromLTWH(336.5, 0, 0, 841)),
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
              expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);

              final hinge = fold.bounds;
              final lcd = tester.getRect(_lcd);
              final keypad = tester.getRect(_keypad);
              final history = tester.getRect(_history);
              final settings = tester.getRect(_settings);

              // 어느 것도 접힘선(과 양쪽 간격)에 걸치지 않는다.
              for (final r in [lcd, keypad, history]) {
                expect(
                  _clearOfHinge(r, hinge, vertical: true),
                  isTrue,
                  reason: '$r',
                );
              }
              // 손 쪽 패널: 주로 쓰는 손 쪽 접힘선 바깥 ~ 본체 가장자리. 반대쪽 패널은 기록 영역 전체다.
              final right =
                  size.width - padding.right - CalcTheme.screenPadding;
              final left = padding.left + CalcTheme.screenPadding;
              final top = padding.top + CalcTheme.screenPadding;
              final bottom =
                  size.height - padding.bottom - CalcTheme.screenPadding;
              const m = CalcTheme.screenHingeMargin;
              final hand = handedness.keypadOnRight
                  ? Rect.fromLTRB(hinge.right + m, top, right, bottom)
                  : Rect.fromLTRB(left, top, hinge.left - m, bottom);
              final other = handedness.keypadOnRight
                  ? Rect.fromLTRB(left, top, hinge.left - m, bottom)
                  : Rect.fromLTRB(hinge.right + m, top, right, bottom);
              expect(history, rectMoreOrLessEquals(other));
              // 손 쪽 패널은 그 패널 크기의 세로형 (#141): LCD·키패드 모두 패널 폭, LCD 바로 아래 키패드
              final portrait = CalcScreenLayout.of(hand.size);
              expect(
                lcd,
                rectMoreOrLessEquals(
                  Rect.fromLTWH(
                    hand.left,
                    hand.top + portrait.top,
                    hand.width,
                    portrait.lcdHeight,
                  ),
                ),
              );
              expect(
                keypad,
                rectMoreOrLessEquals(
                  Rect.fromLTRB(
                    hand.left,
                    lcd.bottom + portrait.gap,
                    hand.right,
                    hand.bottom,
                  ),
                ),
              );
              // 설정 키(ON)는 손 쪽 패널 키패드 안에서 눌린다 (#190).
              expect(
                keypad.inflate(0.01).contains(settings.topLeft) &&
                    keypad.inflate(0.01).contains(settings.bottomRight),
                isTrue,
              );
              expect(_settings.hitTestable(), findsOneWidget);
              // 패널 폭 키패드도 터치 하한을 지킨다 (글자 배율과 무관한 치수라 배율 1.0에서만 본다).
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

    testWidgets('Fold 내부 세로의 손 쪽 패널은 커버 화면 폭의 폰과 같은 세로형이다 (#143 고정값)', (
      tester,
    ) async {
      // 본체 657×801, 접힘선 x=336.5(본체 328.5): 손 쪽 패널 320.5×769. 키패드는 폭에 묶여 320.5×427.3(키 셀 36.3dp),
      // LCD는 남는 높이를 줄 글자 상한 높이(273.5)까지 받고 그 위 약 60dp가 빈다(세로형과 같다).
      await _pump(
        tester,
        size: const Size(673, 841),
        padding: const EdgeInsets.only(top: 32, bottom: 24),
        displayFeatures: [_foldAt(const Rect.fromLTWH(336.5, 0, 0, 841))],
      );
      final keypad = tester.getRect(_keypad);
      expect(
        keypad.size,
        sizeMoreOrLessEquals(const Size(320.5, 320.5 / 0.75)),
      );
      expect(
        KeypadMetrics.minKeyCellHeightOf(
          keypad.size,
          KeypadArrangement.standard,
        ),
        moreOrLessEquals(36.3, epsilon: 0.05),
      );
      expect(
        tester.getRect(_lcd).height,
        moreOrLessEquals(LcdFontSizes.heightAtMaxLineFont),
      );
      expect(
        tester.getRect(_history),
        rectMoreOrLessEquals(const Rect.fromLTRB(8, 40, 328.5, 809)),
      );
    });
  });

  group('접힘선 기준 위아래 배치 (가로 접힘선 — #143, 펼침·반 접힘 모두)', () {
    final devices = <(String, Size, EdgeInsets, double, KeypadArrangement)>[
      // Galaxy Z Fold 내부 화면을 가로로 돌림
      (
        'Fold 내부 가로',
        const Size(841, 673),
        const EdgeInsets.only(top: 24, bottom: 24),
        336.5,
        KeypadArrangement.wide,
      ),
      // Pixel Fold 내부 화면을 세로로 돌림
      (
        'Pixel Fold 내부 세로',
        const Size(701, 841),
        const EdgeInsets.only(top: 32, bottom: 24),
        420.5,
        KeypadArrangement.wide,
      ),
      // Galaxy Z Flip 내부 화면 (펼침, Flex 모드)
      (
        'Flip 내부',
        const Size(411, 1006),
        const EdgeInsets.only(top: 32, bottom: 24),
        503,
        KeypadArrangement.standard,
      ),
      // "화면 크기"를 키운 Fold 가로 (#139 — 절반 269.5dp, #143 전에는 사전 판정에서 떨어졌다)
      (
        'Fold 내부 가로·화면 크기 확대',
        const Size(673, 539),
        const EdgeInsets.only(top: 24, bottom: 24),
        269.5,
        KeypadArrangement.wide,
      ),
    ];

    for (final (name, size, padding, hingeY, expected) in devices) {
      for (final state in const [
        DisplayFeatureState.postureFlat,
        DisplayFeatureState.postureHalfOpened,
      ]) {
        for (final handedness in Handedness.values) {
          for (final scale in [1.0, 2.0]) {
            testWidgets(
              '$name ${size.width}×${size.height}·${state.name}·${handedness.name}·배율 $scale',
              (tester) async {
                final fold = _foldAt(
                  Rect.fromLTWH(0, hingeY, size.width, 0),
                  state: state,
                );
                await _pump(
                  tester,
                  size: size,
                  padding: padding,
                  textScale: scale,
                  handedness: handedness,
                  displayFeatures: [fold],
                );
                expect(tester.takeException(), isNull);
                expect(
                  find.byType(CalcKeyButton),
                  findsNWidgets(totalKeyCount),
                );
                expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);

                final hinge = fold.bounds;
                final lcd = tester.getRect(_lcd);
                final keypad = tester.getRect(_keypad);
                final history = _history.evaluate().isEmpty
                    ? null
                    : tester.getRect(_history);
                final settings = tester.getRect(_settings);
                for (final r in [lcd, keypad, ?history]) {
                  expect(
                    _clearOfHinge(r, hinge, vertical: false),
                    isTrue,
                    reason: '$r',
                  );
                }
                final right =
                    size.width - padding.right - CalcTheme.screenPadding;
                final left = padding.left + CalcTheme.screenPadding;
                final top = padding.top + CalcTheme.screenPadding;
                final bottom =
                    size.height - padding.bottom - CalcTheme.screenPadding;
                const m = CalcTheme.screenHingeMargin;
                // 키패드: 아래 패널 폭 전체(#143 — 폭 상한 없음), 본체 아래, 키가 큰 배열
                final arrangement = tester
                    .widget<CalcKeypad>(find.byType(CalcKeypad))
                    .arrangement;
                expect(arrangement, expected);
                expect(
                  arrangement,
                  KeypadMetrics.preferredArrangementFor(
                    Size(right - left, bottom - (hinge.bottom + m)),
                  ),
                );
                expect(keypad.left, moreOrLessEquals(left));
                expect(keypad.right, moreOrLessEquals(right));
                expect(keypad.bottom, moreOrLessEquals(bottom));
                expect(
                  keypad.top,
                  greaterThanOrEqualTo(hinge.bottom + m - 0.01),
                );
                if (arrangement == KeypadArrangement.wide) {
                  // 위 패널 = 기록(함수부 위) | 활성 LCD(숫자부 위, 접힘선 쪽) — 숫자부는 주로 쓰는 손 쪽
                  expect(_numbersOnLeft(tester), !handedness.keypadOnRight);
                  expect(lcd.bottom, moreOrLessEquals(hinge.top - m));
                  if (handedness.keypadOnRight) {
                    expect(lcd.right, moreOrLessEquals(right));
                  } else {
                    expect(lcd.left, moreOrLessEquals(left));
                  }
                  if (history != null) {
                    expect(history.top, moreOrLessEquals(top));
                    expect(history.bottom, moreOrLessEquals(hinge.top - m));
                    expect(
                      handedness.keypadOnRight ? history.left : history.right,
                      moreOrLessEquals(handedness.keypadOnRight ? left : right),
                    );
                  }
                } else {
                  // 위 패널 맨 위가 활성 LCD(패널 폭 전체), 그 아래가 기록(최근 것부터) — 손잡이와 무관하다
                  expect(_numbersOnLeft(tester), isFalse);
                  expect(lcd.top, moreOrLessEquals(top));
                  expect(lcd.left, moreOrLessEquals(left));
                  expect(lcd.right, moreOrLessEquals(right));
                  expect(history, isNotNull);
                  expect(
                    history,
                    rectMoreOrLessEquals(
                      Rect.fromLTRB(
                        left,
                        lcd.bottom + CalcTheme.screenLcdHistoryGap,
                        right,
                        hinge.top - m,
                      ),
                    ),
                  );
                }
                // 설정 키(ON)는 아래 패널 키패드 안에서 눌린다 (#190).
                expect(
                  keypad.inflate(0.01).contains(settings.topLeft) &&
                      keypad.inflate(0.01).contains(settings.bottomRight),
                  isTrue,
                );
                expect(_settings.hitTestable(), findsOneWidget);
                if (scale == 1.0) _expectTouchTargets(tester);
              },
            );
          }
        }
      }

      testWidgets('$name: 펼침과 반 접힘은 같은 배치다 (#143)', (tester) async {
        List<Rect> rects() {
          return [
            tester.getRect(_lcd),
            tester.getRect(_keypad),
            if (_history.evaluate().isNotEmpty) tester.getRect(_history),
          ];
        }

        final (container, _) = await _pump(
          tester,
          size: size,
          padding: padding,
          displayFeatures: [_foldAt(Rect.fromLTWH(0, hingeY, size.width, 0))],
        );
        final flat = rects();
        await _pump(
          tester,
          size: size,
          padding: padding,
          displayFeatures: [
            _halfOpenedAt(Rect.fromLTWH(0, hingeY, size.width, 0)),
          ],
          container: container,
        );
        expect(rects(), flat);
      });
    }

    for (final (name, padding, touch) in const [
      ('제스처 내비게이션(아래 24)', EdgeInsets.only(top: 32, bottom: 24), 39.4),
      ('3버튼 내비게이션(아래 48)', EdgeInsets.only(top: 32, bottom: 48), 37.3),
    ]) {
      testWidgets('완전히 펼친 Flip 내부의 키 높이 (#143 측정, $name)', (tester) async {
        // 위아래 배치(#143 전 펼친 Flip)는 키패드가 폭에 묶여 395×526.7, 키 44.8dp(3버튼도 같다)였다 —
        // 접힘선 아래 패널(395×463, 3버튼 439)로 높이에 묶여 약 12% 낮아진다(일반 바형 폰과 비슷하다).
        await _pump(
          tester,
          size: const Size(411, 1006),
          padding: padding,
          displayFeatures: [_foldAt(const Rect.fromLTWH(0, 503, 411, 0))],
        );
        expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
        expect(
          KeypadMetrics.minKeyTouchHeightOf(
            tester.getSize(_keypad),
            KeypadArrangement.standard,
          ),
          moreOrLessEquals(touch, epsilon: 0.05),
        );
        expect(tester.getSize(_keypad).width, moreOrLessEquals(395));
        // 위 패널: 활성 LCD 395×225.7(폭 / 1.75), 그 아래 기록 영역 약 221dp
        expect(
          tester.getSize(_lcd),
          sizeMoreOrLessEquals(const Size(395, 395 / 1.75)),
        );
        expect(
          tester.getSize(_history).height,
          moreOrLessEquals(503 - 8 - 40 - 395 / 1.75 - 8),
        );
      });
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

    // 가로로 돌림 → 가로 접힘선
    await _pump(
      tester,
      size: const Size(841, 673),
      displayFeatures: [_foldAt(const Rect.fromLTWH(0, 336.5, 841, 0))],
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

  testWidgets(
    '접힘 정보가 늦게 오는 폴더블(#70): 오기 전 위아래 배치였다가 오면 가로 접힘선 배치가 되고 상태가 유지된다 (#143)',
    (tester) async {
      // 펼친 Flip 내부: #143 전에는 펼친 가로 접힘선을 나누지 않아 접힘 정보 전후가 같은 위아래 배치였다. 이제는 접힘 정보가
      // 오면 접힘선 기준 배치로 바뀐다 — 앱 시작 때는 `main()`이 접힘 정보를 기다려(#158) 이 바뀜이 보이지 않고, 펼친 직후 몇
      // 프레임에만 보일 수 있다. 바뀌어도 LCD·키패드 element와 키 상태는 그대로다.
      final foldable = ValueNotifier(true);
      addTearDown(foldable.dispose);
      tester.view.physicalSize =
          const Size(411, 1006) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          foldableDeviceProvider.overrideWithValue(foldable),
        ],
      );
      addTearDown(container.dispose);
      Widget screen(List<DisplayFeature> features) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(411, 1006),
              padding: const EdgeInsets.only(top: 32, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 32, bottom: 24),
              displayFeatures: features,
            ),
            child: const CalculatorScreen(),
          ),
        ),
      );
      await tester.pumpWidget(screen(const []));
      expect(isStackedArrangement(tester), isTrue);
      await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.shift)));
      await tester.pump();
      final keypadElement = tester.element(find.byType(CalcKeypad));
      final lcdElement = tester.element(_lcd);
      await tester.pumpWidget(
        screen([_foldAt(const Rect.fromLTWH(0, 503, 411, 0))]),
      );
      expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
      expect(container.read(calcProvider).modifier, KeyModifier.shift);
      expect(
        identical(tester.element(find.byType(CalcKeypad)), keypadElement),
        isTrue,
      );
      expect(identical(tester.element(_lcd), lcdElement), isTrue);
    },
  );

  group('접힘선 기준 배치를 쓸 수 없는 창 (#25 R2, #143)', () {
    testWidgets(
      '세로 접힘선: 손 쪽 패널의 키가 쓸 수 있는 크기보다 작으면 위아래 배치로 두고, 반대 손잡이는 책 자세다',
      (tester) async {
        // 접힘선 오른쪽 140dp(창 좌표로는 사전 판정 통과) + 오른쪽 인셋 48 → 오른손잡이 손 쪽 패널이 76dp
        for (final (handedness, expected) in const [
          (Handedness.right, DrawnArrangement.stacked),
          (Handedness.left, DrawnArrangement.sideBySide),
        ]) {
          await _pump(
            tester,
            size: const Size(841, 701),
            padding: const EdgeInsets.only(top: 24, right: 48, bottom: 24),
            handedness: handedness,
            displayFeatures: [_foldAt(const Rect.fromLTWH(701, 0, 0, 701))],
          );
          expect(tester.takeException(), isNull);
          expect(drawnArrangementOf(tester), expected, reason: handedness.name);
          _expectTouchTargets(tester);
        }
      },
    );

    testWidgets('가로 접힘선: 아래 패널의 키가 쓸 수 있는 크기보다 작으면 접힘선 기준 배치를 쓰지 않는다', (
      tester,
    ) async {
      // 아래쪽 352dp(창 좌표로는 사전 판정 통과) + 아래 인셋 260 → 접힘선 간격·화면 여백까지 빼면 키패드 자리 높이 76dp.
      // 넓은 배열(#80)로도 키가 약 12.9dp로 쓸 수 있는 크기(16dp)보다 작다.
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

    testWidgets('가로 접힘선: 위 패널이 활성 LCD 최소 높이보다 낮으면 접힘선 기준 배치를 쓰지 않는다 (#143)', (
      tester,
    ) async {
      // 접힘선 y=150(창 좌표로는 사전 판정 128 통과) + 위 인셋 24 → 위 패널 150 − 32 − 8 = 110 < LCD 최소 높이 112
      await _pump(
        tester,
        size: const Size(841, 673),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        displayFeatures: [_foldAt(const Rect.fromLTWH(0, 150, 841, 0))],
      );
      expect(tester.takeException(), isNull);
      expect(isStackedArrangement(tester), isTrue);
      // 1dp 더 내려 위 패널이 최소 높이를 넘으면 접힘선 기준 배치다.
      await _pump(
        tester,
        size: const Size(841, 673),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        displayFeatures: [_foldAt(const Rect.fromLTWH(0, 152, 841, 0))],
      );
      expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
    });

    testWidgets(
      '아래쪽 281dp·아래 인셋 48의 비대칭 가로 접힘선은 넓은 키패드 배열로 접힘선 기준 배치를 쓴다 (#80)',
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
        _expectTouchTargets(tester, floor: CalcTheme.keyTouchHeightUsableMin);
      },
    );

    for (final state in const [
      DisplayFeatureState.postureHalfOpened,
      DisplayFeatureState.postureFlat,
    ]) {
      testWidgets(
        'Fold에 앱을 나란히 띄운 분할 창(${state.name})은 일반 하한 미만이어도 접힘선 기준 배치를 쓴다 (#80 R1, #143)',
        (tester) async {
          // 창 420×673(접힘선 y=336.5): 실물 배열 약 25.2dp로 일반 하한(28dp) 미만이고 위아래 배치(약 32.7dp)가 더 크지만,
          // 접힘선을 넘지 않도록 쓸 수 있는 크기(16dp) 이상이면 접힘선 기준 배치를 쓴다(#25·#80 R1 사용자 결정 — #143부터
          // 각도와 무관하게, 펼친 창도 같다).
          await _pump(
            tester,
            size: const Size(420, 673),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            displayFeatures: [
              _foldAt(const Rect.fromLTWH(0, 336.5, 420, 0), state: state),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
          expect(tester.getRect(_keypad).top, greaterThanOrEqualTo(336.5));
          expect(tester.getRect(_lcd).bottom, lessThanOrEqualTo(336.5));
          _expectTouchTargets(tester, floor: CalcTheme.keyTouchHeightUsableMin);
          final touch = KeypadMetrics.minKeyTouchHeightOf(
            tester.getSize(_keypad),
            tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement,
          );
          expect(touch, lessThan(CalcTheme.keyTouchHeightFloor));
          // 위 패널(296.5)이 활성 LCD(404 / 1.75 = 230.9)와 기록 최소 높이를 함께 담지 못해 기록 없이 LCD가 상한 높이까지 쓴다.
          expect(_history, findsNothing);
          expect(
            tester.getSize(_lcd).height,
            moreOrLessEquals(LcdFontSizes.heightAtMaxLineFont),
          );
        },
      );
    }

    testWidgets('Fold 가로·3버튼 내비게이션(아래 인셋 48)도 접힘선 기준 배치를 유지한다', (tester) async {
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

    // 펼친 폭 0 가로 접힘선도 앱이 나누므로(#143) 대화상자도 설정 키(ON)가 있는 아래 절반에 가둔다 — Flutter는 펼친 폭 0
    // 접힘선을 나누지 않으므로 앱이 한 번 더 나눈다(`SettingsLauncher`). Fold 가로는 두 절반 모두 대화상자 최소 높이(328)에
    // 못 미쳐 설정 키 쪽 절반 그대로다(반 접힘과 같다).
    for (final (name, size, hingeY, textScale) in [
      ('Flip 내부', const Size(411, 1006), 503.0, 1.0),
      ('Fold 가로', const Size(841, 673), 336.5, 1.0),
      // 아래 절반 312.5dp(인셋 제외) — 카드 높이 약 264dp에서 큰 글자 배율에도 넘치지 않는다
      ('Fold 가로·글자 배율 2.0', const Size(841, 673), 336.5, 2.0),
    ]) {
      testWidgets('펼친 폭 0 가로 접힘선($name): 앱처럼 나눠 대화상자가 아래 절반에 뜬다 (#143)', (
        tester,
      ) async {
        const padding = EdgeInsets.only(top: 24, bottom: 24);
        _setViewPadding(tester, padding);
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(
          tester,
          size: size,
          padding: padding,
          textScale: textScale,
          displayFeatures: [_foldAt(Rect.fromLTWH(0, hingeY, size.width, 0))],
        );
        expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final dialog = tester.getRect(_dialogSurface);
        expect(
          dialog.top,
          greaterThanOrEqualTo(hingeY - 0.01),
          reason: '$dialog',
        );
        expect(dialog.bottom, lessThanOrEqualTo(size.height - 24 + 0.01));
        // 고정된 닫기 버튼이 보이고 눌린다(제목·선택지는 스크롤된다)
        expect(find.byKey(HandednessDialog.closeKey).hitTestable(), findsOne);
        await tester.tap(find.byKey(HandednessDialog.closeKey));
        await tester.pumpAndSettle();
        expect(find.byType(HandednessDialog), findsNothing);
      });
    }

    testWidgets(
      '손 쪽 패널이 짧은 책 자세(640×360): 기록은 반대쪽 패널의 LCD 아래, 대화상자는 키패드 쪽 절반이고 손잡이를 바꾸면 LCD가 접힘선을 건너 옮겨 간다 (#143 R1)',
      (tester) async {
        const size = Size(640, 360);
        const padding = EdgeInsets.only(top: 24);
        _setViewPadding(tester, padding);
        final (container, _) = await _pump(
          tester,
          size: size,
          padding: padding,
          displayFeatures: [_foldAt(const Rect.fromLTWH(320, 0, 0, 360))],
        );
        expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
        // 오른손잡이: 키패드는 오른쪽 패널, LCD는 왼쪽 패널 맨 위(8~312 × 32~205.7), 그 아래 기록(213.7~352)
        final lcd = tester.getRect(_lcd);
        expect(
          lcd,
          rectMoreOrLessEquals(const Rect.fromLTWH(8, 32, 304, 304 / 1.75)),
        );
        expect(
          tester.getRect(_history),
          rectMoreOrLessEquals(
            const Rect.fromLTRB(8, 32 + 304 / 1.75 + 8, 312, 352),
          ),
        );
        expect(tester.getRect(_keypad).left, greaterThanOrEqualTo(328 - 0.01));
        final lcdElement = tester.element(_lcd);
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // 손잡이가 적용되는 배치라 안내 글이 없고, 대화상자는 설정 키 쪽(오른쪽) 절반에 있다.
        expect(find.byKey(HandednessDialog.noteKey), findsNothing);
        final dialog = tester.getRect(_dialogSurface);
        expect(
          dialog.left,
          greaterThanOrEqualTo(320 - 0.01),
          reason: '$dialog',
        );
        await tester.ensureVisible(_option(Handedness.left));
        await tester.pumpAndSettle();
        await tester.tap(_option(Handedness.left));
        await tester.pumpAndSettle();
        expect(container.read(handednessProvider), Handedness.left);
        // 왼손잡이: LCD는 오른쪽 패널로 옮겨 가고(같은 element), 대화상자는 연 자리에 남는다(#94).
        expect(tester.getRect(_lcd).left, greaterThanOrEqualTo(328 - 0.01));
        expect(identical(tester.element(_lcd), lcdElement), isTrue);
        expect(tester.getRect(_dialogSurface), dialog);
      },
    );

    testWidgets(
      '손 쪽 패널이 짧은 책 자세에서 반대쪽 패널이 LCD와 기록을 함께 담지 못하면 기록 없이 LCD만 둔다 (#143 R1)',
      (tester) async {
        // 841×340(상태바 24): 반대쪽 패널 404.5×300 — LCD 404.5 / 1.75 = 231.1 + 8 + 기록 최소 112 > 300
        await _pump(
          tester,
          size: const Size(841, 340),
          padding: const EdgeInsets.only(top: 24),
          displayFeatures: [_foldAt(const Rect.fromLTWH(420.5, 0, 0, 340))],
        );
        expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
        expect(_history, findsNothing);
        expect(
          tester.getSize(_lcd),
          sizeMoreOrLessEquals(Size(404.5, LcdFontSizes.heightAtMaxLineFont)),
        );
      },
    );

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
            tester.getRect(_history).overlaps(opened),
            isTrue,
            reason: '옮겨 온 기록 영역이 대화상자 쪽 절반에 있다 (책 자세, #143)',
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

    // 손잡이에 따라 배치가 갈리는 비대칭 세로 접힘선. 손 쪽 패널의 키가 쓸 수 있는 크기(16dp, 패널 폭 약 141dp)보다
    // 작아지는 손잡이는 위아래 배치, 반대 손잡이는 접힘선 기준 배치(설정 키는 키패드 쪽 = 넓은 절반)다(#143).
    // `_splitLikeApp`은 대화상자 경로(View)의 MediaQuery 인셋으로 절반을 재므로 View에도 같은 인셋을 넣는다
    // (넣지 않으면 실제 앱과 다른 절반을 잰다 — [_setViewPadding]).

    testWidgets(
      '비대칭 접힘선(펼친 폭 0): 한쪽 손잡이로는 위아래 배치라 대화상자는 배치가 바뀌어도 화면 전체에 그대로 뜬다 (#41·#129)',
      (tester) async {
        // x=654, 오른쪽 인셋 48 → 오른쪽 손 쪽 패널 123dp(키 13.9dp). 오른손잡이는 위아래 배치, 왼손잡이는 접힘선 기준 배치.
        const padding = EdgeInsets.only(top: 24, right: 48, bottom: 24);
        _setViewPadding(tester, padding);
        final (container, _) = await _pump(
          tester,
          size: const Size(841, 701),
          padding: padding,
          displayFeatures: [_foldAt(const Rect.fromLTWH(654, 0, 0, 701))],
        );
        expect(isStackedArrangement(tester), isTrue);
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        final opened = tester.getRect(_dialogSurface);
        expect(opened.left, lessThan(654)); // 좁은 절반에 갇히지 않았다
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
      // x=187, 왼쪽 인셋 48 → 왼쪽 손 쪽 패널 123dp(키 13.9dp). 왼손잡이는 위아래 배치(설정 키는 키패드 오른쪽 위),
      // 오른손잡이는 접힘선 기준 배치(키패드·설정 키는 오른쪽 넓은 절반).
      const hingeX = 187.0;
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

    // 반 접은 가로 접힘선: 설정 키는 키패드와 함께 늘 아래 절반이다. 키패드는 아래 패널 폭 전체라(#143) 실물 배열은
    // 손잡이를 바꿔도 그대로이고, 넓은 배열은 함수부(설정 키 포함)·숫자부가 좌우로 맞바뀌어 같은 절반 안에서만 옮겨 간다.
    for (final (name, size, hingeY, keypadMoves) in [
      ('넓은 배열 Fold 가로', const Size(841, 673), 336.5, true),
      ('실물 배열 716×1200', const Size(716, 1200), 600.0, false),
      ('실물 배열 412×915', const Size(412, 915), 457.5, false),
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

    test('대화상자 하한 폭 이상인 세로 접힘선 절반에는 키패드가 폭으로 늘 들어간다 — 비대칭 배치의 위아래 배치 쪽 절반은 하한보다 좁다', () {
      // 인셋을 뺀 절반 폭이 대화상자 하한(dialogMinHalfExtent)일 때 손 쪽 패널 (화면 가장자리·접힘선 여백 제외).
      // 이 폭에서 키가 쓸 수 있는 크기 이상이면, 손잡이에 따라 배치가 갈리는(한쪽 절반에 키패드가 못 들어가는) 화면의
      // 좁은 절반은 늘 하한보다 좁다 — `SettingsLauncher` "접힘선이 있을 때 대화상자 위치"의 전제.
      const region =
          SettingsLauncher.dialogMinHalfExtent -
          CalcTheme.screenPadding -
          CalcTheme.screenHingeMargin;
      expect(
        KeypadMetrics.minKeyTouchHeightOf(
          const Size(region, double.infinity),
          KeypadArrangement.standard,
        ),
        greaterThanOrEqualTo(CalcTheme.keyTouchHeightUsableMin),
      );
    });

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

  group('대화상자를 연 채 화면 기하가 바뀌면 지금 설정 키 쪽 절반으로 옮겨 간다 (#218)', () {
    // 회전: 세로 접힘선(책 자세, 설정 키는 손 쪽 절반)을 돌리면 접힘선이 가로로 눕는다(테이블톱, 설정 키는 아래 절반).
    // 반 접힘·물리 힌지는 Flutter도 나누는 접힘선이라 경로의 기준점이 다시 잰 설정 키를 따라가야 옮겨 가고, 펼친 폭 0
    // 접힘선은 앱만 나누는 절반(`_splitLikeApp`)이 따라간다([SettingsLauncher] "대화상자가 열린 동안 배치가 바뀌면").
    const padding = EdgeInsets.only(top: 32, bottom: 24);

    /// [size] 화면을 가운데에서 나누는 접힘선 (세로 화면이면 세로 접힘선, 가로 화면이면 가로 접힘선)
    DisplayFeature centerFold(
      Size size, {
      double width = 0,
      DisplayFeatureType type = DisplayFeatureType.fold,
      DisplayFeatureState state = DisplayFeatureState.postureHalfOpened,
    }) => _foldAt(
      size.width < size.height
          ? Rect.fromLTWH((size.width - width) / 2, 0, width, size.height)
          : Rect.fromLTWH(0, (size.height - width) / 2, size.width, width),
      type: type,
      state: state,
    );

    /// [r]이 [hinge]를 기준으로 [point]와 같은 쪽 절반 안에 있는지
    bool sameHalf(Rect hinge, Offset point, Rect r) {
      const e = 0.01;
      if (hinge.height > hinge.width) {
        return point.dx > hinge.center.dx
            ? r.left >= hinge.right - e
            : r.right <= hinge.left + e;
      }
      return point.dy > hinge.center.dy
          ? r.top >= hinge.bottom - e
          : r.bottom <= hinge.top + e;
    }

    for (final (name, portrait, featureOf)
        in <(String, Size, DisplayFeature Function(Size))>[
          ('반 접은 Fold 내부', const Size(673, 841), centerFold),
          (
            '펼친 Fold 내부(앱만 나눈다)',
            const Size(673, 841),
            (s) => centerFold(s, state: DisplayFeatureState.postureFlat),
          ),
          (
            '폭 28dp 물리 힌지',
            const Size(720, 1128),
            (s) => centerFold(
              s,
              width: 28,
              type: DisplayFeatureType.hinge,
              state: DisplayFeatureState.postureFlat,
            ),
          ),
        ]) {
      final landscape = portrait.flipped;
      for (final start in [portrait, landscape]) {
        for (final h in Handedness.values) {
          final end = start == portrait ? landscape : portrait;
          testWidgets(
            '$name ${start.width}×${start.height}에서 연 채 회전·${h.name}: 돌린 뒤와 되돌린 뒤 모두 설정 키 쪽 절반이다',
            (tester) async {
              _setViewPadding(tester, padding);
              final (container, _) = await _pump(
                tester,
                size: start,
                padding: padding,
                handedness: h,
                displayFeatures: [featureOf(start)],
              );
              final openedKey = tester.getRect(_settings).center;
              await tester.tap(_settings);
              await tester.pumpAndSettle();
              final element = tester.element(find.byType(HandednessDialog));
              expect(
                sameHalf(
                  featureOf(start).bounds,
                  openedKey,
                  tester.getRect(_dialogSurface),
                ),
                isTrue,
              );

              for (final size in [end, start]) {
                await _pump(
                  tester,
                  size: size,
                  padding: padding,
                  displayFeatures: [featureOf(size)],
                  container: container,
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                final key = tester.getRect(_settings).center;
                final dialog = tester.getRect(_dialogSurface);
                expect(
                  sameHalf(featureOf(size).bounds, key, dialog),
                  isTrue,
                  reason: '$size $key $dialog',
                );
                expect(
                  tester.element(find.byType(HandednessDialog)),
                  same(element),
                );
                if (size == end) {
                  // 이 조합이 #218을 가려내는지: 연 시점의 설정 키 중심(화면 안으로 잘라 낸 값 — #218 전의 고정
                  // `anchorPoint`)이 돌린 뒤에는 지금 설정 키와 반대쪽 절반인지. 가로(테이블톱)에서 시작한 왼손잡이만
                  // 그렇다 — 나머지는 연 시점의 값도 맞는 절반에 떨어져 회귀 방지용이다(#218 R2). 펼친 폭 0
                  // 접힘선은 #218 전에도 앱만 나누는 절반이 다시 쟀다.
                  final stale = Offset(
                    openedKey.dx.clamp(0, size.width),
                    openedKey.dy.clamp(0, size.height),
                  );
                  final hinge = featureOf(size).bounds;
                  final staleDialog = Rect.fromCenter(
                    center: stale,
                    width: 0,
                    height: 0,
                  );
                  expect(
                    !sameHalf(hinge, key, staleDialog),
                    start == landscape && h == Handedness.left,
                    reason: '연 시점 $openedKey → $stale, 지금 $key',
                  );
                }
              }
            },
          );
        }
      }
    }

    testWidgets('회전으로 옮겨 간 뒤에 손잡이를 바꾸면 대화상자는 그 자리에 남는다 (#94)', (tester) async {
      const portrait = Size(673, 841);
      final landscape = portrait.flipped;
      _setViewPadding(tester, padding);
      final (container, _) = await _pump(
        tester,
        size: landscape,
        padding: padding,
        handedness: Handedness.left,
        displayFeatures: [centerFold(landscape)],
      );
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      // 세로 책 자세로 돌린다 — 왼손잡이라 설정 키·대화상자는 왼쪽 절반
      await _pump(
        tester,
        size: portrait,
        padding: padding,
        displayFeatures: [centerFold(portrait)],
        container: container,
      );
      await tester.pumpAndSettle();
      final moved = tester.getRect(_dialogSurface);
      expect(moved.right, lessThanOrEqualTo(portrait.width / 2 + 0.01));

      await tester.tap(_option(Handedness.right));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(container.read(handednessProvider), Handedness.right);
      expect(
        tester.getRect(_settings).left,
        greaterThanOrEqualTo(portrait.width / 2),
      );
      expect(tester.getRect(_dialogSurface), moved);
    });

    testWidgets('손잡이를 바꿔 연 자리에 남은 뒤 회전하면 그때의 설정 키 쪽 절반으로 옮겨 간다', (
      tester,
    ) async {
      const portrait = Size(673, 841);
      final landscape = portrait.flipped;
      _setViewPadding(tester, padding);
      final (container, _) = await _pump(
        tester,
        size: landscape,
        padding: padding,
        handedness: Handedness.right,
        displayFeatures: [centerFold(landscape)],
      );
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      final opened = tester.getRect(_dialogSurface);
      await tester.tap(_option(Handedness.left));
      await tester.pumpAndSettle();
      expect(container.read(handednessProvider), Handedness.left);
      expect(tester.getRect(_dialogSurface), opened);

      // 세로 책 자세로 돌린다 — 왼손잡이라 설정 키는 왼쪽 절반. 연 시점(오른손잡이)의 설정 키 중심은 화면 안으로
      // 잘라 내면 오른쪽 절반이라, 손잡이를 바꾼 뒤에 다시 재지 않으면 오른쪽에 뜬다.
      await _pump(
        tester,
        size: portrait,
        padding: padding,
        displayFeatures: [centerFold(portrait)],
        container: container,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(_settings).right,
        lessThanOrEqualTo(portrait.width / 2),
      );
      final dialog = tester.getRect(_dialogSurface);
      expect(
        dialog.right,
        lessThanOrEqualTo(portrait.width / 2 + 0.01),
        reason: '$dialog',
      );
    });

    testWidgets(
      '경로 페이지는 showDialog와 같은 구조다 — 하위 화면 나눔은 하나이고 경로 의미 노드는 화면 전체다 (#218 R1)',
      (tester) async {
        const size = Size(673, 841);
        _setViewPadding(tester, padding);
        await _pump(
          tester,
          size: size,
          padding: padding,
          handedness: Handedness.right,
          displayFeatures: [centerFold(size)],
        );
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        // 나뉘었다 (오른쪽 절반)
        expect(
          tester.getRect(_dialogSurface).left,
          greaterThanOrEqualTo(size.width / 2 - 0.01),
        );
        final subScreen = find.byType(DisplayFeatureSubScreen);
        expect(subScreen, findsOneWidget);
        // 나눔을 감싸는 경로 의미 노드(`RawDialogRoute.buildPage`) — 대화상자 자신의 노드(AlertDialog)는 나눔 안쪽이다
        final routeScope = find
            .ancestor(
              of: subScreen,
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.scopesRoute == true,
              ),
            )
            .first;
        expect(tester.getRect(routeScope), Offset.zero & size);
      },
    );

    // 같은 자리의 접힘선이 자세만 바뀌면(펴기·반 접기) 배치가 같아(#143) 설정 키를 다시 재지 않는다 — 손잡이를 바꿔
    // 연 자리에 남은 대화상자가 펴고 접을 때 접힘선 건너로 뛰지 않는다(#218 R1). 앱만 나누는 절반과 Flutter가 나누는
    // 절반 사이를 오가도 같은 기준점이다.
    for (final startState in const [
      DisplayFeatureState.postureHalfOpened,
      DisplayFeatureState.postureFlat,
    ]) {
      testWidgets(
        '손잡이를 바꾼 뒤 자세만 바뀌면(${startState.name}에서 시작) 대화상자는 그 자리에 남는다',
        (tester) async {
          const size = Size(673, 841);
          final other = startState == DisplayFeatureState.postureFlat
              ? DisplayFeatureState.postureHalfOpened
              : DisplayFeatureState.postureFlat;
          _setViewPadding(tester, padding);
          final (container, _) = await _pump(
            tester,
            size: size,
            padding: padding,
            handedness: Handedness.left,
            displayFeatures: [centerFold(size, state: startState)],
          );
          await tester.tap(_settings);
          await tester.pumpAndSettle();
          final opened = tester.getRect(_dialogSurface);
          expect(opened.right, lessThanOrEqualTo(size.width / 2 + 0.01));
          await tester.tap(_option(Handedness.right));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(_settings).left,
            greaterThanOrEqualTo(size.width / 2),
          );
          expect(tester.getRect(_dialogSurface), opened);

          for (final state in [other, startState]) {
            await _pump(
              tester,
              size: size,
              padding: padding,
              displayFeatures: [centerFold(size, state: state)],
              container: container,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(tester.getRect(_dialogSurface), opened, reason: '$state');
          }
        },
      );
    }

    // 시스템 인셋만 바뀌어도 본체 크기가 바뀌어 다시 잰다 — 인셋으로 배치가 바뀌어 설정 키가 접힘선 건너로 옮겨 가는
    // 화면 (#218 R1: 손잡이와 무관한 기하를 화면 MediaQuery 대신 본체 크기로 받는 이유 — 계산기 본체는 SafeArea 안이라
    // 인셋이 늘 0으로 보인다). 두 절반 모두 대화상자 최소 크기에 못 미쳐 설정 키 쪽 절반 그대로다(#125).
    testWidgets('인셋이 바뀌어 설정 키가 접힘선 건너로 옮겨 가면 대화상자도 옮겨 간다', (tester) async {
      const size = Size(510, 320);
      final fold = _halfOpenedAt(const Rect.fromLTWH(255, 0, 0, 320));
      const insets = EdgeInsets.only(top: 24, right: 48);
      final (container, _) = await _pump(
        tester,
        size: size,
        handedness: Handedness.left,
        displayFeatures: [fold],
      );
      final before = tester.getRect(_settings).center;
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      expect(
        sameHalf(fold.bounds, before, tester.getRect(_dialogSurface)),
        isTrue,
      );

      _setViewPadding(tester, insets);
      await _pump(
        tester,
        size: size,
        padding: insets,
        displayFeatures: [fold],
        container: container,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final after = tester.getRect(_settings).center;
      expect(
        before.dx > 255,
        isNot(after.dx > 255),
        reason: '설정 키가 접힘선 건너로 옮겨 가는 화면이어야 한다: $before → $after',
      );
      final dialog = tester.getRect(_dialogSurface);
      expect(
        sameHalf(fold.bounds, after, dialog),
        isTrue,
        reason: '$after $dialog',
      );
    });
  });

  group('앱만 나누는 펼친 접힘선으로 바뀌는 프레임에도 대화상자가 접힘선을 가로지르지 않는다 (#226)', () {
    // 배치 값(그린 배치·설정 키 중심)은 프레임이 끝난 뒤에 대화상자로 전달되어 한 프레임 늦다. 펼친 폭 0 접힘선은
    // Flutter가 나누지 않으므로, 고치기 전에는 바뀌는 프레임에 앱 기준 나눔이 이전 배치 값(가로형·방향이 다른 책 자세)을
    // 보고 화면 전체에 띄워 카드가 접힘선을 가로질렀다(#218 R2 실측 — 아래 두 전환).
    /// [r]이 [hinge]를 가로지르지 않는지 (한쪽 절반 안에 있는지)
    bool clear(Rect hinge, Rect r) {
      const e = 0.01;
      return FormFactor.isVerticalHinge(hinge)
          ? r.right <= hinge.left + e || r.left >= hinge.right - e
          : r.bottom <= hinge.top + e || r.top >= hinge.bottom - e;
    }

    /// [r]이 [hinge]를 기준으로 [point]와 같은 쪽 절반 안에 있는지
    bool sameHalf(Rect hinge, Offset point, Rect r) {
      const e = 0.01;
      if (FormFactor.isVerticalHinge(hinge)) {
        return point.dx > hinge.center.dx
            ? r.left >= hinge.right - e
            : r.right <= hinge.left + e;
      }
      return point.dy > hinge.center.dy
          ? r.top >= hinge.bottom - e
          : r.bottom <= hinge.top + e;
    }

    /// 열린 대화상자를 두고 화면을 [size]·[fold]로 바꾼 뒤, 바뀐 첫 프레임과 자리 잡은 뒤의 카드를 확인한다.
    /// 자리 잡은 뒤에는 지금 설정 키 쪽 절반이다(#218). [keyHalf]가 `false`면 자리 잡은 뒤 반대쪽 절반이다 — 설정 키 쪽
    /// 절반이 대화상자 최소 폭에 못 미쳐 넓은 절반에 뜨는 화면(#125).
    Future<void> expectClearOnChange(
      WidgetTester tester,
      ProviderContainer container, {
      required Size size,
      required EdgeInsets padding,
      required DisplayFeature fold,
      required String reason,
      bool keyHalf = true,
    }) async {
      final element = tester.element(find.byType(HandednessDialog));
      // `_pump`는 `pumpWidget` 한 번 — 바뀐 첫 프레임이다
      await _pump(
        tester,
        size: size,
        padding: padding,
        displayFeatures: [fold],
        container: container,
      );
      final first = tester.getRect(_dialogSurface);
      expect(clear(fold.bounds, first), isTrue, reason: '첫 프레임 $reason $first');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(drawnArrangementOf(tester), isNot(DrawnArrangement.stacked));
      final key = tester.getRect(_settings).center;
      final settled = tester.getRect(_dialogSurface);
      expect(
        sameHalf(fold.bounds, key, settled),
        keyHalf,
        reason: '자리 잡은 뒤 $reason $key $settled',
      );
      expect(clear(fold.bounds, settled), isTrue, reason: '$settled');
      // 카드가 화면 전체 가운데 → 절반으로 옮겨 가도 같은 대화상자다(포커스·스크롤 유지)
      expect(tester.element(find.byType(HandednessDialog)), same(element));
    }

    for (final h in Handedness.values) {
      testWidgets('823×603 펼친 접힘선 2개 → 1개(x=411.5)·${h.name}', (tester) async {
        const size = Size(823, 603);
        const padding = EdgeInsets.only(top: 24, bottom: 24);
        _setViewPadding(tester, padding);
        final (container, _) = await _pump(
          tester,
          size: size,
          padding: padding,
          handedness: h,
          displayFeatures: [
            _foldAt(const Rect.fromLTWH(274.5, 0, 0, 603)),
            _foldAt(const Rect.fromLTWH(548.5, 0, 0, 603)),
          ],
        );
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        // 접힘선 2개 화면은 화면 전체 가운데 (#198) — 새 접힘선 x=411.5를 가로지르는 자리다
        final opened = tester.getRect(_dialogSurface);
        expect(opened.center.dx, moreOrLessEquals(size.width / 2));
        await expectClearOnChange(
          tester,
          container,
          size: size,
          padding: padding,
          fold: _foldAt(const Rect.fromLTWH(411.5, 0, 0, 603)),
          reason: '$h',
        );
      });

      // 펼친 Fold 내부를 돌린다: 세로 접힘선(책 자세) ↔ 가로 접힘선(가로 접힘선 기준 배치) — 이전 배치 값은 방향이 다른
      // 접힘선 기준 배치다.
      for (final start in const [Size(673, 841), Size(841, 673)]) {
        testWidgets(
          '펼친 Fold ${start.width}×${start.height}에서 연 채 회전·${h.name}',
          (tester) async {
            const padding = EdgeInsets.only(top: 32, bottom: 24);
            DisplayFeature foldOf(Size s) => _foldAt(
              s.width < s.height
                  ? Rect.fromLTWH(s.width / 2, 0, 0, s.height)
                  : Rect.fromLTWH(0, s.height / 2, s.width, 0),
            );
            _setViewPadding(tester, padding);
            final (container, _) = await _pump(
              tester,
              size: start,
              padding: padding,
              handedness: h,
              displayFeatures: [foldOf(start)],
            );
            await tester.tap(_settings);
            await tester.pumpAndSettle();
            expect(
              clear(foldOf(start).bounds, tester.getRect(_dialogSurface)),
              isTrue,
            );
            for (final size in [start.flipped, start]) {
              await expectClearOnChange(
                tester,
                container,
                size: size,
                padding: padding,
                fold: foldOf(size),
                reason: '$h $size',
              );
            }
          },
        );
      }
    }

    // 접힘선은 그대로이고 창 크기만 바뀌어 앱이 그 접힘선으로 나누게 되는 전환 (#226 R2). 이전 배치 값(위아래 배치, 또는
    // 손잡이에 따라 배치가 바뀌는 화면)은 화면 전체를 고르지만, 그 카드는 접힘선을 가로지르므로 나눈다.
    // - Pixel Fold 내부 2:1 분할 창(접힘선을 품은 왼쪽 창 560dp)을 전체 화면으로 키움, 접힘선 x=420.5
    // - #129의 비대칭 접힘선 화면(841×701, x=654, 오른쪽 인셋 48)을 1000dp로 키움 — 오른손잡이는 설정 키 쪽 절반
    //   (인셋 빼고 298dp)이 대화상자 최소 폭(360dp)에 못 미쳐 왼쪽 절반에 자리 잡는다(#125)
    // 크기 비교를 뺀 R1 수정에서는 첫 프레임에 x=201.5~639.5, 257~695로 가로질렀다(R2 실측).
    for (final h in Handedness.values) {
      for (final (from, to, x, padding, keyHalf) in [
        (
          Size(560, 701),
          Size(841, 701),
          420.5,
          const EdgeInsets.only(top: 24, bottom: 24),
          true,
        ),
        (
          Size(841, 701),
          Size(1000, 701),
          654.0,
          const EdgeInsets.only(top: 24, right: 48, bottom: 24),
          h == Handedness.left,
        ),
      ]) {
        testWidgets(
          '같은 접힘선(x=$x)에서 창이 ${from.width} → ${to.width}로 커져 나누게 되면·${h.name}',
          (tester) async {
            final fold = _foldAt(Rect.fromLTWH(x, 0, 0, from.height));
            _setViewPadding(tester, padding);
            final (container, _) = await _pump(
              tester,
              size: from,
              padding: padding,
              handedness: h,
              displayFeatures: [fold],
            );
            await tester.tap(_settings);
            await tester.pumpAndSettle();
            // 시작 화면은 화면 전체 가운데에 뜬다(위아래 배치, 또는 손잡이에 따라 배치가 바뀌는 화면 — #129)
            final opened = tester.getRect(_dialogSurface);
            expect(
              opened.center.dx,
              moreOrLessEquals((from.width - padding.horizontal) / 2),
              reason: '$opened',
            );
            await expectClearOnChange(
              tester,
              container,
              size: to,
              padding: padding,
              fold: fold,
              reason: '$h',
              keyHalf: keyHalf,
            );
          },
        );
      }
    }

    // 창 크기와 함께 접힘선도 옮겨 가는 크기 변경(분할 화면의 오른쪽 창 등)에서도, 화면 전체 카드가 접힘선을 가로지르지
    // 않으면 화면 전체 그대로다 (#226 R2 — 고치기 전 바뀐 각 프레임에 x=103~541 등 왼쪽 절반으로 튀었다).
    testWidgets('접힘선이 함께 옮겨 가는 크기 변경에서도 가로지르지 않는 화면 전체 대화상자는 그대로다', (
      tester,
    ) async {
      const padding = EdgeInsets.only(top: 24, right: 48, bottom: 24);
      _setViewPadding(tester, padding);
      final (container, _) = await _pump(
        tester,
        size: const Size(841, 701),
        padding: padding,
        handedness: Handedness.right,
        displayFeatures: [_foldAt(const Rect.fromLTWH(654, 0, 0, 701))],
      );
      expect(isStackedArrangement(tester), isTrue);
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      for (final shrink in const [10.0, 20.0, 30.0, 40.0]) {
        final width = 841 - shrink;
        await _pump(
          tester,
          size: Size(width, 701),
          padding: padding,
          displayFeatures: [_foldAt(Rect.fromLTWH(654 - shrink, 0, 0, 701))],
          container: container,
        );
        final dialog = tester.getRect(_dialogSurface);
        expect(
          dialog.center.dx,
          moreOrLessEquals((width - padding.horizontal) / 2),
          reason: '$width $dialog',
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // 바뀐 프레임에 설정 키 쪽 절반이 하한(280dp)에 못 미치면 하한을 넘는 반대쪽 절반이다. 화면 전체에 띄우면 접힘선을
    // 가로지른다. 580×800 창에 접힘선 x=330을 넣으면 설정 키(오른쪽 위) 쪽 절반은 250dp, 반대쪽은 330dp다(둘 다
    // 대화상자 최소 폭 360dp 미만이라 #125의 "넘는 쪽"이 없다).
    testWidgets('바뀐 프레임에 설정 키 쪽 절반이 좁으면 반대쪽 절반이다', (tester) async {
      const size = Size(580, 800);
      final fold = _foldAt(const Rect.fromLTWH(330, 0, 0, 800));
      final (container, _) = await _pump(
        tester,
        size: size,
        handedness: Handedness.right,
      );
      final key = tester.getRect(_settings).center;
      expect(key.dx, greaterThan(330), reason: '$key');
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      await _pump(
        tester,
        size: size,
        displayFeatures: [fold],
        container: container,
      );
      final first = tester.getRect(_dialogSurface);
      expect(first.right, lessThanOrEqualTo(330 + 0.01), reason: '$first');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // 자리 잡은 뒤는 #129 규칙 4대로 화면 전체 가운데다 — 설정 키 쪽 절반(250dp)이 하한 미만이다. 바뀐 프레임에
      // 절반에 보였다가 화면 전체가 되는 한 번의 이동은 접힘선을 가로지르는 한 프레임 대신 택한 것이다.
      final settled = tester.getRect(_dialogSurface);
      expect(tester.getRect(_settings).center.dx, greaterThan(330));
      expect(
        settled.center.dx,
        moreOrLessEquals(size.width / 2),
        reason: '$settled',
      );
    });

    // 접힘선은 그대로이고 창 크기만 바뀌면(분할 화면 구분선 끌기) 배치 값은 같은 접힘선으로 정한 값이라 그대로 쓴다 —
    // 화면 전체에 떠 있던 대화상자가 바뀌는 프레임마다 절반으로 튀지 않는다(#226 R1 — 고치기 전 바뀐 각 프레임에
    // x=108~546). #129의 비대칭 접힘선 화면: 오른손잡이는 위아래 배치라 화면 전체다.
    testWidgets('접힘선은 그대로이고 창 크기만 바뀌면 화면 전체에 떠 있던 대화상자는 그대로다 (R1)', (
      tester,
    ) async {
      const padding = EdgeInsets.only(top: 24, right: 48, bottom: 24);
      DisplayFeature foldOf(double height) =>
          _foldAt(Rect.fromLTWH(654, 0, 0, height));
      _setViewPadding(tester, padding);
      final (container, _) = await _pump(
        tester,
        size: const Size(841, 701),
        padding: padding,
        handedness: Handedness.right,
        displayFeatures: [foldOf(701)],
      );
      expect(isStackedArrangement(tester), isTrue);
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      final opened = tester.getRect(_dialogSurface);
      // 화면 전체(오른쪽 인셋 48을 뺀 안전 영역) 가운데
      expect(opened.center.dx, moreOrLessEquals((841 - 48) / 2));
      for (final height in const [690.0, 680.0, 670.0]) {
        await _pump(
          tester,
          size: Size(841, height),
          padding: padding,
          displayFeatures: [foldOf(height)],
          container: container,
        );
        final dialog = tester.getRect(_dialogSurface);
        expect(
          dialog.center.dx,
          moreOrLessEquals(opened.center.dx),
          reason: '$height $dialog',
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(_dialogSurface).center.dx,
        moreOrLessEquals(opened.center.dx),
      );
    });

    // 배치 값을 정하는 화면 기하는 그대로인데 경로(Navigator)가 보는 접힘선만 바뀌어도, 경로가 갱신을 청해 자리 잡은
    // 뒤에는 배치 값을 따른다. 실제 앱에서는 두 MediaQuery가 같아 이 구성이 생기지 않는다 — 갱신 요청이 빠지면
    // 대화상자가 그 접힘선의 절반에 계속 남는 것을 보는 테스트다(테스트 화면은 계산기 MediaQuery와 View(경로가 본다)를
    // 따로 줄 수 있다). 계산기는 접힘선이 없는 가로형 그대로라 자리 잡은 뒤는 화면 전체 가운데다.
    testWidgets('경로의 접힘선만 바뀌어도 자리 잡은 뒤에는 배치 값을 따른다', (tester) async {
      const size = Size(841, 673);
      const fold = Rect.fromLTWH(0, 336.5, 841, 0);
      await _pump(tester, size: size, handedness: Handedness.right);
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      final opened = tester.getRect(_dialogSurface);
      expect(opened.center.dx, moreOrLessEquals(size.width / 2));

      tester.view.displayFeatures = [_foldAt(fold)];
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_dialogSurface), opened);

      // 같은 접힘선이 0.5dp 다른 자리로 다시 보고되면 같은 화면이다 — 배치 값이 따라온 화면 전체 그대로다. 다른 화면으로
      // 보면 그 프레임에 화면 전체 카드(접힘선을 가로지른다)를 피해 절반으로 튄다(#226 R1).
      tester.view.displayFeatures = [_foldAt(fold.shift(const Offset(0, 0.5)))];
      await tester.pump();
      expect(tester.getRect(_dialogSurface), opened);
      await tester.pumpAndSettle();
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
          // 이슈 재현: 오른쪽 손 쪽 패널 123dp(키 13.9dp)라 위아래 배치, 설정 키(ON)는 키패드 오른쪽 위(좁은 절반). #143 전에는
          // 접힘선 x=560(패널 217dp)이었다 — 지금은 그 폭에서도 키를 쓸 수 있어 책 자세가 된다.
          (
            '반 접힘·오른쪽 좁은 절반·위아래 배치',
            wide,
            rightInset,
            _halfOpenedAt(const Rect.fromLTWH(654, 0, 0, 701)),
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
              const Rect.fromLTWH(634, 0, 20, 701),
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
          // 가로 접힘선: 위 절반이 낮다(인셋을 빼고 226·126dp). y=250은 위 패널 210dp라 가로 접힘선 기준 배치(#143), y=150은
          // 위 패널 110dp가 활성 LCD 최소 높이(112)에 못 미쳐 위아래 배치다. 설정 키는 키패드와 함께 넓은 아래 절반이다.
          for (final (y, stacked) in [(250.0, false), (150.0, true)])
            (
              '반 접은 가로 접힘선 y=$y·위쪽 낮은 절반·${stacked ? '위아래 배치' : '가로 접힘선 기준 배치'}',
              tall,
              portraitInset,
              _halfOpenedAt(Rect.fromLTWH(0, y, 701, 0)),
              Handedness.right,
              stacked,
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

      test('창을 가로지르는 접힘선 2개(십자)는 접힘 정보 순서와 무관하게 나누지 않아 버튼 위치 그대로다 (#198)', () {
        // 1400×1000을 세로 힌지(x=400, 폭 20)·가로 힌지(y=300, 높이 20)로 4분할. 위 두 곳은 높이 300dp로 미달이지만,
        // 접힘선 2개 이상인 화면은 배치처럼 대화상자도 접힘선을 무시한다(경로가 나누지 않는다 — `dialogRouteMediaOf`).
        // #198 전에는 넘는 곳 중 가장 가까운 아래 왼쪽(400×680)의 가운데였다. 버튼은 위 왼쪽.
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
            anchor,
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
      // 하한(280)보다 좁지만 반대 손잡이로도 접힘선 기준 배치(키패드는 약 141dp까지 들어간다, #143) — 주름을
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
      // x=320·오른손잡이: 설정 키는 넓은 오른쪽 절반. 왼쪽 인셋 48이면 왼쪽 손 쪽 패널 256dp(두 손잡이 모두 접힘선 기준
      // 배치)라 오른쪽 절반에 뜬다. 왼쪽 인셋 200으로 바뀌면 패널 104dp(키 11.8dp)라 왼손잡이는 위아래 배치 — 그린 배치·
      // 손잡이 적용 여부는 그대로이고 [SettingsLauncher.handednessKeepsArrangement]만 바뀐다.
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

      const widerInset = EdgeInsets.only(left: 200, top: 24, bottom: 24);
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
        // x=180·왼쪽 인셋 48 → 왼쪽 손 쪽 패널 116dp(키 13.2dp): 키가 쓸 수 있는 크기보다 작아 왼손잡이는 위아래 배치다.
        // 오른손잡이의 설정 키는 넓은 오른쪽 절반이지만, 그 절반에 띄우면 왼손잡이를 고를 때 화면 전체로 옮겨 가야 한다.
        final container = await pumpFold(
          tester,
          size: wide,
          padding: leftInset,
          hingeX: 180,
          handedness: Handedness.right,
        );
        expect(isStackedArrangement(tester), isFalse);
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        final opened = tester.getRect(_dialogSurface);
        // 화면 전체(인셋 안) 가운데 — 오른쪽 절반이었다면 가운데가 (180 + 841) / 2 = 510.5다.
        expect(
          opened.center.dx,
          moreOrLessEquals((leftInset.left + wide.width) / 2),
        );
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

  group('접힘선이 2개 이상인 화면(펼친 트라이폴드)의 설정 대화상자 (#198)', () {
    // Galaxy Z TriFold 공개 해상도 근사(#144) — 가로가 기본 방향, 세로로 돌리면 접힘선이 가로로 눕는다.
    const landscape = Size(823, 603);
    const portrait = Size(603, 823);
    // 위아래가 같아 화면 가운데 = 안전 영역 가운데
    const padding = EdgeInsets.only(top: 24, bottom: 24);

    /// [size] 화면을 세 장으로 나누는 접힘선 2개 (폭 [width], 접힘선 가운데가 1/3·2/3 근사 위치)
    List<DisplayFeature> triFold(
      Size size, {
      double width = 0,
      DisplayFeatureType type = DisplayFeatureType.fold,
      DisplayFeatureState state = DisplayFeatureState.postureHalfOpened,
    }) {
      final vertical = size.width > size.height;
      return [
        for (final at in const [274.5, 548.5])
          _foldAt(
            vertical
                ? Rect.fromLTWH(at - width / 2, 0, width, size.height)
                : Rect.fromLTWH(0, at - width / 2, size.width, width),
            type: type,
            state: state,
          ),
      ];
    }

    Future<void> pumpTriFold(
      WidgetTester tester, {
      required Size size,
      required List<DisplayFeature> features,
      required Handedness handedness,
    }) async {
      // 실제 앱처럼 View에도 인셋을 넣는다 (대화상자 경로는 View의 MediaQuery를 본다)
      _setViewPadding(tester, padding);
      await _pump(
        tester,
        size: size,
        padding: padding,
        handedness: handedness,
        displayFeatures: features,
      );
    }

    // 자세·힌지 폭과 상관없이 화면 전체 가운데다. 고치기 전(`showDialog`)에는 반 접힘·폭 있는 힌지에서 Flutter가 만든
    // 겹치는 하위 화면(0~548.5)에 떠 카드가 x=55~493으로 접힘선 하나를 가로질렀다(#190 R2 실측).
    for (final (name, featuresOf)
        in <(String, List<DisplayFeature> Function(Size))>[
          (
            '펼친 폭 0 접힘선',
            (s) => triFold(s, state: DisplayFeatureState.postureFlat),
          ),
          ('반 접은 폭 0 접힘선', triFold),
          // 폭 20dp 힌지 1개와 반 접힌 주름 1개가 섞인 화면 (#198 R1)
          (
            '폭 20dp 힌지와 반 접힌 주름',
            (s) => [
              triFold(s, width: 20, type: DisplayFeatureType.hinge).first,
              triFold(s).last,
            ],
          ),
          (
            '폭 20dp 물리 힌지 (칸이 모두 카드 최소 폭 미만)',
            (s) => triFold(
              s,
              width: 20,
              type: DisplayFeatureType.hinge,
              state: DisplayFeatureState.postureFlat,
            ),
          ),
        ]) {
      for (final size in const [landscape, portrait]) {
        testWidgets(
          '$name · ${size.width}×${size.height}: 손잡이와 무관하게 화면 가운데에 뜬다',
          (tester) async {
            for (final h in Handedness.values) {
              await pumpTriFold(
                tester,
                size: size,
                features: featuresOf(size),
                handedness: h,
              );
              expect(
                drawnArrangementOf(tester),
                isNot(DrawnArrangement.sideBySide),
              );
              await tester.tap(_settings);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final dialog = tester.getRect(_dialogSurface);
              final center = (Offset.zero & size).center;
              expect(
                dialog.center.dx,
                moreOrLessEquals(center.dx),
                reason: '$h $dialog',
              );
              expect(
                dialog.center.dy,
                moreOrLessEquals(center.dy),
                reason: '$h $dialog',
              );
              // 카드가 Material 최소 폭을 지킨다 (한 칸에 갇히면 약 194dp)
              expect(
                dialog.width,
                greaterThanOrEqualTo(280),
                reason: '$h $dialog',
              );
              await tester.tap(find.byKey(HandednessDialog.closeKey));
              await tester.pumpAndSettle();
            }
          },
        );
      }
    }

    testWidgets(
      '열린 채 접힘선 1개 화면이 되면 지금 설정 키 쪽 절반으로 옮겨 가고, 돌아오면 가운데다 — 대화상자 상태는 유지된다 (#218)',
      (tester) async {
        // 접힘선 1개(반 접힘, 화면 가운데) — 접힘선 기준 배치다
        final single = [_halfOpenedAt(const Rect.fromLTWH(411.5, 0, 0, 603))];
        for (final h in Handedness.values) {
          await pumpTriFold(
            tester,
            size: landscape,
            features: triFold(landscape),
            handedness: h,
          );
          final key = tester.getRect(_settings).center;
          await tester.tap(_settings);
          await tester.pumpAndSettle();
          final element = tester.element(find.byType(HandednessDialog));
          expect(
            tester.getRect(_dialogSurface).center.dx,
            moreOrLessEquals(landscape.width / 2),
          );

          // 앱과 View 모두 접힘선 1개 화면으로 바꾼다 (저장소의 손잡이는 그대로)
          final container = ProviderScope.containerOf(
            tester.element(find.byType(CalculatorScreen)),
          );
          await _pump(
            tester,
            size: landscape,
            padding: padding,
            displayFeatures: single,
            container: container,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
          final dialog = tester.getRect(_dialogSurface);
          final keyNow = tester.getRect(_settings).center;
          // 접힘선 기준 배치로 옮겨 간 지금의 설정 키 쪽 절반이다. 연 시점의 설정 키는 반대쪽 절반이었다 — 오른손잡이
          // x=367.1 → 782.0, 왼손잡이 x=782.4 → 370.5(#198 R2 실측). #218 전에는 Flutter가 나누는 접힘선의 하위
          // 화면을 연 시점의 `anchorPoint`로 골라 대화상자가 연 시점의 쪽에 남았다.
          expect(
            key.dx > 411.5,
            isNot(keyNow.dx > 411.5),
            reason: '$h $key $keyNow',
          );
          expect(
            keyNow.dx > 411.5 ? dialog.left >= 411.5 : dialog.right <= 411.5,
            isTrue,
            reason: '$h $keyNow $dialog',
          );
          expect(tester.element(find.byType(HandednessDialog)), same(element));

          await _pump(
            tester,
            size: landscape,
            padding: padding,
            displayFeatures: triFold(landscape),
            container: container,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(_dialogSurface).center.dx,
            moreOrLessEquals(landscape.width / 2),
            reason: '$h',
          );
          expect(tester.element(find.byType(HandednessDialog)), same(element));
          await tester.tap(find.byKey(HandednessDialog.closeKey));
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      '두 장에 걸친 분할 창(창 끝에 둘째 접힘선): 보고 순서와 무관하게 설정 키 쪽 절반에 뜬다 (#198 R2)',
      (tester) async {
        // 트라이폴드의 두 장에 걸친 분할 창 548.5×603 — 접힘선 1개 규칙(장 폭 274dp ≥ 패널 최소 길이 128dp라 책 자세, #143)
        const size = Size(548.5, 603);
        final middle = _halfOpenedAt(const Rect.fromLTWH(274.5, 0, 0, 603));
        final edge = _halfOpenedAt(const Rect.fromLTWH(548.5, 0, 0, 603));
        Rect? first;
        for (final features in [
          [middle, edge],
          [edge, middle],
        ]) {
          await pumpTriFold(
            tester,
            size: size,
            features: features,
            handedness: Handedness.right,
          );
          expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
          final key = tester.getRect(_settings).center;
          await tester.tap(_settings);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final dialog = tester.getRect(_dialogSurface);
          // 두 절반 모두 최소 크기 미만 — 설정 키 쪽 절반 그대로(#125). 고치기 전에는 [middle, edge] 순서에서 Flutter의
          // 겹치는 칸(0~548.5)에 떠 카드가 x=40~508.5로 주름을 가로질렀다.
          expect(
            key.dx > 274.5 ? dialog.left >= 274.5 : dialog.right <= 274.5,
            isTrue,
            reason: '$features $key $dialog',
          );
          expect(dialog, first ?? dialog, reason: '$features');
          first = dialog;
          await tester.tap(find.byKey(HandednessDialog.closeKey));
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets('경로의 장벽 색은 showDialog처럼 대화상자 테마를 따른다', (tester) async {
      tester.view.physicalSize =
          const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const barrier = Color(0x80112233);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: ThemeData(
              dialogTheme: const DialogThemeData(barrierColor: barrier),
            ),
            home: const CalculatorScreen(),
          ),
        ),
      );
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      final route =
          ModalRoute.of(tester.element(find.byType(HandednessDialog)))!
              as DialogRoute<void>;
      expect(route.barrierColor, barrier);
    });

    testWidgets('경로는 showDialog와 같다 — 장벽(색·닫기·라벨)과 포커스 순환', (tester) async {
      await _pump(tester, size: const Size(390, 844));
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      final route =
          ModalRoute.of(tester.element(find.byType(HandednessDialog)))!
              as DialogRoute<void>;
      expect(route.barrierColor, Colors.black54);
      expect(route.barrierDismissible, isTrue);
      expect(
        route.barrierLabel,
        const DefaultMaterialLocalizations().modalBarrierDismissLabel,
      );
      expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);
      expect(route.fullscreenDialog, isFalse);
      // 최상위 Navigator
      expect(
        route.navigator,
        same(
          Navigator.of(
            tester.element(find.byType(CalculatorScreen)),
            rootNavigator: true,
          ),
        ),
      );
    });

    group('경로 MediaQuery·기준점 (dialogRouteMediaOf·dialogAnchorPointOf)', () {
      const cutout = DisplayFeature(
        bounds: Rect.fromLTWH(400, 0, 24, 24),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      );
      MediaQueryData screenOf(List<DisplayFeature> features) =>
          MediaQueryData(size: landscape, displayFeatures: features);

      test('배치가 쓰는 접힘선 하나뿐이면 그대로다 (경로가 원래대로 나눈다)', () {
        for (final features in [
          <DisplayFeature>[],
          [cutout],
          [_halfOpenedAt(const Rect.fromLTWH(274.5, 0, 0, 603))],
          [
            cutout,
            _foldAt(
              const Rect.fromLTWH(400, 0, 20, 603),
              type: DisplayFeatureType.hinge,
            ),
          ],
        ]) {
          final screen = screenOf(features);
          expect(
            SettingsLauncher.dialogRouteMediaOf(screen),
            same(screen),
            reason: '$features',
          );
        }
      });

      test(
        '배치가 쓰지 않는 접힘 정보(창 가장자리·창 밖·창보다 긺)는 지우고 가로지르는 접힘선 하나만 남긴다 (#198 R2)',
        () {
          final middle = _halfOpenedAt(const Rect.fromLTWH(274.5, 0, 0, 603));
          for (final other in [
            _halfOpenedAt(const Rect.fromLTWH(823, 0, 0, 603)), // 창 가장자리
            _halfOpenedAt(const Rect.fromLTWH(900, 0, 0, 603)), // 창 밖
            _halfOpenedAt(const Rect.fromLTWH(600, 0, 0, 900)), // 창보다 긺(회전 직후)
          ]) {
            for (final features in [
              [middle, other],
              [other, middle],
            ]) {
              expect(
                SettingsLauncher.dialogRouteMediaOf(
                  screenOf([cutout, ...features]),
                ).displayFeatures,
                [cutout, middle],
                reason: '$features',
              );
            }
          }
          // 가로지르는 접힘선이 없으면 접히는 부분이 모두 없어진다
          expect(
            SettingsLauncher.dialogRouteMediaOf(
              screenOf([
                _halfOpenedAt(const Rect.fromLTWH(823, 0, 0, 603)),
                cutout,
              ]),
            ).displayFeatures,
            [cutout],
          );
        },
      );

      test('같은 접힘선이 두 번 보고되면 폭이 넓은 쪽, 같으면 반 접힌 쪽을 남긴다', () {
        final hinge = _foldAt(
          const Rect.fromLTWH(400, 0, 20, 603),
          type: DisplayFeatureType.hinge,
        );
        final crease = _halfOpenedAt(const Rect.fromLTWH(410, 0, 0, 603));
        final flat = _foldAt(const Rect.fromLTWH(410, 0, 0, 603));
        for (final (features, kept) in [
          ([crease, hinge], hinge),
          ([hinge, crease], hinge),
          ([flat, crease], crease),
          ([crease, flat], crease),
        ]) {
          expect(
            SettingsLauncher.dialogRouteMediaOf(screenOf(features))
                .displayFeatures,
            [kept],
            reason: '$features',
          );
        }
      });

      test('접힘선이 2개 이상이면 자세·종류·폭과 상관없이 접히는 부분을 모두 지우고 화면 구멍만 남긴다', () {
        for (final features in [
          triFold(landscape),
          triFold(landscape, state: DisplayFeatureState.postureFlat),
          triFold(landscape, width: 20, type: DisplayFeatureType.hinge),
          // 같은 힌지가 폭 0 접힘선과 함께 두 번 보고됨
          [
            ...triFold(landscape, width: 20, type: DisplayFeatureType.hinge),
            ...triFold(landscape),
          ],
        ]) {
          final screen = screenOf([cutout, ...features]);
          final route = SettingsLauncher.dialogRouteMediaOf(screen);
          expect(route.displayFeatures, [cutout], reason: '$features');
          expect(route.size, screen.size);
        }
      });

      test('접힘선이 2개 이상이면 기준점은 설정 키 중심 그대로다 (겹치는 하위 화면으로 고르지 않는다)', () {
        // 오른쪽 칸(274.5dp)은 최소 크기 미만 — 고치기 전에는 겹치는 칸 0~548.5의 가운데(274.25, 301.5)였다
        const anchor = Offset(782, 340);
        expect(
          SettingsLauncher.dialogAnchorPointOf(
            screenOf(triFold(landscape)),
            anchor,
            const Size(360, 328),
          ),
          anchor,
        );
      });
    });
  });

  group('CalcHingeSplitLayout · CalcTabletopLayout (#143)', () {
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

    Rect mirrorIn(Size body, Rect x) => Rect.fromLTRB(
      body.width - x.right,
      x.top,
      body.width - x.left,
      x.bottom,
    );

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
          expectSane(body, [l.lcd, l.keypad, ?l.history], reason);
          final hingeInBody = hinge.left >= 0 && hinge.right <= body.width;
          if (hingeInBody) {
            for (final r in [l.lcd, l.keypad, ?l.history]) {
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

    test('세로 접힘선: 손 쪽 패널은 그 패널 크기의 세로형, 반대쪽 패널 전체가 기록 영역이다', () {
      for (final (body, hinge) in const [
        (Size(641, 761), Rect.fromLTWH(320.5, 0, 0, 761)),
        (Size(825, 637), Rect.fromLTWH(412.5, 0, 0, 637)),
        (Size(1098, 594), Rect.fromLTWH(532, 0, 34, 594)),
        // 비대칭 접힘선
        (Size(800, 600), Rect.fromLTWH(300, 0, 0, 600)),
      ]) {
        for (final h in Handedness.values) {
          final l = CalcHingeSplitLayout.of(body, hinge, h);
          const m = CalcTheme.screenHingeMargin;
          final hand = h.keypadOnRight
              ? Rect.fromLTRB(hinge.right + m, 0, body.width, body.height)
              : Rect.fromLTRB(0, 0, hinge.left - m, body.height);
          final other = h.keypadOnRight
              ? Rect.fromLTRB(0, 0, hinge.left - m, body.height)
              : Rect.fromLTRB(hinge.right + m, 0, body.width, body.height);
          final portrait = CalcScreenLayout.of(hand.size);
          final reason = '$body $h $l';
          expect(l.history, rectMoreOrLessEquals(other), reason: reason);
          expect(
            l.lcd,
            rectMoreOrLessEquals(
              Rect.fromLTWH(
                hand.left,
                portrait.top,
                hand.width,
                portrait.lcdHeight,
              ),
            ),
            reason: reason,
          );
          expect(
            l.keypad,
            rectMoreOrLessEquals(
              Rect.fromLTRB(
                hand.left,
                portrait.top + portrait.lcdHeight + portrait.gap,
                hand.right,
                body.height,
              ),
            ),
            reason: reason,
          );
        }
      }
      // 고정값 — 두 화면 기기 본체 1098×594(접힘선 532~566): 손 쪽 패널 524×594. 키패드는 높이에 묶여 524×(594 − 8 − LCD)이고
      // LCD는 목표 비율 594 × 0.28 = 166.3dp다. #143 전에는 LCD가 반대쪽 절반 전체 높이(줄 글자 상한 273.5)였다.
      final r = CalcHingeSplitLayout.of(
        const Size(1098, 594),
        const Rect.fromLTWH(532, 0, 34, 594),
        Handedness.right,
      );
      expect(r.history, const Rect.fromLTRB(0, 0, 524, 594));
      expect(
        r.lcd,
        rectMoreOrLessEquals(const Rect.fromLTWH(574, 0, 524, 594 * 0.28)),
      );
      expect(
        r.keypad,
        rectMoreOrLessEquals(Rect.fromLTRB(574, 594 * 0.28 + 8, 1098, 594)),
      );
    });

    test('세로 접힘선: 손 쪽 패널이 짧으면 활성 LCD를 반대쪽 패널 맨 위로 옮긴다 (#143 R1)', () {
      // 640×360(상태바 24) 본체 624×320, 접힘선 x=312: 손 쪽 패널 304×320 — 세로형 키 17.0dp < 일반 하한 28dp.
      const body = Size(624, 320);
      const hinge = Rect.fromLTWH(312, 0, 0, 320);
      for (final h in Handedness.values) {
        final l = CalcHingeSplitLayout.of(body, hinge, h);
        final reason = '$h $l';
        expect(l.shortHandPanel, isTrue, reason: reason);
        final other = h.keypadOnRight
            ? const Rect.fromLTRB(0, 0, 304, 320)
            : const Rect.fromLTRB(320, 0, 624, 320);
        // 활성 LCD는 반대쪽 패널 맨 위 폭 전체(304 / 1.75 = 173.7), 그 아래 기록(138.3 ≥ 112)
        expect(
          l.lcd,
          rectMoreOrLessEquals(Rect.fromLTWH(other.left, 0, 304, 304 / 1.75)),
          reason: reason,
        );
        expect(
          l.history,
          rectMoreOrLessEquals(
            Rect.fromLTRB(other.left, 304 / 1.75 + 8, other.right, 320),
          ),
          reason: reason,
        );
        // 키패드는 손 쪽 패널 높이 전체(폭에 묶이지 않는다)
        expect(l.keypad.height, moreOrLessEquals(320), reason: reason);
        expect(l.keypad.width, moreOrLessEquals(304), reason: reason);
        expect(
          KeypadMetrics.minKeyTouchHeightOf(
            l.keypad.size,
            KeypadArrangement.standard,
          ),
          moreOrLessEquals(27.2, epsilon: 0.05),
        );
      }
      // 키 크기가 일반 하한 이상인 키 큰 패널은 세로형 그대로(Fold 내부 세로 본체 657×801)
      expect(
        CalcHingeSplitLayout.of(
          const Size(657, 801),
          const Rect.fromLTWH(328.5, 0, 0, 801),
          Handedness.right,
        ).shortHandPanel,
        isFalse,
      );
      // 손 쪽 패널이 폭에 묶여 키가 커지지 않는 창(접힘선이 치우침 — 손 쪽 패널 184×769)은 세로형 그대로
      expect(
        CalcHingeSplitLayout.of(
          const Size(657, 769),
          const Rect.fromLTWH(192, 0, 0, 769),
          Handedness.left,
        ).shortHandPanel,
        isFalse,
      );
      // 반대쪽 패널이 활성 LCD 최소 폭(200dp)보다 좁으면 LCD를 옮기지 않는다(본체 600×328, 접힘선 x=190: 반대쪽 패널 182dp)
      expect(
        CalcHingeSplitLayout.of(
          const Size(600, 328),
          const Rect.fromLTWH(190, 0, 0, 328),
          Handedness.right,
        ).shortHandPanel,
        isFalse,
      );
    });

    test('세로 접힘선: 위 제스처 영역 깊이만큼 짧은 손 쪽 패널의 키패드가 아래에서 시작한다 (#172)', () {
      // (본체, 접힘선) — 짧은 손 쪽 패널 창의 본체(640×360 인셋 24 → 624×320, 700×392 인셋 24/24 → 684×344(키 하한으로
      // 줄인 키패드), 841×360 인셋 24 → 825×320)와 짧지 않은 창(Pixel Fold 내부 본체 825×640.8)
      const cases = <(Size, Rect)>[
        (Size(624, 320), Rect.fromLTWH(312, 0, 0, 320)),
        (Size(684, 344), Rect.fromLTWH(342, 0, 0, 344)),
        (Size(825, 320), Rect.fromLTWH(272, 0, 0, 320)),
        (Size(825, 640.8), Rect.fromLTWH(412.5, 0, 0, 640.8)),
      ];
      for (final (body, hinge) in cases) {
        for (final h in Handedness.values) {
          final base = CalcHingeSplitLayout.of(body, hinge, h);
          // 깊이 0은 기본값과 같다.
          expect(
            CalcHingeSplitLayout.of(body, hinge, h, topGestureDepth: 0).keypad,
            base.keypad,
          );
          for (final depth in [0.5, 4.2, 12.2, 24.0]) {
            final l = CalcHingeSplitLayout.of(
              body,
              hinge,
              h,
              topGestureDepth: depth,
            );
            final reason = '$body $h depth=$depth $l';
            expect(l.shortHandPanel, base.shortHandPanel, reason: reason);
            expect(
              l.keypad.top,
              greaterThanOrEqualTo(depth - 0.001),
              reason: reason,
            );
            // 키패드는 그대로 본체 아래·같은 패널에 붙고, LCD·기록은 바뀌지 않는다.
            expect(l.keypad.bottom, moreOrLessEquals(body.height));
            expect(l.keypad.left, moreOrLessEquals(base.keypad.left));
            expect(l.lcd, base.lcd, reason: reason);
            expect(l.history, base.history, reason: reason);
            if (!base.shortHandPanel || base.keypad.top >= depth) {
              // 키패드가 이미 영역 아래면(세로형 — LCD가 위에 있다, 또는 키 하한으로 줄인 키패드) 바뀌지 않는다.
              expect(
                l.keypad,
                rectMoreOrLessEquals(base.keypad),
                reason: reason,
              );
            } else {
              // 높이에 묶인 키패드는 영역 아랫변부터 본체 아래까지다.
              expect(
                l.keypad.top,
                moreOrLessEquals(depth, epsilon: 0.001),
                reason: reason,
              );
            }
          }
        }
      }
      // 비유한·음수 깊이는 0으로 본다.
      for (final depth in [double.nan, double.infinity, -5.0]) {
        final l = CalcHingeSplitLayout.of(
          const Size(624, 320),
          const Rect.fromLTWH(312, 0, 0, 320),
          Handedness.right,
          topGestureDepth: depth,
        );
        expect(l.keypad.top, moreOrLessEquals(0), reason: '$depth');
      }
    });

    test('세로 접힘선: 위 제스처 영역 깊이가 있어도 창 높이를 키울 때 키가 줄지 않고 쓸 수 있는 크기 경계가 같다 (#172 R1)', () {
      double touchOf(CalcHingeSplitLayout l) =>
          KeypadMetrics.minKeyTouchHeightOf(
            l.keypad.size,
            KeypadArrangement.standard,
          );
      for (final width in [624.0, 825.0]) {
        for (final h in Handedness.values) {
          for (final depth in [4.2, 12.2, 24.0, 60.0]) {
            var last = 0.0;
            for (var height = 150.0; height <= 700; height += 0.5) {
              final body = Size(width, height);
              final hinge = Rect.fromLTWH(width / 2, 0, 0, height);
              final base = CalcHingeSplitLayout.of(body, hinge, h);
              final l = CalcHingeSplitLayout.of(
                body,
                hinge,
                h,
                topGestureDepth: depth,
              );
              final reason = '$width×$height $h depth=$depth';
              final touch = touchOf(l);
              expect(touch, greaterThanOrEqualTo(last - 0.01), reason: reason);
              last = touch;
              // 쓸 수 있는 크기(16dp) 판정은 깊이 0과 같다.
              expect(
                touch >= CalcTheme.keyTouchHeightUsableMin,
                touchOf(base) >= CalcTheme.keyTouchHeightUsableMin,
                reason: reason,
              );
              expect(l.keypad.bottom, moreOrLessEquals(height), reason: reason);
              // 키패드 윗변은 영역 아랫변 이상이거나(쓸 수 있는 크기를 지키려고 덜 비운 경우) 키가 쓸 수 있는 크기 근처다.
              if (l.shortHandPanel && l.keypad.top < depth - 0.01) {
                expect(
                  touch,
                  lessThan(CalcTheme.keyTouchHeightUsableMin + 0.05),
                  reason: reason,
                );
              }
            }
          }
        }
      }
    });

    test(
      '세로 접힘선: 깊이가 활성 LCD 최소 높이 + 간격(120dp) 이상이면(가정 밖) 세로형으로 돌아간다 (#172 R2)',
      () {
        // 실측 최대 깊이는 4.2dp라 이런 기기는 없다고 본다(CalcHingeSplitLayout 문서). 깊이만큼 비운 키패드가 세로형보다 키가
        // 작아지면 LCD가 손 쪽 패널로 돌아오고, 세로형 키패드 윗변(120dp)은 영역 안에 든다 — 의도한 동작으로 고정한다.
        const body = Size(624, 320);
        const hinge = Rect.fromLTWH(312, 0, 0, 320);
        final l = CalcHingeSplitLayout.of(
          body,
          hinge,
          Handedness.right,
          topGestureDepth: 125,
        );
        expect(l.shortHandPanel, isFalse);
        expect(
          l,
          isA<CalcHingeSplitLayout>().having(
            (l) => l.keypad.top,
            'keypad.top',
            moreOrLessEquals(
              CalcTheme.screenLcdMinHeight + CalcTheme.screenLcdKeypadGap,
            ),
          ),
        );
        expect(
          CalcHingeSplitLayout.of(body, hinge, Handedness.right).keypad.top,
          lessThan(1),
        );
      },
    );

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
        for (final r in [l.lcd, l.keypad, ?l.history]) {
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
      expect(l.lcd, mirrorIn(body, r.lcd));
      expect(l.keypad, mirrorIn(body, r.keypad));
      expect(l.history, mirrorIn(body, r.history!));
    });

    test('가로 접힘선: 본체 안, 겹침 없음, 접힘선 띠에 걸치지 않음 (극단 크기 포함)', () {
      for (final (body, hinge) in [
        (const Size(825, 593), const Rect.fromLTWH(0, 304.5, 825, 0)),
        (const Size(825, 609), const Rect.fromLTWH(0, 304.5, 825, 0)),
        (const Size(685, 777), const Rect.fromLTWH(0, 380.5, 685, 0)),
        (const Size(395, 934), const Rect.fromLTWH(0, 463, 395, 0)),
        (const Size(360, 700), const Rect.fromLTWH(0, 300, 360, 0)),
        (const Size(800, 600), const Rect.fromLTWH(0, 40, 800, 0)),
        (const Size(800, 600), const Rect.fromLTWH(0, 590, 800, 0)),
        (const Size(1184, 744), const Rect.fromLTWH(0, 360, 1184, 34)),
        (const Size(40, 40), const Rect.fromLTWH(0, 20, 40, 0)),
        (Size.zero, Rect.zero),
      ]) {
        for (final h in Handedness.values) {
          final l = CalcTabletopLayout.of(body, hinge, h);
          final reason = '$body $hinge $h $l';
          final rects = [l.lcd, l.keypad, ?l.history];
          expectSane(body, rects, reason);
          for (final r in rects) {
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

    test('가로 접힘선: 키패드는 아래 패널 폭 전체·본체 아래이고, 배열은 키가 큰 쪽이다 (#143 — 폭 상한 없음)', () {
      for (var width = 300.0; width <= 1600; width += 73) {
        for (var height = 500.0; height <= 1400; height += 89) {
          final body = Size(width, height);
          final hinge = Rect.fromLTWH(0, height / 2, width, 0);
          final lower = Size(width, height / 2 - CalcTheme.screenHingeMargin);
          for (final h in Handedness.values) {
            final l = CalcTabletopLayout.of(body, hinge, h);
            final reason = '$body $h $l';
            expect(
              l.keypadArrangement,
              KeypadMetrics.preferredArrangementFor(lower),
              reason: reason,
            );
            expect(l.keypad.left, 0, reason: reason);
            expect(l.keypad.width, moreOrLessEquals(width), reason: reason);
            expect(l.keypad.bottom, moreOrLessEquals(height), reason: reason);
            expect(
              l.keypad.size,
              sizeMoreOrLessEquals(
                KeypadMetrics.fitSize(lower, l.keypadArrangement),
              ),
              reason: reason,
            );
            expect(
              l.numbersOnLeft,
              l.keypadArrangement == KeypadArrangement.wide && !h.keypadOnRight,
              reason: reason,
            );
          }
        }
      }
    });

    test('가로 접힘선·넓은 배열: 위 패널은 가로형의 위 띠처럼 기록 | 활성 LCD로 나뉜다 (Fold 가로 고정값)', () {
      // Fold 가로 본체 825×609(인셋 24/24), 접힘선 304.5: 위 패널 296.5, 아래 패널 296.5 → 넓은 배열 825×267(폭에 묶임).
      const body = Size(825, 609);
      const hinge = Rect.fromLTWH(0, 304.5, 825, 0);
      const block = 825 / 2.06;
      final r = CalcTabletopLayout.of(body, hinge, Handedness.right);
      expect(r.keypadArrangement, KeypadArrangement.wide);
      expect(
        r.keypad,
        rectMoreOrLessEquals(
          const Rect.fromLTRB(0, 342, 825, 609),
          epsilon: 0.1,
        ),
      );
      expect(
        r.lcd,
        rectMoreOrLessEquals(
          const Rect.fromLTRB(825 - block, 296.5 - block / 1.75, 825, 296.5),
        ),
      );
      expect(
        r.history,
        rectMoreOrLessEquals(const Rect.fromLTWH(0, 0, block, 296.5)),
      );
      // 왼손잡이는 좌우 대칭이고, 키패드는 그대로(숫자부만 왼쪽)
      final l = CalcTabletopLayout.of(body, hinge, Handedness.left);
      expect(l.numbersOnLeft, isTrue);
      expect(l.keypad, r.keypad);
      expect(l.lcd, rectMoreOrLessEquals(mirrorIn(body, r.lcd)));
      expect(l.history, rectMoreOrLessEquals(mirrorIn(body, r.history!)));
    });

    test('가로 접힘선·넓은 배열: 위 패널이 낮으면 가로형처럼 기록 없이 활성 LCD가 폭 전체다', () {
      // 위 패널 120 < 기록 문턱 128 → 기록 없음, 활성 LCD 825×120(접힘선 쪽)
      const body = Size(825, 380);
      const hinge = Rect.fromLTWH(0, 128, 825, 0);
      final l = CalcTabletopLayout.of(body, hinge, Handedness.right);
      expect(l.keypadArrangement, KeypadArrangement.wide);
      expect(l.history, isNull);
      expect(l.lcd, rectMoreOrLessEquals(const Rect.fromLTWH(0, 0, 825, 120)));
    });

    test('가로 접힘선·실물 배열: 위 패널 맨 위가 활성 LCD, 그 아래가 기록 영역이다 (Flip 고정값)', () {
      // Flip 내부 본체 395×934(인셋 32/24), 접힘선 463: 위 패널 455 → 활성 LCD 395×225.7(폭 / 1.75), 간격 8, 기록 221.3.
      // 아래 패널 463 → 실물 배열 키패드 395×463(높이에 묶임).
      const body = Size(395, 934);
      const hinge = Rect.fromLTWH(0, 463, 395, 0);
      for (final h in Handedness.values) {
        final l = CalcTabletopLayout.of(body, hinge, h);
        expect(l.keypadArrangement, KeypadArrangement.standard, reason: '$h');
        expect(l.numbersOnLeft, isFalse, reason: '$h');
        expect(
          l.keypad,
          rectMoreOrLessEquals(const Rect.fromLTRB(0, 471, 395, 934)),
          reason: '$h',
        );
        expect(
          l.lcd,
          rectMoreOrLessEquals(const Rect.fromLTWH(0, 0, 395, 395 / 1.75)),
          reason: '$h',
        );
        expect(
          l.history,
          rectMoreOrLessEquals(
            const Rect.fromLTRB(0, 395 / 1.75 + 8, 395, 455),
          ),
          reason: '$h',
        );
      }
    });

    test('가로 접힘선·실물 배열: 기록이 최소 높이에 못 미치면 기록 없이 활성 LCD가 위 패널을 상한 높이까지 쓴다', () {
      // 폭 404: 활성 LCD 404 / 1.75 = 230.9. 위 패널이 230.9 + 8 + 112 = 350.9 이상이어야 기록을 둔다.
      const width = 404.0;
      const lcdHeight = width / 1.75;
      const threshold =
          lcdHeight +
          CalcTheme.screenLcdHistoryGap +
          CalcTheme.screenHistoryBelowLcdMinHeight;
      CalcTabletopLayout at(double upper) => CalcTabletopLayout.of(
        Size(width, upper + 16 + 520),
        Rect.fromLTWH(0, upper + 8, width, 0),
        Handedness.right,
      );
      final withHistory = at(threshold);
      expect(withHistory.keypadArrangement, KeypadArrangement.standard);
      expect(withHistory.history, isNotNull);
      expect(
        withHistory.history!.height,
        moreOrLessEquals(CalcTheme.screenHistoryBelowLcdMinHeight),
      );
      expect(withHistory.lcd.height, moreOrLessEquals(lcdHeight));
      final without = at(threshold - 0.5);
      expect(without.history, isNull);
      expect(
        without.lcd,
        rectMoreOrLessEquals(
          Rect.fromLTWH(0, 0, width, LcdFontSizes.heightAtMaxLineFont),
        ),
      );
      // 위 패널이 상한 높이보다 낮으면 LCD는 위 패널 전체다
      expect(
        at(200).lcd,
        rectMoreOrLessEquals(const Rect.fromLTWH(0, 0, width, 200)),
      );
    });

    test('가로 접힘선: 음수·비유한 크기는 0으로 본다', () {
      for (final body in const [
        Size(double.nan, double.nan),
        Size(-10, -10),
        Size(double.infinity, 500),
      ]) {
        final l = CalcTabletopLayout.of(
          body,
          const Rect.fromLTWH(0, double.nan, 500, 0),
          Handedness.right,
        );
        for (final r in [l.lcd, l.keypad, ?l.history]) {
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
  });
}
