import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/history_panel.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/korean_locale.dart';
import '../support/screen_arrangement.dart';
import '../support/semantics_order.dart';

/// 가로형 배치 (#142) — 아래 넓은 키패드 배열, 위 띠 전체에 LCD(넓은 계산 영역, #284).
/// 규칙은 `CalcTheme` "가로형 배치" 절, 배치 계산은 [CalcLandscapeLayout].

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));

/// 설정 키(ON, #190)
final _settingsKey = find.byKey(CalcKeyButton.keycapKeyOf(settingsKey));
final _history = find.byKey(HistoryPanel.panelKey);

/// [size] 창·[padding] 인셋으로 [CalculatorScreen]을 띄운다.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
  double textScale = 1.0,
  Handedness handedness = Handedness.right,
  List<DisplayFeature> displayFeatures = const [],
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  tester.view.displayFeatures = displayFeatures;
  addTearDown(tester.view.resetDisplayFeatures);
  SharedPreferences.setMockInitialValues({
    HandednessNotifier.storageKey: handedness.storageValue,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
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
            textScaler: TextScaler.linear(textScale),
            displayFeatures: displayFeatures,
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return container;
}

/// 창·인셋에서 본체 영역 (화면 좌표)
Rect _bodyRectOf(Size window, EdgeInsets padding) => Rect.fromLTRB(
  padding.left + CalcTheme.screenPadding,
  padding.top + CalcTheme.screenPadding,
  window.width - padding.right - CalcTheme.screenPadding,
  window.height - padding.bottom - CalcTheme.screenPadding,
);

Rect _keyRect(WidgetTester tester, CalcKeyId id) =>
    tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id)));

