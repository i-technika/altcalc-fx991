import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/core/theme/high_text_contrast.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/main.dart' as app show main;
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/korean_locale.dart';
import '../support/screen_arrangement.dart';
import '../support/touch_metrics.dart';

/// 화면 크기·인셋을 지정해 [CalculatorScreen]을 띄우고 상태 컨테이너를 돌려준다.
Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  EdgeInsets padding = EdgeInsets.zero,
  double textScale = 1.0,
  bool supportsAnnounce = false,
  bool accessibleNavigation = false,
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
            supportsAnnounce: supportsAnnounce,
            accessibleNavigation: accessibleNavigation,
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return container;
}

/// 폴더블 내부 화면의 세로 접힘선 (펼친 상태)
const _verticalFold = DisplayFeature(
  bounds: Rect.fromLTWH(420, 0, 0, 701),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

String _lcdInputText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('lcd-input-text'))).data!;

void main() {
  group('조립', () {
    testWidgets('LCD 위, 50키 키패드 아래 — 맨 아래 광고 슬롯 없이 키패드가 화면 여백까지 내려온다 (#141)', (
      tester,
    ) async {
      await _pumpScreen(tester);
      expect(find.byType(LcdDisplay), findsOneWidget);
      expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));
      expect(find.byKey(const ValueKey('banner-ad-slot')), findsNothing);

      final lcd = tester.getRect(find.byType(LcdDisplay));
      final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
      expect(lcd.bottom, lessThanOrEqualTo(keypad.top));
      expect(
        keypad.bottom,
        moreOrLessEquals(844 - CalcTheme.screenPadding, epsilon: 0.01),
      );
    });

    testWidgets('상단 시스템 인셋은 LCD가, 하단 인셋은 키패드가 피한다 (#141)', (tester) async {
      const padding = EdgeInsets.only(top: 47, bottom: 34);
      await _pumpScreen(tester, padding: padding);
      final lcd = tester.getRect(find.byType(LcdDisplay));
      final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
      expect(lcd.top, greaterThanOrEqualTo(padding.top));
      // 키패드는 아래 인셋 위 화면 여백까지 쓴다.
      expect(
        keypad.bottom,
        moreOrLessEquals(
          844 - padding.bottom - CalcTheme.screenPadding,
          epsilon: 0.01,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    // 태블릿 세로(#141): LCD와 키패드가 창 폭 전체(좌우 인셋·화면 여백 안)를 쓴다 — 예전에는 둘 다 480dp에서 멈춰
    // 가운데에 놓였다. (창, 인셋)
    for (final (size, padding) in const [
      (Size(800, 1280), EdgeInsets.only(top: 24, bottom: 48)), // 10인치 Android
      (Size(1024, 1366), EdgeInsets.only(top: 24, bottom: 20)), // 12.9인치 iPad
      (Size(768, 1024), EdgeInsets.only(top: 24, bottom: 20)), // iPad
      (Size(800, 1280), EdgeInsets.only(left: 30, top: 24, right: 30)),
    ]) {
      testWidgets(
        '태블릿 세로 ${size.width}×${size.height}·인셋 $padding: LCD·키패드가 전체 폭이다',
        (tester) async {
          await _pumpScreen(tester, size: size, padding: padding);
          expect(tester.takeException(), isNull);
          expect(isStackedArrangement(tester), isTrue);
          final left = padding.left + CalcTheme.screenPadding;
          final right = size.width - padding.right - CalcTheme.screenPadding;
          final lcd = tester.getRect(find.byType(LcdDisplay));
          final keypad = tester.getRect(
            find.byKey(const ValueKey('calc-keypad')),
          );
          for (final r in [lcd, keypad]) {
            expect(r.left, moreOrLessEquals(left, epsilon: 0.01), reason: '$r');
            expect(
              r.right,
              moreOrLessEquals(right, epsilon: 0.01),
              reason: '$r',
            );
          }
          // 키패드는 아래 인셋 위 화면 여백까지 내려온다.
          expect(
            keypad.bottom,
            moreOrLessEquals(
              size.height - padding.bottom - CalcTheme.screenPadding,
              epsilon: 0.01,
            ),
          );
          // 키는 세로로 길어지지 않는다(키패드 가로/세로 비 하한).
          expect(
            keypad.width / keypad.height,
            greaterThanOrEqualTo(CalcTheme.keypadMinAspectRatio - 1e-6),
          );
          // 키가 넓어져도 각인 글자는 상한에서 멈춘다.
          for (final button in tester.widgetList<CalcKeyButton>(
            find.byType(CalcKeyButton),
          )) {
            expect(
              button.mainLabelFontSize,
              lessThanOrEqualTo(CalcTheme.keyMainLabelMaxFontSize),
            );
            expect(
              button.legendFontSize,
              lessThanOrEqualTo(CalcTheme.keyLegendMaxFontSize),
            );
          }
        },
      );
    }

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
          final keypad = tester.getRect(
            find.byKey(const ValueKey('calc-keypad')),
          );
          expect(keypad.bottom, lessThanOrEqualTo(size.height + 0.01));
        });
      }
    }

    testWidgets('AltCalcApp은 ProviderScope 아래에서 계산기 화면을 띄운다', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: AltCalcApp()));
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(find.byType(CalcKeyButton), findsNWidgets(totalKeyCount));
    });
  });

  group('main() — 방향 고정과 설정 불러오기 (#24)', () {
    /// 플랫폼 채널 호출을 기록한다.
    List<MethodCall> recordPlatformCalls(WidgetTester tester) {
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
      return calls;
    }

    List<Object?> orientationRequests(List<MethodCall> calls) => [
      for (final c in calls)
        if (c.method == 'SystemChrome.setPreferredOrientations') c.arguments,
    ];

    /// 고대비 텍스트 채널이 구독 시작 때 [enabled]를 보내게 한다. 앱 전체 수신기는 테스트가 끝나면 멈춘다.
    void mockHighTextContrast(WidgetTester tester, {required bool enabled}) {
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        SystemHighTextContrast.channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) => events.success(enabled),
        ),
      );
      // 정리는 나중에 등록한 것부터 실행된다 — 구독을 먼저 끝낸 뒤 목을 푼다.
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockStreamHandler(
          SystemHighTextContrast.channel,
          null,
        ),
      );
      addTearDown(SystemHighTextContrast.instance.stop);
    }

    /// 물리 화면과 창을 [size](dp)로 맞춘다 (화면 배율 2).
    void setDevice(WidgetTester tester, Size size) {
      tester.view.display.devicePixelRatio = 2;
      tester.view.display.size = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = size * 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.view.display.reset);
      addTearDown(DeviceOrientationLock.instance.stop);
      // 폴더블 판정 조회 채널: 기본은 "폴더블 아님". 채널을 흉내 내지 않으면 테스트의 가짜 비동기 안에서
      // 응답이 오지 않아 main()이 끝나지 않는다.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        FormFactor.deviceChannel,
        (call) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          FormFactor.deviceChannel,
          null,
        ),
      );
      // 고대비 텍스트 채널(#95): 기본은 "꺼짐". 흉내 내지 않으면 첫 값을 기다리다 가짜 비동기 안에서 끝나지 않는다.
      mockHighTextContrast(tester, enabled: false);
    }

    testWidgets('폰: 세로로 고정하고 계산기 화면을 띄운다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setDevice(tester, const Size(390, 844));
      final calls = recordPlatformCalls(tester);
      await app.main();
      await tester.pump();
      expect(orientationRequests(calls), [
        ['DeviceOrientation.portraitUp'],
      ]);
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(isStackedArrangement(tester), isTrue);
    });

    testWidgets('태블릿: 가로로 고정하고 좌우 분할로 띄운다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setDevice(tester, const Size(1280, 800));
      final calls = recordPlatformCalls(tester);
      await app.main();
      await tester.pump();
      expect(orientationRequests(calls), [
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      ]);
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
    });

    testWidgets('Android 고대비 텍스트가 켜져 있으면 첫 화면부터 고대비 팔레트다 (#95)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      setDevice(tester, const Size(390, 844));
      // 첫 값을 다른 시작 작업이 모두 끝난 뒤에 보내, main()이 그 값을 기다린 뒤에야 화면을 띄우는지 본다.
      MockStreamHandlerEventSink? sink;
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        SystemHighTextContrast.channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            sink = events;
          },
        ),
      );
      recordPlatformCalls(tester);
      var started = false;
      final running = app.main().then((_) => started = true);
      await tester.pump();
      await tester.pump();
      expect(sink, isNotNull);
      expect(started, isFalse);
      expect(find.byType(CalculatorScreen), findsNothing);

      sink!.success(true);
      await running;
      // runApp 뒤 첫 프레임
      await tester.pump();
      final keycap =
          tester
                  .widget<AnimatedContainer>(
                    find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.add)),
                  )
                  .decoration!
              as BoxDecoration;
      expect(
        keycap.color,
        CalcPalette.highContrast.keyBackground(KeyCategory.operator),
      );
    });

    testWidgets('저장된 왼손잡이 설정이 첫 화면부터 반영된다', (tester) async {
      SharedPreferences.setMockInitialValues({
        HandednessNotifier.storageKey: 'left',
      });
      setDevice(tester, const Size(1280, 800));
      recordPlatformCalls(tester);
      await app.main();
      await tester.pump();
      final lcd = tester.getRect(find.byType(LcdDisplay));
      final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
      expect(keypad.right, lessThan(lcd.left));
    });

    /// 폴더블 판정 조회 채널 응답을 [foldable]로 고정한다.
    void mockFoldableDevice(WidgetTester tester, {required bool foldable}) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        FormFactor.deviceChannel,
        (call) async => foldable,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          FormFactor.deviceChannel,
          null,
        ),
      );
    }

    /// 네 방향 모두 허용 요청 ([OrientationPolicy.any])
    final anyOrientation = [
      for (final o in FormFactor.preferredOrientationsOf(OrientationPolicy.any))
        o.toString(),
    ];

    testWidgets(
      '폴더블(시작 시 판정): 펼친 내부 화면은 처음부터 네 방향을 허용하고, 접힘 정보가 오면 접힘선 기준으로 나눈다',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        // 내부 화면을 가로로 든 상태, 접힘 정보는 아직 도착 전
        setDevice(tester, const Size(841, 701));
        mockFoldableDevice(tester, foldable: true);
        final calls = recordPlatformCalls(tester);
        await app.main();
        await tester.pump();
        expect(orientationRequests(calls), [anyOrientation]);
        expect(
          DeviceOrientationLock.instance.appliedPolicy,
          OrientationPolicy.any,
        );
        // 접힘 정보가 오기 전에는 위아래 배치 (깜빡임 방지)
        expect(isStackedArrangement(tester), isTrue);

        // 접힘 정보가 오면 다시 요청하지 않고, 접힘선(x = 420) 양쪽에 LCD·키패드를 나눈다.
        tester.view.displayFeatures = const [_verticalFold];
        addTearDown(tester.view.resetDisplayFeatures);
        await tester.pump();
        expect(orientationRequests(calls), hasLength(1));
        expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
        final lcd = tester.getRect(find.byType(LcdDisplay));
        final keypad = tester.getRect(
          find.byKey(const ValueKey('calc-keypad')),
        );
        expect(lcd.right, lessThanOrEqualTo(420));
        expect(keypad.left, greaterThanOrEqualTo(420));
      },
    );

    testWidgets(
      '시작 시 판정이 놓친 폴더블: 접힘 정보가 오면 네 방향 허용으로 다시 요청하고, 같은 정책이면 다시 요청하지 않는다',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        setDevice(tester, const Size(841, 701));
        final calls = recordPlatformCalls(tester);
        await app.main();
        await tester.pump();
        // 시작 시 판정이 놓치면 시작 시점에는 태블릿으로 판정된다(대비책 경로).
        expect(orientationRequests(calls), hasLength(1));
        expect(
          DeviceOrientationLock.instance.appliedPolicy,
          OrientationPolicy.landscape,
        );

        tester.view.displayFeatures = const [_verticalFold];
        addTearDown(tester.view.resetDisplayFeatures);
        await tester.pump();
        expect(orientationRequests(calls).last, anyOrientation);
        expect(
          DeviceOrientationLock.instance.appliedPolicy,
          OrientationPolicy.any,
        );
        // 접힘선이 창을 가로지르므로 접힘선 기준 좌우 배치다.
        expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);

        // 정책이 그대로인 화면 정보 변화(회전 등)에는 다시 요청하지 않는다.
        tester.view.physicalSize = const Size(701, 841) * 2;
        await tester.pump();
        expect(orientationRequests(calls), hasLength(2));
      },
    );

    testWidgets('폴더블: 접으면 세로로, 펴면 네 방향 허용으로 다시 요청하고 계산기 상태는 유지된다', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      const inner = Size(673, 841);
      const cover = Size(344, 882);
      const innerFold = DisplayFeature(
        bounds: Rect.fromLTWH(336.5, 0, 0, 841),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      );
      setDevice(tester, inner);
      tester.view.displayFeatures = const [innerFold];
      addTearDown(tester.view.resetDisplayFeatures);
      mockFoldableDevice(tester, foldable: true);
      final calls = recordPlatformCalls(tester);
      await app.main();
      await tester.pump();
      expect(orientationRequests(calls), [anyOrientation]);
      expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);

      // 펼친 화면에서 키를 누른다.
      await tester.tap(find.byKey(CalcKeyButton.keycapKeyOf(CalcKeyId.sin)));
      await tester.pump();
      final input = _lcdInputText(tester);
      expect(input, isNotEmpty);
      final lcdElement = tester.element(find.byType(LcdDisplay));
      final keypadElement = tester.element(
        find.byKey(const ValueKey('calc-keypad')),
      );

      // 접는다: 커버 화면으로 바뀌고 접힘 정보가 사라진다.
      tester.view.display.size = cover * 2;
      tester.view.physicalSize = cover * 2;
      tester.view.displayFeatures = const [];
      await tester.pump();
      expect(orientationRequests(calls).last, ['DeviceOrientation.portraitUp']);
      expect(isStackedArrangement(tester), isTrue);
      expect(_lcdInputText(tester), input);
      expect(tester.element(find.byType(LcdDisplay)), same(lcdElement));
      expect(
        tester.element(find.byKey(const ValueKey('calc-keypad'))),
        same(keypadElement),
      );

      // 다시 편다.
      tester.view.display.size = inner * 2;
      tester.view.physicalSize = inner * 2;
      tester.view.displayFeatures = const [innerFold];
      await tester.pump();
      expect(orientationRequests(calls).last, anyOrientation);
      expect(orientationRequests(calls), hasLength(3));
      expect(_lcdInputText(tester), input);
      expect(tester.element(find.byType(LcdDisplay)), same(lcdElement));
    });

    testWidgets(
      '커버 화면에서 시작해 시작 시 판정이 놓친 폴더블: 펼치면 접힘 정보 전에도 폴더블로 판정한다 — 가로 요청·좌우 분할 없음 (#70)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        const cover = Size(344, 882);
        // 내부 화면을 가로로 든 채 펼친다 (Android 16 이상은 대화면에서 방향 고정을 무시한다)
        const innerLandscape = Size(841, 673);
        const innerFold = DisplayFeature(
          bounds: Rect.fromLTWH(420.5, 0, 0, 673),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        );
        setDevice(tester, cover);
        addTearDown(tester.view.resetDisplayFeatures);
        final calls = recordPlatformCalls(tester);
        await app.main();
        await tester.pump();
        expect(orientationRequests(calls), [
          ['DeviceOrientation.portraitUp'],
        ]);
        expect(DeviceOrientationLock.instance.foldableDevice.value, isFalse);

        // 펼친다: 물리 화면이 비율이 다른 화면으로 바뀐다. 접힘 정보는 아직 없다.
        tester.view.display.size = innerLandscape * 2;
        tester.view.physicalSize = innerLandscape * 2;
        await tester.pump();
        expect(DeviceOrientationLock.instance.foldableDevice.value, isTrue);
        expect(orientationRequests(calls).last, anyOrientation);
        expect(
          orientationRequests(calls),
          isNot(
            contains([
              'DeviceOrientation.landscapeLeft',
              'DeviceOrientation.landscapeRight',
            ]),
          ),
        );
        // 같은 프레임의 배치도 폴더블 규칙이다: 접힘 정보 전에는 위아래 배치
        expect(isStackedArrangement(tester), isTrue);

        // 접힘 정보가 오면 접힘선 기준 좌우 배치
        tester.view.displayFeatures = const [innerFold];
        await tester.pump();
        expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
      },
    );

    testWidgets(
      '시작 시 판정이 놓친 폴더블: 접힘 정보를 한 번 본 뒤에는 접힘 정보가 잠시 사라져도 좌우 분할로 그리지 않는다 (#70)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        // 물리 화면은 그대로(크기 변화로는 알 수 없다), 접힘 정보만 오간다
        const innerLandscape = Size(841, 673);
        const innerFold = DisplayFeature(
          bounds: Rect.fromLTWH(420.5, 0, 0, 673),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        );
        setDevice(tester, innerLandscape);
        addTearDown(tester.view.resetDisplayFeatures);
        final calls = recordPlatformCalls(tester);
        await app.main();
        await tester.pump();
        // 시작 시점에는 태블릿으로 판정된다(대비책 경로)
        expect(drawnArrangementOf(tester), DrawnArrangement.sideBySide);
        expect(
          DeviceOrientationLock.instance.appliedPolicy,
          OrientationPolicy.landscape,
        );

        tester.view.displayFeatures = const [innerFold];
        await tester.pump();
        expect(DeviceOrientationLock.instance.foldableDevice.value, isTrue);
        expect(orientationRequests(calls).last, anyOrientation);

        // 접힘 정보가 사라진다(회전 직후처럼 몇 프레임 늦게 다시 오는 구간) — 폴더블 규칙대로 위아래 배치
        tester.view.displayFeatures = const [];
        await tester.pump();
        expect(isStackedArrangement(tester), isTrue);
        expect(
          DeviceOrientationLock.instance.appliedPolicy,
          OrientationPolicy.any,
        );
      },
    );

    testWidgets('방향 요청이 실패해도 앱은 뜨고, 다음 화면 정보 변화 때 다시 요청한다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setDevice(tester, const Size(390, 844));
      var attempts = 0;
      var fail = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            attempts++;
            if (fail) throw PlatformException(code: 'unavailable');
          }
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
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(attempts, 1);
      expect(DeviceOrientationLock.instance.appliedPolicy, isNull);

      fail = false;
      tester.view.physicalSize = const Size(391, 844) * 2;
      await tester.pump();
      expect(attempts, 2);
      expect(
        DeviceOrientationLock.instance.appliedPolicy,
        OrientationPolicy.portrait,
      );
    });
  });

  group('세로 폰 화면의 키 크기 하한', () {
    // 배율 반영 메인 글자(dp) 하한
    const minMainFont = 7.0;

    // (창, 인셋, 터치 높이 하한, 배율 반영 각인 글자 하한) — 모두 터치 [CalcTheme.keyTouchHeightFloor]·각인 5.0dp.
    // #141 전에는 가장 작은 320×568만 하한을 낮췄다(#41 — 상단 띠 최소 높이의 비용: 상태바 20dp에서 키 터치 27.96dp,
    // 각인 4.70dp). 맨 아래 광고 슬롯(50dp + 안전 여백 10dp)이 빠지고 아래 화면 여백 8dp가 생겨 본체가 52dp
    // 높아진 뒤로는 그 크기도 기본 하한을 지킨다(키 터치 31.1dp — [CalcTheme] "화면 배치" 절 실측).
    const floor = CalcTheme.keyTouchHeightFloor;
    for (final (size, padding, minTouchHeight, minLegendFont) in const [
      (Size(320, 568), EdgeInsets.zero, floor, 5.0),
      (Size(320, 568), EdgeInsets.only(top: 20), floor, 5.0),
      (Size(360, 640), EdgeInsets.zero, floor, 5.0),
      (Size(360, 640), EdgeInsets.only(top: 24, bottom: 48), floor, 5.0),
      (Size(390, 844), EdgeInsets.zero, floor, 5.0),
      (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34), floor, 5.0),
      (Size(412, 915), EdgeInsets.zero, floor, 5.0),
      (Size(412, 915), EdgeInsets.only(top: 24, bottom: 48), floor, 5.0),
      (Size(440, 956), EdgeInsets.only(top: 62, bottom: 34), floor, 5.0),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${size.width}×${size.height}·인셋 ${padding.top}/'
            '${padding.bottom}, 글자 배율 $scale', (tester) async {
          await _pumpScreen(
            tester,
            size: size,
            padding: padding,
            textScale: scale,
          );
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

          // 주입값만이 아니라 실제 렌더 크기도 본다: 한 글자 라벨(숫자·연산자, 변수 각인 A~F·x·y·M 등)은
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

          // 커서 패드 (#43·#64): 가운데 데드존·홈이 깎아도 방향 키마다 손가락이 들어갈 터치 영역이 남는다.
          // 터치 영역은 외곽 밖·셀 여백까지 넓힌 것이다(#64, 그림 구역보다 넓다 — CursorPad 문서).
          // - 내접원 지름(터치 영역에 들어가는 가장 큰 원): ▲·▼는 터치 하한 이상, 실물처럼 좁게 만든
          //   ◀·▶도 터치 하한의 95% 이상이다(#64 전 90%, 320×568에서 약 27.9dp).
          //   ◀·▶ 내접원은 #64로 거의 늘지 않았다(약 +1dp) — 홈 사이 쐐기(그린 구역)가 정하기 때문이다.
          // - 넓이: 함수 키 셀(각인 띠 포함) 대비 ▲·▼는 135%, ◀·▶는 78% 이상이다
          //   (#64 전 그림 구역 기준 ◀·▶ 0.54~0.58배 → 터치 영역 0.81~0.84배).
          //   (함수 키 셀의 터치 높이와 직접 비교하지 않는다 — 그 높이는 각인 띠까지 넓힌 값이고,
          //   방향 키 구역은 함수 키보다 2~3배 넓다.)
          final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
          final cell = tester.getRect(find.byType(CursorPad));
          final sin = buttons.firstWhere((b) => b.keyDef.id == CalcKeyId.sin);
          final sinCell = tester.getSize(find.byWidget(sin));
          final cellArea = sinCell.width * sinCell.height;
          final g = CursorPadGeometry(pad.size);
          final bounds = cell.shift(-pad.topLeft);
          for (final sector in CursorPadSector.values) {
            final wide =
                sector == CursorPadSector.up || sector == CursorPadSector.down;
            expect(
              hitInscribedDiameter(g, sector, bounds),
              greaterThanOrEqualTo(minTouchHeight * (wide ? 1.0 : 0.95)),
              reason: '${sector.name} 내접원 ${pad.size}',
            );
            expect(
              g.hitArea(sector, bounds),
              greaterThanOrEqualTo(cellArea * (wide ? 1.35 : 0.78)),
              reason: '${sector.name} 넓이 ${pad.size}',
            );
          }
        });
      }
    }
  });

  group('화면 배치 기준 (CalcScreenLayout)', () {
    void expectSumsToBody(Size body, CalcScreenLayout l) {
      for (final v in [l.top, l.lcdHeight, l.gap, l.keypadHeight]) {
        expect(v, greaterThanOrEqualTo(0), reason: '$body $l');
      }
      expect(
        l.top + l.lcdHeight + l.gap + l.keypadHeight,
        moreOrLessEquals(body.height, epsilon: 1e-9),
        reason: '$body $l',
      );
    }

    // 상단 띠 최소 높이 (#41) — LCD·키패드는 본체 높이에서 이것을 뺀 높이를 나눈다.
    const strip = CalcTheme.screenTopStripMinHeight;

    test('기본은 (본체 높이 − 최소 띠) 비율이고 상단 띠는 최소 높이다', () {
      const body = Size(390, 700);
      final l = CalcScreenLayout.of(body);
      expect(l.lcdHeight, moreOrLessEquals((700 - strip) * 0.28));
      expect(l.top, strip);
      expect(l.gap, CalcTheme.screenLcdKeypadGap);
      expectSumsToBody(body, l);
    });

    test('낮은 본체에서도 LCD 최소 높이를 지킨다', () {
      const body = Size(390, 200);
      final l = CalcScreenLayout.of(body);
      expect(l.lcdHeight, CalcTheme.screenLcdMinHeight);
      expect(l.top, strip);
      expectSumsToBody(body, l);
    });

    test('키패드가 비율 하한에 걸려 남는 높이는 LCD 최대 높이까지 LCD가 받는다', () {
      // 최소 띠를 뺀 745: 키패드 최대 390 / 0.75 = 520, LCD = 737 − 520 = 217
      // (목표 745 × 0.28 = 208.6 초과, 최대 390 / 1.75 ≈ 222.9 미만)
      const body = Size(390, 745 + strip);
      final l = CalcScreenLayout.of(body);
      expect(l.keypadHeight, moreOrLessEquals(520));
      expect(l.lcdHeight, moreOrLessEquals(217));
      expect(l.top, moreOrLessEquals(strip));
      expectSumsToBody(body, l);
    });

    test('남는 높이가 최소 띠 이상이면 최소 띠가 없을 때와 같은 배치다 (#41)', () {
      // LCD 최대 374 / 1.75, 키패드 최대 374 / 0.75 — 남는 높이 768 − 둘 ≈ 55.6 ≥ 12
      const body = Size(374, 776);
      final l = CalcScreenLayout.of(body);
      expect(l.lcdHeight, moreOrLessEquals(374 / 1.75));
      expect(l.keypadHeight, moreOrLessEquals(374 / 0.75));
      expect(l.top, moreOrLessEquals(768 - 374 / 1.75 - 374 / 0.75));
      expectSumsToBody(body, l);
    });

    test('남는 높이가 최소 띠보다 낮으면 모자란 만큼만 LCD가 줄어든다 (#41)', () {
      // 남는 높이 5 (본체 = 간격 8 + LCD 최대 + 키패드 최대 + 5) → 띠 12, 모자란 7은 LCD가 낸다
      // (키패드는 최대 그대로 — 키패드가 다 쓰지 못한 높이를 LCD가 받는 규칙 그대로다)
      const lcdMax = 374 / 1.75;
      const keypadMax = 374 / 0.75;
      const body = Size(374, 8 + lcdMax + keypadMax + 5);
      final l = CalcScreenLayout.of(body);
      expect(l.top, moreOrLessEquals(strip));
      expect(l.keypadHeight, moreOrLessEquals(keypadMax));
      expect(l.lcdHeight, moreOrLessEquals(lcdMax - (strip - 5)));
      expectSumsToBody(body, l);
    });

    test('LCD 최대 높이를 넘어 남는 높이는 LCD 위 상단 띠가 된다', () {
      // LCD 최대 320 / 1.75 ≈ 182.86, 키패드 최대 320 / 0.75 ≈ 426.67
      const body = Size(320, 1000);
      final l = CalcScreenLayout.of(body);
      expect(l.lcdHeight, moreOrLessEquals(320 / 1.75));
      expect(l.keypadHeight, moreOrLessEquals(320 / 0.75));
      expect(l.top, moreOrLessEquals(992 - 320 / 1.75 - 320 / 0.75));
      expectSumsToBody(body, l);
    });

    test(
      '태블릿 세로 본체: 폭 상한이 없어 키패드 최대 높이에 닿지 않고, LCD는 목표 비율·키패드는 나머지 전부다 (#141)',
      () {
        // 12.9인치 iPad 세로 본체 1008×1306: 키패드 최대 1008 / 0.75 = 1344, LCD 최대 1008 / 1.75 = 576.
        // 키패드가 실물 크기(640)보다 높아 띠를 줄 전체 높이(본체 안 40dp)까지 늘린다 — 늘린 몫은 키패드만 낸다
        // (LCD는 최소 띠 기준 목표 비율 그대로, #141 R1·R2).
        const fullRow =
            CalcTheme.topStripRowMaxHeight - CalcTheme.screenPadding;
        const body = Size(1008, 1306);
        final l = CalcScreenLayout.of(body);
        expect(l.lcdHeight, moreOrLessEquals((1306 - strip) * 0.28));
        expect(
          l.keypadHeight,
          moreOrLessEquals(
            1306 - fullRow - CalcTheme.screenLcdKeypadGap - l.lcdHeight,
          ),
        );
        expect(l.top, moreOrLessEquals(fullRow));
        expectSumsToBody(body, l);

        // 10인치 Android 세로 본체 784×1192: 설계 시안(2026-11-26 확정안)의 띠 44·LCD 330·키패드 838에 가깝다.
        final android = CalcScreenLayout.of(const Size(784, 1192));
        expect(android.lcdHeight, moreOrLessEquals(330.4, epsilon: 0.1));
        expect(android.keypadHeight, moreOrLessEquals(813.6, epsilon: 0.1));
        expect(android.top, moreOrLessEquals(fullRow));

        // 짧고 넓은 본체(가로 폰·분할 화면)도 높이 규칙은 같다 — 화면은 그런 창을 대개 좌우 분할로 그린다(#38).
        final short = CalcScreenLayout.of(const Size(2000, 300));
        expect(short.lcdHeight, CalcTheme.screenLcdMinHeight);
        expectSumsToBody(const Size(2000, 300), short);
      },
    );

    test(
      '큰 세로 창의 띠: 키패드를 실물 크기(640dp) 아래로 줄이지 않는 만큼만 줄 전체 높이까지 늘린다 (#141 R1)',
      () {
        const fullRow =
            CalcTheme.topStripRowMaxHeight - CalcTheme.screenPadding;
        const floor = CalcTheme.screenTopStripFullRowKeypadMinHeight;
        // 키패드가 640 미만이면 최소 띠 그대로 (정사각형 창 752×752, 752×900)
        for (final body in const [Size(752, 752), Size(752, 900)]) {
          final l = CalcScreenLayout.of(body);
          expect(l.keypadHeight, lessThan(floor), reason: '$l');
          expect(l.top, moreOrLessEquals(strip), reason: '$l');
        }
        // 가장 넓은 폰(본체 424×844)은 키패드가 폭 기준 최대 높이(565dp)에 닿아 남는 높이가 띠가 될 뿐, 띠를 늘리지 않는다.
        final phone = CalcScreenLayout.of(const Size(424, 844));
        expect(phone.keypadHeight, moreOrLessEquals(424 / 0.75));
        expect(phone.top, lessThan(fullRow));
        // 그 사이: 키패드가 정확히 640이 되는 만큼만 띠가 늘어난다.
        final partial = CalcScreenLayout.of(const Size(752, 920));
        expect(partial.keypadHeight, moreOrLessEquals(floor, epsilon: 1e-6));
        expect(partial.top, inExclusiveRange(strip, fullRow));
        expectSumsToBody(const Size(752, 920), partial);
        // 높이를 늘려도 키패드는 줄지 않고, 띠는 줄 전체 높이에서 멈춘다(남는 높이가 생기면 그만큼 더 커진다).
        var previousKeypad = 0.0;
        var previousTop = 0.0;
        for (var h = 700.0; h <= 1400; h += 5) {
          final l = CalcScreenLayout.of(Size(752, h));
          expect(l.keypadHeight, greaterThanOrEqualTo(previousKeypad - 1e-6));
          expect(l.top, greaterThanOrEqualTo(previousTop - 1e-6));
          expectSumsToBody(Size(752, h), l);
          previousKeypad = l.keypadHeight;
          previousTop = l.top;
        }
        expect(previousTop, greaterThanOrEqualTo(fullRow));
      },
    );

    test('창 폭을 넓혀도 띠·LCD·키패드가 튀지 않는다 (#141 R2 — 키패드가 폭에 묶이는 높은 창)', () {
      // 폭 약 480~570dp·높이 930~1100dp 본체는 키패드가 폭에 묶인 채 640dp를 넘는다. R1의 첫 식은 이 구간에서
      // 폭 0.5dp 차이에 LCD가 13dp 줄었다(h 950: 480 → 480.5).
      for (final h in const [950.0, 1000.0, 1100.0]) {
        CalcScreenLayout? previous;
        for (var w = 300.0; w <= 1400; w += 0.5) {
          final l = CalcScreenLayout.of(Size(w, h));
          expectSumsToBody(Size(w, h), l);
          if (previous != null) {
            // 폭 0.5dp에 키패드 최대 높이는 0.5 / 0.75, LCD 최대 높이는 0.5 / 1.75만큼 바뀐다 — 띠·LCD는 그 합보다
            // 많이 움직이지 않는다(R1의 첫 식은 13dp가 한 번에 바뀌었다).
            const step = 0.5 / 0.75 + 0.5 / 1.75 + 1e-6;
            expect(
              (l.top - previous.top).abs(),
              lessThanOrEqualTo(step),
              reason: '$w×$h $l',
            );
            expect(
              (l.lcdHeight - previous.lcdHeight).abs(),
              lessThanOrEqualTo(step),
              reason: '$w×$h $l',
            );
            // 키패드는 줄지 않는다. 예외는 띠가 이미 줄 전체 높이이고 키패드가 실물 크기(640) 이상인 구간뿐이다 —
            // 거기서는 LCD가 폭 기준 최대 높이(폭 / 1.75)까지 자라는 몫(폭 0.5dp에 0.29dp)을 키패드가 내준다.
            if (l.keypadHeight < previous.keypadHeight - 1e-6) {
              expect(
                previous.keypadHeight - l.keypadHeight,
                lessThanOrEqualTo(0.5 / 1.75 + 1e-6),
                reason: '$w×$h $l',
              );
              expect(
                l.top,
                moreOrLessEquals(
                  CalcTheme.topStripRowMaxHeight - CalcTheme.screenPadding,
                ),
                reason: '$w×$h $l',
              );
              expect(
                l.keypadHeight,
                greaterThanOrEqualTo(
                  CalcTheme.screenTopStripFullRowKeypadMinHeight,
                ),
                reason: '$w×$h $l',
              );
            }
          }
          previous = l;
        }
      }
    });

    test('좁은 폭에서도 LCD 최대 높이는 최소 높이 아래로 내려가지 않는다', () {
      final l = CalcScreenLayout.of(const Size(100, 900));
      expect(l.lcdHeight, CalcTheme.screenLcdMinHeight);
    });

    test('본체가 아주 낮거나(간격 미만 포함) 좁아도 음수 없이 합계가 본체 높이다', () {
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
      // 띠, 간격 순으로 본체 높이까지만 받는다 (#41).
      final tiny = CalcScreenLayout.of(const Size(360, 4));
      expect(tiny.top, 4);
      expect(tiny.gap, 0);
      final low = CalcScreenLayout.of(const Size(360, 16));
      expect(low.top, strip);
      expect(low.gap, 4);
    });

    test('무한·NaN 크기는 0으로 본다', () {
      for (final body in const [
        Size.infinite,
        Size(double.nan, double.nan),
        Size(-10, -10),
      ]) {
        final l = CalcScreenLayout.of(body);
        for (final v in [l.top, l.lcdHeight, l.gap, l.keypadHeight]) {
          expect(v, 0, reason: '$body $l');
        }
      }
    });
  });

  group('폰 화면비별 LCD 확인', () {
    final input = find.byKey(const ValueKey('lcd-input-line'));
    final result = find.byKey(const ValueKey('lcd-result-line'));
    final keypadFinder = find.byKey(const ValueKey('calc-keypad'));

    // 독립 계산한 기대값 (배율 반영 후 줄 글자 크기). 본체 = 창 − 인셋 − 화면 여백 8×2 (#141 — 맨 아래 광고 슬롯 없음)
    // 390×844 인셋 0: 본체 828·폭 374 → LCD 374/1.75, 키패드 374/0.75, 띠 820 − 둘,
    //   글자 = 폭 기준 (356 − 17·1.2) / 11.28
    // 390×844 iPhone 인셋(47/34): 본체 747 → 키패드가 폭 기준 최대 높이에 닿아 LCD도 최대(374/1.75),
    //   띠 739 − 둘 = 26.6 (#141 전에는 본체 695로 LCD 683 × 0.28·띠 12였다), 글자 = 폭 기준
    // 412×915 Android 인셋(24/24): 본체 851·폭 396 → LCD 396/1.75, 띠 843 − LCD − 528,
    //   글자 = 폭 기준 (378 − 20.4) / 11.28
    for (final (size, padding, lcd, top, font) in [
      (
        const Size(390, 844),
        EdgeInsets.zero,
        374 / 1.75,
        820 - 374 / 1.75 - 374 / 0.75,
        335.6 / 11.28,
      ),
      (
        const Size(390, 844),
        const EdgeInsets.only(top: 47, bottom: 34),
        374 / 1.75,
        739 - 374 / 1.75 - 374 / 0.75,
        335.6 / 11.28,
      ),
      (
        const Size(412, 915),
        const EdgeInsets.only(top: 24, bottom: 24),
        396 / 1.75,
        843 - 396 / 1.75 - 396 / 0.75,
        357.6 / 11.28,
      ),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$size·인셋 ${padding.top}/${padding.bottom}·배율 $scale: '
            'LCD ${lcd.toStringAsFixed(1)}dp, 띠 ${top.toStringAsFixed(1)}dp, '
            '줄 글자 ${font.toStringAsFixed(1)}dp', (tester) async {
          await _pumpScreen(
            tester,
            size: size,
            padding: padding,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          final lcdRect = tester.getRect(find.byType(LcdDisplay));
          expect(lcdRect.height, moreOrLessEquals(lcd, epsilon: 0.01));
          expect(
            lcdRect.top,
            moreOrLessEquals(
              padding.top + CalcTheme.screenPadding + top,
              epsilon: 0.01,
            ),
          );
          final text = tester.element(
            find.byKey(const ValueKey('lcd-input-text')),
          );
          final scaled = MediaQuery.textScalerOf(text)
              .scale(DefaultTextStyle.of(text).style.fontSize!);
          if (scale == 1.0) {
            expect(scaled, moreOrLessEquals(font, epsilon: 0.01));
          } else {
            // 배율을 키우면 상태 표시가 커진 만큼만 줄 글자가 줄어든다.
            expect(scaled, lessThanOrEqualTo(font + 0.01));
            expect(scaled, greaterThan(font * 0.95));
          }
        });
      }
    }

    // 소형(4", 16:9) ~ 대형(6.7", 19.5:9)·초장형(21:9) 세로 폰 — (창, 인셋, 배율 반영 줄 글자 하한)
    // 줄 글자 하한은 18dp다. #141 전에는 본체가 높이 500dp인 두 경우(320×568 인셋 0, 360×640 인셋 24/48)만
    // 17.7dp로 낮췄다(#41 — 상단 띠 최소 높이의 비용). 맨 아래 광고 슬롯이 빠져 본체가 552dp가 된 뒤로는 그 크기도
    // 18dp 이상이다(LCD 136.6 → 151.2dp).
    for (final (size, padding, minLine) in const [
      (Size(320, 568), EdgeInsets.zero, 18.0),
      (Size(320, 568), EdgeInsets.only(top: 20), 18.0),
      (Size(360, 640), EdgeInsets.zero, 18.0),
      (Size(360, 640), EdgeInsets.only(top: 24, bottom: 48), 18.0),
      (Size(360, 800), EdgeInsets.zero, 18.0),
      (Size(390, 844), EdgeInsets.zero, 18.0),
      (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34), 18.0),
      (Size(412, 915), EdgeInsets.zero, 18.0),
      (Size(430, 932), EdgeInsets.zero, 18.0),
      (Size(440, 956), EdgeInsets.zero, 18.0),
      (Size(411, 960), EdgeInsets.zero, 18.0),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${size.width}×${size.height}·인셋 ${padding.top}/'
            '${padding.bottom}, 글자 배율 $scale', (tester) async {
          await _pumpScreen(
            tester,
            size: size,
            padding: padding,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          final lcdRect = tester.getRect(find.byType(LcdDisplay));
          final keypad = tester.getRect(keypadFinder);

          // 본체 = 아래 화면 여백 위 ~ 상단 화면 여백 아래 (#141). LCD 목표 비율은 상단 띠 최소 높이(#41)를 뺀
          // 높이에 대한 것이다.
          final bodyBottom =
              size.height - padding.bottom - CalcTheme.screenPadding;
          final body =
              bodyBottom -
              padding.top -
              CalcTheme.screenPadding -
              CalcTheme.screenTopStripMinHeight;
          // LCD는 본체의 목표 비율 이상(키패드 잉여분을 받으면 그보다 크다)이되 LCD 최대 이하
          final lcdMax = lcdRect.width / CalcTheme.screenLcdMinAspectRatio;
          expect(
            lcdRect.height,
            greaterThanOrEqualTo(
              math.min(
                    lcdMax,
                    math.max(
                      body * CalcTheme.screenLcdHeightRatio,
                      CalcTheme.screenLcdMinHeight,
                    ),
                  ) -
                  0.01,
            ),
          );
          expect(lcdRect.height, lessThanOrEqualTo(lcdMax + 0.01));
          // 키패드는 본체 아래에 붙고, LCD는 키패드 바로 위에 붙는다.
          expect(keypad.bottom, moreOrLessEquals(bodyBottom, epsilon: 0.01));
          expect(
            keypad.top - lcdRect.bottom,
            moreOrLessEquals(CalcTheme.screenLcdKeypadGap, epsilon: 0.01),
          );

          // 배율 반영 줄 글자 하한 (위 표)
          final text = tester.element(
            find.byKey(const ValueKey('lcd-input-text')),
          );
          final line = MediaQuery.textScalerOf(text)
              .scale(DefaultTextStyle.of(text).style.fontSize!);
          expect(line, greaterThanOrEqualTo(minLine));

          // 입력·결과 줄은 각각 분수(2행 + 막대)를 담는다.
          final fractionHeight =
              2 * (line * CalcTheme.lcdInputStyle.height!).ceilToDouble() +
              line * CalcTheme.lcdFractionBarRatio;
          for (final l in [input, result]) {
            expect(
              tester.getSize(l).height,
              greaterThanOrEqualTo(fractionHeight - 0.01),
            );
          }
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

  group('스크린리더 (#20)', () {
    Future<void> press(WidgetTester tester, CalcKeyId id) async {
      await tester.tap(_keycap(id));
      await tester.pump();
    }

    /// 알림 메시지를 꺼낸다. 모든 알림은 왼쪽→오른쪽·정중함(polite) 수준이어야 한다.
    List<String> takeMessages(WidgetTester tester) {
      final announcements = tester.takeAnnouncements();
      for (final a in announcements) {
        expect(a.textDirection, TextDirection.ltr, reason: a.message);
        expect(a.assertiveness, Assertiveness.polite, reason: a.message);
      }
      return [for (final a in announcements) a.message];
    }

    final announcer = find.byKey(const ValueKey('screen-reader-announcer'));

    group('알림을 지원하는 플랫폼(iOS)', () {
      Future<SemanticsHandle> pumpIos(
        WidgetTester tester, {
        bool korean = true,
      }) async {
        final handle = tester.ensureSemantics(); // 스크린리더 켜짐
        if (korean) useKoreanLocale(tester);
        await _pumpScreen(tester, supportsAnnounce: true);
        tester.takeAnnouncements();
        return handle;
      }

      testWidgets('SHIFT/ALPHA가 켜지면 알리고, 같은 키로 끄면 꺼짐을 알린다', (tester) async {
        final handle = await pumpIos(tester);
        await press(tester, CalcKeyId.shift);
        await press(tester, CalcKeyId.shift);
        await press(tester, CalcKeyId.alpha);
        await press(tester, CalcKeyId.alpha);
        expect(takeMessages(tester), ['시프트 켜짐', '시프트 꺼짐', '알파 켜짐', '알파 꺼짐']);
        handle.dispose();
      });

      testWidgets('SHIFT → ALPHA → ALPHA: 알파 켜짐, 알파 꺼짐', (tester) async {
        final handle = await pumpIos(tester);
        await press(tester, CalcKeyId.shift);
        await press(tester, CalcKeyId.alpha);
        await press(tester, CalcKeyId.alpha);
        expect(takeMessages(tester), ['시프트 켜짐', '알파 켜짐', '알파 꺼짐']);
        handle.dispose();
      });

      testWidgets('입력된 기능 이름을 알리고(같은 입력 반복도), 기능 없는 층의 키로 풀리면 꺼짐을 알린다', (
        tester,
      ) async {
        final handle = await pumpIos(tester);
        await press(tester, CalcKeyId.shift);
        await press(tester, CalcKeyId.sin); // SHIFT sin = sin⁻¹
        await press(tester, CalcKeyId.num7);
        await press(tester, CalcKeyId.num7);
        await press(tester, CalcKeyId.alpha);
        await press(tester, CalcKeyId.num4); // ALPHA 4 = 기능 없음 (무시)
        expect(takeMessages(tester), [
          '시프트 켜짐',
          '아크사인',
          '7',
          '7',
          '알파 켜짐',
          '알파 꺼짐',
        ]);
        // 알림을 지원하는 플랫폼에서는 liveRegion 알림 노드를 두지 않는다 (중복 낭독 방지).
        expect(announcer, findsNothing);
        handle.dispose();
      });

      testWidgets('영어 기기에서는 영어로 알린다', (tester) async {
        final handle = await pumpIos(tester, korean: false);
        await press(tester, CalcKeyId.shift);
        await press(tester, CalcKeyId.sin);
        expect(takeMessages(tester), ['Shift on', 'Arcsine']);
        handle.dispose();
      });

      testWidgets('스크린리더가 꺼져 있으면 알리지 않는다', (tester) async {
        useKoreanLocale(tester);
        await _pumpScreen(tester, supportsAnnounce: true);
        tester.takeAnnouncements();
        await press(tester, CalcKeyId.shift);
        await press(tester, CalcKeyId.sin);
        expect(tester.takeAnnouncements(), isEmpty);
      }, semanticsEnabled: false);
    });

    group('알림을 지원하지 않는 플랫폼(Android)', () {
      /// 알림 노드 라벨 (반복 구분 글자 제거 전)
      String rawLabel(WidgetTester tester) =>
          tester.getSemantics(announcer).label;

      testWidgets('알림 노드 하나의 liveRegion 라벨로 알리고, 같은 말이 이어져도 라벨이 매번 바뀐다', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        useKoreanLocale(tester);
        await _pumpScreen(tester);
        expect(
          tester.getSemantics(announcer).flagsCollection.isLiveRegion,
          isTrue,
        );
        final heard = <String>[];
        var previous = rawLabel(tester);
        for (final id in [
          CalcKeyId.num7,
          CalcKeyId.num7, // 같은 입력 반복
          CalcKeyId.shift,
          CalcKeyId.sin,
          CalcKeyId.shift,
          CalcKeyId.sin, // 같은 기능 반복
        ]) {
          await press(tester, id);
          final label = rawLabel(tester);
          expect(label, isNot(previous), reason: '라벨이 같으면 Android가 읽지 않는다');
          previous = label;
          heard.add(label.replaceAll(ScreenReaderAnnouncer.repeatMarker, ''));
        }
        expect(heard, ['7', '7', '시프트 켜짐', '아크사인', '시프트 켜짐', '아크사인']);
        expect(tester.takeAnnouncements(), isEmpty);
        handle.dispose();
      });

      testWidgets('상태 표시줄·입력 줄은 liveRegion이 아니다 (상태 표시줄 전체 반복 낭독 방지)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pumpScreen(tester);
        expect(
          tester
              .getSemantics(find.byType(LcdStatusBar))
              .flagsCollection
              .isLiveRegion,
          isFalse,
        );
        expect(
          tester
              .getSemantics(find.byKey(const ValueKey('lcd-input-line')))
              .flagsCollection
              .isLiveRegion,
          isFalse,
        );
        handle.dispose();
      });
    });

    testWidgets('LCD 입력 줄은 각인 기호가 아니라 기능 이름으로 읽힌다', (tester) async {
      final handle = tester.ensureSemantics();
      useKoreanLocale(tester);
      await _pumpScreen(tester);
      await press(tester, CalcKeyId.shift);
      await press(tester, CalcKeyId.sin); // sin⁻¹
      expect(_lcdInputText(tester), 'sin⁻¹');
      final label = tester
          .getSemantics(find.byKey(const ValueKey('lcd-input-line')))
          .label;
      expect(label, contains('아크사인'));
      expect(label, isNot(contains('sin')));
      handle.dispose();
    });

    testWidgets('영어 기기에서는 키·힌트·상태 표시줄·입력 줄을 영어로 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpScreen(tester);
      expect(
        tester.getSemantics(find.byType(LcdStatusBar)).label,
        'Degrees, Math input output',
      );
      final sin = tester.getSemantics(
        find.byWidgetPredicate(
          (w) => w is CalcKeyButton && w.keyDef.id == CalcKeyId.sin,
        ),
      );
      expect(sin.label, 'Sine');
      expect(sin.hint, 'Shift Arcsine, Alpha Variable D');
      await press(tester, CalcKeyId.shift);
      await press(tester, CalcKeyId.sin);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('lcd-input-line'))).label,
        contains('Arcsine'),
      );
      handle.dispose();
    });

    testWidgets('실행 중 기기 언어를 바꾸면 키 라벨이 새 언어로 바뀐다', (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await tester.pumpWidget(const ProviderScope(child: AltCalcApp()));
      expect(find.semantics.byLabel('Sine'), findsOne);
      tester.platformDispatcher.localeTestValue = const Locale('ko', 'KR');
      await tester.pump();
      expect(find.semantics.byLabel('사인'), findsOne);
      expect(find.semantics.byLabel('Sine'), findsNothing);
      handle.dispose();
    });
  });
}
