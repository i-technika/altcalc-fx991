import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

import '../support/korean_locale.dart';

/// 넓은 키패드 배열 (#80) — 숫자부를 함수부 오른쪽에 나란히 두는 배열의 치수·배치·선택 규칙.

/// Galaxy Z Fold 가로 반 접힘(인셋 24/24)의 아래 절반 키패드 자리 (본체 좌표 825 × 234.5)
const _foldTabletop = Size(825, 234.5);

/// Galaxy Z Flip 내부 반 접힘(Flex 모드)의 아래 절반 키패드 자리 (395 × 411)
const _flipTabletop = Size(395, 411);

/// 테스트 화면(기본 800×600)을 넓은 키패드 자리보다 넓게 키운다.
void _wideView(WidgetTester tester) {
  tester.view.physicalSize =
      const Size(2100, 600) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _host(Widget child, {required Size size, double textScale = 1.0}) {
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

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

Finder _button(CalcKeyId id) =>
    find.byWidgetPredicate((w) => w is CalcKeyButton && w.keyDef.id == id);

final _numberIds = {for (final r in numberRows) ...r.map((d) => d.id)};

/// 함수부 블록(상단 조작부 + 함수부) 키
final _functionBlockIds = allKeys
    .map((d) => d.id)
    .where((id) => !_numberIds.contains(id))
    .toSet();

/// 함수부 키 셀의 가로/세로 비 (간격 포함 셀 — 열 폭 / 행 높이)
double _functionCellAspect(KeypadMetrics m) =>
    m.blockWidth / functionColumns / m.functionRowHeight;

void main() {
  group('KeypadMetrics — 넓은 배열 치수', () {
    test('높이 배수: 넓은 배열의 함수부 행 높이·키 간격은 같은 행 높이의 표준 키패드와 같다', () {
      expect(KeypadMetrics.wideHeightFactor, moreOrLessEquals(2.0));
      final wide = KeypadMetrics.compute(
        _foldTabletop,
        TextScaler.noScaling,
        arrangement: KeypadArrangement.wide,
      );
      final standard = KeypadMetrics.compute(
        Size(
          wide.blockWidth,
          wide.size.height * KeypadMetrics.wideHeightFactor,
        ),
        TextScaler.noScaling,
      );
      expect(standard.size.width, moreOrLessEquals(wide.blockWidth));
      expect(
        wide.functionRowHeight,
        moreOrLessEquals(standard.functionRowHeight),
      );
      expect(wide.verticalGap, moreOrLessEquals(standard.verticalGap));
      expect(wide.horizontalGap, moreOrLessEquals(standard.horizontalGap));
      // 같은 키 모양이라 글자 크기도 같다.
      expect(
        wide.mainLabelFontSize,
        moreOrLessEquals(standard.mainLabelFontSize),
      );
      expect(wide.legendFontSize, moreOrLessEquals(standard.legendFontSize));
      // 숫자부 4행이 블록 높이를 나눈다 (함수부 행의 1.25배)
      expect(
        wide.numberRowHeight,
        moreOrLessEquals(wide.size.height / numberRows.length),
      );
      expect(
        wide.sectionGap,
        moreOrLessEquals(wide.blockWidth * CalcTheme.keypadWideSectionGapRatio),
      );
    });

    test('fitSize: 영역 안, 블록 폭 ≤ 최대 폭, 함수부 셀 비는 표준 키패드 범위와 같다', () {
      // 표준 키패드의 함수부 셀 가로/세로 비 범위 (가로/세로 비 하한·상한 키패드)
      final low = _functionCellAspect(
        KeypadMetrics.compute(
          Size(360, 360 / CalcTheme.keypadMinAspectRatio),
          TextScaler.noScaling,
        ),
      );
      final high = _functionCellAspect(
        KeypadMetrics.compute(
          Size(360 * CalcTheme.keypadMaxAspectRatio, 360),
          TextScaler.noScaling,
        ),
      );
      for (final area in const [
        _foldTabletop,
        _flipTabletop,
        Size(685, 318.5), // Pixel Fold 세로 반 접힘 — 폭에 묶인다
        Size(2000, 300), // 아주 넓은 영역 — 블록 폭 상한
        Size(600, 600),
        Size(300, 100),
        Size(double.infinity, double.infinity),
      ]) {
        final s = KeypadMetrics.fitSize(area, KeypadArrangement.wide);
        expect(s.width, lessThanOrEqualTo(area.width), reason: '$area');
        expect(s.height, lessThanOrEqualTo(area.height), reason: '$area');
        final m = KeypadMetrics.compute(
          area,
          TextScaler.noScaling,
          arrangement: KeypadArrangement.wide,
        );
        expect(m.size, s, reason: '$area');
        // 두 블록 + 블록 사이 간격 = 키패드 폭 (fitSize와 치수 계산이 같은 폭 단위를 쓴다)
        expect(
          2 * m.blockWidth + m.sectionGap,
          moreOrLessEquals(m.size.width),
          reason: '$area',
        );
        expect(
          m.blockWidth,
          lessThanOrEqualTo(CalcTheme.keypadMaxWidth + 1e-9),
          reason: '$area',
        );
        expect(
          _functionCellAspect(m),
          inInclusiveRange(low - 1e-9, high + 1e-9),
          reason: '$area',
        );
      }
      expect(
        KeypadMetrics.fitSize(Size.zero, KeypadArrangement.wide),
        Size.zero,
      );
    });

    test('preferredArrangementFor: 넓은 배열의 키가 클 때만 넓은 배열이다', () {
      // Fold 가로 반 접힘: 19.9 → 39.9dp
      expect(
        KeypadMetrics.minKeyTouchHeightOf(
          _foldTabletop,
          KeypadArrangement.standard,
        ),
        moreOrLessEquals(19.93, epsilon: 0.01),
      );
      expect(
        KeypadMetrics.minKeyTouchHeightOf(
          _foldTabletop,
          KeypadArrangement.wide,
        ),
        moreOrLessEquals(39.86, epsilon: 0.01),
      );
      expect(
        KeypadMetrics.preferredArrangementFor(_foldTabletop),
        KeypadArrangement.wide,
      );
      // Flip 내부: 실물 배열 34.9dp > 넓은 배열 21.7dp
      expect(
        KeypadMetrics.preferredArrangementFor(_flipTabletop),
        KeypadArrangement.standard,
      );
      // 세로 폰 키패드 자리는 실물 배열 그대로
      expect(
        KeypadMetrics.preferredArrangementFor(const Size(374, 430)),
        KeypadArrangement.standard,
      );
      // 둘 다 0이면(같으면) 실물 배열
      expect(
        KeypadMetrics.preferredArrangementFor(Size.zero),
        KeypadArrangement.standard,
      );
    });
  });

  group('CalcKeypad — 넓은 배열 배치', () {
    for (final area in const [
      Size(1, 1),
      Size(50, 20),
      Size(360, 150),
      Size(2000, 300),
      Size(400.3, 133.7),
    ]) {
      for (final scale in [0.85, 2.0]) {
        testWidgets(
          '${area.width}×${area.height}·글자 배율 $scale: 예외·넘침 없이 영역 안에 들어간다',
          (tester) async {
            _wideView(tester);
            await tester.pumpWidget(
              _host(
                const CalcKeypad(arrangement: KeypadArrangement.wide),
                size: area,
                textScale: scale,
              ),
            );
            expect(tester.takeException(), isNull);
            final keypad = tester.getRect(
              find.byKey(const ValueKey('calc-keypad')),
            );
            final bounds = (Offset.zero & area).inflate(0.01);
            expect(bounds.contains(keypad.topLeft), isTrue);
            expect(bounds.contains(keypad.bottomRight), isTrue);
          },
        );
      }
    }

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('Fold 가로 반 접힘 자리·글자 배율 $scale: 넘침 없이 숫자부가 함수부 오른쪽에 놓인다', (
        tester,
      ) async {
        _wideView(tester);
        await tester.pumpWidget(
          _host(
            CalcKeypad(
              onKeyPressed: (_) {},
              arrangement: KeypadArrangement.wide,
            ),
            size: _foldTabletop,
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        final keypad = tester.getRect(
          find.byKey(const ValueKey('calc-keypad')),
        );
        expect(
          keypad.size,
          KeypadMetrics.fitSize(_foldTabletop, KeypadArrangement.wide),
        );
        final m = KeypadMetrics.compute(
          _foldTabletop,
          TextScaler.noScaling,
          arrangement: KeypadArrangement.wide,
        );
        final inside = keypad.inflate(0.01);
        var functionRight = double.negativeInfinity;
        var numberLeft = double.infinity;
        for (final def in allKeys) {
          final cap = tester.getRect(_keycap(def.id));
          expect(inside.contains(cap.topLeft), isTrue, reason: def.id.name);
          expect(inside.contains(cap.bottomRight), isTrue, reason: def.id.name);
          if (_numberIds.contains(def.id)) {
            numberLeft = numberLeft < cap.left ? numberLeft : cap.left;
          } else {
            functionRight = functionRight > cap.right
                ? functionRight
                : cap.right;
          }
        }
        // 두 블록 사이 간격 = 구역 간격 + 양쪽 셀 여백(키 사이 가로 간격 절반씩)
        expect(
          numberLeft - functionRight,
          moreOrLessEquals(m.sectionGap + m.horizontalGap, epsilon: 0.01),
        );
        // 각 블록 안의 키 배열은 실물 그대로다: 7은 숫자부 왼쪽 위, = 는 오른쪽 아래, SHIFT는 함수부 왼쪽 위
        final seven = tester.getRect(_keycap(CalcKeyId.num7));
        final equals = tester.getRect(_keycap(CalcKeyId.equals));
        final shift = tester.getRect(_keycap(CalcKeyId.shift));
        expect(seven.left, moreOrLessEquals(numberLeft, epsilon: 0.01));
        expect(
          equals.right,
          moreOrLessEquals(keypad.right - m.horizontalGap / 2, epsilon: 0.01),
        );
        expect(
          shift.left,
          moreOrLessEquals(keypad.left + m.horizontalGap / 2, epsilon: 0.01),
        );
        expect(seven.top, lessThan(equals.top));
        expect(shift.top, lessThan(seven.top + 1));
      });
    }

    testWidgets('그린 키의 가장 낮은 터치 높이가 minKeyTouchHeightOf(넓은 배열)과 같다', (
      tester,
    ) async {
      _wideView(tester);
      await tester.pumpWidget(
        _host(
          const CalcKeypad(arrangement: KeypadArrangement.wide),
          size: _foldTabletop,
        ),
      );
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
      }
      expect(
        lowest,
        moreOrLessEquals(
          KeypadMetrics.minKeyTouchHeightOf(
            _foldTabletop,
            KeypadArrangement.wide,
          ),
          epsilon: 0.01,
        ),
      );
      expect(lowest, greaterThanOrEqualTo(CalcTheme.keyTouchHeightFloor));
    });

    testWidgets('배열을 바꿔도 키 element·상태가 유지된다 (접고 펼 때)', (tester) async {
      _wideView(tester);
      await tester.pumpWidget(_host(const CalcKeypad(), size: _foldTabletop));
      final states = {
        for (final def in allKeys) def.id: tester.state(_button(def.id)),
      };
      await tester.pumpWidget(
        _host(
          const CalcKeypad(arrangement: KeypadArrangement.wide),
          size: _foldTabletop,
        ),
      );
      expect(tester.takeException(), isNull);
      for (final def in allKeys) {
        expect(
          identical(tester.state(_button(def.id)), states[def.id]),
          isTrue,
          reason: def.id.name,
        );
      }
    });

    for (final arrangement in KeypadArrangement.values) {
      testWidgets('스크린리더는 함수부 블록을 다 읽은 뒤 숫자부를 읽는다 (${arrangement.name})', (
        tester,
      ) async {
        _wideView(tester);
        final handle = tester.ensureSemantics();
        useKoreanLocale(tester);
        await tester.pumpWidget(
          _host(CalcKeypad(arrangement: arrangement), size: _foldTabletop),
        );
        const strings = KoSemanticStrings();
        final labelToId = {
          for (final def in allKeys) strings.keyButton(def.id): def.id,
        };
        final order = <CalcKeyId>[];
        void visit(SemanticsNode node) {
          final id = labelToId[node.label];
          if (id != null) order.add(id);
          for (final child in node.debugListChildrenInOrder(
            DebugSemanticsDumpOrder.traversalOrder,
          )) {
            visit(child);
          }
        }

        // 키패드를 덮는 가장 가까운 의미 노드부터 화면 순서대로 훑는다.
        visit(tester.getSemantics(find.byKey(const ValueKey('calc-keypad'))));
        expect(order.toSet(), allKeys.map((d) => d.id).toSet());
        expect(order, hasLength(allKeys.length));
        final firstNumber = order.indexWhere(_numberIds.contains);
        final lastFunction = order.lastIndexWhere(_functionBlockIds.contains);
        expect(lastFunction, lessThan(firstNumber), reason: '$order');
        // 숫자부 안은 행 순서 (7 8 9 DEL AC 4 …)
        expect(order.sublist(firstNumber), [
          for (final r in numberRows) ...r.map((d) => d.id),
        ]);
        handle.dispose();
      });
    }
  });
}
