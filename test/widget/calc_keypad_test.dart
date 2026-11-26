import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';
import '../support/cursor_pad_labels.dart';
import '../support/key_legends.dart';
import '../support/korean_locale.dart';
import '../support/touch_metrics.dart';

/// 지정한 크기 영역에 키패드를 배치한다.
Widget _host(
  Widget child, {
  Size size = const Size(360, 420),
  double textScale = 1.0,
  bool highContrast = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        highContrast: highContrast,
      ),
      child: Scaffold(
        backgroundColor: CalcTheme.bodyBackground,
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    ),
  );
}

/// 커서 패드 셀이 #141 전보다 가로로 넓은(가로/세로 비 2.2 초과) 실물 배열 키패드 크기 — 실제 창에서 생기는 크기를 포함한다.
/// 가로형(#142) 뒤 실제 창으로 다시 쟀다(#159). 넓은 배열의 가로형 창(2000×400 등)은 화면 테스트가 본다
/// (`calculator_screen_test.dart` "넓은 키패드 셀의 커서 패드").
const _wideCellAreas = <Size>[
  Size(800, 300), // _areas의 가로 모드 폰 (화면은 가로형으로 그린다 — #142)
  Size(396, 295.84), // 412×450 창의 위아래 배치 (셀 비 2.32)
  Size(584, 411.04), // 600×610 창의 위아래 배치 (2.47)
  Size(752, 524.8), // 768×768 정사각형 창의 위아래 배치 (2.49)
  Size(1600, 300), // 극단 크기 (9.26)
];

/// 커서 패드 방향 키 터치 영역의 내접원 지름 하한 — 함수 키(sin) 터치 높이 대비 (#159).
/// 손가락이 들어가는 크기는 셀 높이가 정한다. 그래서 셀이 넓어져도 이 비는 거의 그대로다.
/// - ▲·▼: 보통 셀의 측정값이 0.947~0.980배이고, 가장 낮은 곳은 393×560·412×640이다. 넓은 셀은 0.970~0.980배다.
///   하한은 보통 셀의 최솟값 아래로 둔다(내접원은 0.5dp 격자 근사다).
/// - ◀·▶: 측정 1.07배 이상이다. 셀이 넓을수록 커진다.
const _upDownInscribedMinRatio = 0.94;
const _leftRightInscribedMinRatio = 1.0;

/// [sector] 방향 키 터치 영역의 내접원 지름이 함수 키(sin) 터치 높이의 하한 비율 이상인지 확인한다 (#159).
void _expectInscribedVersusFunctionKey(WidgetTester tester, String reason) {
  final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
  final cell = tester.getRect(find.byType(CursorPad));
  final sin = tester.widget<CalcKeyButton>(_button(CalcKeyId.sin));
  final sinCell = tester.getSize(_button(CalcKeyId.sin));
  final touch = sin.extendHitAreaToLegend
      ? sinCell.height
      : sinCell.height * (1 - CalcTheme.keyLegendHeightRatio);
  final g = CursorPadGeometry(pad.size);
  final bounds = cell.shift(-pad.topLeft);
  for (final sector in CursorPadSector.values) {
    final vertical =
        sector == CursorPadSector.up || sector == CursorPadSector.down;
    expect(
      hitInscribedDiameter(g, sector, bounds),
      greaterThanOrEqualTo(
        touch *
            (vertical ? _upDownInscribedMinRatio : _leftRightInscribedMinRatio),
      ),
      reason: '${sector.name} $reason (sin 터치 높이 $touch)',
    );
  }
}

/// 테스트 화면(기본 800×600)을 [size]로 넓힌다 — [_host]의 영역이 화면보다 크면 화면 크기로 잘리기 때문이다.
void _setViewSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

List<CalcKeyButton> _buttons(WidgetTester tester) =>
    tester.widgetList<CalcKeyButton>(find.byType(CalcKeyButton)).toList();

Finder _button(CalcKeyId id) =>
    find.byWidgetPredicate((w) => w is CalcKeyButton && w.keyDef.id == id);

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

/// 작은 글자를 더 많이 키우는 비선형 배율 (안드로이드 14 이상 흉내)
class _NonLinearScaler extends TextScaler {
  const _NonLinearScaler();

  @override
  double scale(double fontSize) =>
      fontSize < 12 ? fontSize * 1.8 : fontSize + 9.6;

  @override
  double get textScaleFactor => 1.8;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = 99}) =>
      this;
}

/// 키패드 영역 크기 (가로 × 세로) — 일반 폰부터 극단적인 화면비까지
const _areas = <Size>[
  Size(280, 300), // 아주 작은 폰
  Size(320, 380),
  Size(360, 420),
  Size(393, 560),
  Size(412, 640),
  Size(360, 900), // 세로로 아주 긴 화면
  Size(800, 300), // 가로 모드 폰
  Size(780, 900), // 태블릿 세로
];

