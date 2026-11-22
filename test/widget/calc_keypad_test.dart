import 'dart:math' as math;

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

  _cursorPadShapeTests();

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
    testWidgets('▲를 누른 채 ◄ 구역·허브·외곽 밖으로 미끄러지면 ▲ 반복이 멈춘다', (tester) async {
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

      // ◄ 구역, 가운데 허브(데드존), 외곽 밖 모서리
      for (final target in [at(-0.6, -0.1), at(0, 0), at(-0.95, -0.9)]) {
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

    test('시맨틱 영역은 서로 겹치지 않고, 자기 구역(또는 외곽 밖)에만 걸치며 구역을 넉넉히 덮는다', () {
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
          // 영역 안 표본 점은 모두 자기 구역이거나 외곽 밖이다 (다른 구역·허브 위가 없다).
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
                greaterThan(geometry.hubRadius),
                reason: '$size ${a.name} $p 허브 위',
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
      // 대각선 (0.55, 0.55): 뾰족한 마름모면 밖(|u|+|v| = 1.1)이지만 꼭짓점이 둥글어 안이다.
      expect(g.sectorAt(at(g, 0.55, 0.55)), CursorPadSector.down);
    });

    test('X자 홈은 |u| = k·|v| 이고, k > 1이라 ◀·▶ 쪽으로 좁아진다', () {
      final g = CursorPadGeometry(const Size(114, 66));
      const v = 0.4;
      expect(g.sectorAt(at(g, k * v * 0.95, -v)), CursorPadSector.up);
      expect(g.sectorAt(at(g, k * v * 1.05, -v)), CursorPadSector.right);
      expect(g.sectorAt(at(g, -k * v * 0.95, v)), CursorPadSector.down);
      expect(g.sectorAt(at(g, -k * v * 1.05, v)), CursorPadSector.left);
      // 상자 대각선 위 점(타원 시절 경계)은 이제 ▲·▼ 쪽이다.
      expect(g.sectorAt(at(g, 0.4, -0.4)), CursorPadSector.up);
    });

    test('허브 반지름 안쪽은 데드존, 바로 바깥은 방향 키다', () {
      for (final size in padSizes) {
        final g = CursorPadGeometry(size);
        // 허브 지름은 패드 짧은 변의 약 1/4 (실물 사진 눈대중 범위)
        expect(
          2 * g.hubRadius / math.min(size.width, size.height),
          inInclusiveRange(0.2, 0.3),
          reason: '$size',
        );
        for (final sector in CursorPadSector.values) {
          final dir = switch (sector) {
            CursorPadSector.up => const Offset(0, -1),
            CursorPadSector.down => const Offset(0, 1),
            CursorPadSector.left => const Offset(-1, 0),
            CursorPadSector.right => const Offset(1, 0),
          };
          expect(g.sectorAt(g.center + dir * (g.hubRadius - 0.5)), isNull);
          expect(
            g.sectorAt(g.center + dir * (g.hubRadius + 0.5)),
            sector,
            reason: '$size ${sector.name}',
          );
        }
      }
    });

    test('▲·▼는 ◀·▶보다 넓고, 좌우·상하 대칭이며, 가장 좁은 구역도 충분히 넓다', () {
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
        expect(
          area(CursorPadSector.up),
          greaterThan(area(CursorPadSector.left) * 1.2),
          reason: '$size',
        );
        // 가장 좁은 ◀·▶도 패드 상자의 10% 이상이다.
        expect(
          area(CursorPadSector.left),
          greaterThan(size.width * size.height * 0.1),
          reason: '$size',
        );
      }
    });

    test('구역 경로는 방향 판정과 일치한다 (경계 1dp 이내 제외)', () {
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
            if (!_stableAt(g, p, 1)) continue;
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
        expect(checked, greaterThan(total * 0.8), reason: '$size');
      }
    });

    test('구역 넓이 합 + 허브 넓이는 외곽 넓이와 같다', () {
      final g = CursorPadGeometry(const Size(114, 66));
      const n = CalcTheme.cursorPadOutlineExponent;
      var inside = 0;
      const step = 0.25;
      for (var x = step / 2; x < g.size.width; x += step) {
        for (var y = step / 2; y < g.size.height; y += step) {
          final d = Offset(x, y) - g.center;
          final u = (d.dx / g.radiusX).abs();
          final v = (d.dy / g.radiusY).abs();
          if (math.pow(u, n) + math.pow(v, n) <= 1) inside++;
        }
      }
      final outline = inside * step * step;
      final sum =
          CursorPadSector.values.map(g.sectorArea).reduce((a, b) => a + b) +
          math.pi * g.hubRadius * g.hubRadius;
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
            if (!_stableAt(g, p, 1)) continue;
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
        '${area.width}×${area.height}: 누른 곳의 방향만 입력되고 허브·외곽 밖은 무시된다',
        (tester) async {
          final pressed = <CalcKeyId>[];
          await tester.pumpWidget(
            _host(
              CalcKeypad(onKeyPressed: pressed.add, enableHaptics: false),
              size: area,
            ),
          );
          final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
          final g = CursorPadGeometry(pad.size);
          final hit = <CursorPadSector?>{};
          for (var i = 0; i <= 12; i++) {
            for (var j = 0; j <= 8; j++) {
              final local = Offset(pad.width * i / 12, pad.height * j / 8);
              if (!_stableAt(g, local, 1.5)) continue;
              final expected = g.sectorAt(local);
              hit.add(expected);
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
          // 격자가 네 방향과 데드존(허브·외곽 밖)을 모두 지나갔다.
          expect(hit, {...CursorPadSector.values, null});
        },
      );
    }

    testWidgets('허브를 누르면 아무 키도 입력되지 않는다', (tester) async {
      final pressed = <CalcKeyId>[];
      await tester.pumpWidget(
        _host(CalcKeypad(onKeyPressed: pressed.add, enableHaptics: false)),
      );
      final pad = tester.getRect(find.byKey(const ValueKey('cursor-pad')));
      final g = CursorPadGeometry(pad.size);
      expect(g.hubRadius, greaterThan(5));
      for (final d in [
        Offset.zero,
        Offset(g.hubRadius * 0.7, 0),
        Offset(-g.hubRadius * 0.7, 0),
        Offset(0, -g.hubRadius * 0.7),
        Offset(0, g.hubRadius * 0.7),
      ]) {
        await tester.tapAt(pad.center + d);
        await tester.pump();
      }
      expect(pressed, isEmpty);
    });

    for (final area in _areas) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '${area.width}×${area.height}, 글자 배율 $scale: 방향 라벨은 통째로 자기 구역 안에 그려진다',
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
          },
        );
      }
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
