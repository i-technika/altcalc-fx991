import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/settings_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
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

import '../support/bundled_fonts.dart';
import '../support/korean_locale.dart';
import '../support/screen_arrangement.dart';

/// 짧은 창(분할 화면·팝업 창·가로로 돈 폰)의 배치와 "창이 너무 작다" 안내 (#38).
/// 규칙은 `CalcTheme` "짧은 창" 절.

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));

/// 설정 키(ON, #190)
final _settings = find.byKey(CalcKeyButton.keycapKeyOf(settingsKey));
final _notice = find.byKey(WindowTooSmallNotice.noticeKey);

/// [size] 창·[padding] 인셋으로 [CalculatorScreen]을 띄운다. 같은 [container]로 다시 부르면 창 크기만 바꿔
/// 다시 그린다(LCD·키패드 element는 그대로다).
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
  double textScale = 1.0,
  Handedness handedness = Handedness.right,
  List<DisplayFeature> displayFeatures = const [],
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  tester.view.displayFeatures = displayFeatures;
  addTearDown(tester.view.resetDisplayFeatures);
  if (container == null) {
    SharedPreferences.setMockInitialValues({
      HandednessNotifier.storageKey: handedness.storageValue,
    });
    final prefs = await SharedPreferences.getInstance();
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
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return container;
}

/// 창·인셋에서 본체 크기 (화면 여백·인셋을 뺀 크기 — `CalculatorScreen`과 같은 계산, #141).
/// 이 파일의 화면은 제스처 영역을 주지 않으므로 아래 여백([CalcTheme.screenBottomMargin], #63)도 화면 여백이다.
Size _bodyOf(Size window, EdgeInsets padding) => Size(
  window.width - padding.horizontal - 2 * CalcTheme.screenPadding,
  window.height - padding.vertical - 2 * CalcTheme.screenPadding,
);

/// 키를 쓸 수 없을 만큼 작은 창 — 두 배치 모두 키가 [CalcTheme.keyTouchHeightUsableMin] 미만이다(가로형 8.8dp).
/// 미리보기 "작은 팝업 창" 프리셋과 같은 크기다.
const _tinyWindow = Size(320, 200);

/// 위아래 배치 키패드 크기
Size _stackedKeypadOf(Size body) =>
    Size(body.width, CalcScreenLayout.of(body).keypadHeight);

/// 위아래 배치로 그렸을 때의 가장 낮은 키 터치 높이 (dp)
double _stackedTouchOf(Size body) => KeypadMetrics.minKeyTouchHeightOf(
  _stackedKeypadOf(body),
  KeypadArrangement.standard,
);

/// 가로형으로 그렸을 때의 가장 낮은 키 터치 높이 (dp)
double _landscapeTouchOf(Size body) => KeypadMetrics.minKeyTouchHeightOf(
  CalcLandscapeLayout.of(body, Handedness.right).keypad.size,
  KeypadArrangement.wide,
);

/// 위아래 배치·가로형의 가장 낮은 키 셀 높이 (dp) — 화면이 배치를 고를 때 비교하는 값 (#142)
double _stackedCellOf(Size body) => KeypadMetrics.minKeyCellHeightOf(
  _stackedKeypadOf(body),
  KeypadArrangement.standard,
);
double _landscapeCellOf(Size body) => KeypadMetrics.minKeyCellHeightOf(
  CalcLandscapeLayout.of(body, Handedness.right).keypad.size,
  KeypadArrangement.wide,
);

/// 그린 키패드의 구역 배열
KeypadArrangement _drawnKeypadArrangement(WidgetTester tester) =>
    tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement;

/// 그린 키패드의 가장 낮은 키 셀 높이 (dp)
double _drawnCell(WidgetTester tester) => KeypadMetrics.minKeyCellHeightOf(
  tester.getSize(_keypad),
  _drawnKeypadArrangement(tester),
);

/// [id] 키의 화면 영역
Rect _keyRect(WidgetTester tester, CalcKeyId id) => tester.getRect(
  find.byWidgetPredicate((w) => w is CalcKeyButton && w.keyDef.id == id),
);

/// 그린 키(커서 패드 제외) 중 가장 낮은 터치 높이 (dp) — `CalcKeyButton`의 터치 영역 규칙
double _lowestDrawnTouch(WidgetTester tester) {
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
  }
  return lowest;
}