void main() {
  _cursorPadR2Tests();
  group('키 구성', () {
    testWidgets('50개 키가 각각 한 번씩 배치된다', (tester) async {
      await tester.pumpWidget(_host(const CalcKeypad()));
      final ids = _buttons(tester).map((b) => b.keyDef.id).toList();
      expect(ids.length, totalKeyCount);
      expect(ids.toSet(), CalcKeyId.values.toSet());
    });

    testWidgets('커서 패드만 각인 띠가 없다', (tester) async {
      await tester.pumpWidget(_host(const CalcKeypad()));
      final cursorIds = cursorPad.all.map((d) => d.id).toSet();
      for (final b in _buttons(tester)) {
        expect(
          b.showLegendBand,
          !cursorIds.contains(b.keyDef.id),
          reason: b.keyDef.id.name,
        );
      }
      expect(find.byKey(const ValueKey('cursor-pad')), findsOneWidget);
    });

    testWidgets('커서 패드 홈·외곽선·허브 둘레는 키 테두리 색이고, 고대비 모드에서 함께 바뀐다 (#54)', (
      tester,
    ) async {
      final decoration = find.descendant(
        of: find.byKey(const ValueKey('cursor-pad')),
        matching: find.byType(CustomPaint),
      );
      for (final palette in [CalcPalette.standard, CalcPalette.highContrast]) {
        await tester.pumpWidget(
          _host(const CalcKeypad(), highContrast: palette.isHighContrast),
        );
        expect(
          decoration,
          paints
            ..line(color: palette.keyBorder)
            ..line(color: palette.keyBorder)
            ..path(color: palette.keyBorder)
            ..circle(color: CalcTheme.cursorPadHub)
            ..circle(color: palette.keyBorder),
          reason: '고대비=${palette.isHighContrast}',
        );
      }
    });

    testWidgets('반복 콜백은 autoRepeatKeys에만 연결된다', (tester) async {
      await tester.pumpWidget(
        _host(CalcKeypad(onKeyPressed: (_) {}, onKeyRepeat: (_) {})),
      );
      for (final b in _buttons(tester)) {
        expect(
          b.onRepeat != null,
          autoRepeatKeys.contains(b.keyDef.id),
          reason: b.keyDef.id.name,
        );
      }
    });

    testWidgets('키는 실물 배열 순서대로 놓인다 (위→아래, 왼→오른)', (tester) async {
      await tester.pumpWidget(_host(const CalcKeypad()));
      Offset at(CalcKeyId id) => tester.getCenter(_keycap(id));

      // 상단 조작부: SHIFT ALPHA | 커서 | MENU ON
      expect(at(CalcKeyId.shift).dx, lessThan(at(CalcKeyId.alpha).dx));
      expect(at(CalcKeyId.alpha).dx, lessThan(at(CalcKeyId.cursorLeft).dx));
      expect(
        at(CalcKeyId.cursorLeft).dx,
        lessThan(at(CalcKeyId.cursorRight).dx),
      );
      expect(at(CalcKeyId.cursorRight).dx, lessThan(at(CalcKeyId.menu).dx));
      expect(at(CalcKeyId.menu).dx, lessThan(at(CalcKeyId.on).dx));
      expect(at(CalcKeyId.shift).dy, lessThan(at(CalcKeyId.optn).dy));
      expect(at(CalcKeyId.cursorUp).dy, lessThan(at(CalcKeyId.cursorLeft).dy));
      expect(
        at(CalcKeyId.cursorLeft).dy,
        lessThan(at(CalcKeyId.cursorDown).dy),
      );
      // 구역 순서: 상단 조작부 → 함수부 → 숫자부
      expect(at(CalcKeyId.optn).dy, lessThan(at(CalcKeyId.fraction).dy));
      expect(at(CalcKeyId.sto).dy, lessThan(at(CalcKeyId.num7).dy));
      expect(at(CalcKeyId.num7).dy, lessThan(at(CalcKeyId.num0).dy));
      expect(at(CalcKeyId.ans).dx, lessThan(at(CalcKeyId.equals).dx));
    });

    testWidgets('숫자부 키가 함수부 키보다 크다', (tester) async {
      await tester.pumpWidget(_host(const CalcKeypad()));
      final fn = tester.getSize(_button(CalcKeyId.sin));
      final num = tester.getSize(_button(CalcKeyId.num5));
      expect(num.height, greaterThan(fn.height));
      expect(num.width, greaterThan(fn.width));
    });
  });

  group('입력 연결', () {
    testWidgets('누르면 onKeyPressed, 반복 키를 길게 누르면 onKeyRepeat', (tester) async {
      final pressed = <CalcKeyId>[];
      final repeated = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeypad(
            onKeyPressed: pressed.add,
            onKeyRepeat: repeated.add,
            enableHaptics: false,
          ),
        ),
      );

      await tester.tap(_keycap(CalcKeyId.sin));
      expect(pressed, [CalcKeyId.sin]);

      final g = await tester.startGesture(
        tester.getCenter(_keycap(CalcKeyId.del)),
      );
      await tester.pump(CalcKeyButton.defaultRepeatDelay);
      await tester.pump(CalcKeyButton.defaultRepeatInterval);
      await g.up();
      expect(pressed, [CalcKeyId.sin, CalcKeyId.del]);
      expect(repeated, [CalcKeyId.del, CalcKeyId.del]);
    });

    testWidgets('onKeyPressed가 null이면 모든 키가 비활성이다', (tester) async {
      await tester.pumpWidget(_host(const CalcKeypad()));
      for (final b in _buttons(tester)) {
        expect(b.onPressed, isNull);
      }
    });

    testWidgets('키패드는 스크롤 영역 안에 있지 않다', (tester) async {
      await tester.pumpWidget(_host(CalcKeypad(onKeyPressed: (_) {})));
      expect(
        find.ancestor(
          of: _keycap(CalcKeyId.num5),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });
  });

  group('반응형 배치', () {
    for (final area in _areas) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          '${area.width}×${area.height}, 글자 배율 $scale: 넘침 없이 영역 안에 들어간다',
          (tester) async {
            await tester.pumpWidget(
              _host(
                CalcKeypad(onKeyPressed: (_) {}),
                size: area,
                textScale: scale,
              ),
            );
            expect(tester.takeException(), isNull);

            final keypad = tester.getRect(
              find.byKey(const ValueKey('calc-keypad')),
            );
            final bounds = Offset.zero & area;
            expect(bounds.inflate(0.01).contains(keypad.topLeft), isTrue);
            expect(bounds.inflate(0.01).contains(keypad.bottomRight), isTrue);

            // 폭은 영역 폭 전체이고(#141 — 가로 상한 없음), 세로로 길어지지 않는다.
            expect(keypad.width, moreOrLessEquals(area.width, epsilon: 0.01));
            expect(
              keypad.width / keypad.height,
              greaterThanOrEqualTo(CalcTheme.keypadMinAspectRatio - 1e-6),
            );

            for (final def in allKeys) {
              final cap = tester.getRect(_keycap(def.id));
              final inside = keypad.inflate(0.01);
              expect(inside.contains(cap.topLeft), isTrue, reason: def.id.name);
              expect(
                inside.contains(cap.bottomRight),
                isTrue,
                reason: def.id.name,
              );
            }
          },
        );
      }
    }

    testWidgets('키패드는 가로 제약 영역 가운데에 놓인다', (tester) async {
      const area = Size(800, 300);
      await tester.pumpWidget(_host(const CalcKeypad(), size: area));
      final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
      expect(keypad.center.dx, moreOrLessEquals(area.width / 2, epsilon: 0.01));
    });
  });

  group('글자 크기 통일', () {
    testWidgets('모든 키에 같은 각인·메인 글자 크기가 주입된다', (tester) async {
      await tester.pumpWidget(_host(const CalcKeypad()));
      final buttons = _buttons(tester);
      expect(buttons.map((b) => b.legendFontSize).toSet(), hasLength(1));
      expect(buttons.map((b) => b.mainLabelFontSize).toSet(), hasLength(1));
      expect(buttons.first.legendFontSize, isNotNull);
      expect(buttons.first.mainLabelFontSize, isNotNull);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      test('글자 배율 $scale: 배율을 반영한 글자가 각인 띠·키캡 높이를 넘지 않는다', () {
        final scaler = TextScaler.linear(scale);
        final m = KeypadMetrics.compute(const Size(360, 420), scaler);
        final effective = scaler.clamp(
          maxScaleFactor: CalcTheme.keyMaxTextScaleFactor,
        );
        final cell = m.functionRowHeight - m.verticalGap;
        final legendHeight = cell * CalcTheme.keyLegendHeightRatio;
        expect(
          effective.scale(m.legendFontSize).ceilToDouble(),
          lessThanOrEqualTo(legendHeight),
        );
        expect(
          effective.scale(m.mainLabelFontSize),
          lessThan(cell - legendHeight),
        );
      });
    }

    for (final scale in [1.0, 1.3]) {
      testWidgets('글자 배율 $scale: 한 글자 메인 라벨은 모두 같은 크기로, 축소 없이 그려진다', (
        tester,
      ) async {
        await tester.pumpWidget(_host(const CalcKeypad(), textScale: scale));
        final cursorIds = cursorPad.all.map((d) => d.id).toSet();
        final heights = <double>{};
        for (final def in allKeys) {
          if (cursorIds.contains(def.id)) continue;
          if (def.mainLabel.runes.length != 1) continue;
          final text = find.descendant(
            of: _keycap(def.id),
            matching: find.byType(Text),
          );
          // FittedBox가 줄이면 화면상 높이(getRect)가 레이아웃 높이(getSize)보다 작아진다.
          final rendered = tester.getRect(text).height;
          expect(
            rendered,
            moreOrLessEquals(tester.getSize(text).height, epsilon: 0.01),
            reason: def.id.name,
          );
          heights.add(rendered.roundToDouble());
        }
        expect(heights, hasLength(1));
      });
    }

    test('폭 기준: 통일 크기는 높이 기준 크기의 하한 비율 이상, 높이 기준 이하다', () {
      for (final scale in [1.0, 1.3]) {
        final scaler = TextScaler.linear(scale);
        final m = KeypadMetrics.compute(const Size(360, 420), scaler);
        final cap = m.functionKeyHeight * (1 - CalcTheme.keyLegendHeightRatio);
        // 이 크기에서는 높이 제한에 걸리지 않으므로 높이 기준 = 비율 크기다.
        final byHeight = cap * CalcTheme.keyMainLabelFontRatio;
        expect(m.mainLabelFontSize, lessThanOrEqualTo(byHeight + 1e-9));
        expect(
          m.mainLabelFontSize,
          greaterThanOrEqualTo(
            byHeight * CalcTheme.keypadUniformFontMinRatio - 1e-9,
          ),
        );
      }
    });

    test('폭 기준: 좁은 키패드일수록 통일 크기가 셀 높이 비율보다 작아진다', () {
      // 같은 높이에서 폭만 줄이면 높이 기준은 같고 폭 제한만 강해진다.
      final wide = KeypadMetrics.compute(
        const Size(400, 400),
        TextScaler.noScaling,
      );
      final narrow = KeypadMetrics.compute(
        const Size(300, 400),
        TextScaler.noScaling,
      );
      expect(narrow.mainLabelFontSize, lessThan(wide.mainLabelFontSize));
    });

    testWidgets('비선형 글자 배율에서도 넘침 없이 배치된다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 420),
              textScaler: _NonLinearScaler(),
            ),
            child: const Scaffold(
              body: SizedBox(width: 360, height: 420, child: CalcKeypad()),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final m = KeypadMetrics.compute(
        const Size(360, 420),
        const _NonLinearScaler(),
      );
      final legendHeight = m.functionKeyHeight * CalcTheme.keyLegendHeightRatio;
      expect(
        const _NonLinearScaler().scale(m.legendFontSize).ceilToDouble(),
        lessThanOrEqualTo(legendHeight),
      );
    });

    test('시스템 글자 배율이 커지면 (상한까지) 메인 글자가 함께 커진다', () {
      const area = Size(360, 420);
      final normal = KeypadMetrics.compute(area, TextScaler.noScaling);
      final large = KeypadMetrics.compute(area, const TextScaler.linear(1.3));
      final scaledNormal = normal.mainLabelFontSize;
      final scaledLarge = const TextScaler.linear(1.3)
          .scale(large.mainLabelFontSize);
      expect(scaledLarge, greaterThan(scaledNormal));
    });

    group('글자 크기 상한 (#141)', () {
      test('태블릿처럼 큰 키패드는 키가 아무리 커져도 상한에서 멈춘다 (가로로 넓어져도 커지지 않는다)', () {
        for (final area in const [
          Size(784, 813.6), // 10인치 800×1280 세로
          Size(1008, 895.68), // 12.9인치 iPad 세로
          Size(2000, 2000),
          Size(3000, 900), // 아주 넓은 키
        ]) {
          final m = KeypadMetrics.compute(area, TextScaler.noScaling);
          expect(
            m.mainLabelFontSize,
            moreOrLessEquals(CalcTheme.keyMainLabelMaxFontSize),
            reason: '$area',
          );
          expect(
            m.legendFontSize,
            moreOrLessEquals(CalcTheme.keyLegendMaxFontSize),
            reason: '$area',
          );
        }
      });

      testWidgets('상한에 걸린 키패드도 시스템 글자 배율은 그대로 반영한다 (상한은 배율 반영 전 크기)', (
        tester,
      ) async {
        // 테스트 글꼴은 글자 폭이 넓어 784dp 폭에서는 배율 1.3의 폭 기준에 걸린다 — 폭 제한이 없는 큰 키패드로 본다.
        const area = Size(2000, 1500);
        _setViewSize(tester, area);
        await tester.pumpWidget(
          _host(const CalcKeypad(), size: area, textScale: 1.3),
        );
        expect(tester.takeException(), isNull);
        final m = KeypadMetrics.compute(area, const TextScaler.linear(1.3));
        expect(
          m.mainLabelFontSize,
          moreOrLessEquals(CalcTheme.keyMainLabelMaxFontSize),
        );
        // 한 글자 라벨(숫자 7)은 상한 × 배율 크기로 그려진다(FittedBox가 줄이지 않는다).
        final seven = find.descendant(
          of: _keycap(CalcKeyId.num7),
          matching: find.byType(Text),
        );
        expect(
          tester.widget<Text>(seven).style?.fontSize,
          CalcTheme.keyMainLabelMaxFontSize,
        );
        expect(
          tester.getRect(seven).height,
          moreOrLessEquals(tester.getSize(seven).height, epsilon: 0.01),
        );
      });

      testWidgets('글자 크기를 주입하지 않은 키 버튼도 상한을 넘지 않는다', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: CalcKeyButton(
                    keyDef: allKeys.firstWhere((d) => d.id == CalcKeyId.num7),
                  ),
                ),
              ),
            ),
          ),
        );
        final text = tester.widget<Text>(
          find.descendant(
            of: _keycap(CalcKeyId.num7),
            matching: find.byType(Text),
          ),
        );
        expect(
          text.style?.fontSize,
          lessThanOrEqualTo(CalcTheme.keyMainLabelMaxFontSize),
        );
      });
    });
  });

  group('터치 영역 확장', () {
    test('키캡 높이가 최소 터치 높이 미만이면 각인 띠까지 넓힌다', () {
      final small = KeypadMetrics.compute(
        const Size(320, 380),
        TextScaler.noScaling,
      );
      expect(small.extendFunctionHitArea, isTrue);

      // 실물 크기 키패드(480×640dp — #141 전의 최대 크기): 숫자부 키캡은 48dp 이상이라 넓히지 않고,
      // 함수부 키캡(약 39dp)은 여전히 각인 띠까지 넓힌다.
      final huge = KeypadMetrics.compute(
        const Size(480, 640),
        TextScaler.noScaling,
      );
      double capHeightOf(double cellHeight) =>
          cellHeight * (1 - CalcTheme.keyLegendHeightRatio);
      expect(huge.size, const Size(480, 640));
      expect(
        capHeightOf(huge.numberKeyHeight),
        greaterThanOrEqualTo(CalcTheme.keyMinTouchTargetHeight),
      );
      expect(huge.extendNumberHitArea, isFalse);
      expect(
        capHeightOf(huge.functionKeyHeight),
        lessThan(CalcTheme.keyMinTouchTargetHeight),
      );
      expect(huge.extendFunctionHitArea, isTrue);

      // 태블릿 세로 키패드(10인치 800×1280의 784×813.6, #141): 함수부 키캡도 48dp 이상이라 어느 쪽도 넓히지 않는다.
      final tablet = KeypadMetrics.compute(
        const Size(784, 813.6),
        TextScaler.noScaling,
      );
      expect(
        capHeightOf(tablet.functionKeyHeight),
        greaterThanOrEqualTo(CalcTheme.keyMinTouchTargetHeight),
      );
      expect(tablet.extendFunctionHitArea, isFalse);
      expect(tablet.extendNumberHitArea, isFalse);
    });

    testWidgets('확장 여부가 각 구역 키에 전달된다 (커서 패드는 제외)', (tester) async {
      await tester.pumpWidget(_host(const CalcKeypad()));
      final m = KeypadMetrics.compute(
        const Size(360, 420),
        TextScaler.noScaling,
      );
      final numberIds = {for (final r in numberRows) ...r.map((d) => d.id)};
      final cursorIds = cursorPad.all.map((d) => d.id).toSet();
      for (final b in _buttons(tester)) {
        final id = b.keyDef.id;
        final expected = cursorIds.contains(id)
            ? false
            : numberIds.contains(id)
            ? m.extendNumberHitArea
            : m.extendFunctionHitArea;
        expect(b.extendHitAreaToLegend, expected, reason: id.name);
      }
    });
  });

  _cursorPadShapeTests();
  _cursorPadHitTests();

  for (final area in _wideCellAreas) {
    testWidgets(
      '${area.width}×${area.height}: 키패드가 가로로 넓어져도 방향 키 터치 영역은 #141 전 폭보다 줄지 않고 '
      '손가락 크기는 보통 셀과 같은 기준이다',
      (tester) async {
        // 같은 높이에서 #141 전 키패드 폭(높이 × 1.25, 480dp 이하)과 견준다. 패드는 비율 상한에서 멈추고 남는 폭은
        // ◀·▶가 받으므로, 어느 방향도 그때보다 좁아지지 않는다.
        Map<CursorPadSector, double> hitAreas() {
          final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
          final cell = tester.getRect(find.byType(CursorPad));
          final g = CursorPadGeometry(pad.size);
          final bounds = cell.shift(-pad.topLeft);
          return {
            for (final sector in CursorPadSector.values)
              sector: g.hitArea(sector, bounds),
          };
        }

        _setViewSize(tester, area);
        final before = Size(
          math.min(area.height * 1.25, math.min(480.0, area.width)),
          area.height,
        );
        await tester.pumpWidget(_host(const CalcKeypad(), size: before));
        final old = hitAreas();
        await tester.pumpWidget(_host(const CalcKeypad(), size: area));
        final now = hitAreas();
        for (final sector in CursorPadSector.values) {
          expect(
            now[sector],
            greaterThanOrEqualTo(old[sector]! - 1e-6),
            reason: '${sector.name} $area (전 $before)',
          );
        }
        // 손가락이 들어가는 크기(내접원)는 보통 셀과 같은 기준을 지킨다(#159).
        _expectInscribedVersusFunctionKey(tester, '$area');
        // 함수 키 셀과 견준 ▲·▼ 넓이 비율은 보통 셀의 하한(0.9배)보다 낮아진다. 함수 키가 옆으로만 넓어지기 때문이다.
        // #159에서 패드 모양을 그대로 두기로 정했다(CalcTheme.cursorPadMaxAspectRatio 문서). 대신 지금 값보다 나빠지지
        // 않게 하한을 둔다. 측정: 412×450 창 0.92, 600×610 창 0.88, 768×768 창 0.87, 800×300 0.66, 1600×300 0.54배.
        final sin = tester.getSize(_button(CalcKeyId.sin));
        for (final sector in [CursorPadSector.up, CursorPadSector.down]) {
          expect(
            now[sector]! / (sin.width * sin.height),
            greaterThanOrEqualTo(0.5),
            reason: '${sector.name} $area',
          );
        }
      },
    );
  }

  group('KeypadMetrics.fitSize', () {
    test('비율 범위 안이면 영역을 그대로 쓴다', () {
      expect(KeypadMetrics.fitSize(const Size(360, 420)), const Size(360, 420));
    });

    test('폭은 언제나 영역 폭 전체이고, 높이만 폭 / 가로세로비 하한을 넘지 않게 줄인다 (#141)', () {
      for (final area in const [
        Size(1200, 1600),
        Size(2000, 700),
        Size(784, 1100),
        Size(784, 842),
        Size(800, 300),
      ]) {
        final s = KeypadMetrics.fitSize(area);
        expect(s.width, area.width, reason: '$area');
        expect(
          s.height,
          math.min(area.height, area.width / CalcTheme.keypadMinAspectRatio),
          reason: '$area',
        );
      }
      // 태블릿 세로: 예전 폭 상한(480dp)·가로세로비 상한(1.25)이 없어 영역을 그대로 쓴다.
      expect(KeypadMetrics.fitSize(const Size(784, 842)), const Size(784, 842));
    });

    test('너무 길면 높이를 줄이고, 넓은 영역은 그대로 쓴다 (가로로 넓어지는 것은 허용 — #141)', () {
      expect(KeypadMetrics.fitSize(const Size(800, 300)), const Size(800, 300));

      final tall = KeypadMetrics.fitSize(const Size(360, 900));
      expect(tall.width, 360);
      expect(tall.height, 360 / CalcTheme.keypadMinAspectRatio);
    });

    test('넓은 배열도 폭은 영역 폭 전체이고, 블록이 세로로 길어지지 않게 높이만 줄인다 (#141)', () {
      for (final area in const [
        Size(825, 300),
        Size(1248, 464),
        Size(2400, 400),
        Size(700, 900),
      ]) {
        final s = KeypadMetrics.fitSize(area, KeypadArrangement.wide);
        expect(s.width, area.width, reason: '$area');
        final block = area.width / (2 + CalcTheme.keypadWideSectionGapRatio);
        expect(
          s.height,
          moreOrLessEquals(
            math.min(
              area.height,
              block /
                  (CalcTheme.keypadMinAspectRatio *
                      KeypadMetrics.wideHeightFactor),
            ),
          ),
          reason: '$area',
        );
      }
    });

    test(
      '비유한 폭은 0으로 본다 (호출 측은 유한한 영역을 넘긴다 — CalcKeypad는 fallbackSize로 바꾼다)',
      () {
        expect(
          KeypadMetrics.fitSize(const Size(double.infinity, double.infinity)),
          Size.zero,
        );
      },
    );

    test('0 이하 영역도 예외 없이 0 크기가 된다', () {
      expect(KeypadMetrics.fitSize(Size.zero), Size.zero);
      final m = KeypadMetrics.compute(Size.zero, TextScaler.noScaling);
      expect(m.legendFontSize, greaterThan(0));
      expect(m.mainLabelFontSize, greaterThan(0));
    });
  });

  // 실제 번들 글꼴로 잰다 (테스트 글꼴은 글자 폭이 넓어 폭 기준에 먼저 걸린다). 글꼴 등록은 이후 테스트에도 남으므로
  // main의 맨 끝 그룹에 둔다.
  group('실제 글꼴 기준 글자 크기 상한 (#141)', () {
    setUpAll(loadBundledFonts);

    test('폰 키패드(가장 넓은 폰 본체 424dp 이하)에는 상한이 걸리지 않는다 (실제 글꼴 — 폭 기준이 덜 줄인다)', () {
      // 세로 폰의 키패드는 폭 기준 최대 높이(폭 / 가로세로비 하한)를 넘지 않는다.
      for (final width in [304.0, 374.0, 424.0]) {
        final area = Size(width, width / CalcTheme.keypadMinAspectRatio);
        for (final scale in [1.0, 1.3]) {
          final m = KeypadMetrics.compute(area, TextScaler.linear(scale));
          expect(
            m.mainLabelFontSize,
            lessThan(CalcTheme.keyMainLabelMaxFontSize),
            reason: '$area ×$scale',
          );
          expect(
            m.legendFontSize,
            lessThan(CalcTheme.keyLegendMaxFontSize),
            reason: '$area ×$scale',
          );
        }
      }
    });

    test('실물 크기 키패드(480×640dp)의 글자는 상한 이하이고, 상한은 그 글자를 크게 넘지 않는다', () {
      // 상한의 근거 (CalcTheme.keyMainLabelMaxFontSize): #141 전 최대 키패드의 글자 크기를 올림한 값이다.
      final m = KeypadMetrics.compute(
        const Size(480, 640),
        TextScaler.noScaling,
      );
      expect(
        m.mainLabelFontSize,
        inInclusiveRange(
          CalcTheme.keyMainLabelMaxFontSize - 0.5,
          CalcTheme.keyMainLabelMaxFontSize,
        ),
      );
      expect(
        m.legendFontSize,
        inInclusiveRange(
          CalcTheme.keyLegendMaxFontSize - 0.5,
          CalcTheme.keyLegendMaxFontSize,
        ),
      );
    });
  });
}

