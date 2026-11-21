import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/main.dart' as app show main;
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/banner_ad_slot.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';

/// 화면 크기·인셋을 지정해 [CalculatorScreen]을 띄우고 상태 컨테이너를 돌려준다.
Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  EdgeInsets padding = EdgeInsets.zero,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
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
            textScaler: TextScaler.linear(textScale),
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return container;
}

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

String _lcdInputText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('lcd-input-text'))).data!;

void main() {
  group('조립', () {
    testWidgets('LCD, 50키 키패드, 광고 슬롯이 위에서 아래로 배치된다', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(LcdDisplay), findsOneWidget);
      expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));
      expect(find.byType(BannerAdSlot), findsOneWidget);

      final lcd = tester.getRect(find.byType(LcdDisplay));
      final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
      final ad = tester.getRect(find.byKey(const ValueKey('banner-ad-slot')));
      expect(lcd.bottom, lessThanOrEqualTo(keypad.top));
      expect(
        ad.top - keypad.bottom,
        greaterThanOrEqualTo(CalcTheme.adSlotMinSafetyMargin),
      );
    });

    testWidgets('상단 시스템 인셋은 LCD가, 하단 인셋은 광고 슬롯이 피한다', (tester) async {
      const padding = EdgeInsets.only(top: 47, bottom: 34);
      await _pumpScreen(tester, padding: padding);
      final lcd = tester.getRect(find.byType(LcdDisplay));
      final ad = tester.getRect(find.byKey(const ValueKey('banner-ad-slot')));
      expect(lcd.top, greaterThanOrEqualTo(padding.top));
      expect(ad.bottom, lessThanOrEqualTo(844 - padding.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('키패드는 스크롤 영역 안에 있지 않다', (tester) async {
      await _pumpScreen(tester);
      expect(
        find.ancestor(
          of: find.byType(CalcKeypad),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });

    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(412, 915),
      Size(360, 800),
      Size(640, 360),
      Size(800, 1280),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${size.width}×${size.height}, 글자 배율 $scale: 넘침이 없다', (
          tester,
        ) async {
          await _pumpScreen(tester, size: size, textScale: scale);
          expect(tester.takeException(), isNull);
          final ad = tester.getRect(
            find.byKey(const ValueKey('banner-ad-slot')),
          );
          expect(ad.bottom, lessThanOrEqualTo(size.height + 0.01));
        });
      }
    }

    testWidgets('AltCalcApp은 ProviderScope 아래에서 계산기 화면을 띄운다', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: AltCalcApp()));
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));
    });

    testWidgets('main()은 화면을 세로로 고정하고 계산기 화면을 띄운다', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await app.main();
      await tester.pump();
      final call = calls.singleWhere(
        (c) => c.method == 'SystemChrome.setPreferredOrientations',
      );
      expect(call.arguments, ['DeviceOrientation.portraitUp']);
      expect(find.byType(CalculatorScreen), findsOneWidget);
    });
  });

  group('세로 폰 화면의 키 크기 하한', () {
    // 터치 높이(dp) 하한, 배율 반영 메인·각인 글자(dp) 하한
    const minTouchHeight = 28.0;
    const minMainFont = 7.0;
    const minLegendFont = 5.0;

    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(412, 915),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${size.width}×${size.height}, 글자 배율 $scale', (
          tester,
        ) async {
          await _pumpScreen(tester, size: size, textScale: scale);
          final buttons = tester
              .widgetList<CalcKeyButton>(find.byType(CalcKeyButton))
              .toList();
          final scaler = TextScaler.linear(scale)
              .clamp(maxScaleFactor: CalcTheme.keyMaxTextScaleFactor);

          for (final b in buttons) {
            if (b.keyDef.category == KeyCategory.cursor) continue;
            final cell = tester.getSize(find.byWidget(b));
            final touch = b.extendHitAreaToLegend
                ? cell.height
                : cell.height * (1 - CalcTheme.keyLegendHeightRatio);
            expect(
              touch,
              greaterThanOrEqualTo(minTouchHeight),
              reason: b.keyDef.id.name,
            );
          }
          expect(
            scaler.scale(buttons.first.mainLabelFontSize!),
            greaterThanOrEqualTo(minMainFont),
          );
          expect(
            scaler.scale(buttons.first.legendFontSize!),
            greaterThanOrEqualTo(minLegendFont),
          );

          // 주입값만이 아니라 실제 렌더 크기도 본다: 한 글자 라벨(숫자·연산자, 변수 각인 A~F·X·Y·M 등)은
          // FittedBox로 줄지 않아야 한다. (테스트 글꼴은 글자 폭이 실제보다 넓어 긴 라벨은 줄 수 있다.)
          for (final b in buttons) {
            final def = b.keyDef;
            if (def.category == KeyCategory.cursor) continue;
            for (final label in [
              def.mainLabel,
              def.shiftLabel,
              def.alphaLabel,
            ]) {
              if (label == null || label.runes.length != 1) continue;
              final text = find.descendant(
                of: find.byWidget(b),
                matching: find.text(label),
              );
              final rendered = tester.getRect(text).height;
              expect(
                rendered,
                moreOrLessEquals(tester.getSize(text).height, epsilon: 0.01),
                reason: '${def.id.name} "$label"',
              );
            }
          }

          // 커서 패드: 방향 하나의 터치 영역(타원의 1/4)은 함수 키 셀(각인 띠 포함)의 80% 이상이다.
          final pad = tester.getSize(find.byKey(const ValueKey('cursor-pad')));
          final sin = buttons.firstWhere((b) => b.keyDef.id == CalcKeyId.sin);
          final sinCell = tester.getSize(find.byWidget(sin));
          expect(
            math.pi * pad.width * pad.height / 16, // 타원 넓이의 1/4
            greaterThanOrEqualTo(0.8 * sinCell.width * sinCell.height),
          );
        });
      }
    }
  });

  group('LCD 높이', () {
    test('기본은 본체 높이 비율이며 최소 높이를 지킨다', () {
      const body = Size(390, 700);
      expect(
        CalculatorScreen.lcdHeightFor(body),
        moreOrLessEquals(700 * CalcTheme.screenLcdHeightRatio),
      );
      expect(
        CalculatorScreen.lcdHeightFor(const Size(390, 200)),
        CalcTheme.screenLcdMinHeight,
      );
    });

    test('세로로 긴 화면은 키패드 비율 하한을 넘는 높이를 LCD에 준다', () {
      const body = Size(320, 1000);
      final lcd = CalculatorScreen.lcdHeightFor(body);
      final keypad = body.height - lcd - CalcTheme.screenLcdKeypadGap;
      expect(
        keypad,
        moreOrLessEquals(body.width / CalcTheme.keypadMinAspectRatio),
      );
    });

    test('본체가 아주 낮아도 LCD + 간격이 본체를 넘지 않는다', () {
      for (final h in [0.0, 4.0, 50.0, 100.0]) {
        final lcd = CalculatorScreen.lcdHeightFor(Size(360, h));
        expect(lcd, greaterThanOrEqualTo(0));
        expect(
          lcd + CalcTheme.screenLcdKeypadGap,
          lessThanOrEqualTo(math.max(h, CalcTheme.screenLcdKeypadGap)),
        );
      }
    });
  });

  group('상태 머신 연동', () {
    testWidgets('SHIFT → S 켜짐, CALC → SOLVE 입력 후 S 꺼짐', (tester) async {
      final container = await _pumpScreen(tester);

      await tester.tap(_keycap(CalcKeyId.shift));
      await tester.pump();
      expect(container.read(calcProvider).modifier, KeyModifier.shift);
      expect(
        tester.widget<LcdDisplay>(find.byType(LcdDisplay)).status.shift,
        isTrue,
      );

      await tester.tap(_keycap(CalcKeyId.calc));
      await tester.pump();
      expect(container.read(calcProvider).modifier, KeyModifier.none);
      expect(
        tester.widget<LcdDisplay>(find.byType(LcdDisplay)).status.shift,
        isFalse,
      );
      expect(_lcdInputText(tester), 'SOLVE');
    });

    testWidgets('ALPHA → A 켜짐, ( −) → A 입력 후 A 꺼짐', (tester) async {
      final container = await _pumpScreen(tester);
      await tester.tap(_keycap(CalcKeyId.alpha));
      await tester.pump();
      expect(
        tester.widget<LcdDisplay>(find.byType(LcdDisplay)).status.alpha,
        isTrue,
      );
      await tester.tap(_keycap(CalcKeyId.negative));
      await tester.pump();
      expect(container.read(calcProvider).modifier, KeyModifier.none);
      expect(_lcdInputText(tester), 'A');
    });

    testWidgets('DEL을 누른 채 SHIFT를 눌러도 반복은 S를 소비하지 않는다', (tester) async {
      final container = await _pumpScreen(tester);

      final del = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.del)),
        pointer: 1,
      );
      await tester.pump();
      final shift = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.shift)),
        pointer: 2,
      );
      await shift.up();
      await tester.pump(CalcKeyButton.defaultRepeatDelay);
      await tester.pump(CalcKeyButton.defaultRepeatInterval);
      await tester.pump(CalcKeyButton.defaultRepeatInterval);
      await del.up();
      await tester.pump();

      final s = container.read(calcProvider);
      expect(s.modifier, KeyModifier.shift);
      expect(s.inputCount, 4); // 누름 1 + 반복 3
      expect(
        s.lastInput,
        KeyInput(CalcKeyId.del, KeyLayer.main, isRepeat: true),
      );
    });

    testWidgets('키 입력으로 키패드는 다시 빌드되지 않는다', (tester) async {
      await _pumpScreen(tester);
      final before = tester.element(find.byType(CalcKeypad)).widget;
      await tester.tap(_keycap(CalcKeyId.shift));
      await tester.pump();
      await tester.tap(_keycap(CalcKeyId.num7));
      await tester.pump();
      expect(
        identical(tester.element(find.byType(CalcKeypad)).widget, before),
        isTrue,
      );
    });
  });
}
