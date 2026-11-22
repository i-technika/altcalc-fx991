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
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
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
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return (container, prefs);
}

void main() {
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

    testWidgets('접힘선이 지나는 대화면 가로 창은 위아래 배치다 (힌지 기준 분할은 #25)', (tester) async {
      await _pump(
        tester,
        size: const Size(1280, 800),
        displayFeatures: const [_verticalFold],
      );
      expect(
        tester.getRect(_lcd).bottom,
        lessThanOrEqualTo(tester.getRect(_keypad).top),
      );
      expect(_settings, findsNothing);
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