void _cursorPadR2Tests() {
  group('커서 패드 (이동·시맨틱)', () {
    testWidgets('▲를 누른 채 ◄ 터치 영역·허브·셀 밖으로 미끄러지면 ▲ 반복이 멈춘다', (tester) async {
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeypad(
            onKeyPressed: (_) {},
            onKeyRepeat: repeats.add,
            enableHaptics: false,
          ),
        ),
      );
      final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
      final cell = tester.getRect(find.byType(CursorPad));
      Offset at(double u, double v) =>
          pad.center + Offset(u * pad.width / 2, v * pad.height / 2);

      // ◄ 구역, 가운데 허브(데드존), 셀 위쪽 밖(이웃 키와의 간격)
      for (final target in [
        at(-0.6, -0.1),
        at(0, 0),
        Offset(pad.center.dx, cell.top - 1),
      ]) {
        repeats.clear();
        final g = await tester.startGesture(at(0, -0.6));
        await tester.pump(CalcKeyButton.defaultRepeatDelay);
        expect(repeats, [CalcKeyId.cursorUp]);
        await g.moveTo(target);
        await tester.pump(CalcKeyButton.defaultRepeatInterval * 5);
        expect(repeats, [CalcKeyId.cursorUp], reason: '$target');
        await g.up();
        await tester.pump();
      }
    });

    testWidgets('▲를 누른 채 외곽 밖(▲ 터치 영역)으로 미끄러져도 ▲ 반복은 이어진다', (tester) async {
      final repeats = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(
          CalcKeypad(
            onKeyPressed: (_) {},
            onKeyRepeat: repeats.add,
            enableHaptics: false,
          ),
        ),
      );
      final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
      final cell = tester.getRect(find.byType(CursorPad));
      final g = CursorPadGeometry(pad.size);
      Offset at(double u, double v) =>
          pad.center + Offset(u * pad.width / 2, v * pad.height / 2);
      // 외곽 밖이지만 ▲ 터치 영역인 윗변 쪽 점 (전제 확인)
      final corner = at(-0.35, -0.97);
      final local = corner - pad.topLeft;
      expect(g.sectorAt(local), isNull);
      expect(
        g.hitSectorAt(local, cell.shift(-pad.topLeft)),
        CursorPadSector.up,
      );

      final gesture = await tester.startGesture(at(0, -0.6));
      await tester.pump(CalcKeyButton.defaultRepeatDelay);
      expect(repeats, [CalcKeyId.cursorUp]);
      await gesture.moveTo(corner);
      await tester.pump(CalcKeyButton.defaultRepeatInterval * 3);
      expect(repeats.length, greaterThan(1));
      expect(repeats.toSet(), {CalcKeyId.cursorUp});
      await gesture.up();
      await tester.pump();
    });

    test('시맨틱 영역은 서로 겹치지 않고, 자기 구역(허브 고리 포함, 또는 외곽 밖)에만 걸치며 구역을 넉넉히 덮는다', () {
      // 패드 비율 하한·상한 근처와 정사각형(비율 제한 밖 극단)까지
      for (final size in const [
        Size(90, 64),
        Size(116, 78),
        Size(200, 111),
        Size(100, 100),
      ]) {
        final geometry = CursorPadGeometry(size);
        final rects = {
          for (final s in CursorPadSector.values)
            s: CursorPad.semanticRect(s, size),
        };
        for (final a in CursorPadSector.values) {
          final rect = rects[a]!;
          expect(rect.isEmpty, isFalse, reason: '$size ${a.name}');
          expect(
            (Offset.zero & size).intersect(rect),
            rect,
            reason: '$size ${a.name}',
          );
          for (final b in CursorPadSector.values) {
            if (a == b) continue;
            final overlap = rect.intersect(rects[b]!);
            expect(
              overlap.width <= 0 || overlap.height <= 0,
              isTrue,
              reason: '$size ${a.name} × ${b.name}',
            );
          }
          // 영역 안 표본 점은 모두 자기 구역이거나 외곽 밖이다 (다른 구역·데드존 위가 없다).
          // 그려진 허브의 고리는 누르면 그쪽 방향이라 자기 구역에 든다(#166).
          var own = 0;
          final inner = rect.deflate(0.01);
          for (var x = inner.left; x <= inner.right; x += 0.5) {
            for (var y = inner.top; y <= inner.bottom; y += 0.5) {
              final p = Offset(x, y);
              final at = geometry.sectorAt(p);
              if (at == a) {
                own++;
                continue;
              }
              expect(at, isNull, reason: '$size ${a.name} $p → ${at?.name}');
              expect(
                (p - geometry.center).distance,
                greaterThan(geometry.deadZoneRadius),
                reason: '$size ${a.name} $p 데드존 위',
              );
            }
          }
          // 자기 구역 넓이의 40% 이상을 덮는다 (표본 점 하나 = 0.25dp²).
          expect(
            own * 0.25,
            greaterThan(geometry.sectorArea(a) * 0.4),
            reason: '$size ${a.name}',
          );
        }
      }
    });

    test('시맨틱 영역은 허브 고리까지 들어가고, 셀 여백이 없으면 ▲·▼와 ◀·▶ 영역 높이가 같다 (#166)', () {
      for (final size in const [
        Size(90, 64),
        Size(97.7, 67.8), // 320×568·상태바 20dp 화면의 패드
        Size(136.2, 97.3), // 412×915 화면의 패드
        Size(200, 111),
        Size(100, 100),
      ]) {
        final g = CursorPadGeometry(size);
        final c = g.center;
        // 셀 = 패드 상자 (앱에서 셀 여백이 없을 때와 같다)
        final rects = {
          for (final s in CursorPadSector.values)
            s: CursorPad.semanticRect(s, size, Offset.zero & size),
        };
        final up = rects[CursorPadSector.up]!;
        final left = rects[CursorPadSector.left]!;
        // ▲·▼ 영역은 그려진 허브 안(허브 가장자리보다 가운데 쪽)까지 내려오고, 데드존 앞에서 멈춘다.
        expect(up.bottom, greaterThan(c.dy - g.hubRadius), reason: '$size ▲');
        expect(
          up.bottom,
          lessThanOrEqualTo(c.dy - g.deadZoneRadius),
          reason: '$size ▲',
        );
        // ▲·▼ 영역 높이 = ◀·▶ 영역 높이 (짧은 변을 고르게 나눈다)
        expect(
          up.height,
          moreOrLessEquals(left.height, epsilon: 1e-9),
          reason: '$size',
        );
        // 고리의 일부를 덮는다. 사각형 네 개라 가운데 십자 사이(|dx| < X, |dy| < Y)는 비어
        // 약 21~48%다(0.05dp 격자 측정, 200×111이 21.6%로 가장 낮다 — 이 테스트의 0.25dp 격자로는 22.7%).
        // #43 규칙(허브를 덮지 않음)에서는 0%였다.
        var ringPoints = 0;
        var covered = 0;
        for (var x = -g.hubRadius; x <= g.hubRadius; x += 0.25) {
          for (var y = -g.hubRadius; y <= g.hubRadius; y += 0.25) {
            final d = Offset(x, y).distance;
            if (d <= g.deadZoneRadius || d > g.hubRadius) continue;
            ringPoints++;
            if (rects.values.any((r) => r.contains(c + Offset(x, y)))) {
              covered++;
            }
          }
        }
        expect(covered / ringPoints, greaterThan(0.18), reason: '$size');
      }
    });

    for (final area in const [Size(800, 300), Size(393, 560), Size(360, 420)]) {
      testWidgets(
        '${area.width}×${area.height}: 시맨틱 노드는 계산한 영역(바깥 변은 셀 변)에 놓인다',
        (tester) async {
          final handle = tester.ensureSemantics();
          useKoreanLocale(tester);
          await tester.pumpWidget(_host(const CalcKeypad(), size: area));
          final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
          final cell = tester.getRect(find.byType(CursorPad));
          final bounds = cell.shift(-pad.topLeft);
          for (final sector in CursorPadSector.values) {
            final node = find.semantics
                .byLabel(
                  const KoSemanticStrings().keyButton(
                    CursorPad.defOf(sector).id,
                  ),
                )
                .evaluate()
                .single;
            final actual = _semanticsGlobalRect(
              node,
              tester.view.devicePixelRatio,
            );
            final expected = CursorPad.semanticRect(
              sector,
              pad.size,
              bounds,
            ).shift(pad.topLeft);
            final reason = '${sector.name} $area';
            expect(
              (actual.topLeft - expected.topLeft).distance +
                  (actual.bottomRight - expected.bottomRight).distance,
              lessThan(1e-3),
              reason: '$reason: $actual ≠ $expected',
            );
            // 바깥쪽 변은 셀 변이다.
            final (got, want) = switch (sector) {
              CursorPadSector.up => (actual.top, cell.top),
              CursorPadSector.down => (actual.bottom, cell.bottom),
              CursorPadSector.left => (actual.left, cell.left),
              CursorPadSector.right => (actual.right, cell.right),
            };
            expect(got, moreOrLessEquals(want, epsilon: 1e-3), reason: reason);
          }
          handle.dispose();
        },
      );
    }

    testWidgets('방향마다 시맨틱 노드가 하나씩 있고, 시맨틱 탭으로 입력된다', (tester) async {
      final handle = tester.ensureSemantics();
      useKoreanLocale(tester);
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(CalcKeypad(onKeyPressed: pressed.add, enableHaptics: false)),
      );
      for (final sector in CursorPadSector.values) {
        final def = CursorPad.defOf(sector);
        final finder = find.semantics.byLabel(
          const KoSemanticStrings().keyButton(def.id),
        );
        expect(finder, findsOne, reason: sector.name);
        tester.semantics.tap(finder);
        await tester.pump();
        expect(pressed.last, def.id);
      }
      handle.dispose();
    });
  });

  group('폭 제약 라벨의 렌더링', () {
    // 폭 제약을 결정하는 가장 긴 메인 라벨(SHIFT·ALPHA)까지 포함해 모든 메인 라벨이
    // FittedBox 축소 없이 통일 크기로 그려진다 (통일 크기가 하한에 걸리지 않는 크기에서).
    // 테스트 글꼴(글자 폭 1em)은 실제 고정폭 글꼴(약 0.6em)보다 넓어, 배율 1.3에서는 하한에 걸린다.
    for (final scale in [1.0]) {
      testWidgets('360×420, 글자 배율 $scale: 모든 메인 라벨이 축소 없이 그려진다', (
        tester,
      ) async {
        await tester.pumpWidget(_host(const CalcKeypad(), textScale: scale));
        final m = KeypadMetrics.compute(
          const Size(360, 420),
          TextScaler.linear(scale),
        );
        final cap = m.functionKeyHeight * (1 - CalcTheme.keyLegendHeightRatio);
        // 전제: 통일 크기가 폭 제약으로 정해졌다 (하한 미만이 아니고 높이 기준보다 작다).
        final byHeight = cap * CalcTheme.keyMainLabelFontRatio;
        expect(m.mainLabelFontSize, lessThan(byHeight));
        expect(
          m.mainLabelFontSize,
          greaterThan(byHeight * CalcTheme.keypadUniformFontMinRatio),
        );
        for (final def in allKeys) {
          if (def.category == KeyCategory.cursor) continue;
          // 2차원 각인(#155)은 Text가 아니라 KeyLegendView로 그려진다.
          final text = find.descendant(
            of: _keycap(def.id),
            matching: findLegend(def.mainLegend),
          );
          expect(
            tester.getRect(text).height,
            moreOrLessEquals(tester.getSize(text).height, epsilon: 0.01),
            reason: def.mainLabel,
          );
        }
      });
    }
  });
}

