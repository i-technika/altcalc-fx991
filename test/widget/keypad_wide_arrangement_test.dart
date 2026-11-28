import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';

import '../support/korean_locale.dart';
import '../support/semantics_hit_testing.dart';

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

    test(
      'fitSize: 영역 폭 전체, 함수부 셀은 표준 키패드보다 세로로 길어지지 않는다 (#141 — 가로 상한 없음)',
      () {
        // 표준 키패드의 함수부 셀 가로/세로 비 하한 (가로/세로 비 하한 키패드)
        final low = _functionCellAspect(
          KeypadMetrics.compute(
            Size(360, 360 / CalcTheme.keypadMinAspectRatio),
            TextScaler.noScaling,
          ),
        );
        for (final area in const [
          _foldTabletop,
          _flipTabletop,
          Size(685, 318.5), // Pixel Fold 세로 반 접힘 — 폭에 묶인다
          Size(2000, 300), // 아주 넓은 영역 — 블록이 가로로 넓어진다
          Size(600, 600),
          Size(300, 100),
        ]) {
          final s = KeypadMetrics.fitSize(area, KeypadArrangement.wide);
          expect(s.width, area.width, reason: '$area');
          expect(s.height, lessThanOrEqualTo(area.height), reason: '$area');
          final m = KeypadMetrics.compute(
            area,
            TextScaler.noScaling,
            arrangement: KeypadArrangement.wide,
          );
          expect(m.size, s, reason: '$area');
          // 블록 사이 간격 = 블록 폭 × 비율 (fitSize의 폭 단위와 치수 계산의 블록 폭이 맞는다)
          expect(
            m.sectionGap,
            moreOrLessEquals(
              m.blockWidth * CalcTheme.keypadWideSectionGapRatio,
            ),
            reason: '$area',
          );
          expect(
            _functionCellAspect(m),
            greaterThanOrEqualTo(low - 1e-9),
            reason: '$area',
          );
        }
        expect(
          KeypadMetrics.fitSize(Size.zero, KeypadArrangement.wide),
          Size.zero,
        );
      },
    );

    test(
      'minKeyCellHeightOf (#142): 키패드가 커지면 줄지 않고, 함수부 셀 높이와 같으며, 터치 높이 이상이다',
      () {
        for (final arrangement in KeypadArrangement.values) {
          var previous = 0.0;
          for (var h = 50.0; h <= 1500; h += 10) {
            final size = Size(h * 1.6, h);
            final cell = KeypadMetrics.minKeyCellHeightOf(size, arrangement);
            expect(
              cell,
              greaterThanOrEqualTo(previous - 1e-9),
              reason: '$size',
            );
            previous = cell;
            final m = KeypadMetrics.compute(
              size,
              TextScaler.noScaling,
              arrangement: arrangement,
            );
            expect(
              cell,
              moreOrLessEquals(m.functionKeyHeight),
              reason: '$size',
            );
            expect(
              cell,
              greaterThanOrEqualTo(
                KeypadMetrics.minKeyTouchHeightOf(size, arrangement) - 1e-9,
              ),
              reason: '$size',
            );
          }
        }
      },
    );

    test('wideBlockWidthOf (#142): 넓은 배열의 블록 폭과 같다', () {
      for (final width in const [400.0, 825.0, 1264.0]) {
        final m = KeypadMetrics.compute(
          Size(width, 200),
          TextScaler.noScaling,
          arrangement: KeypadArrangement.wide,
        );
        expect(
          KeypadMetrics.wideBlockWidthOf(width),
          moreOrLessEquals(m.blockWidth),
        );
      }
    });

    test(
      '블록 사이 최소 간격 (#285 — 책 자세의 접힘선): 보통 간격보다 넓을 때만 블록을 줄이고, 치수·세로 한계가 함께 따른다',
      () {
        for (final width in const [300.0, 549.0, 657.0, 825.0, 1098.0]) {
          final natural = KeypadMetrics.wideBlockWidthOf(width);
          final naturalGap = width - 2 * natural;
          for (final minGap in const [0.0, 16.0, 50.0, 120.0]) {
            final block = KeypadMetrics.wideBlockWidthOf(
              width,
              minSectionGap: minGap,
            );
            final reason = '$width 최소 간격 $minGap';
            // 간격은 보통 간격과 최소 간격 중 넓은 쪽이다
            expect(
              width - 2 * block,
              moreOrLessEquals(math.max(naturalGap, minGap)),
              reason: reason,
            );
            // 세로 한계는 줄어든 블록 폭을 따른다 — 키가 세로로 길어지지 않는다
            final size = KeypadMetrics.fitSize(
              Size(width, double.infinity),
              KeypadArrangement.wide,
              minGap,
            );
            expect(
              size.height,
              moreOrLessEquals(
                block /
                    (CalcTheme.keypadMinAspectRatio *
                        KeypadMetrics.wideHeightFactor),
              ),
              reason: reason,
            );
            // 치수 계산이 같은 블록 폭·간격을 쓴다
            final m = KeypadMetrics.compute(
              Size(width, 200),
              TextScaler.noScaling,
              arrangement: KeypadArrangement.wide,
              minSectionGap: minGap,
            );
            expect(m.blockWidth, moreOrLessEquals(block), reason: reason);
            expect(
              m.sectionGap,
              moreOrLessEquals(width - 2 * block),
              reason: reason,
            );
            // 블록이 줄면 키도 커지지 않는다
            expect(
              KeypadMetrics.minKeyCellHeightOf(
                Size(width, 400),
                KeypadArrangement.wide,
                minSectionGap: minGap,
              ),
              lessThanOrEqualTo(
                KeypadMetrics.minKeyCellHeightOf(
                      Size(width, 400),
                      KeypadArrangement.wide,
                    ) +
                    1e-9,
              ),
              reason: reason,
            );
          }
        }
        // 비유한·음수 최소 간격은 0으로 본다
        for (final bad in const [double.nan, double.infinity, -10.0]) {
          expect(
            KeypadMetrics.wideBlockWidthOf(825, minSectionGap: bad),
            moreOrLessEquals(KeypadMetrics.wideBlockWidthOf(825)),
            reason: '$bad',
          );
        }
      },
    );

    testWidgets('CalcKeypad.minSectionGap: 두 블록 사이가 그 간격 이상이다 (#285)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 657,
              height: 212,
              child: CalcKeypad(
                arrangement: KeypadArrangement.wide,
                minSectionGap: 50,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
      Rect key(CalcKeyId id) =>
          tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id)));
      // 함수부 오른쪽 끝 열(ON 키 쪽)과 숫자부 왼쪽 끝 열(7) 사이
      expect(
        key(CalcKeyId.num7).left - key(settingsKey).right,
        greaterThanOrEqualTo(50 - 0.01),
      );
      expect(keypad.width, moreOrLessEquals(657));
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

    test('preferredArrangementFor는 터치 높이가 아니라 셀 높이로 비교한다 (#143)', () {
      // 880×790: 실물 배열은 키캡이 48dp를 넘어 터치 높이가 각인 띠를 뺀 48.3dp로 줄고(셀 67.2dp), 넓은 배열은 셀·터치
      // 48.4dp다. 터치 높이로 비교하면 넓은 배열이 이기지만 키는 실물 배열이 훨씬 크다.
      const size = Size(880, 790);
      expect(
        KeypadMetrics.minKeyTouchHeightOf(size, KeypadArrangement.wide),
        greaterThan(
          KeypadMetrics.minKeyTouchHeightOf(size, KeypadArrangement.standard),
        ),
      );
      expect(
        KeypadMetrics.minKeyCellHeightOf(size, KeypadArrangement.standard),
        moreOrLessEquals(67.2, epsilon: 0.05),
      );
      expect(
        KeypadMetrics.minKeyCellHeightOf(size, KeypadArrangement.wide),
        moreOrLessEquals(48.4, epsilon: 0.05),
      );
      expect(
        KeypadMetrics.preferredArrangementFor(size),
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
        // 블록 경계는 키 셀(버튼)로 잰다 — 그린 키캡은 셀 가운데에 좁혀 그릴 수 있다(#220)
        for (final def in allKeys) {
          final cap = tester.getRect(_keycap(def.id));
          final cell = tester.getRect(_button(def.id));
          expect(inside.contains(cap.topLeft), isTrue, reason: def.id.name);
          expect(inside.contains(cap.bottomRight), isTrue, reason: def.id.name);
          expect(
            cell.inflate(0.01).contains(cap.topLeft) &&
                cell.inflate(0.01).contains(cap.bottomRight),
            isTrue,
            reason: '${def.id.name} 키캡이 셀 안',
          );
          if (_numberIds.contains(def.id)) {
            numberLeft = numberLeft < cell.left ? numberLeft : cell.left;
          } else {
            functionRight = functionRight > cell.right
                ? functionRight
                : cell.right;
          }
        }
        // 두 블록 사이 간격 = 구역 간격 + 양쪽 셀 여백(키 사이 가로 간격 절반씩)
        expect(
          numberLeft - functionRight,
          moreOrLessEquals(m.sectionGap + m.horizontalGap, epsilon: 0.01),
        );
        // 각 블록 안의 키 배열은 실물 그대로다: 7은 숫자부 왼쪽 위, = 는 오른쪽 아래, SHIFT는 함수부 왼쪽 위
        final seven = tester.getRect(_button(CalcKeyId.num7));
        final equals = tester.getRect(_button(CalcKeyId.equals));
        final shift = tester.getRect(_button(CalcKeyId.shift));
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
            : cell.height - b.legendBandHeightFor(cell.height);
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

    testWidgets('숫자부 왼쪽(#142): 블록만 좌우로 맞바뀌고 구역 안 키 배열·키 element는 그대로다', (
      tester,
    ) async {
      _wideView(tester);
      await tester.pumpWidget(
        _host(
          const CalcKeypad(arrangement: KeypadArrangement.wide),
          size: _foldTabletop,
        ),
      );
      Finder key(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));
      final states = {
        for (final def in allKeys) def.id: tester.state(_button(def.id)),
      };
      final right = {
        for (final def in allKeys) def.id: tester.getRect(key(def.id)),
      };
      await tester.pumpWidget(
        _host(
          const CalcKeypad(
            arrangement: KeypadArrangement.wide,
            numbersOnLeft: true,
          ),
          size: _foldTabletop,
        ),
      );
      expect(tester.takeException(), isNull);
      final keypad = tester.getRect(find.byKey(const ValueKey('calc-keypad')));
      for (final def in allKeys) {
        expect(
          identical(tester.state(_button(def.id)), states[def.id]),
          isTrue,
          reason: def.id.name,
        );
        // 블록 단위의 좌우 대칭: 블록 폭만큼 옮겨 가고, 블록 안 위치(왼쪽부터의 거리)는 같다.
        final before = right[def.id]!;
        final after = tester.getRect(key(def.id));
        expect(
          after.width,
          moreOrLessEquals(before.width),
          reason: def.id.name,
        );
        expect(
          after.height,
          moreOrLessEquals(before.height),
          reason: def.id.name,
        );
        expect(after.top, moreOrLessEquals(before.top), reason: def.id.name);
        final number = _numberIds.contains(def.id);
        expect(
          number ? after.left < before.left : after.left > before.left,
          isTrue,
          reason: def.id.name,
        );
      }
      // 숫자부는 키패드 왼쪽 끝에서 시작하고, 함수부는 오른쪽 끝에서 끝난다.
      expect(
        tester.getRect(key(CalcKeyId.num7)).left,
        lessThan(keypad.left + keypad.width * 0.1),
      );
      expect(
        tester.getRect(key(CalcKeyId.num7)).right,
        lessThan(tester.getRect(key(CalcKeyId.sin)).left),
      );
    });

    for (final (arrangement, numbersOnLeft) in const [
      (KeypadArrangement.standard, false),
      (KeypadArrangement.wide, false),
      (
        KeypadArrangement.wide,
        true,
      ), // 왼손잡이 가로형 (#142) — 숫자부가 왼쪽이어도 함수부를 먼저 읽는다
    ]) {
      testWidgets('스크린리더는 함수부 블록을 다 읽은 뒤 숫자부를 읽는다 '
          '(${arrangement.name}${numbersOnLeft ? '·숫자부 왼쪽' : ''})', (
        tester,
      ) async {
        _wideView(tester);
        final handle = tester.ensureSemantics();
        useKoreanLocale(tester);
        await tester.pumpWidget(
          _host(
            CalcKeypad(arrangement: arrangement, numbersOnLeft: numbersOnLeft),
            size: _foldTabletop,
          ),
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
        // 커서 패드는 ◀ ▲ ▼ ▶ 순서로 이어 읽는다 — TalkBack 에뮬레이터 확인 순서(#173), 넓은 배열·숫자부 왼쪽에서도 같다.
        final firstCursor = order.indexOf(CalcKeyId.cursorLeft);
        expect(order.sublist(firstCursor, firstCursor + 4), const [
          CalcKeyId.cursorLeft,
          CalcKeyId.cursorUp,
          CalcKeyId.cursorDown,
          CalcKeyId.cursorRight,
        ], reason: '$order');
        final firstNumber = order.indexWhere(_numberIds.contains);
        final lastFunction = order.lastIndexWhere(_functionBlockIds.contains);
        expect(lastFunction, lessThan(firstNumber), reason: '$order');
        // 숫자부 안은 행 순서 (7 8 9 DEL AC 4 …)
        expect(order.sublist(firstNumber), [
          for (final r in numberRows) ...r.map((d) => d.id),
        ]);
        // 터치 탐색: 커서 패드 셀 어디를 짚어도 screenSemanticSectorAt 방향의 노드에 닿는다 (#203)
        expectCursorPadTouchExplorationMatchesSpec(
          tester,
          reason: '${arrangement.name} $numbersOnLeft',
        );
        handle.dispose();
      });
    }
  });
}
