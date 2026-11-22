import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
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
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/korean_locale.dart';
import '../support/touch_metrics.dart';

/// 대화면 가로 창의 좌우 분할 배치와 손잡이 설정 (#24).

/// 폴더블 내부 화면의 세로 접힘선 (펼친 상태)
const _verticalFold = DisplayFeature(
  bounds: Rect.fromLTWH(640, 0, 0, 800),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));
final _ad = find.byKey(const ValueKey('banner-ad-slot'));
final _settings = find.byKey(SettingsButton.buttonKey);

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
  group('좌우 분할 배치: 화면 크기 × 손잡이', () {
    // 대화면 가로 창 (Android 태블릿: 상태 표시줄 24·작업 표시줄 48, iPad: 상태 표시줄 24·홈 표시줄 20)
    const windows = [
      (Size(1280, 800), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(960, 600), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(1024, 768), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(1194, 834), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(1366, 1024), EdgeInsets.only(top: 24, bottom: 20)),
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

              final lcd = tester.getRect(_lcd);
              final keypad = tester.getRect(_keypad);
              final ad = tester.getRect(_ad);
              final settings = tester.getRect(_settings);
              final left = padding.left + CalcTheme.screenPadding;
              final right =
                  size.width - padding.right - CalcTheme.screenPadding;

              // 좌우: 키패드는 손 쪽 가장자리, LCD는 반대쪽, 사이에 간격. 설정 버튼은 키패드에서 먼 끝.
              if (handedness.keypadOnRight) {
                expect(keypad.right, moreOrLessEquals(right));
                expect(lcd.left, moreOrLessEquals(left));
                expect(
                  keypad.left - lcd.right,
                  moreOrLessEquals(CalcTheme.screenSplitGap),
                );
                expect(settings.left, moreOrLessEquals(lcd.left));
              } else {
                expect(keypad.left, moreOrLessEquals(left));
                expect(lcd.right, moreOrLessEquals(right));
                expect(
                  lcd.left - keypad.right,
                  moreOrLessEquals(CalcTheme.screenSplitGap),
                );
                expect(settings.right, moreOrLessEquals(lcd.right));
              }
              // LCD 쪽이 키패드보다 좁지 않다.
              expect(lcd.width, greaterThanOrEqualTo(keypad.width - 0.01));

              // 위아래: LCD와 키패드 윗변이 맞고, 키패드 아래에 광고 안전 여백, 광고는 전체 폭
              expect(lcd.top, moreOrLessEquals(keypad.top));
              expect(lcd.top, greaterThanOrEqualTo(padding.top));
              expect(
                ad.top - keypad.bottom,
                greaterThanOrEqualTo(CalcTheme.adSlotMinSafetyMargin),
              );
              expect(
                ad.bottom,
                lessThanOrEqualTo(size.height - padding.bottom + 0.01),
              );
              // 광고는 전체 폭에서 좌우 시스템 인셋만 피한다 (BannerAdSlot 계약)
              expect(
                ad.width,
                moreOrLessEquals(size.width - padding.horizontal),
              );

              // 설정 버튼: LCD 아래, 키패드 높이 안, 겹치지 않음, 48dp, 눌린다
              expect(settings.top, greaterThanOrEqualTo(lcd.bottom));
              expect(settings.bottom, lessThanOrEqualTo(keypad.bottom + 0.01));
              expect(settings.overlaps(keypad), isFalse);
              expect(
                settings.width,
                moreOrLessEquals(CalcTheme.settingsButtonSize),
              );
              expect(
                settings.height,
                moreOrLessEquals(CalcTheme.settingsButtonSize),
              );
              expect(_settings.hitTestable(), findsOneWidget);

              // 키 크기 상한
              expect(
                keypad.width,
                lessThanOrEqualTo(CalcTheme.keypadMaxWidth + 0.01),
              );
            },
          );
        }
      }
    }
  });

  group('위아래 배치로 남는 창', () {
    for (final size in const [
      Size(800, 1280), // 태블릿 세로 (방향 고정이 무시된 경우)
      Size(678, 1024), // iPad Split View 절반
      Size(768, 768), // 정사각형 창
      Size(390, 844),
      Size(844, 390), // 가로 폰 — 짧은 창 대응은 #38
    ]) {
      testWidgets(
        '${size.width}×${size.height}: 왼손잡이 설정이어도 위아래 배치이고 설정 버튼이 없다',
        (tester) async {
          await _pump(tester, size: size, handedness: Handedness.left);
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(_lcd).bottom,
            lessThanOrEqualTo(tester.getRect(_keypad).top),
          );
          expect(_settings, findsNothing);
        },
      );
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
      expect(_settings, findsOneWidget);
    });
  });

  group('키 크기 상한', () {
    for (final size in const [
      Size(800, 1280),
      Size(1366, 1024),
      Size(2000, 1400),
      // 폴더블 내부 화면(위아래 배치)에도 같은 상한이 걸린다 — Fold5 내부 키패드 폭 약 674 → 480dp (의도)
      Size(690, 829),
    ]) {
      testWidgets('${size.width}×${size.height}: 키패드는 최대 폭·높이를 넘지 않는다', (
        tester,
      ) async {
        await _pump(tester, size: size);
        final keypad = tester.getRect(_keypad);
        expect(keypad.width, moreOrLessEquals(CalcTheme.keypadMaxWidth));
        expect(
          keypad.height,
          lessThanOrEqualTo(
            CalcTheme.keypadMaxWidth / CalcTheme.keypadMinAspectRatio + 0.01,
          ),
        );
        // 세로 창에서는 가운데 정렬된다.
        if (size.height > size.width) {
          expect(keypad.center.dx, moreOrLessEquals(size.width / 2));
        }
      });
    }
  });

  group('손잡이 설정 UI', () {
    testWidgets('설정 버튼 → 왼손잡이: 키패드가 왼쪽으로 옮겨지고 저장되며, 키패드는 다시 빌드되지 않는다', (
      tester,
    ) async {
      final (container, prefs) = await _pump(
        tester,
        size: const Size(1280, 800),
      );
      final keypadWidget = tester.element(find.byType(CalcKeypad)).widget;
      expect(
        tester.getRect(_keypad).left,
        greaterThan(tester.getRect(_lcd).right),
      );

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
      expect(
        tester.getRect(_keypad).right,
        lessThan(tester.getRect(_lcd).left),
      );
      expect(
        identical(tester.element(find.byType(CalcKeypad)).widget, keypadWidget),
        isTrue,
      );

      // 닫기 버튼으로 닫는다.
      await tester.tap(find.byKey(HandednessDialog.closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(HandednessDialog), findsNothing);
      expect(container.read(handednessProvider), Handedness.left);
    });

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

    testWidgets('스크린리더: 설정 버튼 이름, 선택지는 단일 선택 그룹과 선택 상태로 알려진다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        size: const Size(1280, 800),
        handedness: Handedness.left,
      );
      expect(
        tester.getSemantics(_settings),
        isSemantics(tooltip: 'Settings', isButton: true),
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
      '열린 채 창이 아주 낮아지면 제목·닫기 버튼은 고정되고 선택지만 스크롤되며, 화살표로 옮긴 선택지는 화면 안으로 스크롤된다',
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

    testWidgets('설정 아이콘 색은 기기의 고대비 설정을 따른다 (#54)', (tester) async {
      for (final palette in [CalcPalette.standard, CalcPalette.highContrast]) {
        await _pump(
          tester,
          size: const Size(1280, 800),
          highContrast: palette.isHighContrast,
        );
        expect(
          tester.widget<IconButton>(_settings).color,
          palette.settingsIcon,
          reason: '고대비=${palette.isHighContrast}',
        );
      }
    });

    testWidgets('한국어 기기에서는 설정 문구가 한국어다', (tester) async {
      useKoreanLocale(tester);
      await _pump(tester, size: const Size(1280, 800));
      expect(tester.widget<IconButton>(_settings).tooltip, '설정');
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
    expect(_settings, findsNothing);
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

    // 다시 가로로
    await _pump(tester, size: const Size(1280, 800), container: container);
    expect(_settings, findsOneWidget);
    expect(
      identical(tester.element(find.byType(CalcKeypad)), keypadElement),
      isTrue,
    );
    await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.sin)));
    await tester.pump();
    expect(container.read(calcProvider).modifier, KeyModifier.none);
    expect(container.read(calcProvider).lastInput?.layer, KeyLayer.shift);
  });

  group('CalcSplitLayout', () {
    test('모든 영역은 본체 안에 있고 LCD·키패드·설정 버튼이 서로 겹치지 않는다', () {
      for (final body in const [
        Size(1264, 702),
        Size(944, 502),
        Size(1350, 954),
        Size(700, 300),
        Size(200, 100),
        Size(40, 40),
        Size(0, 0),
      ]) {
        for (final h in Handedness.values) {
          final l = CalcSplitLayout.of(body, h);
          final bounds = (Offset.zero & body).inflate(0.01);
          for (final r in [l.lcd, l.keypad, l.settingsButton]) {
            expect(r.width, greaterThanOrEqualTo(0), reason: '$body $h $l');
            expect(r.height, greaterThanOrEqualTo(0), reason: '$body $h $l');
            expect(
              bounds.contains(r.topLeft) && bounds.contains(r.bottomRight),
              isTrue,
              reason: '$body $h $l',
            );
          }
          expect(l.lcd.overlaps(l.keypad), isFalse, reason: '$body $h $l');
          expect(
            l.settingsButton.overlaps(l.lcd),
            isFalse,
            reason: '$body $h $l',
          );
          expect(
            l.settingsButton.overlaps(l.keypad),
            isFalse,
            reason: '$body $h $l',
          );
        }
      }
    });

    test('왼손잡이 배치는 오른손잡이 배치의 좌우 대칭이다', () {
      const body = Size(1264, 702);
      final r = CalcSplitLayout.of(body, Handedness.right);
      final l = CalcSplitLayout.of(body, Handedness.left);
      Rect mirror(Rect x) => Rect.fromLTRB(
        body.width - x.right,
        x.top,
        body.width - x.left,
        x.bottom,
      );
      expect(l.lcd, mirror(r.lcd));
      expect(l.keypad, mirror(r.keypad));
      expect(l.settingsButton, mirror(r.settingsButton));
    });

    test('키패드는 본체 아래에 붙고, LCD 높이는 최소 높이 ~ 폭의 최대 높이 범위다', () {
      const body = Size(1264, 702);
      final l = CalcSplitLayout.of(body, Handedness.right);
      expect(l.keypad.bottom, moreOrLessEquals(body.height));
      expect(
        l.lcd.height,
        lessThanOrEqualTo(
          l.lcd.width / CalcTheme.screenLcdMinAspectRatio + 0.01,
        ),
      );
      expect(l.lcd.height, greaterThanOrEqualTo(CalcTheme.screenLcdMinHeight));
    });

    test('음수·비유한 크기는 0으로 본다', () {
      for (final body in const [
        Size(double.nan, double.nan),
        Size(-10, -10),
        Size(double.infinity, 500),
      ]) {
        final l = CalcSplitLayout.of(body, Handedness.right);
        for (final r in [l.lcd, l.keypad, l.settingsButton]) {
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

/// 폴더블 화면: 창 크기, 시스템 인셋, 접힘 정보 (화면 좌표)
typedef _Foldable = (String, Size, EdgeInsets, DisplayFeature);

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

/// 키패드의 모든 키(커서 패드 제외)가 터치 하한 이상이고, 커서 패드 구역도 #43 하한을 지키는지 확인한다.
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
  // 배치 판정에 쓰는 계산값이 실제로 그린 키의 최소 터치 높이와 같다.
  expect(
    KeypadMetrics.minKeyTouchHeightOf(tester.getSize(_keypad)),
    moreOrLessEquals(lowest, epsilon: 0.01),
  );
  final pad = CursorPadGeometry(
    tester.getSize(find.byKey(const ValueKey('cursor-pad'))),
  );
  for (final sector in CursorPadSector.values) {
    final wide = sector == CursorPadSector.up || sector == CursorPadSector.down;
    expect(
      inscribedDiameter(pad, sector),
      greaterThanOrEqualTo(floor * (wide ? 1.0 : 0.9)),
      reason: sector.name,
    );
  }
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
              final ad = tester.getRect(_ad);

              // 어느 것도 접힘선(과 양쪽 간격)에 걸치지 않는다.
              for (final r in [lcd, keypad, settings]) {
                expect(
                  _clearOfHinge(r, hinge, vertical: true),
                  isTrue,
                  reason: '$r',
                );
              }
              // 키패드는 주로 쓰는 손 쪽 절반의 바깥 가장자리, LCD·설정 버튼은 반대쪽 절반
              final right =
                  size.width - padding.right - CalcTheme.screenPadding;
              final left = padding.left + CalcTheme.screenPadding;
              if (handedness.keypadOnRight) {
                expect(keypad.left, greaterThanOrEqualTo(hinge.right));
                expect(keypad.right, moreOrLessEquals(right));
                expect(lcd.right, lessThanOrEqualTo(hinge.left));
                expect(lcd.left, moreOrLessEquals(left));
                expect(settings.right, lessThanOrEqualTo(hinge.left));
              } else {
                expect(keypad.right, lessThanOrEqualTo(hinge.left));
                expect(keypad.left, moreOrLessEquals(left));
                expect(lcd.left, greaterThanOrEqualTo(hinge.right));
                expect(lcd.right, moreOrLessEquals(right));
                expect(settings.left, greaterThanOrEqualTo(hinge.right));
              }
              // LCD 쪽은 접힘선까지 절반 전체를 쓴다 (간격만 남긴다).
              expect(
                handedness.keypadOnRight
                    ? hinge.left - lcd.right
                    : lcd.left - hinge.right,
                moreOrLessEquals(CalcTheme.screenHingeMargin),
              );
              // 윗변 정렬, 설정 버튼은 LCD 아래·겹침 없음·48dp·눌림
              expect(lcd.top, moreOrLessEquals(keypad.top));
              expect(settings.top, greaterThanOrEqualTo(lcd.bottom));
              expect(settings.overlaps(keypad), isFalse);
              expect(
                settings.width,
                moreOrLessEquals(CalcTheme.settingsButtonSize),
              );
              expect(_settings.hitTestable(), findsOneWidget);
              // 광고 슬롯 안전 여백, 키 크기 상한
              expect(
                ad.top - keypad.bottom,
                greaterThanOrEqualTo(CalcTheme.adSlotMinSafetyMargin),
              );
              expect(
                keypad.width,
                lessThanOrEqualTo(CalcTheme.keypadMaxWidth + 0.01),
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
        const Size(411, 1005),
        const EdgeInsets.only(top: 32, bottom: 24),
        _halfOpenedAt(const Rect.fromLTWH(0, 502.5, 411, 0)),
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
              final ad = tester.getRect(_ad);

              for (final r in [lcd, keypad, settings]) {
                expect(
                  _clearOfHinge(r, hinge, vertical: false),
                  isTrue,
                  reason: '$r',
                );
              }
              // LCD는 위 절반(접힘선 쪽에 붙음), 키패드는 아래 절반
              expect(
                lcd.bottom,
                moreOrLessEquals(hinge.top - CalcTheme.screenHingeMargin),
              );
              expect(keypad.top, greaterThanOrEqualTo(hinge.bottom));
              // 키패드는 주로 쓰는 손 쪽 가장자리, 설정 버튼은 반대쪽
              final right =
                  size.width - padding.right - CalcTheme.screenPadding;
              final left = padding.left + CalcTheme.screenPadding;
              if (handedness.keypadOnRight) {
                expect(keypad.right, moreOrLessEquals(right));
                expect(settings.left, moreOrLessEquals(left));
              } else {
                expect(keypad.left, moreOrLessEquals(left));
                expect(settings.right, moreOrLessEquals(right));
              }
              expect(settings.overlaps(keypad), isFalse);
              expect(settings.overlaps(lcd), isFalse);
              expect(_settings.hitTestable(), findsOneWidget);
              // 반 접은 테이블톱 자세는 완화된 하한을 지킨다 (사용자 결정, #25 R2).
              if (scale == 1.0) {
                _expectTouchTargets(
                  tester,
                  floor: CalcTheme.tabletopKeyTouchHeightFloor,
                );
              }
              expect(
                ad.top - keypad.bottom,
                greaterThanOrEqualTo(CalcTheme.adSlotMinSafetyMargin),
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
    expect(_settings, findsOneWidget);
    expect(container.read(calcProvider).modifier, KeyModifier.shift);
    expect(
      identical(tester.element(find.byType(CalcKeypad)), keypadElement),
      isTrue,
    );
    expect(identical(tester.element(_lcd), lcdElement), isTrue);

    // 접음 → 커버 화면 (접힘 정보 없음) → 위아래 배치, 설정 버튼 없음
    await _pump(tester, size: const Size(344, 882), container: container);
    expect(_settings, findsNothing);
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
      ('Flip 내부', const Size(411, 1005), const Rect.fromLTWH(0, 502.5, 411, 0)),
    ]) {
      testWidgets(
        '$name ${size.width}×${size.height}: 위아래 배치, 설정 버튼 없음, 키는 터치 하한 이상',
        (tester) async {
          await _pump(
            tester,
            size: size,
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            displayFeatures: [_foldAt(fold)],
          );
          expect(tester.takeException(), isNull);
          expect(_settings, findsNothing);
          expect(
            tester.getRect(_lcd).bottom,
            lessThanOrEqualTo(tester.getRect(_keypad).top),
          );
          _expectTouchTargets(tester);
        },
      );
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
      expect(_settings, findsNothing);
      _expectTouchTargets(tester);

      // 가로 반 접힘: 아래쪽 281dp + 아래 인셋 48 → 광고 슬롯까지 빼면 키가 하한(테이블톱)보다 낮다
      await _pump(
        tester,
        size: const Size(841, 673),
        padding: const EdgeInsets.only(top: 24, bottom: 48),
        displayFeatures: [_halfOpenedAt(const Rect.fromLTWH(0, 392, 841, 0))],
      );
      expect(tester.takeException(), isNull);
      expect(_settings, findsNothing);
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
      expect(_settings, findsOneWidget);
      expect(tester.getRect(_keypad).top, greaterThanOrEqualTo(336.5));
      _expectTouchTargets(tester, floor: CalcTheme.tabletopKeyTouchHeightFloor);
    });

    testWidgets('접힘선이 인셋 안(창 가장자리)에 있으면 접힘선 기준으로 나누지 않는다', (tester) async {
      await _pump(
        tester,
        size: const Size(841, 701),
        padding: const EdgeInsets.only(left: 32, top: 24, bottom: 24),
        displayFeatures: [_foldAt(const Rect.fromLTWH(20, 0, 0, 701))],
      );
      expect(tester.takeException(), isNull);
      expect(_settings, findsNothing);
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
    testWidgets('물리 힌지·왼손잡이: 대화상자는 설정 버튼이 있는 쪽(오른쪽) 절반에 뜬다', (tester) async {
      await _pump(
        tester,
        size: const Size(1114, 720),
        handedness: Handedness.left,
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
      '반 접은 세로 접힘선의 절반 폭(약 336dp)·글자 배율 2.0·왼손잡이: 오른쪽 절반에 넘치지 않고 뜨고 선택된다',
      (tester) async {
        final (container, _) = await _pump(
          tester,
          size: const Size(673, 841),
          padding: const EdgeInsets.only(top: 32, bottom: 24),
          textScale: 2.0,
          handedness: Handedness.left,
          displayFeatures: [
            _halfOpenedAt(const Rect.fromLTWH(336.5, 0, 0, 841)),
          ],
        );
        await tester.tap(_settings);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // 왼손잡이: 설정 버튼은 오른쪽 절반 → 대화상자도 오른쪽 절반 (anchor 없으면 왼쪽에 뜬다)
        expect(
          tester.getRect(_dialogSurface).left,
          greaterThanOrEqualTo(336.5),
        );
        await tester.tap(_option(Handedness.right));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(container.read(handednessProvider), Handedness.right);
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
      // 오른손잡이: 설정 버튼은 왼쪽 절반
      expect(tester.getRect(_dialogSurface).right, lessThanOrEqualTo(336.5));
    });

    testWidgets('반 접은 테이블톱: 대화상자는 설정 버튼이 있는 아래 절반에 뜬다', (tester) async {
      await _pump(
        tester,
        size: const Size(701, 841),
        padding: const EdgeInsets.only(top: 32, bottom: 24),
        displayFeatures: [_halfOpenedAt(const Rect.fromLTWH(0, 420.5, 701, 0))],
      );
      expect(tester.getRect(_settings).top, greaterThanOrEqualTo(420.5));
      await tester.tap(_settings);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_dialogSurface).top, greaterThanOrEqualTo(420.5));
    });
  });

  group('CalcSplitLayout (접힘선) · CalcTabletopLayout', () {
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
          final l = CalcSplitLayout.of(body, h, hinge: hinge);
          final reason = '$body $hinge $h $l';
          expectSane(body, [l.lcd, l.keypad, l.settingsButton], reason);
          final hingeInBody = hinge.left >= 0 && hinge.right <= body.width;
          if (hingeInBody) {
            for (final r in [l.lcd, l.keypad, l.settingsButton]) {
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

    test('세로 접힘선: 왼손잡이 배치는 가운데 접힘선 기준 오른손잡이 배치의 좌우 대칭이다', () {
      const body = Size(825, 637);
      const hinge = Rect.fromLTWH(412.5, 0, 0, 637);
      final r = CalcSplitLayout.of(body, Handedness.right, hinge: hinge);
      final l = CalcSplitLayout.of(body, Handedness.left, hinge: hinge);
      Rect mirror(Rect x) => Rect.fromLTRB(
        body.width - x.right,
        x.top,
        body.width - x.left,
        x.bottom,
      );
      expect(l.lcd, mirror(r.lcd));
      expect(l.keypad, mirror(r.keypad));
      expect(l.settingsButton, mirror(r.settingsButton));
    });

    test('가로 접힘선: 본체 안, 겹침 없음, 접힘선 띠에 걸치지 않음 (설정 버튼 대체 자리 포함)', () {
      for (final (body, hinge) in [
        (const Size(825, 593), const Rect.fromLTWH(0, 304.5, 825, 0)),
        (const Size(685, 777), const Rect.fromLTWH(0, 380.5, 685, 0)),
        // 아래 절반 폭을 키패드가 다 써서 설정 버튼이 위 절반으로 가는 창
        (const Size(360, 700), const Rect.fromLTWH(0, 300, 360, 0)),
        (const Size(800, 600), const Rect.fromLTWH(0, 40, 800, 0)),
        (const Size(800, 600), const Rect.fromLTWH(0, 590, 800, 0)),
        (const Size(40, 40), const Rect.fromLTWH(0, 20, 40, 0)),
        (Size.zero, Rect.zero),
      ]) {
        for (final h in Handedness.values) {
          final l = CalcTabletopLayout.of(body, hinge, h);
          final reason = '$body $hinge $h $l';
          expectSane(body, [l.lcd, l.keypad, l.settingsButton], reason);
          for (final r in [l.lcd, l.keypad, l.settingsButton]) {
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

    test('가로 접힘선: 설정 버튼 자리가 없으면 위 절반 모서리로 가고 LCD는 그 아래로 줄어든다', () {
      const body = Size(360, 700);
      const hinge = Rect.fromLTWH(0, 300, 360, 0);
      final l = CalcTabletopLayout.of(body, hinge, Handedness.right);
      expect(l.settingsButton.bottom, lessThanOrEqualTo(l.lcd.top));
      expect(l.settingsButton.left, 0);
      expect(l.settingsButton.height, CalcTheme.settingsButtonSize);
    });
  });
}