void main() {
  group('가로형 배치: 화면 크기 × 손잡이', () {
    // 가로로 넓은 창 (Android 태블릿: 상태 표시줄 24·작업 표시줄 48, iPad: 상태 표시줄 24·홈 표시줄 20)
    const windows = [
      (Size(1280, 800), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(960, 600), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(1024, 768), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(1194, 834), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(1366, 1024), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(2000, 1400), EdgeInsets.zero),
      (Size(1280, 500), EdgeInsets.zero), // 낮은 데스크톱 창 — LCD 135.5dp
      // 가로 화면 좌우 인셋 (카메라 컷아웃·측면 내비게이션 바)
      (Size(1280, 800), EdgeInsets.only(left: 32, top: 24, right: 48)),
    ];

    for (final (size, padding) in windows) {
      for (final handedness in Handedness.values) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '${size.width}×${size.height}·${handedness.name}·배율 $scale'
            '${padding.horizontal > 0 ? '·좌우 인셋' : ''}',
            (tester) async {
              await _pump(
                tester,
                size: size,
                padding: padding,
                textScale: scale,
                handedness: handedness,
              );
              expect(tester.takeException(), isNull);
              expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));
              expect(drawnArrangementOf(tester), DrawnArrangement.landscape);

              final body = _bodyRectOf(size, padding);
              final lcd = tester.getRect(_lcd);
              final keypad = tester.getRect(_keypad);
              final keypadWidget = tester.widget<CalcKeypad>(
                find.byType(CalcKeypad),
              );

              // 키패드: 넓은 배열, 본체 폭 전체·본체 아래, 세로 한계 이하 (키가 세로로 길어지지 않는다)
              expect(keypadWidget.arrangement, KeypadArrangement.wide);
              expect(keypadWidget.numbersOnLeft, !handedness.keypadOnRight);
              expect(keypad.left, moreOrLessEquals(body.left));
              expect(keypad.right, moreOrLessEquals(body.right));
              expect(keypad.bottom, moreOrLessEquals(body.bottom));
              expect(
                keypad.height,
                lessThanOrEqualTo(
                  KeypadMetrics.fitSize(
                        Size(keypad.width, double.infinity),
                        KeypadArrangement.wide,
                      ).height +
                      0.01,
                ),
              );
              // 숫자부는 주로 쓰는 손 쪽 블록이다.
              final number = _keyRect(tester, CalcKeyId.num7);
              final function = _keyRect(tester, CalcKeyId.sin);
              expect(
                handedness.keypadOnRight
                    ? number.left > function.right
                    : number.right < function.left,
                isTrue,
              );

              // LCD는 키패드 바로 위(간격 8)이고 본체 폭 전체다 — 넓은 계산 영역, 기록 영역은 없다 (#284).
              expect(
                keypad.top - lcd.bottom,
                moreOrLessEquals(CalcTheme.screenLcdKeypadGap),
              );
              // 그린 영역이 배치 계산과 같다.
              final expected = CalcLandscapeLayout.of(body.size, handedness);
              expect(
                lcd,
                rectMoreOrLessEquals(expected.lcd.shift(body.topLeft)),
              );
              expect(
                keypad,
                rectMoreOrLessEquals(expected.keypad.shift(body.topLeft)),
              );
              expect(_history, findsNothing);
              expect(lcd.left, moreOrLessEquals(body.left));
              expect(lcd.right, moreOrLessEquals(body.right));

              // 상단 띠가 없어(#190) LCD는 본체 윗변부터이고, 키패드가 남긴 높이를 모두 받는다 — LCD 위에 빈 곳이 없다 (#232).
              expect(expected.lcd.top, moreOrLessEquals(0));
              expect(lcd.top, moreOrLessEquals(body.top));
              expect(
                expected.lcd.bottom + CalcTheme.screenLcdKeypadGap,
                moreOrLessEquals(expected.keypad.top),
              );
              // 설정 키(ON)는 키패드 안이고 눌린다.
              final on = tester.getRect(_settingsKey);
              expect(keypad.inflate(0.01).contains(on.topLeft), isTrue);
              expect(keypad.inflate(0.01).contains(on.bottomRight), isTrue);
              expect(_settingsKey.hitTestable(), findsOneWidget);
            },
          );
        }
      }
    }
  });

  group('낮은 가로형 — 키패드가 높이를 다 가져가는 창 (#142)', () {
    for (final (size, padding) in const [
      (Size(1280, 400), EdgeInsets.zero), // LCD 112dp(LCD 최소 높이)
      (Size(844, 390), EdgeInsets.only(left: 47, right: 47, bottom: 21)),
      (Size(932, 430), EdgeInsets.only(left: 59, right: 59, bottom: 21)),
    ]) {
      testWidgets(
        '${size.width}×${size.height}: LCD가 본체 폭 전체이고 낮으며(최소 높이 ~ 128dp 미만) 기록 영역은 없다',
        (tester) async {
          await _pump(
            tester,
            size: size,
            padding: padding,
            handedness: Handedness.left,
          );
          expect(tester.takeException(), isNull);
          expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
          final body = _bodyRectOf(size, padding);
          final lcd = tester.getRect(_lcd);
          expect(lcd.left, moreOrLessEquals(body.left));
          expect(lcd.right, moreOrLessEquals(body.right));
          // 1280×400·844×390은 LCD 최소 높이(112), 932×430은 126.7dp다.
          expect(
            lcd.height,
            inInclusiveRange(CalcTheme.screenLcdMinHeight - 0.01, 128),
          );
          expect(_history, findsNothing);
          // 숨긴 기록 영역은 스크린리더에도 없다.
          final handle = tester.ensureSemantics();
          await tester.pump();
          expect(
            find.bySemanticsLabel(const EnSemanticStrings().historyEmpty),
            findsNothing,
          );
          handle.dispose();
        },
      );
    }
  });

  testWidgets('태블릿 가로: 상단 띠 없이 LCD가 본체 윗변부터 키패드 위까지, 본체 폭 전체다 (#190, #284)', (
    tester,
  ) async {
    // 10인치 Android 1280×800: 키패드가 넓은 배열 세로 한계(409.1)에 닿아 남는 높이를 모두 LCD가 받는다.
    const size = Size(1280, 800);
    const padding = EdgeInsets.only(top: 24, bottom: 48);
    await _pump(tester, size: size, padding: padding);
    final body = _bodyRectOf(size, padding);
    final lcd = tester.getRect(_lcd);
    final keypad = tester.getRect(_keypad);
    expect(_history, findsNothing);
    expect(lcd.top, moreOrLessEquals(body.top));
    expect(lcd.left, moreOrLessEquals(body.left));
    expect(lcd.right, moreOrLessEquals(body.right));
    expect(lcd.height, moreOrLessEquals(294.9, epsilon: 0.1));
    expect(
      keypad.top - lcd.bottom,
      moreOrLessEquals(CalcTheme.screenLcdKeypadGap),
    );
  });

  testWidgets('한국어 기기: 책 자세의 빈 기록 영역은 "계산 기록 없음"으로 읽힌다 (#285 전까지)', (
    tester,
  ) async {
    useKoreanLocale(tester);
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      size: const Size(841, 701),
      displayFeatures: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(420.5, 0, 0, 701),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        ),
      ],
    );
    expect(
      tester.getSemantics(_history),
      isSemantics(label: const KoSemanticStrings().historyEmpty),
    );
    handle.dispose();
  });

  Finder keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

  for (final handedness in Handedness.values) {
    testWidgets(
      '스크린리더 읽기 순서: LCD → 키패드(함수부·설정 키 → 숫자부), 기록 없음 (${handedness.name})',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          size: const Size(1280, 800),
          handedness: handedness,
        );
        final order = semanticsTraversalOrder(tester);
        final lcd = semanticsIndexIn(tester, order, _lcd);
        final function = semanticsIndexIn(tester, order, keycap(CalcKeyId.sin));
        final number = semanticsIndexIn(tester, order, keycap(CalcKeyId.num7));
        // 설정 키(ON)는 키패드의 상단 조작부에 있어 함수부 구역과 함께 읽힌다 (#190).
        final on = semanticsIndexIn(tester, order, _settingsKey);
        expect(lcd, lessThan(on));
        expect(lcd, lessThan(function));
        expect(function, lessThan(number));
        expect(on, lessThan(number));
        // 기록 영역이 없으니 빈 기록 노드도 읽지 않는다(#284).
        expect(
          find.bySemanticsLabel(const EnSemanticStrings().historyEmpty),
          findsNothing,
        );
        handle.dispose();
      },
    );
  }

  // 순서 키는 모든 배치에 붙는다 — 계산기를 연 사용자가 먼저 듣는 것이 LCD다(#142). 설정은 키패드의 ON 키다(#190).
  for (final (name, size, features) in [
    ('세로형 390×844', const Size(390, 844), const <DisplayFeature>[]),
    (
      '세로 접힘선 841×701',
      const Size(841, 701),
      const [
        DisplayFeature(
          bounds: Rect.fromLTWH(420.5, 0, 0, 701),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        ),
      ],
    ),
  ]) {
    testWidgets('스크린리더 읽기 순서 ($name): LCD → 키패드(설정 키 포함)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, size: size, displayFeatures: features);
      final order = semanticsTraversalOrder(tester);
      final lcd = semanticsIndexIn(tester, order, _lcd);
      final key = semanticsIndexIn(tester, order, keycap(CalcKeyId.shift));
      final on = semanticsIndexIn(tester, order, _settingsKey);
      final number = semanticsIndexIn(tester, order, keycap(CalcKeyId.num7));
      expect(lcd, lessThan(key));
      expect(key, lessThan(on));
      expect(on, lessThan(number));
      handle.dispose();
    });
  }

  group('작은 가로형 창의 큰 글자 배율', () {
    for (final (size, padding) in const [
      (Size(411, 400), EdgeInsets.only(top: 24)),
      // Android 16 폰 에뮬레이터 실측 분할 창(#137 R1): 1/3 위·아래(3버튼), 320×568dp 화면의 1/2 위
      (Size(411.43, 304.76), EdgeInsets.only(top: 24)),
      (Size(411.43, 304.76), EdgeInsets.only(bottom: 48)),
      (Size(320, 278.86), EdgeInsets.only(top: 24)),
      (Size(640, 360), EdgeInsets.only(top: 24)),
      (Size(568, 320), EdgeInsets.zero),
      (Size(844, 390), EdgeInsets.only(left: 47, right: 47, bottom: 21)),
      (Size(700, 420), EdgeInsets.zero),
    ]) {
      for (final scale in const [2.0, 3.0]) {
        for (final handedness in Handedness.values) {
          testWidgets(
            '${size.width}×${size.height}·배율 $scale·${handedness.name}: 넘치지 않고 대화상자도 열린다',
            (tester) async {
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              await _pump(
                tester,
                size: size,
                padding: padding,
                textScale: scale,
                handedness: handedness,
              );
              expect(tester.takeException(), isNull);
              expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
              await tester.tap(_settingsKey);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  group('CalcLandscapeLayout', () {
    test('10인치 Android 가로(본체 1264×712) 오른손잡이 배치 고정값', () {
      final l = CalcLandscapeLayout.of(const Size(1264, 712), Handedness.right);
      const block = 1264 / 2.06;
      const keypadHeight = block / 1.5; // 넓은 배열 세로 한계 409.1
      // LCD: 키패드가 세로 한계에 닿아 남는 높이 712 − 8 − 409.1 = 294.9를 모두 받는다(목표 199.4) — 상단 띠가 없어
      // 본체 윗변부터다(#190). 본체 폭 전체다(#284 — 전에는 숫자부 위 블록 폭이고 함수부 위가 기록 영역이었다).
      const lcdHeight = 712 - 8 - keypadHeight;
      expect(
        l.lcd,
        rectMoreOrLessEquals(const Rect.fromLTWH(0, 0, 1264, lcdHeight)),
      );
      expect(
        l.keypad,
        rectMoreOrLessEquals(
          const Rect.fromLTWH(0, 712 - keypadHeight, 1264, keypadHeight),
        ),
      );
      expect(l.numbersOnLeft, isFalse);
    });

    test('모든 영역은 본체 안에 있고 서로 겹치지 않으며, 높이 합계가 본체 높이와 같다', () {
      for (final body in const [
        Size(1264, 712),
        Size(1350, 964),
        Size(1984, 1384),
        Size(734, 353),
        Size(395, 380),
        Size(304, 184),
        Size(40, 40),
        Size(0, 0),
      ]) {
        for (final h in Handedness.values) {
          final l = CalcLandscapeLayout.of(body, h);
          final bounds = (Offset.zero & body).inflate(0.01);
          for (final r in [l.lcd, l.keypad]) {
            expect(r.width, greaterThanOrEqualTo(0), reason: '$body $h $l');
            expect(r.height, greaterThanOrEqualTo(0), reason: '$body $h $l');
            expect(
              bounds.contains(r.topLeft) && bounds.contains(r.bottomRight),
              isTrue,
              reason: '$body $h $l',
            );
          }
          expect(l.lcd.overlaps(l.keypad), isFalse, reason: '$body $h $l');
          // LCD는 본체 윗변부터 키패드 위 간격까지다 (#190 — 상단 띠가 없다).
          expect(l.lcd.top, moreOrLessEquals(0), reason: '$body $h $l');
          expect(l.keypad.bottom, moreOrLessEquals(body.height));
        }
      }
    });

    test('왼손잡이 배치는 오른손잡이 배치의 좌우 대칭이다 — LCD는 같고 숫자부만 옮겨 간다', () {
      for (final body in const [
        Size(1264, 712),
        Size(1350, 964),
        Size(734, 353),
      ]) {
        final r = CalcLandscapeLayout.of(body, Handedness.right);
        final l = CalcLandscapeLayout.of(body, Handedness.left);
        Rect mirror(Rect x) => Rect.fromLTRB(
          body.width - x.right,
          x.top,
          body.width - x.left,
          x.bottom,
        );
        expect(l.lcd, rectMoreOrLessEquals(mirror(r.lcd)), reason: '$body');
        expect(l.lcd, rectMoreOrLessEquals(r.lcd), reason: '$body');
        expect(l.keypad, rectMoreOrLessEquals(mirror(r.keypad)));
        expect(l.numbersOnLeft, isTrue);
        expect(r.numbersOnLeft, isFalse);
      }
    });

    /// 본체 [body] 가로형의 LCD 줄 글자 (배율 반영 전)
    double lineFont(CalcLandscapeLayout l) =>
        LcdFontSizes.forSize(l.lcd.size, TextScaler.noScaling).input;

    /// 앞 배치 [p] → 다음 배치 [l]로 창이 조금 커질 때의 연속성 (#142 R1·R2): 키패드는 줄지 않고, LCD 높이는 한 걸음([step])
    /// 넘게 바뀌지 않으며, LCD 줄 글자는 한 걸음에 3%보다 많이 바뀌지 않는다. (#284 전에는 기록 영역이 생기고 없어지는 경계에서
    /// 활성 LCD 폭이 블록 폭으로 바뀌어 글자가 그 문턱만큼 줄 수 있었다 — 이제 LCD는 언제나 본체 폭 전체다.)
    void expectContinuous(
      CalcLandscapeLayout p,
      CalcLandscapeLayout l,
      double step,
      String reason,
    ) {
      expect(
        l.keypad.height,
        greaterThanOrEqualTo(p.keypad.height - 1e-6),
        reason: reason,
      );
      expect(
        (l.lcd.height - p.lcd.height).abs(),
        lessThanOrEqualTo(step + 1e-6),
        reason: reason,
      );
      final before = lineFont(p);
      final after = lineFont(l);
      expect(
        (after - before).abs(),
        lessThanOrEqualTo(before * 0.03 + 1e-6),
        reason: reason,
      );
    }

    test('본체 높이를 늘릴 때 키는 줄지 않고 LCD 높이·글자가 연속이다', () {
      for (final width in const [1350.0, 1264.0, 984.0, 640.0, 395.0]) {
        CalcLandscapeLayout? previous;
        for (var height = 150.0; height <= 1400; height += 0.5) {
          final l = CalcLandscapeLayout.of(
            Size(width, height),
            Handedness.right,
          );
          final p = previous;
          if (p != null) {
            expectContinuous(p, l, 0.5, '$width×$height $p → $l');
          }
          previous = l;
        }
      }
    });

    test('본체 폭을 늘릴 때도 키는 줄지 않고 LCD 높이·글자가 연속이다 (#142 R1·R2)', () {
      // R1 재현: 본체 높이 426·폭 461 → 461.5에서 활성 LCD가 228.8 → 128dp로 줄었다.
      // R2 재현: 본체 높이 584·폭 626 → 626.5에서 줄 글자가 49.5 → 23.6dp로 줄었다.
      for (final height in const [
        330.0,
        380.0,
        426.0,
        450.0,
        500.0,
        584.0,
        712.0,
        964.0,
      ]) {
        CalcLandscapeLayout? previous;
        for (var width = 300.0; width <= 2000; width += 0.5) {
          final l = CalcLandscapeLayout.of(
            Size(width, height),
            Handedness.right,
          );
          final p = previous;
          if (p != null) {
            expectContinuous(p, l, 0.5, '$width×$height $p → $l');
          }
          previous = l;
        }
      }
    });

    test('LCD는 언제나 본체 폭 전체이고, 키패드와 간격이 쓰지 않는 높이를 모두 받는다 (#190, #284)', () {
      for (var height = 150.0; height <= 1400; height += 7) {
        for (final width in const [
          1984.0,
          1350.0,
          1264.0,
          984.0,
          640.0,
          626.0,
          461.0,
          395.0,
        ]) {
          for (final h in Handedness.values) {
            final l = CalcLandscapeLayout.of(Size(width, height), h);
            final reason = '$width×$height $h $l';
            expect(l.lcd.left, moreOrLessEquals(0), reason: reason);
            expect(l.lcd.width, moreOrLessEquals(width), reason: reason);
            expect(l.lcd.top, moreOrLessEquals(0), reason: reason);
            expect(
              l.lcd.height,
              moreOrLessEquals(
                height - CalcTheme.screenLcdKeypadGap - l.keypad.height,
              ),
              reason: reason,
            );
          }
        }
      }
    });

    test('음수·비유한 크기는 0으로 본다', () {
      for (final body in const [
        Size(double.nan, double.nan),
        Size(-10, -10),
        Size(double.infinity, 500),
      ]) {
        final l = CalcLandscapeLayout.of(body, Handedness.right);
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
  });

  // 실제 번들 글꼴로 키 각인 크기를 잰다. 글꼴 등록은 이후 테스트에도 남으므로 파일 맨 끝 그룹에 둔다.
  group('태블릿 가로: 실제 글꼴 기준 LCD 줄 글자', () {
    setUpAll(loadBundledFonts);

    testWidgets('12.9인치 iPad 가로: LCD 줄 글자는 키 메인 각인보다 크다', (tester) async {
      await _pump(
        tester,
        size: const Size(1366, 1024),
        padding: const EdgeInsets.only(top: 24, bottom: 20),
      );
      final lineFont = tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('lcd-input-text')),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style
          .fontSize!;
      final keyFont = tester
          .widgetList<CalcKeyButton>(find.byType(CalcKeyButton))
          .first
          .mainLabelFontSize!;
      // LCD 1350×519.1(위 띠 전체, #284 — #284 전 활성 LCD 655×519.1. #232 전에는 줄 글자 상한 높이 655×273.5, #189 전에는 블록 폭의 실물 비율 높이
      // 655×374.5·54.7dp) — 줄 글자는 상한 40dp. 키 메인 각인은 약 29.9dp다(#264 — 상한 16.5dp를 없앴다).
      expect(keyFont, greaterThan(16.5));
      expect(lineFont, greaterThan(keyFont));
      expect(
        lineFont,
        moreOrLessEquals(
          LcdFontSizes.forSize(
            tester.getSize(_lcd),
            TextScaler.noScaling,
          ).input,
          epsilon: 0.5,
        ),
      );
    });
  });
}
