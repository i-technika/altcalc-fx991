import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/settings_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/banner_ad_slot.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/handedness_dialog.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/korean_locale.dart';
import '../support/screen_arrangement.dart';

/// 짧은 창(분할 화면·팝업 창·가로로 돈 폰)의 배치와 "창이 너무 작다" 안내 (#38).
/// 규칙은 `CalcTheme` "짧은 창" 절.

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));
final _settings = find.byKey(SettingsButton.buttonKey);
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

/// 창·인셋에서 본체 크기 (광고 슬롯·안전 여백·화면 여백·인셋을 뺀 크기 — `CalculatorScreen`과 같은 계산)
Size _bodyOf(Size window, EdgeInsets padding) => Size(
  window.width - padding.horizontal - 2 * CalcTheme.screenPadding,
  window.height -
      BannerAdSlot.defaultHeightFor(window) -
      CalcTheme.adSlotSafetyMargin -
      padding.vertical -
      CalcTheme.screenPadding,
);

/// 위아래 배치로 그렸을 때의 가장 낮은 키 터치 높이 (dp)
double _stackedTouchOf(Size body) => KeypadMetrics.minKeyTouchHeightOf(
  Size(body.width, CalcScreenLayout.of(body).keypadHeight),
);

/// 좌우 분할로 그렸을 때의 가장 낮은 키 터치 높이 (dp)
double _splitTouchOf(Size body) => KeypadMetrics.minKeyTouchHeightOf(
  CalcSplitLayout.of(body, Handedness.right).keypad.size,
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
  group('짧은 창은 키가 더 큰 좌우 분할로 그린다', () {
    // (창, 인셋, 그린 키 터치 하한 — CalcTheme "짧은 창" 절의 실측값을 내림)
    const cases = [
      (Size(411, 420), EdgeInsets.only(top: 24), 21.0), // 폰 분할 화면 위
      (Size(411, 440), EdgeInsets.only(bottom: 48), 21.0), // 폰 분할 화면 아래
      (Size(844, 390), EdgeInsets.only(left: 47, right: 47, bottom: 21), 25.0),
      (Size(640, 360), EdgeInsets.only(top: 24), 22.0),
      (Size(568, 320), EdgeInsets.zero, 21.0),
      (Size(360, 300), EdgeInsets.zero, 18.0), // 팝업 창
    ];
    for (final (size, padding, minTouch) in cases) {
      for (final handedness in Handedness.values) {
        testWidgets(
          '${size.width}×${size.height}·${handedness.name}: 좌우 분할, 키패드는 주로 쓰는 손 쪽',
          (tester) async {
            await _pump(
              tester,
              size: size,
              padding: padding,
              handedness: handedness,
            );
            expect(tester.takeException(), isNull);
            expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
            expect(_notice, findsNothing);

            // 짧은 창이다: 위아래 배치였다면 키가 일반 하한보다 낮고, 그린 좌우 분할의 키가 그보다 크다.
            final body = _bodyOf(size, padding);
            final stackedTouch = _stackedTouchOf(body);
            expect(stackedTouch, lessThan(CalcTheme.keyTouchHeightFloor));
            final drawnTouch = _lowestDrawnTouch(tester);
            expect(drawnTouch, greaterThan(stackedTouch));
            expect(drawnTouch, greaterThanOrEqualTo(minTouch));
            // 배치를 고르는 계산값이 실제로 그린 키와 같다.
            expect(
              KeypadMetrics.minKeyTouchHeightOf(tester.getSize(_keypad)),
              moreOrLessEquals(drawnTouch, epsilon: 0.01),
            );

            // 키패드는 주로 쓰는 손 쪽 본체 가장자리·본체 아래에 붙는다.
            final keypad = tester.getRect(_keypad);
            final lcd = tester.getRect(_lcd);
            const p = CalcTheme.screenPadding;
            if (handedness.keypadOnRight) {
              expect(
                keypad.right,
                moreOrLessEquals(size.width - padding.right - p),
              );
              expect(lcd.right, lessThanOrEqualTo(keypad.left));
            } else {
              expect(keypad.left, moreOrLessEquals(padding.left + p));
              expect(lcd.left, greaterThanOrEqualTo(keypad.right));
            }
            expect(
              keypad.bottom,
              moreOrLessEquals(padding.top + p + body.height),
            );
            // LCD는 짧은 창에서도 최소 높이 아래로 줄지 않는다.
            expect(
              lcd.height,
              greaterThanOrEqualTo(CalcTheme.screenLcdMinHeight - 0.01),
            );

            // 설정 버튼은 LCD 아래에서 눌리고, LCD·키패드와 겹치지 않는다.
            final button = tester.getRect(_settings);
            expect(_settings.hitTestable(), findsOneWidget);
            expect(button.overlaps(lcd), isFalse);
            expect(button.overlaps(keypad), isFalse);
            expect(button.bottom, lessThanOrEqualTo(keypad.bottom + 0.01));
          },
        );
      }
    }

    testWidgets('가로 폰 844×390: LCD 줄 글자도 위아래 배치보다 커진다', (tester) async {
      const size = Size(844, 390);
      const padding = EdgeInsets.only(left: 47, right: 47, bottom: 21);
      await _pump(tester, size: size, padding: padding);
      final lcd = tester.getSize(_lcd);
      final stacked = CalcScreenLayout.of(_bodyOf(size, padding));
      double lineOf(Size s) =>
          LcdFontSizes.forSize(s, TextScaler.noScaling).input;
      expect(
        lineOf(lcd),
        greaterThan(lineOf(Size(stacked.lcdWidth, stacked.lcdHeight)) * 1.5),
      );
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
      // 키 24.8dp — 좌우 분할은 21.5dp
      (Size(412, 520), EdgeInsets.only(top: 24)),
      // iPhone SE 1세대: 키 27.96dp로 일반 하한 미만이지만 좌우 분할은 약 16dp
      (Size(320, 568), EdgeInsets.only(top: 20)),
      // 좁고 낮은 팝업 창 — 좌우 분할은 키패드 폭이 절반이라 더 작다
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
        expect(_splitTouchOf(body), lessThanOrEqualTo(stackedTouch));
        expect(
          _lowestDrawnTouch(tester),
          moreOrLessEquals(stackedTouch, epsilon: 0.01),
        );
      });
    }

    testWidgets('세로 폰처럼 키가 일반 하한 이상인 창은 좌우 분할과 비교하지 않는다', (tester) async {
      // 390×844: 좌우 분할도 키 28dp 미만이 아니지만 위아래 배치 그대로다(짧은 창이 아님).
      const size = Size(390, 844);
      const padding = EdgeInsets.only(top: 47, bottom: 34);
      await _pump(tester, size: size, padding: padding);
      expect(isStackedArrangement(tester), isTrue);
      expect(
        _stackedTouchOf(_bodyOf(size, padding)),
        greaterThanOrEqualTo(CalcTheme.keyTouchHeightFloor),
      );
    });
  });

  group('접힘선이 있는 짧은 창 (#38 R1)', () {
    // 세로 접힘선: 접힘선 기준 좌우 배치가 일반 하한(28dp) 미만이어도 위아래 배치보다 키가 크면 쓴다.
    for (final (size, padding, hingeX) in const [
      (
        Size(640, 360),
        EdgeInsets.only(top: 24),
        320.0,
      ), // 키 22.8dp (위아래 11.6dp → 전에는 안내)
      (Size(700, 420), EdgeInsets.only(top: 24, bottom: 24), 350.0), // 하한 바로 아래
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
            // 접힘선 기준 배치로 그렸다(가운데 접힘선이면 영역이 짧은 창 좌우 분할과 같아, 배치 종류로 구분한다 —
            // 대화상자를 접힘선 기준으로 나눌지가 이것으로 정해진다, #25·#129).
            expect(
              tester
                  .widget<SettingsButton>(find.byType(SettingsButton))
                  .arrangement,
              ScreenArrangement.hingeSplit,
            );
            final drawnTouch = _lowestDrawnTouch(tester);
            expect(drawnTouch, lessThan(CalcTheme.keyTouchHeightFloor));
            expect(
              drawnTouch,
              greaterThan(_stackedTouchOf(_bodyOf(size, padding))),
            );
            // LCD·키패드·설정 버튼 어느 것도 접힘선(과 양쪽 간격)에 걸치지 않고, 키패드는 손 쪽 절반이다.
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

    testWidgets('접힘선 기준 배치를 쓰지 않는 펼친 가로 접힘선이어도 짧은 창이면 좌우 분할과 비교한다', (
      tester,
    ) async {
      // 펼친 폭 0 가로 접힘선은 접힘선 기준 배치 조건(양쪽 280dp)에 맞지 않아 위아래 배치를 받는다. 위아래 배치도
      // 접힘선을 가로지르므로, 키가 더 큰 좌우 분할(전에는 키패드 237×190 → 402×322)로 그린다.
      const size = Size(844, 390);
      const fold = DisplayFeature(
        bounds: Rect.fromLTWH(0, 195, 844, 0),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      );
      await _pump(tester, size: size, displayFeatures: const [fold]);
      expect(tester.takeException(), isNull);
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
      expect(
        _lowestDrawnTouch(tester),
        greaterThan(_stackedTouchOf(_bodyOf(size, EdgeInsets.zero))),
      );
    });
  });

  group('키를 쓸 수 없을 만큼 작은 창은 안내를 띄운다', () {
    // 그린 키가 16dp 이상이면 계산기, 아니면 안내 — 위아래·좌우 분할 모두 16dp 미만일 때만 안내다.
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
              _splitTouchOf(body),
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
      (Size(320, 240), EdgeInsets.zero),
      (Size(600, 220), EdgeInsets.only(top: 24)),
      (Size(240, 360), EdgeInsets.zero),
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
            // 안내(스크롤 영역)는 인셋·광고 슬롯을 뺀 본체 영역(위쪽 화면 여백 포함)과 같다.
            final area = Rect.fromLTRB(
              padding.left + CalcTheme.screenPadding,
              padding.top,
              size.width - padding.right - CalcTheme.screenPadding,
              size.height -
                  BannerAdSlot.defaultHeightFor(size) -
                  CalcTheme.adSlotSafetyMargin -
                  padding.bottom,
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
      await _pump(tester, size: const Size(320, 240));
      const message = KoSettingsStrings();
      expect(find.text(message.windowTooSmall), findsOneWidget);
      // liveRegion 노드 자신이 문구를 라벨로 가져야 Android가 나타날 때 읽는다(라벨 변경 시에만 알림).
      final node = tester.getSemantics(_notice);
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(node.label, message.windowTooSmall);
      expect(find.bySemanticsLabel(message.windowTooSmall), findsOneWidget);
      // 숨긴 계산기(설정 버튼·LCD 알림 노드)는 의미 트리에 없다.
      expect(find.byTooltip(message.settingsButton), findsNothing);
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

      await _pump(tester, size: const Size(320, 240), container: container);
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

    testWidgets('안내 중에는 숨긴 키·설정 버튼이 터치를 받지 않는다', (tester) async {
      final container = await _pump(tester, size: const Size(320, 240));
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

    testWidgets('키보드 포커스가 있던 설정 버튼은 안내 중 포커스를 잃는다 (숨긴 계산기는 포커스 대상이 아니다)', (
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
              of: find.byType(SettingsButton, skipOffstage: false),
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
      await _pump(tester, size: const Size(320, 240), container: container);
      expect(_notice, findsOneWidget);
      expect(focusInSettings(), isFalse);
      // 안내 중 Tab을 눌러도 숨긴 설정 버튼으로 가지 않는다.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusInSettings(), isFalse);
    });
  });

  group('창 크기를 키울 때 키가 줄지 않는다 (#38 R1)', () {
    // 두 배치 중 키가 큰 쪽을 고르므로 짧은 변 600dp 미만에서는 높이를 늘려도 키가 줄지 않는다. (600dp부터는
    // 광고 슬롯이 50 → 60dp로 커지는 이 이슈 전부터의 경계가 있어 범위에서 뺀다.)
    for (final width in const [844.0, 640.0, 560.0, 411.0]) {
      testWidgets('폭 $width: 높이 260 → 599dp', (tester) async {
        var previous = 0.0;
        for (var height = 260.0; height < 600; height += 3) {
          final size = Size(width, height);
          await _pump(tester, size: size);
          if (_notice.evaluate().isNotEmpty) {
            expect(previous, 0, reason: '$size: 계산기를 그린 뒤 다시 안내가 나왔다');
            continue;
          }
          final touch = KeypadMetrics.minKeyTouchHeightOf(
            tester.getSize(_keypad),
          );
          expect(touch, greaterThanOrEqualTo(previous - 0.01), reason: '$size');
          previous = touch;
        }
        expect(previous, greaterThan(0));
      });
    }
  });

  group('창 폭을 키울 때도 키가 줄지 않고, 짧은 변 600dp 경계는 기록대로다 (#38 R2)', () {
    for (final height in const [360.0, 598.0]) {
      testWidgets('높이 $height: 폭 240 → 598dp', (tester) async {
        var previous = 0.0;
        for (var width = 240.0; width < 600; width += 4) {
          final size = Size(width, height);
          await _pump(tester, size: size);
          if (_notice.evaluate().isNotEmpty) {
            expect(previous, 0, reason: '$size: 계산기를 그린 뒤 다시 안내가 나왔다');
            continue;
          }
          final touch = KeypadMetrics.minKeyTouchHeightOf(
            tester.getSize(_keypad),
          );
          expect(touch, greaterThanOrEqualTo(previous - 0.01), reason: '$size');
          previous = touch;
        }
        expect(previous, greaterThan(0));
      });
    }

    testWidgets('거의 정사각형인 세로 창: 짧은 변 600 미만은 키가 큰 좌우 분할, 600부터는 위아래 배치', (
      tester,
    ) async {
      // CalcTheme "짧은 창" 절에 기록한 경계 — 정사각형 대화면(768×768 등)은 FormFactor 규칙대로 위아래 배치다.
      await _pump(tester, size: const Size(598, 610));
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
      await _pump(tester, size: const Size(600, 610));
      expect(isStackedArrangement(tester), isTrue);
      await _pump(tester, size: const Size(768, 768));
      expect(isStackedArrangement(tester), isTrue);
    });
  });

  // 실제 글꼴로 재는 그룹이라 마지막에 둔다(번들 글꼴은 로드한 뒤 이 파일 안에서 계속 유지된다).
  group('글자 하한: 안내가 나오지 않는 창의 키 글자 (실제 글꼴, #38 R1)', () {
    setUpAll(loadBundledFonts);

    testWidgets(
      '창 크기 격자에서 메인 4.8dp·각인 3.1dp 이상 (CalcTheme "짧은 창" 절의 실측 하한 4.9·3.2dp)',
      (tester) async {
        var nearThreshold = false;
        for (var w = 220.0; w <= 900; w += 40) {
          for (var h = 200.0; h <= 600; h += 20) {
            final size = Size(w, h);
            await _pump(tester, size: size);
            if (_notice.evaluate().isNotEmpty) continue;
            final keypad = tester.getSize(_keypad);
            final m = KeypadMetrics.compute(keypad, TextScaler.noScaling);
            expect(
              m.mainLabelFontSize,
              greaterThanOrEqualTo(4.8),
              reason: '$size',
            );
            expect(
              m.legendFontSize,
              greaterThanOrEqualTo(3.1),
              reason: '$size',
            );
            if (KeypadMetrics.minKeyTouchHeightOf(keypad) < 17) {
              nearThreshold = true;
            }
          }
        }
        // 안내 직전 크기가 격자에 있어야 이 하한이 의미 있다.
        expect(nearThreshold, isTrue);
      },
    );
  });
}
