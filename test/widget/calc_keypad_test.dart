import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

import '../support/korean_locale.dart';

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

  group('커서 패드', () {
    /// 패드 중심 기준 정규화 좌표 (u, v ∈ -1..1, 타원 반지름 단위)를 화면 좌표로 바꾼다.
    Offset padPoint(Rect pad, double u, double v) =>
        pad.center + Offset(u * pad.width / 2, v * pad.height / 2);

    /// 위 방향 부채꼴 안의 점들 (중심 근처, 대각선 근처, 바깥쪽)
    const upPoints = [(0.0, -0.12), (0.45, -0.6), (-0.45, -0.6), (0.0, -0.9)];

    Offset rotate((double, double) p, CursorPadSector sector) {
      final (u, v) = p;
      return switch (sector) {
        CursorPadSector.up => Offset(u, v),
        CursorPadSector.down => Offset(-u, -v),
        CursorPadSector.left => Offset(v, u),
        CursorPadSector.right => Offset(-v, u),
      };
    }

    for (final area in const [Size(320, 380), Size(360, 420), Size(412, 640)]) {
      testWidgets('${area.width}×${area.height}: 부채꼴 어디를 눌러도 그 방향만 입력된다', (
        tester,
      ) async {
        final pressed = <CalcKeyId>[];
        await tester.pumpWidget(
          _host(
            CalcKeypad(onKeyPressed: pressed.add, enableHaptics: false),
            size: area,
          ),
        );
        final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
        for (final sector in CursorPadSector.values) {
          for (final p in upPoints) {
            pressed.clear();
            final q = rotate(p, sector);
            await tester.tapAt(padPoint(pad, q.dx, q.dy));
            await tester.pump();
            expect(pressed, [
              CursorPad.defOf(sector).id,
            ], reason: '${sector.name} $p');
          }
        }
      });
    }

    testWidgets('타원 밖 모서리는 아무 키도 입력하지 않는다', (tester) async {
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(CalcKeypad(onKeyPressed: pressed.add, enableHaptics: false)),
      );
      final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
      for (final (u, v) in const [(0.95, 0.95), (-0.95, -0.95)]) {
        await tester.tapAt(padPoint(pad, u, v));
      }
      expect(pressed, isEmpty);
    });

    testWidgets('방향 라벨은 자기 부채꼴 안쪽에 그려진다', (tester) async {
      await tester.pumpWidget(_host(const CalcKeypad()));
      final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
      for (final sector in CursorPadSector.values) {
        final label = tester.getRect(
          find.descendant(
            of: _keycap(CursorPad.defOf(sector).id),
            matching: find.byType(Text),
          ),
        );
        final u = (label.center.dx - pad.center.dx) / (pad.width / 2);
        final v = (label.center.dy - pad.center.dy) / (pad.height / 2);
        final inSector = switch (sector) {
          CursorPadSector.up => v < 0 && u.abs() < v.abs(),
          CursorPadSector.down => v > 0 && u.abs() < v.abs(),
          CursorPadSector.left => u < 0 && v.abs() < u.abs(),
          CursorPadSector.right => u > 0 && v.abs() < u.abs(),
        };
        expect(inSector, isTrue, reason: sector.name);
        expect(u * u + v * v, lessThan(1), reason: sector.name);
      }
    });

    test('부채꼴 상자는 패드를 반씩 나누고, 경로는 패드 중심에서 만난다', () {
      const size = Size(120, 100);
      for (final sector in CursorPadSector.values) {
        final box = CursorPad.sectorBox(sector, size);
        expect((Offset.zero & size).intersect(box), box);
        expect(box.width * box.height, size.width * size.height / 2);
        final path = CursorPad.sectorPath(sector, box.size);
        // 패드 중심 쪽으로 조금 들어간 점은 그 부채꼴에 속한다.
        final towardCenter = Offset.lerp(
          box.center,
          size.center(Offset.zero),
          0.5,
        )!;
        expect(path.contains(towardCenter - box.topLeft), isTrue);
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

void _cursorPadR2Tests() {
  group('커서 패드 (이동·시맨틱)', () {
    testWidgets('▲를 누른 채 ◄ 부채꼴이나 타원 밖으로 미끄러지면 ▲ 반복이 멈춘다', (tester) async {
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
      Offset at(double u, double v) =>
          pad.center + Offset(u * pad.width / 2, v * pad.height / 2);

      for (final target in [at(-0.6, -0.1), at(-0.95, -0.9)]) {
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

    test('시맨틱 영역은 서로 겹치지 않고 각자 자기 부채꼴 쪽에 있다', () {
      const size = Size(120, 100);
      final rects = {
        for (final s in CursorPadSector.values)
          s: CursorPad.semanticRect(s, size),
      };
      for (final a in CursorPadSector.values) {
        for (final b in CursorPadSector.values) {
          if (a == b) continue;
          final overlap = rects[a]!.intersect(rects[b]!);
          expect(
            overlap.width <= 0 || overlap.height <= 0,
            isTrue,
            reason: '${a.name} × ${b.name}',
          );
        }
        // 영역 중심은 그 방향 부채꼴 안이다.
        final c = rects[a]!.center - size.center(Offset.zero);
        final inSector = switch (a) {
          CursorPadSector.up => c.dy < 0 && c.dx.abs() < c.dy.abs(),
          CursorPadSector.down => c.dy > 0 && c.dx.abs() < c.dy.abs(),
          CursorPadSector.left => c.dx < 0 && c.dy.abs() < c.dx.abs(),
          CursorPadSector.right => c.dx > 0 && c.dy.abs() < c.dx.abs(),
        };
        expect(inSector, isTrue, reason: a.name);
      }
    });

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
          final text = find.descendant(
            of: _keycap(def.id),
            matching: find.byType(Text),
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
