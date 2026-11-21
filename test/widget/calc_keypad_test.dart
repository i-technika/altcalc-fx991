import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

/// 지정한 크기 영역에 키패드를 배치한다.
Widget _host(
  Widget child, {
  Size size = const Size(360, 420),
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
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

List<CalcKeyButton> _buttons(WidgetTester tester) =>
    tester.widgetList<CalcKeyButton>(find.byType(CalcKeyButton)).toList();

Finder _button(CalcKeyId id) =>
    find.byWidgetPredicate((w) => w is CalcKeyButton && w.keyDef.id == id);

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

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
      expect(find.byKey(const ValueKey('cursor-pad-base')), findsOneWidget);
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

            final aspect = keypad.width / keypad.height;
            expect(
              aspect,
              inInclusiveRange(
                CalcTheme.keypadMinAspectRatio - 1e-6,
                CalcTheme.keypadMaxAspectRatio + 1e-6,
              ),
            );

            for (final def in allKeys) {
              final cap = tester.getRect(_keycap(def.id));
              expect(
                keypad.inflate(0.01).contains(cap.bottomRight),
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

    test('시스템 글자 배율이 커지면 (상한까지) 메인 글자가 함께 커진다', () {
      const area = Size(360, 420);
      final normal = KeypadMetrics.compute(area, TextScaler.noScaling);
      final large = KeypadMetrics.compute(area, const TextScaler.linear(1.3));
      final scaledNormal = normal.mainLabelFontSize;
      final scaledLarge = const TextScaler.linear(1.3)
          .scale(large.mainLabelFontSize);
      expect(scaledLarge, greaterThan(scaledNormal));
    });
  });

  group('터치 영역 확장', () {
    test('키캡 높이가 최소 터치 높이 미만이면 각인 띠까지 넓힌다', () {
      final small = KeypadMetrics.compute(
        const Size(320, 380),
        TextScaler.noScaling,
      );
      expect(small.extendFunctionHitArea, isTrue);

      final huge = KeypadMetrics.compute(
        const Size(1200, 1600),
        TextScaler.noScaling,
      );
      expect(huge.extendFunctionHitArea, isFalse);
      expect(huge.extendNumberHitArea, isFalse);
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

  group('KeypadMetrics.fitSize', () {
    test('비율 범위 안이면 영역을 그대로 쓴다', () {
      expect(KeypadMetrics.fitSize(const Size(360, 420)), const Size(360, 420));
    });

    test('너무 넓으면 폭을, 너무 길면 높이를 줄인다', () {
      final wide = KeypadMetrics.fitSize(const Size(800, 300));
      expect(wide.height, 300);
      expect(wide.width, 300 * CalcTheme.keypadMaxAspectRatio);

      final tall = KeypadMetrics.fitSize(const Size(360, 900));
      expect(tall.width, 360);
      expect(tall.height, 360 / CalcTheme.keypadMinAspectRatio);
    });

    test('0 이하 영역도 예외 없이 0 크기가 된다', () {
      expect(KeypadMetrics.fitSize(Size.zero), Size.zero);
      final m = KeypadMetrics.compute(Size.zero, TextScaler.noScaling);
      expect(m.legendFontSize, greaterThan(0));
      expect(m.mainLabelFontSize, greaterThan(0));
    });
  });
}
