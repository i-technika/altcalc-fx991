import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/main.dart' as app show main;
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/banner_ad_slot.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/korean_locale.dart';

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

/// 다각형 [polygon](멤버십 판정 [inside])에 들어가는 가장 큰 원의 지름 (0.5dp 격자 근사, dp).
/// 영역 안 각 표본 점에서 다각형 경계까지의 최소 거리 중 최댓값의 두 배다.
double _inscribedDiameter(List<Offset> polygon, bool Function(Offset) inside) {
  double distanceToEdge(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  final bounds = (Path()..addPolygon(polygon, true)).getBounds();
  var best = 0.0;
  for (var x = bounds.left; x <= bounds.right; x += 0.5) {
    for (var y = bounds.top; y <= bounds.bottom; y += 0.5) {
      final p = Offset(x, y);
      if (!inside(p)) continue;
      var nearest = double.infinity;
      for (var i = 0; i < polygon.length; i++) {
        nearest = math.min(
          nearest,
          distanceToEdge(p, polygon[i], polygon[(i + 1) % polygon.length]),
        );
      }
      best = math.max(best, nearest);
    }
  }
  return best * 2;
}

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

    /// 물리 화면과 창을 [size](dp)로 맞춘다 (화면 배율 2).
    void setDevice(WidgetTester tester, Size size) {
      tester.view.display.devicePixelRatio = 2;
      tester.view.display.size = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = size * 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.view.display.reset);
      addTearDown(DeviceOrientationLock.instance.stop);
      // 힌지 센서 조회 채널: 기본은 "센서 없음". 채널을 흉내 내지 않으면 테스트의 가짜 비동기 안에서
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
      expect(find.byKey(SettingsButton.buttonKey), findsNothing);
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
      expect(find.byKey(SettingsButton.buttonKey), findsOneWidget);
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

    /// 힌지 센서 조회 채널 응답을 [hinge]로 고정한다.
    void mockHingeSensor(WidgetTester tester, {required bool hinge}) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        FormFactor.deviceChannel,
        (call) async => hinge,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          FormFactor.deviceChannel,
          null,
        ),
      );
    }

    testWidgets('폴더블(힌지 센서): 펼친 내부 화면에서도 처음부터 세로만 요청하고 위아래 배치로 띄운다', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      // Fold 내부 화면을 가로로 든 상태, 접힘 정보는 아직 도착 전
      setDevice(tester, const Size(829, 690));
      mockHingeSensor(tester, hinge: true);
      final calls = recordPlatformCalls(tester);
      await app.main();
      await tester.pump();
      expect(orientationRequests(calls), [
        ['DeviceOrientation.portraitUp'],
      ]);
      expect(DeviceOrientationLock.instance.appliedKind, DeviceKind.foldable);
      expect(find.byKey(SettingsButton.buttonKey), findsNothing);

      // 접힘 정보가 나중에 와도 다시 요청하지 않는다.
      tester.view.displayFeatures = const [_verticalFold];
      addTearDown(tester.view.resetDisplayFeatures);
      await tester.pump();
      expect(orientationRequests(calls), hasLength(1));
    });

    testWidgets(
      '힌지 센서를 알리지 않는 폴더블: 접힘 정보가 오면 세로로 다시 요청하고, 같은 종류면 다시 요청하지 않는다',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        setDevice(tester, const Size(841, 701));
        final calls = recordPlatformCalls(tester);
        await app.main();
        await tester.pump();
        // 힌지 센서 정보가 없으면 시작 시점에는 태블릿으로 판정된다(대비책 경로).
        expect(orientationRequests(calls), hasLength(1));
        expect(DeviceOrientationLock.instance.appliedKind, DeviceKind.tablet);

        tester.view.displayFeatures = const [_verticalFold];
        addTearDown(tester.view.resetDisplayFeatures);
        await tester.pump();
        expect(orientationRequests(calls).last, [
          'DeviceOrientation.portraitUp',
        ]);
        expect(DeviceOrientationLock.instance.appliedKind, DeviceKind.foldable);
        // 접힘선이 창을 지나므로 위아래 배치다 (힌지 기준 분할은 #25).
        expect(find.byKey(SettingsButton.buttonKey), findsNothing);

        // 기기 종류가 그대로인 화면 정보 변화(회전 등)에는 다시 요청하지 않는다.
        tester.view.physicalSize = const Size(701, 841) * 2;
        await tester.pump();
        expect(orientationRequests(calls), hasLength(2));
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
      expect(DeviceOrientationLock.instance.appliedKind, isNull);

      fail = false;
      tester.view.physicalSize = const Size(391, 844) * 2;
      await tester.pump();
      expect(attempts, 2);
      expect(DeviceOrientationLock.instance.appliedKind, DeviceKind.phone);
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
              _inscribedDiameter(
                g.hitPolygon(sector, bounds),
                (p) => g.hitSectorAt(p, bounds) == sector,
              ),
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

    test('기본은 본체 높이 비율이고 상단 띠가 없다', () {
      const body = Size(390, 700);
      final l = CalcScreenLayout.of(body);
      expect(l.lcdHeight, moreOrLessEquals(196)); // 700 × 0.28
      expect(l.top, 0);
      expect(l.gap, CalcTheme.screenLcdKeypadGap);
      expectSumsToBody(body, l);
    });

    test('낮은 본체에서도 LCD 최소 높이를 지킨다', () {
      const body = Size(390, 200);
      final l = CalcScreenLayout.of(body);
      expect(l.lcdHeight, CalcTheme.screenLcdMinHeight);
      expect(l.top, 0);
      expectSumsToBody(body, l);
    });

    test('키패드가 비율 하한에 걸려 남는 높이는 LCD 최대 높이까지 LCD가 받는다', () {
      // 키패드 최대 390 / 0.75 = 520, LCD = 737 − 520 = 217
      // (목표 745 × 0.28 = 208.6 초과, 최대 390 / 1.75 ≈ 222.9 미만)
      const body = Size(390, 745);
      final l = CalcScreenLayout.of(body);
      expect(l.keypadHeight, moreOrLessEquals(520));
      expect(l.lcdHeight, moreOrLessEquals(217));
      expect(l.top, moreOrLessEquals(0));
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
      expect(CalcScreenLayout.of(const Size(360, 4)).gap, 4);
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
    final adFinder = find.byKey(const ValueKey('banner-ad-slot'));

    // 독립 계산한 기대값 (배율 반영 후 줄 글자 크기)
    // 390×844 인셋 0: 본체 776·폭 374 → LCD 374/1.75, 키패드 374/0.75, 띠 768 − 둘,
    //   글자 = 폭 기준 (356 − 17·1.2) / 11.28
    // 390×844 iPhone 인셋(47/34): 본체 695 → LCD = 695 × 0.28 (잉여분 188.3보다 큼, 최대 미만), 띠 0,
    //   글자 = 높이 기준 (LCD − 18 − 4) / 6.288
    // 412×915 Android 인셋(24/24): 본체 799·폭 396 → LCD 396/1.75, 띠 791 − LCD − 528,
    //   글자 = 폭 기준 (378 − 20.4) / 11.28
    for (final (size, padding, lcd, top, font) in [
      (
        const Size(390, 844),
        EdgeInsets.zero,
        374 / 1.75,
        768 - 374 / 1.75 - 374 / 0.75,
        335.6 / 11.28,
      ),
      (
        const Size(390, 844),
        const EdgeInsets.only(top: 47, bottom: 34),
        695 * 0.28,
        0.0,
        (695 * 0.28 - 22) / 6.288,
      ),
      (
        const Size(412, 915),
        const EdgeInsets.only(top: 24, bottom: 24),
        396 / 1.75,
        791 - 396 / 1.75 - 396 / 0.75,
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

    // 소형(4", 16:9) ~ 대형(6.7", 19.5:9)·초장형(21:9) 세로 폰
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
      Size(411, 960),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${size.width}×${size.height}, 글자 배율 $scale', (
          tester,
        ) async {
          await _pumpScreen(tester, size: size, textScale: scale);
          expect(tester.takeException(), isNull);
          final lcdRect = tester.getRect(find.byType(LcdDisplay));
          final keypad = tester.getRect(keypadFinder);
          final ad = tester.getRect(adFinder);

          // 본체 = 광고 슬롯 안전 여백 위 ~ 상단 화면 여백 아래
          final body =
              ad.top - CalcTheme.adSlotSafetyMargin - CalcTheme.screenPadding;
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
          // 키패드는 광고 슬롯 바로 위에 붙고, LCD는 키패드 바로 위에 붙는다.
          expect(
            ad.top - keypad.bottom,
            moreOrLessEquals(CalcTheme.adSlotSafetyMargin, epsilon: 0.01),
          );
          expect(
            keypad.top - lcdRect.bottom,
            moreOrLessEquals(CalcTheme.screenLcdKeypadGap, epsilon: 0.01),
          );

          // 배율 반영 줄 글자는 가장 작은 폰(16:9)에서도 18dp 이상이다.
          final text = tester.element(
            find.byKey(const ValueKey('lcd-input-text')),
          );
          final line = MediaQuery.textScalerOf(text)
              .scale(DefaultTextStyle.of(text).style.fontSize!);
          expect(line, greaterThanOrEqualTo(18));

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
