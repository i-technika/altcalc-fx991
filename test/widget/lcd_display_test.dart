import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';

/// 크기를 지정한 LCD를 띄운다. [width]/[height]가 `null`이면 그 축은 무한 제약.
Future<void> _pump(
  WidgetTester tester,
  Widget lcd, {
  double? width = 360,
  double? height = 160,
  double textScale = 1.0,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  Widget child = lcd;
  if (width == null || height == null) {
    child = UnconstrainedBox(
      constrainedAxis: width != null
          ? Axis.horizontal
          : (height != null ? Axis.vertical : null),
      child: child,
    );
  }
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(1200, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: textDirection,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    ),
  );
}

/// 상태 표시줄 안의 [label] 텍스트 위젯
Finder _statusText(String label) =>
    find.descendant(of: find.byType(LcdStatusBar), matching: find.text(label));

final _inputLine = find.byKey(const ValueKey('lcd-input-line'));
final _resultLine = find.byKey(const ValueKey('lcd-result-line'));

/// [line] 줄의 내용 영역(◀/▶ 자리 제외)
Finder _content(Finder line) => find.descendant(
  of: line,
  matching: find.byKey(const ValueKey('lcd-line-content')),
);

Color? _colorOf(WidgetTester tester, Finder f) =>
    tester.widget<Text>(f).style?.color;

/// LCD 베젤 안쪽 영역
Rect _innerRect(WidgetTester tester) =>
    tester.getRect(find.byType(LcdDisplay)).deflate(CalcTheme.lcdFrameWidth);