/// 시맨틱 노드의 논리 좌표(dp) 전역 사각형 — 부모 노드 변환을 루트까지 거슬러 쌓은 물리 픽셀 좌표를
/// 기기 배율([devicePixelRatio])로 나눈다.
Rect _semanticsGlobalRect(SemanticsNode node, double devicePixelRatio) {
  var rect = node.rect;
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    final transform = n.transform;
    if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
  }
  return Rect.fromLTRB(
    rect.left / devicePixelRatio,
    rect.top / devicePixelRatio,
    rect.right / devicePixelRatio,
    rect.bottom / devicePixelRatio,
  );
}

/// [p] 주변 [eps] 이내에서 터치 방향 판정([CursorPadGeometry.hitSectorAt])이 바뀌지 않는지
bool _stableHitAt(CursorPadGeometry g, Rect bounds, Offset p, double eps) {
  final s = g.hitSectorAt(p, bounds);
  for (final d in [
    Offset(eps, 0),
    Offset(-eps, 0),
    Offset(0, eps),
    Offset(0, -eps),
  ]) {
    if (g.hitSectorAt(p + d, bounds) != s) return false;
  }
  return true;
}

/// 커서 패드 터치 영역 (#64): 외곽 안은 X자 홈, 외곽 밖·셀 여백은 홈 끝 → 셀 모서리 선으로 나눠 준다
void _cursorPadHitTests() {
  group('커서 패드 터치 영역 (CursorPadGeometry.hit*)', () {
    // 셀(패드 로컬 좌표): 셀 = 패드, 가로 여백, 세로 여백
    const padSize = Size(114, 66);
    final cases = <String, Rect>{
      '셀 = 패드': Offset.zero & padSize,
      '가로 여백': const Rect.fromLTRB(-20, 0, 134, 66),
      '세로 여백': const Rect.fromLTRB(0, -9, 114, 75),
      // 셀이 패드보다 위아래로 크게 높은 경우 (#166 R1 — 시맨틱 영역이 셀 높이에 묶이지 않는지)
      '세로 여백 큼(셀 = 패드 높이 × 2)': const Rect.fromLTRB(0, -33, 114, 99),
      '세로 여백 매우 큼(× 3)': const Rect.fromLTRB(0, -66, 114, 132),
    };
    final g = CursorPadGeometry(padSize);

    test('외곽 안에서는 그림 판정(sectorAt)과 같다', () {
      for (final bounds in cases.values) {
        for (var x = 0.5; x < padSize.width; x += 2) {
          for (var y = 0.5; y < padSize.height; y += 2) {
            final p = Offset(x, y);
            final drawn = g.sectorAt(p);
            if (drawn == null) continue;
            expect(g.hitSectorAt(p, bounds), drawn, reason: '$p');
          }
        }
      }
    });

    test('셀 안은 데드존만 빼고 모두 어느 한 방향이며, 셀 밖·유한하지 않은 좌표는 아니다', () {
      for (final MapEntry(key: name, value: bounds) in cases.entries) {
        for (var x = bounds.left; x <= bounds.right; x += 1.5) {
          for (var y = bounds.top; y <= bounds.bottom; y += 1.5) {
            final p = Offset(x, y);
            final inDeadZone = (p - g.center).distance <= g.deadZoneRadius;
            expect(
              g.hitSectorAt(p, bounds) == null,
              inDeadZone,
              reason: '$name $p',
            );
          }
        }
        for (final p in [
          bounds.topLeft - const Offset(0.5, 0),
          bounds.bottomRight + const Offset(0, 0.5),
          const Offset(double.nan, 0),
          const Offset(double.infinity, 10),
        ]) {
          expect(g.hitSectorAt(p, bounds), isNull, reason: '$name $p');
        }
      }
    });

    test('셀 여백은 가까운 쪽 방향이다 (좌우 여백 ◀·▶, 위아래 여백 ▲·▼)', () {
      final wide = cases['가로 여백']!;
      expect(
        g.hitSectorAt(Offset(wide.left + 1, g.center.dy), wide),
        CursorPadSector.left,
      );
      expect(
        g.hitSectorAt(Offset(wide.right - 1, g.center.dy), wide),
        CursorPadSector.right,
      );
      final tall = cases['세로 여백']!;
      expect(
        g.hitSectorAt(Offset(g.center.dx, tall.top + 1), tall),
        CursorPadSector.up,
      );
      expect(
        g.hitSectorAt(Offset(g.center.dx, tall.bottom - 1), tall),
        CursorPadSector.down,
      );
    });

    test('터치 다각형은 셀 안에 있고, 경로 판정이 명세 판정과 일치하며, 넓이 합이 셀 − 데드존이다', () {
      for (final MapEntry(key: name, value: bounds) in cases.entries) {
        var total = 0.0;
        for (final sector in CursorPadSector.values) {
          final polygon = g.hitPolygon(sector, bounds);
          expect(polygon, isNotEmpty, reason: '$name ${sector.name}');
          for (final p in polygon) {
            expect(
              bounds.inflate(1e-9).contains(p),
              isTrue,
              reason: '$name ${sector.name} $p',
            );
          }
          final path = g.hitPath(sector, bounds);
          for (var x = bounds.left + 0.25; x < bounds.right; x += 2) {
            for (var y = bounds.top + 0.25; y < bounds.bottom; y += 2) {
              final p = Offset(x, y);
              if (!_stableHitAt(g, bounds, p, 0.3)) continue;
              expect(
                path.contains(p),
                g.hitSectorAt(p, bounds) == sector,
                reason: '$name ${sector.name} $p',
              );
            }
          }
          // 외곽 안 구역보다 넓다.
          expect(
            g.hitArea(sector, bounds),
            greaterThan(g.sectorArea(sector)),
            reason: '$name ${sector.name}',
          );
          total += g.hitArea(sector, bounds);
        }
        final deadZone = math.pi * g.deadZoneRadius * g.deadZoneRadius;
        expect(
          total,
          moreOrLessEquals(
            bounds.width * bounds.height - deadZone,
            epsilon: deadZone * 0.02,
          ),
          reason: name,
        );
      }
    });

    test('버튼 상자(셀 반쪽) 로컬 경로·여백은 셀 크기만으로 패드 경로를 옮긴 것이다', () {
      for (final cell in const [
        Size(160, 100),
        Size(240, 110),
        Size(130, 100),
      ]) {
        final padRect = CursorPad.padRectIn(cell);
        final g = CursorPadGeometry(padRect.size);
        final bounds = (Offset.zero & cell).shift(-padRect.topLeft);
        for (final sector in CursorPadSector.values) {
          final box = CursorPad.sectorBox(sector, cell);
          final outset = CursorPad.hitOutsetOf(sector, cell);
          // 여백을 뺀 안쪽이 그림 상자(패드 반쪽)다.
          expect(outset.isNonNegative, isTrue, reason: '$cell ${sector.name}');
          final inner = outset.deflateRect(box);
          final drawn = CursorPad.sectorBox(
            sector,
            padRect.size,
          ).shift(padRect.topLeft);
          for (final (a, b) in [
            (inner.left, drawn.left),
            (inner.top, drawn.top),
            (inner.right, drawn.right),
            (inner.bottom, drawn.bottom),
          ]) {
            expect(a, moreOrLessEquals(b, epsilon: 1e-9));
          }
          final local = CursorPad.hitPath(sector, box.size);
          for (var x = 0.5; x < box.width; x += 3) {
            for (var y = 0.5; y < box.height; y += 3) {
              final p = box.topLeft + Offset(x, y) - padRect.topLeft;
              if (!_stableHitAt(g, bounds, p, 0.3)) continue;
              expect(
                local.contains(Offset(x, y)),
                g.hitSectorAt(p, bounds) == sector,
                reason: '$cell ${sector.name} $p',
              );
            }
          }
        }
      }
    });

    test('셀의 네 변은 각각 한 방향이다 (옆 변 ◀·▶, 위·아래 변 ▲·▼)', () {
      for (final MapEntry(key: name, value: bounds) in cases.entries) {
        for (var i = 1; i < 40; i++) {
          final t = i / 40;
          final y = bounds.top + bounds.height * t;
          final x = bounds.left + bounds.width * t;
          expect(
            g.hitSectorAt(Offset(bounds.left, y), bounds),
            CursorPadSector.left,
            reason: '$name 왼쪽 변 $y',
          );
          expect(
            g.hitSectorAt(Offset(bounds.right, y), bounds),
            CursorPadSector.right,
            reason: '$name 오른쪽 변 $y',
          );
          expect(
            g.hitSectorAt(Offset(x, bounds.top), bounds),
            CursorPadSector.up,
            reason: '$name 윗변 $x',
          );
          expect(
            g.hitSectorAt(Offset(x, bounds.bottom), bounds),
            CursorPadSector.down,
            reason: '$name 아랫변 $x',
          );
        }
      }
    });

    test('아주 작은 패드·높은 셀에서도 시맨틱 영역은 뒤집히지 않고 자기 방향의 터치 영역 안이다 (#166 R2)', () {
      for (final size in const [
        Size(4, 3),
        Size(3, 2.5),
        Size(2.5, 2.2),
        Size(60, 40),
      ]) {
        final small = CursorPadGeometry(size);
        for (final tall in [1.0, 2.0, 6.0]) {
          final extra = size.height * (tall - 1) / 2;
          final cell = Rect.fromLTRB(
            0,
            -extra,
            size.width,
            size.height + extra,
          );
          for (final s in CursorPadSector.values) {
            for (final r in [
              small.semanticRect(s),
              small.semanticRect(s, cell),
            ]) {
              final name = '$size ×$tall ${s.name} $r';
              expect(r.left, lessThanOrEqualTo(r.right), reason: name);
              expect(r.top, lessThanOrEqualTo(r.bottom), reason: name);
            }
            final r = small.semanticRect(s, cell);
            if (r.isEmpty) continue;
            final inner = r.deflate(math.min(r.shortestSide / 4, 0.05));
            for (var i = 0; i <= 6; i++) {
              for (var j = 0; j <= 6; j++) {
                final p = Offset(
                  inner.left + inner.width * i / 6,
                  inner.top + inner.height * j / 6,
                );
                expect(
                  small.hitSectorAt(p, cell),
                  s,
                  reason: '$size ×$tall ${s.name} $p',
                );
              }
            }
          }
        }
      }
    });

    test('셀까지 넓힌 시맨틱 영역은 서로 겹치지 않고 자기 방향의 터치 영역 안이다', () {
      for (final MapEntry(key: name, value: bounds) in cases.entries) {
        final rects = {
          for (final s in CursorPadSector.values)
            s: CursorPad.semanticRect(s, padSize, bounds),
        };
        for (final MapEntry(key: s, value: r) in rects.entries) {
          // 바깥쪽 변은 셀 변이다.
          final edge = switch (s) {
            CursorPadSector.up => (r.top, bounds.top),
            CursorPadSector.down => (r.bottom, bounds.bottom),
            CursorPadSector.left => (r.left, bounds.left),
            CursorPadSector.right => (r.right, bounds.right),
          };
          expect(edge.$1, edge.$2, reason: '$name ${s.name}');
          for (final o in CursorPadSector.values) {
            if (o == s) continue;
            expect(
              r.intersect(rects[o]!).isEmpty,
              isTrue,
              reason: '$name ${s.name}/${o.name}',
            );
          }
          final inner = r.deflate(0.5);
          for (var i = 0; i <= 8; i++) {
            for (var j = 0; j <= 8; j++) {
              final p = Offset(
                inner.left + inner.width * i / 8,
                inner.top + inner.height * j / 8,
              );
              expect(g.hitSectorAt(p, bounds), s, reason: '$name ${s.name} $p');
            }
          }
        }
      }
    });

    test('0 크기 패드·빈 셀은 예외 없이 빈 터치 영역이다', () {
      final empty = CursorPadGeometry(Size.zero);
      for (final s in CursorPadSector.values) {
        expect(empty.hitPolygon(s, const Rect.fromLTWH(0, 0, 10, 10)), isEmpty);
        expect(g.hitPolygon(s, Rect.zero), isEmpty);
        expect(empty.hitArea(s, const Rect.fromLTWH(0, 0, 10, 10)), 0);
      }
      expect(empty.hitSectorAt(Offset.zero, Rect.largest), isNull);
      // 빈 셀은 hitPolygon과 같이 어느 방향도 아니다 (셀 모서리 위 점도)
      expect(g.hitSectorAt(Offset.zero, Rect.zero), isNull);
    });
  });
}

