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

  group('화면 배치 기준 (CalcScreenLayout)', () {
    void expectSumsToBody(Size body, CalcScreenLayout l) {
      for (final v in [l.top, l.lcdHeight, l.keypadHeight]) {
        expect(v, greaterThanOrEqualTo(0), reason: '$body $l');
      }
      expect(
        l.top + l.lcdHeight + CalcTheme.screenLcdKeypadGap + l.keypadHeight,
        moreOrLessEquals(
          math.max(body.height, CalcTheme.screenLcdKeypadGap),
          epsilon: 1e-9,
        ),
        reason: '$body $l',
      );
    }

    test('기본은 본체 높이 비율이고 상단 띠가 없다', () {
      const body = Size(390, 700);
      final l = CalcScreenLayout.of(body);
      expect(
        l.lcdHeight,
        moreOrLessEquals(700 * CalcTheme.screenLcdHeightRatio),
      );
      expect(l.top, 0);
      expectSumsToBody(body, l);
    });

    test('낮은 본체에서도 LCD 최소 높이를 지킨다', () {
      final l = CalcScreenLayout.of(const Size(390, 200));
      expect(l.lcdHeight, CalcTheme.screenLcdMinHeight);
      expect(l.top, 0);
    });

    test('키패드가 비율 하한에 걸려 남는 높이는 LCD 최대 높이까지 LCD가 받는다', () {
      const body = Size(390, 720);
      final l = CalcScreenLayout.of(body);
      final keypadMax = body.width / CalcTheme.keypadMinAspectRatio;
      expect(l.keypadHeight, moreOrLessEquals(keypadMax));
      expect(l.lcdHeight, greaterThan(720 * CalcTheme.screenLcdHeightRatio));
      expect(
        l.lcdHeight,
        lessThan(body.width / CalcTheme.screenLcdMinAspectRatio),
      );
      expect(l.top, moreOrLessEquals(0));
      expectSumsToBody(body, l);
    });

    test('LCD 최대 높이를 넘어 남는 높이는 LCD 위 상단 띠가 된다', () {
      const body = Size(320, 1000);
      final l = CalcScreenLayout.of(body);
      expect(
        l.lcdHeight,
        moreOrLessEquals(body.width / CalcTheme.screenLcdMinAspectRatio),
      );
      expect(
        l.keypadHeight,
        moreOrLessEquals(body.width / CalcTheme.keypadMinAspectRatio),
      );
      expect(l.top, greaterThan(0));
      expectSumsToBody(body, l);
    });

    test('좁은 폭에서도 LCD 최대 높이는 최소 높이 아래로 내려가지 않는다', () {
      final l = CalcScreenLayout.of(const Size(100, 900));
      expect(l.lcdHeight, CalcTheme.screenLcdMinHeight);
    });

    test('본체가 아주 낮거나 좁아도 음수 없이 본체를 넘지 않는다', () {
      for (final body in const [
        Size(360, 0),
        Size(360, 4),
        Size(360, 50),
        Size(360, 100),
        Size(0, 600),
        Size(0, 0),
        Size(2000, 300),
      ]) {
        expectSumsToBody(body, CalcScreenLayout.of(body));
      }
    });
  });

  group('폰 화면비별 LCD 확인', () {
    // 소형(4", 16:9) ~ 대형(6.7", 19.5:9)·초장형(21:9) 세로 폰
    const phones = [
      Size(320, 568),
      Size(360, 640),
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
      Size(411, 960),
    ];
    final input = find.byKey(const ValueKey('lcd-input-line'));
    final result = find.byKey(const ValueKey('lcd-result-line'));
    Finder content(Finder line) => find.descendant(
      of: line,
      matching: find.byKey(const ValueKey('lcd-line-content')),
    );

    for (final size in phones) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${size.width}×${size.height}, 글자 배율 $scale', (
          tester,
        ) async {
          await _pumpScreen(tester, size: size, textScale: scale);
          expect(tester.takeException(), isNull);
          final lcdRect = tester.getRect(find.byType(LcdDisplay));
          final keypad = tester.getRect(
            find.byKey(const ValueKey('calc-keypad')),
          );
          final ad = tester.getRect(
            find.byKey(const ValueKey('banner-ad-slot')),
          );

          // LCD는 본체(광고 슬롯 위)의 목표 비율 근처를 차지하고, 키패드는 광고 슬롯 바로 위에 붙는다.
          final body = ad.top - CalcTheme.adSlotSafetyMargin;
          expect(lcdRect.height / body, inInclusiveRange(0.2, 0.3));
          expect(
            ad.top - keypad.bottom,
            moreOrLessEquals(CalcTheme.adSlotSafetyMargin, epsilon: 0.01),
          );
          expect(lcdRect.bottom, lessThanOrEqualTo(keypad.top));

          // 주입된 글자 크기는 LCD 크기에서 산출한 값이고 줄 높이 맞춤으로 다시 줄지 않는다.
          final lcd = tester.widget<LcdDisplay>(find.byType(LcdDisplay));
          final scaler = TextScaler.linear(scale)
              .clamp(maxScaleFactor: CalcTheme.lcdMaxTextScaleFactor);
          final fonts = LcdFontSizes.forSize(lcdRect.size, scaler);
          expect(lcd.inputFontSize, fonts.input);
          expect(lcd.resultFontSize, fonts.result);
          expect(lcd.statusFontSize, fonts.status);
          final rendered = DefaultTextStyle.of(
            tester.element(find.byKey(const ValueKey('lcd-input-text'))),
          ).style;
          expect(rendered.fontSize, fonts.input);

          // 배율 반영 줄 글자는 폰에서 20dp 이상이고, 배율을 키워도 LCD 크기로 정해진 값을 넘지 않는다.
          final scaledLine = scaler.scale(fonts.input);
          expect(scaledLine, greaterThanOrEqualTo(20));
          expect(
            scaledLine,
            moreOrLessEquals(
              LcdFontSizes.forSize(lcdRect.size, TextScaler.noScaling).input,
              epsilon: 0.01,
            ),
          );

          // 입력 줄은 2행 템플릿, 결과 줄은 1행을 담고, 결과 줄은 최대 결과 칸 수를 담는다.
          final row = (scaledLine * CalcTheme.lcdInputStyle.height!)
              .ceilToDouble();
          expect(
            tester.getSize(input).height,
            greaterThanOrEqualTo(CalcTheme.lcdInputLineFlex * row),
          );
          expect(tester.getSize(result).height, greaterThanOrEqualTo(row));
          expect(
            tester.getSize(content(result)).width,
            greaterThanOrEqualTo(
              CalcTheme.lcdLineColumns *
                      (scaledLine * CalcTheme.lcdLineCharWidthRatio +
                          CalcTheme.lcdResultStyle.letterSpacing!) -
                  0.01,
            ),
          );
        });
      }
    }
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