bool _containsRect(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.01 &&
    inner.top >= outer.top - 0.01 &&
    inner.right <= outer.right + 0.01 &&
    inner.bottom <= outer.bottom + 0.01;

void main() {
  group('상태 표시줄', () {
    testWidgets('모든 슬롯이 그려지고 켜진 것만 활성 색이다', (tester) async {
      await _pump(tester, const LcdDisplay());
      for (final slot in LcdIndicatorSlot.values) {
        expect(_statusText(slot.template), findsOneWidget, reason: slot.name);
      }
      expect(_colorOf(tester, _statusText('D')), CalcTheme.lcdStatusActive);
      expect(_colorOf(tester, _statusText('Math')), CalcTheme.lcdStatusActive);
      expect(_colorOf(tester, _statusText('S')), CalcTheme.lcdStatusInactive);
      expect(_colorOf(tester, _statusText('STO')), CalcTheme.lcdStatusInactive);
      expect(_colorOf(tester, _statusText('▲')), CalcTheme.lcdStatusInactive);
    });

    testWidgets('상태에 따라 표시 문자와 색이 바뀐다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(
          status: LcdStatus(
            shift: true,
            angleUnit: AngleUnit.radian,
            numberFormat: NumberDisplayFormat.sci,
            complex: ComplexResultIndicator.rectangular,
            historyDown: true,
          ),
        ),
      );
      expect(_colorOf(tester, _statusText('S')), CalcTheme.lcdStatusActive);
      expect(_statusText('R'), findsOneWidget);
      expect(_statusText('D'), findsNothing);
      expect(_statusText('SCI'), findsOneWidget);
      expect(_statusText('FIX'), findsNothing);
      expect(_colorOf(tester, _statusText('i')), CalcTheme.lcdStatusActive);
      expect(_colorOf(tester, _statusText('▼')), CalcTheme.lcdStatusActive);
    });

    testWidgets('showInactiveIndicators가 false면 꺼진 표시기를 그리지 않는다', (
      tester,
    ) async {
      await _pump(tester, const LcdDisplay(showInactiveIndicators: false));
      expect(_statusText('D'), findsOneWidget);
      expect(_statusText('Math'), findsOneWidget);
      expect(_statusText('S'), findsNothing);
      expect(_statusText('Disp'), findsNothing);
    });

    testWidgets('표시기가 켜지고 꺼져도 슬롯 위치가 바뀌지 않는다', (tester) async {
      Future<Map<LcdIndicatorSlot, Rect>> rects(LcdStatus s) async {
        await _pump(
          tester,
          LcdDisplay(status: s, showInactiveIndicators: false),
        );
        return {
          for (final slot in LcdIndicatorSlot.values)
            slot: tester.getRect(find.byKey(ValueKey(slot))),
        };
      }

      final off = await rects(const LcdStatus(mathIO: false));
      final on = await rects(
        const LcdStatus(
          shift: true,
          alpha: true,
          memory: true,
          store: true,
          angleUnit: AngleUnit.gradian,
          numberFormat: NumberDisplayFormat.fix,
          engineering: true,
          complex: ComplexResultIndicator.polar,
          disp: true,
          historyUp: true,
          historyDown: true,
        ),
      );
      expect(on, off);
    });

    for (final width in [360.0, 1000.0]) {
      testWidgets('폭 $width에서 슬롯이 LCD 폭 전체에 순서대로 분포한다', (tester) async {
        await _pump(tester, const LcdDisplay(), width: width);
        final bar = tester.getRect(find.byType(LcdStatusBar));
        final rects = [
          for (final slot in LcdIndicatorSlot.values)
            tester.getRect(find.byKey(ValueKey(slot))),
        ];
        expect(rects.first.left, closeTo(bar.left, 0.5));
        expect(rects.last.right, closeTo(bar.right, 0.5));
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i].left, greaterThan(rects[i - 1].right));
        }
      });
    }

    testWidgets('주변이 RTL이어도 LCD는 왼쪽 → 오른쪽으로 배치된다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(inputOverflow: LcdLineOverflow(left: true)),
        textDirection: TextDirection.rtl,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey(LcdIndicatorSlot.shift))).left,
        lessThan(
          tester
              .getRect(find.byKey(const ValueKey(LcdIndicatorSlot.disp)))
              .left,
        ),
      );
      final lcd = tester.getRect(find.byType(LcdDisplay));
      expect(tester.getCenter(find.text('◀')).dx, lessThan(lcd.center.dx));
    });

    testWidgets('스크린리더에는 켜진 표시기만 읽힌다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const LcdDisplay(status: LcdStatus(alpha: true, memory: true)),
      );
      expect(
        tester.getSemantics(find.byType(LcdStatusBar)),
        matchesSemantics(label: 'A M D Math'),
      );
      handle.dispose();
    });

    testWidgets('statusFontSize를 주입하면 상태 표시 글자 크기에 반영된다', (tester) async {
      await _pump(tester, const LcdDisplay(statusFontSize: 14));
      expect(tester.widget<Text>(_statusText('Math')).style?.fontSize, 14);
    });

    testWidgets('LcdStatusBar에 글자 크기 없는 스타일을 넘겨도 기본 크기로 그린다', (tester) async {
      await _pump(
        tester,
        const LcdStatusBar(
          status: LcdStatus.initial,
          style: TextStyle(color: Color(0xFF000000)),
        ),
        height: 20,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(_statusText('Math')).style?.fontSize,
        CalcTheme.lcdStatusStyle.fontSize,
      );
    });
  });

  group('입력·결과 줄', () {
    testWidgets('입력은 왼쪽, 결과는 오른쪽에 정렬되고 줄별 기본 스타일이 적용된다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(input: Text('2+3'), result: Text('5')),
      );
      final inputArea = tester.getRect(_content(_inputLine));
      final resultArea = tester.getRect(_content(_resultLine));
      expect(tester.getRect(find.text('2+3')).left, inputArea.left);
      expect(tester.getRect(find.text('5')).right, resultArea.right);
      expect(inputArea.bottom, lessThanOrEqualTo(resultArea.top + 0.01));

      final inputStyle = DefaultTextStyle.of(tester.element(find.text('2+3')));
      final resultStyle = DefaultTextStyle.of(tester.element(find.text('5')));
      expect(inputStyle.style.fontSize, CalcTheme.lcdInputStyle.fontSize);
      expect(resultStyle.style.fontSize, CalcTheme.lcdResultStyle.fontSize);
    });

    testWidgets('inputFontSize/resultFontSize를 주입하면 줄 글자 크기에 반영된다', (
      tester,
    ) async {
      await _pump(
        tester,
        const LcdDisplay(
          input: Text('1'),
          result: Text('2'),
          inputFontSize: 18,
          resultFontSize: 20,
        ),
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('1'))).style.fontSize,
        18,
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('2'))).style.fontSize,
        20,
      );
    });

    testWidgets('줄 내용은 줄 높이 안에서 세로 가운데에 놓인다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(
          input: Text('1'),
          result: Text('2'),
          inputOverflow: LcdLineOverflow(right: true),
        ),
      );
      for (final (line, text) in [(_inputLine, '1'), (_resultLine, '2')]) {
        final lineRect = tester.getRect(line);
        final textRect = tester.getRect(find.text(text));
        expect(textRect.height, lessThan(lineRect.height));
        expect(textRect.center.dy, closeTo(lineRect.center.dy, 0.5));
      }
    });

    testWidgets('상태 표시줄과 줄 내용은 모두 베젤 안쪽에 그려진다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(
          input: Text('1+2'),
          result: Text('3'),
          inputOverflow: LcdLineOverflow(left: true, right: true),
          resultOverflow: LcdLineOverflow(left: true, right: true),
        ),
      );
      final inner = _innerRect(tester);
      final targets = [
        for (final slot in LcdIndicatorSlot.values) find.byKey(ValueKey(slot)),
        find.text('1+2'),
        find.text('3'),
        ...find
            .text('◀')
            .evaluate()
            .map((e) => find.byElementPredicate((x) => x == e)),
        ...find
            .text('▶')
            .evaluate()
            .map((e) => find.byElementPredicate((x) => x == e)),
      ];
      expect(targets.length, LcdIndicatorSlot.values.length + 6);
      for (final f in targets) {
        final r = tester.getRect(f);
        expect(_containsRect(inner, r), isTrue, reason: '$r ⊄ $inner');
      }
    });

    testWidgets('스크롤 표시 ◀/▶는 지정한 쪽에만 나타나고 줄 글자 크기에 비례한다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(
          inputOverflow: LcdLineOverflow(right: true),
          resultOverflow: LcdLineOverflow(left: true),
        ),
      );
      Finder inLine(Finder line, String s) =>
          find.descendant(of: line, matching: find.text(s));
      expect(inLine(_inputLine, '▶'), findsOneWidget);
      expect(inLine(_inputLine, '◀'), findsNothing);
      expect(inLine(_resultLine, '◀'), findsOneWidget);
      expect(inLine(_resultLine, '▶'), findsNothing);

      final arrow = tester.widget<Text>(inLine(_inputLine, '▶'));
      expect(
        arrow.style?.fontSize,
        CalcTheme.lcdInputStyle.fontSize! * CalcTheme.lcdScrollArrowFontRatio,
      );
    });

    testWidgets('스크롤 표시가 켜져도 내용 위치가 흔들리지 않는다', (tester) async {
      await _pump(tester, const LcdDisplay(input: Text('12')));
      final before = tester.getRect(find.text('12'));
      await _pump(
        tester,
        const LcdDisplay(
          input: Text('12'),
          inputOverflow: LcdLineOverflow(left: true, right: true),
        ),
      );
      expect(tester.getRect(find.text('12')), before);
    });

    testWidgets('줄 내용은 줄 폭·높이를 최대값으로 하는 느슨한 제약을 받는다 (M2 연동)', (tester) async {
      final seen = <String, BoxConstraints>{};
      Widget probe(String name) => LayoutBuilder(
        builder: (context, c) {
          seen[name] = c;
          return const SizedBox.shrink();
        },
      );
      await _pump(
        tester,
        LcdDisplay(input: probe('input'), result: probe('result')),
      );
      for (final (name, line) in [
        ('input', _inputLine),
        ('result', _resultLine),
      ]) {
        final area = tester.getSize(_content(line));
        final c = seen[name]!;
        expect(c.hasBoundedWidth, isTrue, reason: name);
        expect(c.maxWidth, closeTo(area.width, 0.01), reason: name);
        expect(c.maxHeight, closeTo(area.height, 0.01), reason: name);
        expect(c.minWidth, 0, reason: name);
      }
    });

    testWidgets('가로 스크롤 내용을 넣으면 줄 폭 기준으로 스크롤되어 끝(커서 쪽)을 보여줄 수 있다', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final long = '1234567890' * 10;
      await _pump(
        tester,
        LcdDisplay(
          input: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(long),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(controller.position.maxScrollExtent, greaterThan(0));
      // reverse: 끝부분이 줄의 오른쪽 끝에 맞춰 보인다.
      expect(
        tester.getRect(find.text(long)).right,
        closeTo(tester.getRect(_content(_inputLine)).right, 0.5),
      );
    });

    testWidgets('긴 Text는 축소 없이 줄 폭에서 잘리고 넘침 오류가 없다', (tester) async {
      final long = '1234567890' * 10;
      await _pump(tester, LcdDisplay(input: Text(long)));
      expect(tester.takeException(), isNull);
      final area = tester.getRect(_content(_inputLine));
      final text = tester.getRect(find.text(long));
      expect(text.width, closeTo(area.width, 0.01));
      expect(text.left, area.left);
      // 축소하지 않았다: 글자 크기는 그대로다.
      expect(
        DefaultTextStyle.of(tester.element(find.text(long))).style.fontSize,
        CalcTheme.lcdInputStyle.fontSize,
      );
    });
  });

  group('반응형', () {
    testWidgets('부모 크기를 그대로 채운다', (tester) async {
      await _pump(tester, const LcdDisplay(), width: 300, height: 120);
      expect(tester.getSize(find.byType(LcdDisplay)), const Size(300, 120));
    });

    testWidgets('제약이 무한한 축에는 fallbackSize를 쓴다', (tester) async {
      await _pump(tester, const LcdDisplay(), width: 250, height: null);
      expect(
        tester.getSize(find.byType(LcdDisplay)),
        Size(250, LcdDisplay.fallbackSize.height),
      );
    });

    for (final (w, h, scale) in [
      (360.0, 160.0, 2.0),
      (360.0, 100.0, 1.0),
      (360.0, 60.0, 1.3),
      (120.0, 160.0, 1.0),
      (200.0, 100.0, 3.0),
    ]) {
      testWidgets('LCD $w×$h·글자 배율 $scale: 넘침 없이 모든 글자가 제자리에 들어간다', (
        tester,
      ) async {
        await _pump(
          tester,
          const LcdDisplay(
            status: LcdStatus(shift: true, disp: true),
            input: Text('sin(30)'),
            result: Text('0.5'),
            inputOverflow: LcdLineOverflow(left: true, right: true),
          ),
          width: w,
          height: h,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        final inner = _innerRect(tester);
        final bar = tester.getRect(find.byType(LcdStatusBar));
        for (final slot in LcdIndicatorSlot.values) {
          final r = tester.getRect(find.byKey(ValueKey(slot)));
          // 축소(FittedBox)된 경우에도 상태 표시줄 안에 있어야 한다.
          expect(_containsRect(bar, r), isTrue, reason: slot.name);
        }
        for (final (line, text) in [
          (_inputLine, 'sin(30)'),
          (_resultLine, '0.5'),
        ]) {
          final lineRect = tester.getRect(line);
          final textRect = tester.getRect(find.text(text));
          expect(
            textRect.height,
            lessThanOrEqualTo(lineRect.height + 0.01),
            reason: '$text 높이가 줄 높이를 넘는다',
          );
          expect(_containsRect(inner, lineRect), isTrue, reason: text);
        }
      });
    }

    testWidgets('아주 낮은 LCD(4dp)에서도 넘침 오류가 없다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(input: Text('1'), result: Text('1')),
        height: 4,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('글자 배율은 상태 표시와 줄 내용 모두 상한까지만 반영된다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(input: Text('1')),
        textScale: 3.0,
        height: 400,
      );
      final status = tester.widget<Text>(_statusText('Math'));
      expect(
        status.textScaler!.scale(10),
        closeTo(10 * CalcTheme.lcdMaxTextScaleFactor, 1e-9),
      );
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('1'))).scale(10),
        closeTo(10 * CalcTheme.lcdMaxTextScaleFactor, 1e-9),
      );
    });
  });

  group('fitLineStyle', () {
    const base = CalcTheme.lcdResultStyle;
    final hf = base.height!;

    test('줄 높이가 충분하면 요청 크기를 그대로 쓴다', () {
      final s = LcdDisplay.fitLineStyle(
        base,
        fontSize: 20,
        lineHeight: 100,
        textScaler: TextScaler.noScaling,
      );
      expect(s.fontSize, 20);
    });

    test('배율 반영 높이가 줄 높이를 넘으면 줄 높이에 맞춰 줄인다', () {
      final s = LcdDisplay.fitLineStyle(
        base,
        lineHeight: 30,
        textScaler: const TextScaler.linear(1.3),
      );
      expect(s.fontSize! * 1.3 * hf, closeTo(30, 1e-9));
    });

    test('줄 높이가 0 이하여도 양수 글자 크기를 준다', () {
      final s = LcdDisplay.fitLineStyle(
        base,
        lineHeight: -5,
        textScaler: TextScaler.noScaling,
      );
      expect(s.fontSize, greaterThan(0));
    });
  });

  group('LcdLineOverflow', () {
    test('기본값은 넘침 없음이며 동등성을 지킨다', () {
      expect(const LcdLineOverflow(), LcdLineOverflow.none);
      expect(
        const LcdLineOverflow(left: true),
        isNot(const LcdLineOverflow(right: true)),
      );
      expect(
        const LcdLineOverflow(left: true).hashCode,
        const LcdLineOverflow(left: true).hashCode,
      );
    });
  });
}