/// [p] 주변 [eps] 이내에서 방향 판정이 바뀌지 않는지 — 경계 근처는 다각형 근사 오차로 판정이 갈릴 수 있다.
bool _stableAt(CursorPadGeometry g, Offset p, double eps) {
  final s = g.sectorAt(p);
  for (final d in [
    Offset(eps, 0),
    Offset(-eps, 0),
    Offset(0, eps),
    Offset(0, -eps),
  ]) {
    if (g.sectorAt(p + d) != s) return false;
  }
  return true;
}

/// 커서 패드 모양 (#43): 둥근 마름모 외곽 + X자 홈 + 가운데 허브(데드존)
void _cursorPadShapeTests() {
  group('커서 패드 모양 (CursorPadGeometry)', () {
    // 실제 키패드에서 나오는 패드 크기들(작은 폰·일반 폰·태블릿)과 정사각형
    const padSizes = [
      Size(90, 47),
      Size(114, 66),
      Size(255, 147),
      Size(100, 100),
    ];
    const k = CalcTheme.cursorPadGrooveSlope;

    /// 외곽 반지름 단위 정규화 좌표 (u, v)를 패드 로컬 좌표로 바꾼다.
    Offset at(CursorPadGeometry g, double u, double v) =>
        g.center + Offset(u * g.radiusX, v * g.radiusY);

    test('네 방향 대표 점, 허브, 외곽 밖', () {
      final g = CursorPadGeometry(const Size(114, 66));
      expect(g.sectorAt(at(g, 0, -0.8)), CursorPadSector.up);
      expect(g.sectorAt(at(g, 0, 0.8)), CursorPadSector.down);
      expect(g.sectorAt(at(g, -0.85, 0)), CursorPadSector.left);
      expect(g.sectorAt(at(g, 0.85, 0)), CursorPadSector.right);
      // 가운데 허브는 어느 방향도 아니다.
      expect(g.sectorAt(g.center), isNull);
      // 패드 상자 네 모서리는 외곽 밖이다.
      for (final corner in [
        Offset.zero,
        Offset(g.size.width, 0),
        Offset(0, g.size.height),
        Offset(g.size.width, g.size.height),
      ]) {
        expect(g.sectorAt(corner), isNull, reason: '$corner');
      }
    });

    test('외곽은 타원도 뾰족한 마름모도 아닌 둥근 마름모다', () {
      final g = CursorPadGeometry(const Size(114, 66));
      // 축 위: 외곽 바로 안은 방향, 바로 밖은 없음
      expect(g.sectorAt(at(g, 0.99, 0)), CursorPadSector.right);
      expect(g.sectorAt(at(g, 1.02, 0)), isNull);
      expect(g.sectorAt(at(g, 0, -0.99)), CursorPadSector.up);
      expect(g.sectorAt(at(g, 0, -1.02)), isNull);
      // 대각선 (0.68, 0.68): 타원이면 안(0.92 < 1)이지만 둥근 마름모는 밖이다.
      expect(g.sectorAt(at(g, 0.68, 0.68)), isNull);
      // 대각선 (0.55, 0.55): 뾰족한 마름모면 밖(|u|+|v| = 1.1)이지만 변이 부풀어 안이다.
      // (k < 1이라 이 점은 ◀·▶ 쪽이다 — |u| = 0.55 > k·|v|)
      expect(g.sectorAt(at(g, 0.55, 0.55)), CursorPadSector.right);
    });

    test('외곽 꼭짓점은 뾰족하지 않고 둥글다 (꼭짓점에서 2차로 물러난다)', () {
      final g = CursorPadGeometry(const Size(114, 66));

      /// 정규화 높이 [v]에서 ▶ 꼭짓점 쪽 외곽까지의 u (이분법, 판정 기준 [CursorPadGeometry.sectorAt])
      double edgeU(double v) {
        var lo = 0.5;
        var hi = 1.5;
        for (var i = 0; i < 60; i++) {
          final mid = (lo + hi) / 2;
          if (g.sectorAt(at(g, mid, v)) == null) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        return lo;
      }

      // 둥근 꼭짓점은 후퇴량 1 − u가 v²에 비례(비 4)하고, 뾰족한 꼭짓점은 |v|에 비례(비 2)한다.
      // (|u|ⁿ+|v|ⁿ 초타원 n=1.5는 |v|^1.5에 비례해 비가 약 2.8이다.)
      final ratio = (1 - edgeU(0.1)) / (1 - edgeU(0.05));
      expect(ratio, inInclusiveRange(3.6, 4.4));
      expect(1 - edgeU(0.1), greaterThan(0));
    });

    test('X자 홈은 |u| = k·|v| 이고, k < 1이라 ▲·▼ 쪽으로 좁아진다 (실측, #65)', () {
      final g = CursorPadGeometry(const Size(114, 66));
      const v = 0.4;
      expect(g.sectorAt(at(g, k * v * 0.95, -v)), CursorPadSector.up);
      expect(g.sectorAt(at(g, k * v * 1.05, -v)), CursorPadSector.right);
      expect(g.sectorAt(at(g, -k * v * 0.95, v)), CursorPadSector.down);
      expect(g.sectorAt(at(g, -k * v * 1.05, v)), CursorPadSector.left);
      // 상자 대각선 위 점은 ◀·▶ 쪽이다 (홈이 대각선보다 가파르다).
      expect(g.sectorAt(at(g, 0.4, -0.4)), CursorPadSector.right);
    });

    test('데드존 안쪽만 무시하고, 그려진 허브의 바깥 고리는 방향 키다', () {
      for (final size in padSizes) {
        final g = CursorPadGeometry(size);
        expect(g.deadZoneRadius, greaterThan(0), reason: '$size');
        expect(g.deadZoneRadius, lessThan(g.hubRadius), reason: '$size');
        for (final sector in CursorPadSector.values) {
          final dir = switch (sector) {
            CursorPadSector.up => const Offset(0, -1),
            CursorPadSector.down => const Offset(0, 1),
            CursorPadSector.left => const Offset(-1, 0),
            CursorPadSector.right => const Offset(1, 0),
          };
          expect(g.sectorAt(g.center + dir * (g.deadZoneRadius * 0.9)), isNull);
          expect(
            g.sectorAt(g.center + dir * (g.deadZoneRadius * 1.1)),
            sector,
            reason: '$size ${sector.name}',
          );
          // 허브 고리 (데드존과 허브 가장자리 사이)
          final ring = (g.deadZoneRadius + g.hubRadius) / 2;
          expect(
            g.sectorAt(g.center + dir * ring),
            sector,
            reason: '$size ${sector.name} 허브 고리',
          );
        }
      }
    });

    test('◀·▶는 ▲·▼보다 넓고(실측, #65), 좌우·상하 대칭이며, 가장 좁은 구역도 충분히 넓다', () {
      for (final size in padSizes) {
        final g = CursorPadGeometry(size);
        double area(CursorPadSector s) => g.sectorArea(s);
        expect(
          area(CursorPadSector.up),
          moreOrLessEquals(area(CursorPadSector.down), epsilon: 0.01),
        );
        expect(
          area(CursorPadSector.left),
          moreOrLessEquals(area(CursorPadSector.right), epsilon: 0.01),
        );
        // 실물은 ◀·▶ 키가 ▲·▼ 키보다 넓다(▲·▼는 위·아래 호를 따라 휜 띠). 90×47 패드에서 약 1.13배.
        expect(
          area(CursorPadSector.left),
          greaterThan(area(CursorPadSector.up) * 1.05),
          reason: '$size',
        );
        // 가장 좁은 ▲·▼도 패드 상자의 10% 이상이다.
        expect(
          area(CursorPadSector.up),
          greaterThan(size.width * size.height * 0.1),
          reason: '$size',
        );
      }
    });

    test('구역 경로는 방향 판정과 일치한다 (경계 0.3dp 이내 제외)', () {
      for (final size in padSizes) {
        final g = CursorPadGeometry(size);
        final paths = {
          for (final s in CursorPadSector.values) s: g.sectorPath(s),
        };
        var checked = 0;
        var total = 0;
        for (var x = 0.5; x < size.width; x += 1.5) {
          for (var y = 0.5; y < size.height; y += 1.5) {
            total++;
            final p = Offset(x, y);
            if (!_stableAt(g, p, 0.3)) continue;
            final expected = g.sectorAt(p);
            for (final s in CursorPadSector.values) {
              expect(
                paths[s]!.contains(p),
                s == expected,
                reason: '$size $p ${s.name} (판정: ${expected?.name})',
              );
            }
            checked++;
          }
        }
        // 경계 근처로 빠지는 점은 일부뿐이다.
        expect(checked, greaterThan(total * 0.95), reason: '$size');
      }
    });

    test('구역 넓이 합 + 데드존 넓이는 외곽 넓이와 같다', () {
      final g = CursorPadGeometry(const Size(114, 66));
      const p = CalcTheme.cursorPadOutlineExponent;
      var inside = 0;
      const step = 0.25;
      for (var x = step / 2; x < g.size.width; x += step) {
        for (var y = step / 2; y < g.size.height; y += step) {
          final d = Offset(x, y) - g.center;
          final u = d.dx / g.radiusX;
          final v = d.dy / g.radiusY;
          if (math.pow((u + v).abs(), p) + math.pow((u - v).abs(), p) <= 2) {
            inside++;
          }
        }
      }
      final outline = inside * step * step;
      final sum =
          CursorPadSector.values.map(g.sectorArea).reduce((a, b) => a + b) +
          math.pi * g.deadZoneRadius * g.deadZoneRadius;
      expect(sum, moreOrLessEquals(outline, epsilon: outline * 0.01));
    });

    test('외곽·홈·허브는 패드 상자 안에 있다 (선 두께 포함)', () {
      for (final size in padSizes) {
        final g = CursorPadGeometry(size);
        const half = CalcTheme.cursorPadDividerWidth / 2;
        final box = (Offset.zero & size).inflate(0.01);
        final outline = g.outlinePath().getBounds().inflate(half);
        expect(box.intersect(outline), outline, reason: '$size');
        final grooves = g.grooves();
        expect(grooves.length, 4);
        for (final (hub, end) in grooves) {
          expect(
            (hub - g.center).distance,
            moreOrLessEquals(g.hubRadius, epsilon: 1e-6),
          );
          expect(box.contains(end), isTrue);
          // 홈은 두 구역의 경계다: 홈 양옆이 서로 다른 방향이다.
          final mid = Offset.lerp(hub, end, 0.5)!;
          final along = end - hub;
          final normal = Offset(-along.dy, along.dx) / along.distance;
          final a = g.sectorAt(mid + normal * 1.5);
          final b = g.sectorAt(mid - normal * 1.5);
          expect(a, isNotNull, reason: '$size');
          expect(b, isNotNull, reason: '$size');
          expect(a, isNot(b), reason: '$size');
        }
      }
    });

    test('키캡 상자 로컬 경로는 패드 경로를 상자 원점만큼 옮긴 것이다', () {
      const size = Size(114, 66);
      final g = CursorPadGeometry(size);
      for (final sector in CursorPadSector.values) {
        final box = CursorPad.sectorBox(sector, size);
        expect((Offset.zero & size).intersect(box), box);
        expect(box.width * box.height, size.width * size.height / 2);
        expect(CursorPad.padSizeOf(sector, box.size), size);
        // 구역 전체가 자기 상자 안에 있다.
        final bounds = g.sectorPath(sector).getBounds();
        expect(
          box.inflate(0.01).intersect(bounds),
          bounds,
          reason: sector.name,
        );
        final local = CursorPad.sectorPath(sector, box.size);
        for (var x = 0.5; x < box.width; x += 3) {
          for (var y = 0.5; y < box.height; y += 3) {
            final p = box.topLeft + Offset(x, y);
            if (!_stableAt(g, p, 0.3)) continue;
            expect(
              local.contains(Offset(x, y)),
              g.sectorAt(p) == sector,
              reason: '${sector.name} $p',
            );
          }
        }
      }
    });

    test('fitSize: 비율 범위 안이면 셀 그대로, 벗어나면 한 변을 줄인다', () {
      const min = CalcTheme.cursorPadMinAspectRatio;
      const max = CalcTheme.cursorPadMaxAspectRatio;
      expect(CursorPad.fitSize(const Size(160, 100)), const Size(160, 100));
      // 세로로 긴 셀(일반 폰): 높이를 줄인다
      final tall = CursorPad.fitSize(const Size(130, 100));
      expect(tall.width, 130);
      expect(tall.height, moreOrLessEquals(130 / min));
      // 가로로 긴 셀(태블릿): 폭을 줄인다
      final wide = CursorPad.fitSize(const Size(240, 110));
      expect(wide.height, 110);
      expect(wide.width, moreOrLessEquals(110 * max));
      expect(CursorPad.fitSize(Size.zero), Size.zero);
      expect(CursorPad.fitSize(const Size(-5, 10)), Size.zero);
    });

    test('유한하지 않은 좌표는 어느 방향도 아니다', () {
      final g = CursorPadGeometry(const Size(116, 78));
      for (final p in const [
        Offset(double.nan, double.nan),
        Offset(double.infinity, 0),
        Offset(0, double.negativeInfinity),
      ]) {
        expect(g.sectorAt(p), isNull, reason: '$p');
      }
    });

    test('0 크기 패드는 예외 없이 빈 모양이다', () {
      final g = CursorPadGeometry(Size.zero);
      expect(g.sectorAt(Offset.zero), isNull);
      for (final s in CursorPadSector.values) {
        expect(g.sectorPath(s).getBounds().isEmpty, isTrue);
        expect(g.sectorArea(s), 0);
        expect(g.semanticRect(s), Rect.zero);
      }
      expect(g.outlinePath().getBounds().isEmpty, isTrue);
      expect(g.grooves(), isEmpty);
    });
  });

  group('커서 패드 (누름·라벨)', () {
    for (final area in _areas) {
      testWidgets(
        '${area.width}×${area.height}: 셀 안 어디를 눌러도 홈·(홈 끝 → 셀 모서리) 선으로 나눈 방향이 입력되고 한가운데만 무시된다',
        (tester) async {
          final pressed = <CalcKeyId>[];
          await tester.pumpWidget(
            _host(
              CalcKeypad(onKeyPressed: pressed.add, enableHaptics: false),
              size: area,
            ),
          );
          final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
          final cell = tester.getRect(find.byType(CursorPad));
          final g = CursorPadGeometry(pad.size);
          final bounds = cell.shift(-pad.topLeft); // 패드 로컬 좌표의 셀
          final hit = <CursorPadSector?>{};
          var outsideOutline = 0;
          // 셀 테두리 바로 위는 빼고(버튼 상자 오른쪽·아래 변은 히트 테스트에서 빠진다) 한가운데를 지나는 격자
          for (var i = 1; i < 12; i++) {
            for (var j = 1; j < 8; j++) {
              final local =
                  bounds.topLeft +
                  Offset(bounds.width * i / 12, bounds.height * j / 8);
              if (!_stableHitAt(g, bounds, local, 0.5)) continue;
              final expected = g.hitSectorAt(local, bounds);
              hit.add(expected);
              if (expected != null && g.sectorAt(local) == null) {
                outsideOutline++;
              }
              pressed.clear();
              await tester.tapAt(pad.topLeft + local);
              await tester.pump();
              expect(
                pressed,
                expected == null ? isEmpty : [CursorPad.defOf(expected).id],
                reason: '$local (판정: ${expected?.name})',
              );
            }
          }
          // 격자가 네 방향과 데드존(한가운데)을 모두 지나갔고, 외곽 밖 점도 방향을 입력했다.
          expect(hit, {...CursorPadSector.values, null});
          expect(outsideOutline, greaterThan(0));
        },
      );
    }

    testWidgets('허브 한가운데는 무시되고, 허브 바깥 고리는 그쪽 방향이 입력된다', (tester) async {
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(CalcKeypad(onKeyPressed: pressed.add, enableHaptics: false)),
      );
      final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
      final g = CursorPadGeometry(pad.size);
      expect(g.deadZoneRadius, greaterThan(2));
      // 데드존 안: 무입력
      for (final d in [
        Offset.zero,
        Offset(g.deadZoneRadius * 0.6, 0),
        Offset(0, -g.deadZoneRadius * 0.6),
      ]) {
        await tester.tapAt(pad.center + d);
        await tester.pump();
      }
      expect(pressed, isEmpty);
      // 허브 고리: 축 방향의 키
      final ring = (g.deadZoneRadius + g.hubRadius) / 2;
      for (final (d, id) in [
        (Offset(0, -ring), CalcKeyId.cursorUp),
        (Offset(0, ring), CalcKeyId.cursorDown),
        (Offset(-ring, 0), CalcKeyId.cursorLeft),
        (Offset(ring, 0), CalcKeyId.cursorRight),
      ]) {
        pressed.clear();
        await tester.tapAt(pad.center + d);
        await tester.pump();
        expect(pressed, [id], reason: '$d');
      }
    });

    for (final area in const [Size(800, 300), Size(360, 900)]) {
      testWidgets(
        '${area.width}×${area.height}: 패드 상자 밖 셀 여백은 가까운 방향 키, 셀 밖 간격은 아무 키도 입력하지 않는다',
        (tester) async {
          final pressed = <CalcKeyId>[];
          await tester.pumpWidget(
            _host(
              CalcKeypad(onKeyPressed: pressed.add, enableHaptics: false),
              size: area,
            ),
          );
          final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
          final cell = tester.getRect(find.byType(CursorPad));
          // 전제: 셀 비율이 범위 밖이라 패드 상자가 셀보다 작다.
          expect(pad.width < cell.width || pad.height < cell.height, isTrue);
          // 셀 여백 (#64): 왼쪽·오른쪽 여백은 ◀·▶, 위·아래 여백은 ▲·▼
          final margins = [
            if (pad.left - cell.left > 2)
              (Offset(cell.left + 1, cell.center.dy), CalcKeyId.cursorLeft),
            if (cell.right - pad.right > 2)
              (Offset(cell.right - 1, cell.center.dy), CalcKeyId.cursorRight),
            if (pad.top - cell.top > 2)
              (Offset(cell.center.dx, cell.top + 1), CalcKeyId.cursorUp),
            if (cell.bottom - pad.bottom > 2)
              (Offset(cell.center.dx, cell.bottom - 1), CalcKeyId.cursorDown),
          ];
          expect(margins, isNotEmpty);
          for (final (p, id) in margins) {
            pressed.clear();
            await tester.tapAt(p);
            await tester.pump();
            expect(pressed, [id], reason: '$p');
          }
          // 셀 밖(이웃 키와의 간격)은 넓히지 않는다 — 다른 키 사이와 같은 간격이 남는다.
          for (final p in [
            Offset(cell.left - 0.5, cell.center.dy),
            Offset(cell.right + 0.5, cell.center.dy),
            Offset(cell.center.dx, cell.top - 0.5),
            Offset(cell.center.dx, cell.bottom + 0.5),
          ]) {
            pressed.clear();
            await tester.tapAt(p);
            await tester.pump();
            expect(pressed, isEmpty, reason: '셀 밖 $p');
          }
        },
      );
    }

    for (final area in _areas) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '${area.width}×${area.height}, 글자 배율 $scale: 방향 라벨은 통째로 자기 구역 안, 허브 밖에 그려지고 자리가 있으면 줄지 않는다',
          (tester) async {
            await tester.pumpWidget(
              _host(const CalcKeypad(), size: area, textScale: scale),
            );
            final pad = tester.getRect(
              find.byKey(const ValueKey('cursor-pad')),
            );
            final g = CursorPadGeometry(pad.size);
            for (final sector in CursorPadSector.values) {
              final label = tester
                  .getRect(
                    find.descendant(
                      of: _keycap(CursorPad.defOf(sector).id),
                      matching: find.byType(Text),
                    ),
                  )
                  .shift(-pad.topLeft);
              // 라벨 상자의 네 모서리와 중심이 모두 자기 구역 안이다 (홈·허브·외곽에 잘리지 않는다).
              for (final p in [
                label.topLeft,
                label.topRight,
                label.bottomLeft,
                label.bottomRight,
                label.center,
              ]) {
                expect(g.sectorAt(p), sector, reason: '${sector.name} $p');
              }
            }
            // 라벨은 허브(둘레선 포함)에 덮이지 않고 줄지도 않는다 (#65).
            expectCursorPadLabelsClearOfHub(tester, context: '떼어 둠');
            // 눌러서 키캡이 내려가도(▲는 허브 쪽으로 1dp) 마찬가지다.
            for (final sector in CursorPadSector.values) {
              final gesture = await tester.startGesture(
                tester.getCenter(cursorPadLabel(sector)),
              );
              await tester.pump();
              expectCursorPadLabelsClearOfHub(
                tester,
                sectors: [sector],
                context: '누름',
              );
              await gesture.up();
              await tester.pumpAndSettle();
            }
          },
        );
      }
    }

    for (final area in _areas) {
      testWidgets(
        '${area.width}×${area.height}: 방향 키는 터치 영역을 넓혀도 패드 반쪽 상자에 그대로 그려진다',
        (tester) async {
          // 버튼 상자는 셀 반쪽이지만, 키캡은 hitOutset 안쪽(패드 반쪽)에 그린다 (#64 — 그림 불변).
          await tester.pumpWidget(_host(const CalcKeypad(), size: area));
          final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
          final cell = tester.getRect(find.byType(CursorPad));
          for (final sector in CursorPadSector.values) {
            final id = CursorPad.defOf(sector).id;
            final drawn = CursorPad.sectorBox(
              sector,
              pad.size,
            ).shift(pad.topLeft);
            final keycap = tester.getRect(_keycap(id));
            final reason = '${sector.name} $area';
            expect(
              keycap.left,
              moreOrLessEquals(drawn.left, epsilon: 1e-6),
              reason: reason,
            );
            expect(
              keycap.top,
              moreOrLessEquals(drawn.top, epsilon: 1e-6),
              reason: reason,
            );
            expect(
              keycap.right,
              moreOrLessEquals(drawn.right, epsilon: 1e-6),
              reason: reason,
            );
            // 키캡 아래에는 눌림 이동 여유(pressRoom)만큼 빈 곳이 있다.
            expect(
              keycap.bottom,
              moreOrLessEquals(
                drawn.bottom - CalcTheme.keyPressedOffset,
                epsilon: 1e-6,
              ),
              reason: reason,
            );
            // 버튼 상자(터치)는 셀 반쪽이다.
            final box = tester.getRect(_button(id));
            final half = CursorPad.sectorBox(
              sector,
              cell.size,
            ).shift(cell.topLeft);
            expect(
              (box.topLeft - half.topLeft).distance +
                  (box.bottomRight - half.bottomRight).distance,
              lessThan(1e-6),
              reason: reason,
            );
          }
        },
      );
    }

    for (final area in _areas) {
      testWidgets('${area.width}×${area.height}: 셀의 네 변은 각각 그쪽 방향 키 하나가 받는다', (
        tester,
      ) async {
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(
          _host(
            CalcKeypad(onKeyPressed: pressed.add, enableHaptics: false),
            size: area,
          ),
        );
        final cell = tester.getRect(find.byType(CursorPad));
        // 변에서 1dp 안쪽, 모서리 2dp 이내는 뺀다(두 방향의 경계).
        final inner = cell.deflate(1);
        for (final (from, to, id) in [
          (inner.topLeft, inner.bottomLeft, CalcKeyId.cursorLeft),
          (inner.topRight, inner.bottomRight, CalcKeyId.cursorRight),
          (inner.topLeft, inner.topRight, CalcKeyId.cursorUp),
          (inner.bottomLeft, inner.bottomRight, CalcKeyId.cursorDown),
        ]) {
          final length = (to - from).distance;
          for (var i = 1; i < 10; i++) {
            final t = i / 10;
            if (t * length < 2 || (1 - t) * length < 2) continue;
            final p = Offset.lerp(from, to, t)!;
            pressed.clear();
            await tester.tapAt(p);
            await tester.pump();
            expect(pressed, [id], reason: '$area $p');
          }
        }
      });
    }

    for (final area in _areas) {
      testWidgets(
        '${area.width}×${area.height}: 방향 키 터치 영역은 함수 키 셀보다 크게 줄지 않는다 (가로로 긴 셀 포함)',
        (tester) async {
          // #64 전에는 그림 구역만 눌려 ◀·▶가 함수 키 셀의 0.48~0.59배였다(가로로 긴 셀일수록 작았다).
          // 셀 여백과 외곽 밖을 터치 영역에 넣어 커졌고, 홈 기울기를 실측(#65)으로 바꾼 뒤의 측정값은
          // ◀·▶ 1.14~1.20배, ▲·▼ 1.05~1.11배다.
          // 화면을 영역 크기로 넓혀 키패드가 테스트 화면(800×600)에 잘리지 않게 한다(780×900 등).
          _setViewSize(tester, area);
          await tester.pumpWidget(_host(const CalcKeypad(), size: area));
          final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
          final cell = tester.getRect(find.byType(CursorPad));
          // 내접원(손가락이 들어가는 크기)은 셀 모양과 관계없이 같은 기준이다(#159).
          _expectInscribedVersusFunctionKey(tester, '$area');
          // 셀이 #141 전의 가장 넓은 경우(가로/세로 비 약 2.1 — 가로 폰 800×300의 키패드가 375dp로 줄던 때)보다
          // 넓으면 비교 기준인 함수 키 셀만 넓어지고 패드는 비율 상한에서 멈춰 ▲·▼ 비율이 아래 하한(0.9배) 밑으로 내려갈 수 있다
          // (CalcTheme.cursorPadMaxAspectRatio 문서 — #159에서 모양을 그대로 두기로 정했다). 그 크기([_wideCellAreas])는
          // 아래 "가로로 넓어져도" 테스트가 절대 넓이와 낮춘 하한으로 본다. 여기서 건너뛰는 크기가 그 목록에 있는지도 확인한다.
          if (cell.width / cell.height > 2.2) {
            expect(_wideCellAreas, contains(area));
            return;
          }
          final sin = tester.getSize(_button(CalcKeyId.sin));
          final g = CursorPadGeometry(pad.size);
          final bounds = cell.shift(-pad.topLeft);
          for (final sector in CursorPadSector.values) {
            final vertical =
                sector == CursorPadSector.up || sector == CursorPadSector.down;
            expect(
              g.hitArea(sector, bounds) / (sin.width * sin.height),
              greaterThanOrEqualTo(vertical ? 0.9 : 1.1),
              reason: '${sector.name} $area',
            );
          }
        },
      );
    }

    for (final area in _areas) {
      testWidgets(
        '${area.width}×${area.height}: 패드 상자는 셀 가운데에 정해진 가로/세로 비로 놓인다',
        (tester) async {
          await tester.pumpWidget(_host(const CalcKeypad(), size: area));
          final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
          final cell = tester.getRect(find.byType(CursorPad));
          expect(
            pad.width / pad.height,
            inInclusiveRange(
              CalcTheme.cursorPadMinAspectRatio - 1e-9,
              CalcTheme.cursorPadMaxAspectRatio + 1e-9,
            ),
          );
          final fitted = CursorPad.fitSize(cell.size);
          expect(pad.width, moreOrLessEquals(fitted.width, epsilon: 1e-6));
          expect(pad.height, moreOrLessEquals(fitted.height, epsilon: 1e-6));
          expect(
            (pad.center - cell.center).distance,
            moreOrLessEquals(0, epsilon: 1e-6),
          );
        },
      );
    }
  });
}