void main() {
  group('짧은 창은 키가 더 큰 가로형으로 그린다 (#38, #142)', () {
    // (창, 인셋, 그린 키 터치 하한 — CalcTheme "짧은 창" 절의 실측값을 내림)
    const cases = [
      (Size(411, 400), EdgeInsets.only(top: 24), 21.0), // 폰 분할 화면 위 (미리보기 프리셋)
      (Size(411, 420), EdgeInsets.only(bottom: 48), 21.0), // 폰 분할 화면 아래
      (Size(844, 390), EdgeInsets.only(left: 47, right: 47, bottom: 21), 37.0),
      (Size(640, 360), EdgeInsets.only(top: 24), 31.0),
      (Size(568, 320), EdgeInsets.zero, 29.0),
      (Size(360, 300), EdgeInsets.zero, 18.0), // 팝업 창
    ];
    for (final (size, padding, minTouch) in cases) {
      for (final handedness in Handedness.values) {
        testWidgets(
          '${size.width}×${size.height}·${handedness.name}: 가로형, 숫자부는 주로 쓰는 손 쪽',
          (tester) async {
            await _pump(
              tester,
              size: size,
              padding: padding,
              handedness: handedness,
            );
            expect(tester.takeException(), isNull);
            expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
            expect(_notice, findsNothing);

            // 짧은 창이다: 위아래 배치였다면 키가 일반 하한보다 낮고, 그린 가로형의 키가 그보다 크다.
            final body = _bodyOf(size, padding);
            final stackedTouch = _stackedTouchOf(body);
            expect(stackedTouch, lessThan(CalcTheme.keyTouchHeightFloor));
            final drawnTouch = _lowestDrawnTouch(tester);
            expect(drawnTouch, greaterThan(stackedTouch));
            expect(drawnTouch, greaterThanOrEqualTo(minTouch));
            // 배치를 고르는 계산값이 실제로 그린 키와 같다.
            expect(
              KeypadMetrics.minKeyTouchHeightOf(
                tester.getSize(_keypad),
                KeypadArrangement.wide,
              ),
              moreOrLessEquals(drawnTouch, epsilon: 0.01),
            );

            // 키패드는 본체 폭 전체·본체 아래에 붙고, LCD는 그 바로 위다.
            final keypad = tester.getRect(_keypad);
            final lcd = tester.getRect(_lcd);
            const p = CalcTheme.screenPadding;
            expect(keypad.left, moreOrLessEquals(padding.left + p));
            expect(
              keypad.right,
              moreOrLessEquals(size.width - padding.right - p),
            );
            expect(
              keypad.bottom,
              moreOrLessEquals(padding.top + p + body.height),
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
            // 위 띠가 낮아 기록 영역이 없고, 활성 LCD가 띠 폭 전체를 쓴다. 짧은 창에서도 최소 높이 아래로 줄지 않는다.
            expect(find.byKey(HistoryPanel.panelKey), findsNothing);
            expect(lcd.width, moreOrLessEquals(keypad.width));
            expect(
              lcd.height,
              greaterThanOrEqualTo(CalcTheme.screenLcdMinHeight - 0.01),
            );

            // 설정 키(ON, #190)는 키패드 안에서 눌린다.
            final button = tester.getRect(_settings);
            expect(_settings.hitTestable(), findsOneWidget);
            expect(keypad.inflate(0.01).contains(button.topLeft), isTrue);
            expect(keypad.inflate(0.01).contains(button.bottomRight), isTrue);
          },
        );
      }
    }

    testWidgets('가로 폰 844×390: 키에 높이를 주고 LCD는 띠 폭 전체·최소 높이다', (tester) async {
      const size = Size(844, 390);
      const padding = EdgeInsets.only(left: 47, right: 47, bottom: 21);
      await _pump(tester, size: size, padding: padding);
      final body = _bodyOf(size, padding);
      final lcd = tester.getSize(_lcd);
      expect(lcd.width, moreOrLessEquals(body.width));
      expect(lcd.height, moreOrLessEquals(CalcTheme.screenLcdMinHeight));
      // 위아래 배치의 두 배 가까이 키가 크다(CalcTheme "가로형 배치" 절 18.8 → 37.6dp).
      expect(_drawnCell(tester), greaterThan(_stackedCellOf(body) * 1.9));
    });
  });

  group('짧은 창의 설정 대화상자는 큰 글자 배율에서도 넘치지 않는다', () {
    // 제목을 고정하던 때(#72)는 360×300·배율 2.0에서 20dp, 320×260·배율 1.3에서 2.2dp 넘쳤다 — 이제 제목도
    // 선택지와 함께 스크롤하고 닫기 버튼만 고정한다.
    for (final size in const [Size(360, 300), Size(320, 260), Size(640, 260)]) {
      for (final textScale in const [1.3, 2.0]) {
        testWidgets('${size.width}×${size.height}·배율 $textScale', (
          tester,
        ) async {
          // 대화상자 경로는 화면 위쪽(View의 MediaQuery)에서 빌드되므로 기기 배율로 준다.
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final container = await _pump(
            tester,
            size: size,
            handedness: Handedness.left,
          );
          expect(_notice, findsNothing);
          await tester.tap(_settings);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // 닫기 버튼은 스크롤하지 않아도 누를 수 있고, 선택지는 스크롤해서 고른다.
          final close = find.byKey(HandednessDialog.closeKey);
          expect(close.hitTestable(), findsOneWidget);
          final right = find.byKey(
            HandednessDialog.optionKeyOf(Handedness.right),
          );
          await tester.ensureVisible(right);
          await tester.pumpAndSettle();
          // 선택지가 스크롤 영역보다 클 수 있다 — 스크롤 영역 안에 보이는 부분을 누른다.
          final viewport = tester.getRect(
            find
                .descendant(
                  of: find.byType(HandednessDialog),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          final visible = tester.getRect(right).intersect(viewport);
          expect(
            visible.height,
            greaterThan(CalcTheme.keyTouchHeightUsableMin),
          );
          await tester.tapAt(visible.center);
          await tester.pumpAndSettle();
          expect(container.read(handednessProvider), Handedness.right);
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(find.byType(HandednessDialog), findsNothing);
        });
      }
    }
  });

  group('짧은 창이어도 위아래 배치의 키가 더 크면 위아래 배치다', () {
    for (final (size, padding) in const [
      // 폰 분할 화면 위: 키 22.1dp — 가로형은 21.7dp (#190에서 상단 띠 최소 높이 12dp가 키패드로 가 위아래 배치가 이겼다.
      // 그 전 예시 412×520은 키 28.7dp로 일반 하한을 넘어 짧은 창이 아니다.)
      (Size(411, 420), EdgeInsets.only(top: 24)),
      // iPhone 4s 크기: 키 25.8dp로 일반 하한 미만이지만 가로형은 약 16.7dp. (#141 전의 예시 iPhone SE 1세대
      // 320×568은 맨 아래 광고 슬롯이 빠져 키 31.1dp로 일반 하한을 넘어 짧은 창이 아니다.)
      (Size(320, 480), EdgeInsets.only(top: 20)),
      // 좁고 낮은 팝업 창 — 가로형은 넓은 배열이 폭에 묶여 더 작다
      (Size(300, 420), EdgeInsets.zero),
    ]) {
      testWidgets('${size.width}×${size.height}', (tester) async {
        await _pump(
          tester,
          size: size,
          padding: padding,
          handedness: Handedness.left,
        );
        expect(tester.takeException(), isNull);
        expect(isStackedArrangement(tester), isTrue);
        expect(_notice, findsNothing);
        final body = _bodyOf(size, padding);
        final stackedTouch = _stackedTouchOf(body);
        expect(stackedTouch, lessThan(CalcTheme.keyTouchHeightFloor));
        expect(_landscapeCellOf(body), lessThanOrEqualTo(_stackedCellOf(body)));
        expect(
          _lowestDrawnTouch(tester),
          moreOrLessEquals(stackedTouch, epsilon: 0.01),
        );
      });
    }

    testWidgets('세로 폰은 가로형보다 키가 커 위아래 배치다', (tester) async {
      // 390×844: 위아래 42.4dp, 가로형 20.6dp (CalcTheme "짧은 창" 절)
      const size = Size(390, 844);
      const padding = EdgeInsets.only(top: 47, bottom: 34);
      await _pump(tester, size: size, padding: padding);
      expect(isStackedArrangement(tester), isTrue);
      final body = _bodyOf(size, padding);
      expect(_landscapeCellOf(body), lessThan(_stackedCellOf(body) / 2));
    });
  });

  group('접힘선이 있는 짧은 창 (#38 R1)', () {
    // 세로 접힘선: 접힘선 기준 배치(책 자세)는 키가 쓸 수 있는 크기(16dp) 이상이면 일반 하한(28dp) 미만이어도 쓴다(#143 —
    // 접힘선은 언제나 경계다). 손 쪽 패널이 짧아 세로형의 키가 일반 하한 미만이면 활성 LCD를 반대쪽 패널로 옮겨 키패드가
    // 패널 높이를 다 쓴다(#143 R1 사용자 결정) — 세로형 그대로면 LCD 최소 높이가 패널 높이를 먼저 가져가 키가 위아래 배치와
    // 같았다(640×360: 17.0dp, 700×392: 17.7dp).
    for (final (size, padding, hingeX, touch) in const [
      (Size(640, 360), EdgeInsets.only(top: 24), 320.0, 27.2),
      (Size(700, 392), EdgeInsets.only(top: 24, bottom: 24), 350.0, 27.88),
    ]) {
      for (final handedness in Handedness.values) {
        testWidgets(
          '${size.width}×${size.height} 세로 접힘선·${handedness.name}: 접힘선 기준 좌우 배치',
          (tester) async {
            final fold = DisplayFeature(
              bounds: Rect.fromLTWH(hingeX, 0, 0, size.height),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureFlat,
            );
            await _pump(
              tester,
              size: size,
              padding: padding,
              handedness: handedness,
              displayFeatures: [fold],
            );
            expect(tester.takeException(), isNull);
            expect(_notice, findsNothing);
            expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
            // 접힘선 기준 배치로 그렸다(대화상자를 접힘선 기준으로 나눌지가 배치 종류로 정해진다, #25·#129).
            expect(
              tester
                  .widget<SettingsLauncher>(find.byType(SettingsLauncher))
                  .arrangement,
              ScreenArrangement.hingeSplit,
            );
            final drawnTouch = _lowestDrawnTouch(tester);
            expect(drawnTouch, lessThan(CalcTheme.keyTouchHeightFloor));
            expect(
              drawnTouch,
              greaterThanOrEqualTo(CalcTheme.keyTouchHeightUsableMin),
            );
            expect(drawnTouch, moreOrLessEquals(touch, epsilon: 0.01));
            expect(
              drawnTouch,
              greaterThan(_stackedTouchOf(_bodyOf(size, padding))),
            );
            // 활성 LCD는 반대쪽 패널 맨 위(본체 윗변)다.
            final lcd = tester.getRect(_lcd);
            expect(
              lcd.top,
              moreOrLessEquals(padding.top + CalcTheme.screenPadding),
            );
            expect(
              handedness.keypadOnRight
                  ? lcd.right <= hingeX
                  : lcd.left >= hingeX,
              isTrue,
              reason: '$lcd',
            );
            // LCD·키패드·설정 키 어느 것도 접힘선(과 양쪽 간격)에 걸치지 않고, 키패드는 손 쪽 절반이다.
            const m = CalcTheme.screenHingeMargin - 0.01;
            for (final rect in [
              tester.getRect(_lcd),
              tester.getRect(_keypad),
              tester.getRect(_settings),
            ]) {
              expect(
                rect.right <= hingeX - m || rect.left >= hingeX + m,
                isTrue,
                reason: '$rect',
              );
            }
            final keypad = tester.getRect(_keypad);
            expect(
              handedness.keypadOnRight
                  ? keypad.left >= hingeX
                  : keypad.right <= hingeX,
              isTrue,
            );
          },
        );
      }
    }

    // #143 R1: 세로 접힘선이 있는 창도 높이를 키울 때 키가 크게 튀지 않는다. 책 자세가 쓸 수 있는 크기(16dp) 경계에서
    // 가로형(접힘선을 가로지름)과 바뀌던 것은 손 쪽 패널이 짧으면 LCD를 반대쪽 패널로 옮겨 없앴다(841×350 → 355: 31.6 → 16.2dp).
    // 남는 경계는 세로형으로 돌아오는 일반 하한(28dp) 근처다 — 그 아래로는 줄지 않는다.
    for (final width in [640.0, 841.0]) {
      testWidgets('세로 접힘선 창 폭 $width: 높이를 키울 때 키가 일반 하한 아래로 튀지 않는다 (#143 R1)', (
        tester,
      ) async {
        const padding = EdgeInsets.only(top: 28);
        double? previous;
        for (var height = 300.0; height <= 700; height += 5) {
          final size = Size(width, height);
          await _pump(
            tester,
            size: size,
            padding: padding,
            displayFeatures: [
              DisplayFeature(
                bounds: Rect.fromLTWH(width / 2, 0, 0, height),
                type: DisplayFeatureType.fold,
                state: DisplayFeatureState.postureFlat,
              ),
            ],
          );
          expect(tester.takeException(), isNull, reason: '$size');
          final touch = _lowestDrawnTouch(tester);
          final p = previous;
          if (p != null && touch < p) {
            // 줄어드는 것은 일반 하한 근처에서 세로형으로 돌아올 때뿐이고, 하한 아래로는 줄지 않는다.
            expect(
              touch,
              greaterThanOrEqualTo(CalcTheme.keyTouchHeightFloor - 0.01),
              reason: '$size $p → $touch',
            );
          }
          previous = touch;
        }
      });
    }

    testWidgets('접힘선 기준 배치를 쓰지 않는 가로 접힘선이어도 짧은 창이면 가로형과 비교한다', (tester) async {
      // 위 패널이 패널 최소 길이(128dp)보다 짧은 가로 접힘선은 접힘선 기준 배치 조건에 맞지 않아 위아래 배치를 받는다.
      // 위아래 배치도 접힘선을 가로지르므로, 키가 더 큰 가로형으로 그린다.
      const size = Size(844, 390);
      const fold = DisplayFeature(
        bounds: Rect.fromLTWH(0, 100, 844, 0),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      );
      await _pump(tester, size: size, displayFeatures: const [fold]);
      expect(tester.takeException(), isNull);
      expect(drawnArrangementOf(tester), DrawnArrangement.landscape);
      expect(
        _lowestDrawnTouch(tester),
        greaterThan(_stackedTouchOf(_bodyOf(size, EdgeInsets.zero))),
      );
    });

    testWidgets('가운데 가로 접힘선은 짧은 창이어도 접힘선 기준 배치다 (#143 — 펼친 접힘선도 나눈다)', (
      tester,
    ) async {
      const size = Size(844, 390);
      const fold = DisplayFeature(
        bounds: Rect.fromLTWH(0, 195, 844, 0),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      );
      await _pump(tester, size: size, displayFeatures: const [fold]);
      expect(tester.takeException(), isNull);
      expect(_notice, findsNothing);
      expect(drawnArrangementOf(tester), DrawnArrangement.tabletop);
      expect(
        _lowestDrawnTouch(tester),
        greaterThanOrEqualTo(CalcTheme.keyTouchHeightUsableMin),
      );
    });
  });

  group('키를 쓸 수 없을 만큼 작은 창은 안내를 띄운다', () {
    // 그린 키가 16dp 이상이면 계산기, 아니면 안내 — 위아래·가로형 모두 16dp 미만일 때만 안내다.
    const widths = [240.0, 300.0, 320.0, 360.0, 600.0];
    const heights = [220.0, 260.0, 300.0, 360.0, 400.0];
    testWidgets('창 크기 격자: 안내는 두 배치 모두 키가 하한 미만일 때만, 계산기의 키는 하한 이상', (
      tester,
    ) async {
      var notices = 0;
      var calculators = 0;
      for (final w in widths) {
        for (final h in heights) {
          final size = Size(w, h);
          await _pump(tester, size: size);
          expect(tester.takeException(), isNull, reason: '$size');
          final body = _bodyOf(size, EdgeInsets.zero);
          if (_notice.evaluate().isNotEmpty) {
            notices++;
            expect(
              _stackedTouchOf(body),
              lessThan(CalcTheme.keyTouchHeightUsableMin),
              reason: '$size',
            );
            expect(
              _landscapeTouchOf(body),
              lessThan(CalcTheme.keyTouchHeightUsableMin),
              reason: '$size',
            );
            expect(_lcd, findsNothing, reason: '$size');
            expect(_keypad, findsNothing, reason: '$size');
            expect(_settings, findsNothing, reason: '$size');
          } else {
            calculators++;
            expect(
              _lowestDrawnTouch(tester),
              greaterThanOrEqualTo(CalcTheme.keyTouchHeightUsableMin - 0.01),
              reason: '$size',
            );
          }
        }
      }
      // 격자에 두 경우가 모두 있어야 이 검사가 의미 있다.
      expect(notices, greaterThan(0));
      expect(calculators, greaterThan(0));
    });

    for (final (size, padding) in const [
      (Size(320, 200), EdgeInsets.zero), // 가로형 8.8dp
      // 300×240: 두 배치 모두 16dp 미만 (#190 전 예시 320×240은 상단 띠가 빠져 가로형 16.7dp로 계산기다)
      (Size(300, 240), EdgeInsets.zero),
      (Size(600, 220), EdgeInsets.only(top: 24)),
      (Size(240, 300), EdgeInsets.zero), // 위아래 12.9dp
    ]) {
      for (final textScale in const [1.0, 2.0]) {
        testWidgets(
          '${size.width}×${size.height}·글자 ${textScale}x: 안내가 본체 안에 넘치지 않고 보인다',
          (tester) async {
            await _pump(
              tester,
              size: size,
              padding: padding,
              textScale: textScale,
            );
            expect(tester.takeException(), isNull);
            expect(_notice, findsOneWidget);
            expect(_lcd, findsNothing);
            expect(_keypad, findsNothing);
            expect(_settings, findsNothing);
            final text = find.text(const EnSettingsStrings().windowTooSmall);
            expect(text, findsOneWidget);
            // 글자 배율을 되돌리지 않는다(줄이지 않고 스크롤한다).
            expect(
              tester.renderObject<RenderParagraph>(text).textScaler.scale(10),
              moreOrLessEquals(10 * textScale),
            );
            // 안내(스크롤 영역)는 인셋·화면 여백을 뺀 본체 영역과 같다.
            final area = Rect.fromLTRB(
              padding.left + CalcTheme.screenPadding,
              padding.top + CalcTheme.screenPadding,
              size.width - padding.right - CalcTheme.screenPadding,
              size.height - padding.bottom - CalcTheme.screenPadding,
            );
            final notice = tester.getRect(_notice);
            expect(notice.left, moreOrLessEquals(area.left));
            expect(notice.top, moreOrLessEquals(area.top));
            expect(notice.right, moreOrLessEquals(area.right));
            expect(notice.bottom, moreOrLessEquals(area.bottom));
            // 아이콘·문구는 본체 폭 안에 있고, 스크롤하면 끝까지 본체 안에 보인다.
            for (final part in [find.byIcon(Icons.open_in_full), text]) {
              await tester.ensureVisible(part);
              await tester.pumpAndSettle();
              final r = tester.getRect(part);
              expect(r.left, greaterThanOrEqualTo(area.left - 0.01));
              expect(r.right, lessThanOrEqualTo(area.right + 0.01));
              if (r.height <= area.height) {
                expect(r.top, greaterThanOrEqualTo(area.top - 0.01));
                expect(r.bottom, lessThanOrEqualTo(area.bottom + 0.01));
              }
            }
          },
        );
      }
    }

    testWidgets('한국어 기기에서는 한국어 안내, 스크린리더는 나타날 때 읽는다(liveRegion)', (
      tester,
    ) async {
      useKoreanLocale(tester);
      final handle = tester.ensureSemantics();
      await _pump(tester, size: _tinyWindow);
      const message = KoSettingsStrings();
      expect(find.text(message.windowTooSmall), findsOneWidget);
      // liveRegion 노드 자신이 문구를 라벨로 가져야 Android가 나타날 때 읽는다(라벨 변경 시에만 알림).
      final node = tester.getSemantics(_notice);
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(node.label, message.windowTooSmall);
      expect(find.bySemanticsLabel(message.windowTooSmall), findsOneWidget);
      // 숨긴 계산기(설정 키·LCD 알림 노드)는 의미 트리에 없다.
      expect(
        find.bySemanticsLabel(const KoSemanticStrings().keyButton(settingsKey)),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('창을 다시 키우면 계산기가 상태 그대로 돌아온다 (LCD·키패드 element 유지)', (
      tester,
    ) async {
      const normal = Size(411, 600);
      final container = await _pump(tester, size: normal);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is CalcKeyButton && w.keyDef.id == CalcKeyId.num7,
        ),
      );
      await tester.pump();
      final lcdElement = tester.element(_lcd);
      final keypadElement = tester.element(find.byType(CalcKeypad));
      final input = container.read(calcProvider).lastInput;
      expect(input?.id, CalcKeyId.num7);

      await _pump(tester, size: _tinyWindow, container: container);
      expect(_notice, findsOneWidget);
      expect(_lcd, findsNothing);

      await _pump(tester, size: normal, container: container);
      expect(_notice, findsNothing);
      expect(identical(tester.element(_lcd), lcdElement), isTrue);
      expect(
        identical(tester.element(find.byType(CalcKeypad)), keypadElement),
        isTrue,
      );
      expect(container.read(calcProvider).lastInput, input);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('lcd-input-text'))).data,
        input!.label,
      );
    });

    testWidgets('안내 중에는 숨긴 키(설정 키 포함)가 터치를 받지 않는다', (tester) async {
      final container = await _pump(tester, size: _tinyWindow);
      final before = container.read(calcProvider);
      // 본체 곳곳을 눌러도 상태가 바뀌지 않고 대화상자도 뜨지 않는다.
      for (final p in const [
        Offset(160, 30),
        Offset(300, 20),
        Offset(40, 150),
        Offset(280, 160),
      ]) {
        await tester.tapAt(p);
        await tester.pumpAndSettle();
      }
      expect(container.read(calcProvider), before);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('키보드 포커스가 있던 설정 키(ON)는 안내 중 포커스를 잃는다 (숨긴 계산기는 포커스 대상이 아니다)', (
      tester,
    ) async {
      final container = await _pump(tester, size: const Size(411, 600));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      bool focusInSettings() {
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused == null) return false;
        return find
            .descendant(
              of: find.byWidgetPredicate(
                (w) => w is CalcKeyButton && w.keyDef.id == settingsKey,
                skipOffstage: false,
              ),
              matching: find.byElementPredicate(
                (e) => identical(e, focused),
                skipOffstage: false,
              ),
              skipOffstage: false,
            )
            .evaluate()
            .isNotEmpty;
      }

      expect(focusInSettings(), isTrue);
      await _pump(tester, size: _tinyWindow, container: container);
      expect(_notice, findsOneWidget);
      expect(focusInSettings(), isFalse);
      // 안내 중 Tab을 눌러도 숨긴 설정 키로 가지 않는다.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusInSettings(), isFalse);
    });
  });

  group('창 크기를 키울 때 키가 줄지 않는다 (#38 R1, #142)', () {
    // 두 배치 중 키(가장 낮은 셀 높이)가 큰 쪽을 고르므로 높이를 늘려도 키가 줄지 않는다. 세로형 ↔ 가로형이 바뀌는
    // 경계를 지나는 폭을 고른다. 터치 높이가 아니라 셀 높이로 보는 이유는 `KeypadMetrics.minKeyCellHeightOf` —
    // 터치 높이는 키캡이 48dp를 넘는 순간 각인 띠를 빼며 배치와 무관하게 한 번 줄어든다.
    for (final width in const [1280.0, 844.0, 640.0, 560.0, 411.0]) {
      testWidgets('폭 $width: 높이 200 → 1000dp', (tester) async {
        var previous = 0.0;
        for (var height = 200.0; height <= 1000; height += 5) {
          final size = Size(width, height);
          await _pump(tester, size: size);
          if (_notice.evaluate().isNotEmpty) {
            expect(previous, 0, reason: '$size: 계산기를 그린 뒤 다시 안내가 나왔다');
            continue;
          }
          final cell = _drawnCell(tester);
          expect(cell, greaterThanOrEqualTo(previous - 0.01), reason: '$size');
          previous = cell;
        }
        expect(previous, greaterThan(0));
      });
    }
  });

  group('창 폭을 키울 때도 키가 줄지 않고, 세로형 ↔ 가로형 경계에서 키가 튀지 않는다 (#38 R2, #142)', () {
    for (final height in const [360.0, 598.0, 800.0]) {
      testWidgets('높이 $height: 폭 240 → 1400dp', (tester) async {
        var previous = 0.0;
        for (var width = 240.0; width <= 1400; width += 5) {
          final size = Size(width, height);
          await _pump(tester, size: size);
          if (_notice.evaluate().isNotEmpty) {
            expect(previous, 0, reason: '$size: 계산기를 그린 뒤 다시 안내가 나왔다');
            continue;
          }
          final cell = _drawnCell(tester);
          expect(cell, greaterThanOrEqualTo(previous - 0.01), reason: '$size');
          previous = cell;
        }
        expect(previous, greaterThan(0));
      });
    }

    testWidgets('경계가 짧은 변 600dp에 묶이지 않는다: 키가 큰 쪽이 그대로 이어진다', (tester) async {
      // #142 전 좌우 분할은 짧은 변 600dp에서 비교를 멈춰 601×599.9(위아래) → 601×600(좌우)에서 키가 약 6% 줄었다.
      for (final size in const [Size(601, 599.9), Size(601, 600)]) {
        await _pump(tester, size: size);
        expect(isStackedArrangement(tester), isTrue, reason: '$size');
      }
      // 정사각형·거의 정사각형 창은 세로형의 키가 커 세로형이다 (CalcTheme "가로형 배치" 절 실측).
      for (final size in const [
        Size(598, 610),
        Size(600, 610),
        Size(768, 768),
      ]) {
        await _pump(tester, size: size);
        expect(isStackedArrangement(tester), isTrue, reason: '$size');
        final body = _bodyOf(size, EdgeInsets.zero);
        expect(_landscapeCellOf(body), lessThan(_stackedCellOf(body)));
      }
      // 가로로 조금 긴 창은 짧은 변이 600dp 미만이어도, 이상이어도 가로형이다.
      for (final size in const [Size(700, 599.9), Size(700, 600)]) {
        await _pump(tester, size: size);
        expect(
          drawnArrangementOf(tester),
          DrawnArrangement.landscape,
          reason: '$size',
        );
      }
    });

    testWidgets('세로형 ↔ 가로형이 바뀌는 폭에서 두 배치의 키 셀 높이가 거의 같다 (연속)', (tester) async {
      // 높이 600 창에서 폭을 1dp씩 늘려 처음 가로형이 되는 폭을 찾고, 그 직전 폭의 세로형 키와 견준다.
      double? before;
      for (var width = 600.0; width <= 800; width += 1) {
        await _pump(tester, size: Size(width, 600));
        final cell = _drawnCell(tester);
        if (drawnArrangementOf(tester) == DrawnArrangement.landscape) {
          expect(before, isNotNull);
          expect(cell, greaterThanOrEqualTo(before!));
          expect(cell - before, lessThan(0.5), reason: '폭 $width');
          return;
        }
        before = cell;
      }
      fail('높이 600 창에서 폭 800dp까지 가로형이 되지 않았다');
    });
  });

  // 실제 글꼴로 재는 그룹이라 마지막에 둔다(번들 글꼴은 로드한 뒤 이 파일 안에서 계속 유지된다).
  group('글자 하한: 안내가 나오지 않는 창의 키 글자 (실제 글꼴, #38 R1)', () {
    setUpAll(loadBundledFonts);

    testWidgets(
      '창 크기 격자에서 메인 4.8dp·각인 3.1dp 이상 (#38 R1에서 정한 하한 — 가로형 뒤에도 유지)',
      (tester) async {
        var nearThreshold = false;
        // 격자 + 안내 직전 창(320×240: 가로형 키 16.7dp — #190에서 상단 띠가 빠져 격자의 가장 작은 키가 17dp를 넘었다)
        final sizes = [
          for (var w = 220.0; w <= 900; w += 40)
            for (var h = 200.0; h <= 600; h += 20) Size(w, h),
          const Size(320, 240),
        ];
        for (final size in sizes) {
          await _pump(tester, size: size);
          if (_notice.evaluate().isNotEmpty) continue;
          final keypad = tester.getSize(_keypad);
          final arrangement = _drawnKeypadArrangement(tester);
          final m = KeypadMetrics.compute(
            keypad,
            TextScaler.noScaling,
            arrangement: arrangement,
          );
          expect(
            m.mainLabelFontSize,
            greaterThanOrEqualTo(4.8),
            reason: '$size',
          );
          expect(m.legendFontSize, greaterThanOrEqualTo(3.1), reason: '$size');
          if (KeypadMetrics.minKeyTouchHeightOf(keypad, arrangement) < 17) {
            nearThreshold = true;
          }
        }
        // 안내 직전 크기가 있어야 이 하한이 의미 있다.
        expect(nearThreshold, isTrue);
      },
    );
  });
}
