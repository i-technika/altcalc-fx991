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

/// [line] 줄의 내용 영역(◄/► 자리 제외)
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
      expect(tester.getCenter(find.text('◄')).dx, lessThan(lcd.center.dx));
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

    testWidgets('입력은 입력 줄 위쪽, 결과는 결과 줄 아래쪽에 붙는다 (실물 Natural 표시)', (
      tester,
    ) async {
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
        if (text == '1') {
          expect(textRect.top, closeTo(lineRect.top, 0.5));
        } else {
          expect(textRect.bottom, closeTo(lineRect.bottom, 0.5));
        }
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
            .text('◄')
            .evaluate()
            .map((e) => find.byElementPredicate((x) => x == e)),
        ...find
            .text('►')
            .evaluate()
            .map((e) => find.byElementPredicate((x) => x == e)),
      ];
      expect(targets.length, LcdIndicatorSlot.values.length + 6);
      for (final f in targets) {
        final r = tester.getRect(f);
        expect(_containsRect(inner, r), isTrue, reason: '$r ⊄ $inner');
      }
    });

    testWidgets('스크롤 표시 ◄/►는 지정한 쪽에만 나타나고 줄 글자 크기에 비례한다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(
          inputOverflow: LcdLineOverflow(right: true),
          resultOverflow: LcdLineOverflow(left: true),
        ),
      );
      Finder inLine(Finder line, String s) =>
          find.descendant(of: line, matching: find.text(s));
      expect(inLine(_inputLine, '►'), findsOneWidget);
      expect(inLine(_inputLine, '◄'), findsNothing);
      expect(inLine(_resultLine, '◄'), findsOneWidget);
      expect(inLine(_resultLine, '►'), findsNothing);

      final arrow = tester.widget<Text>(inLine(_inputLine, '►'));
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

    testWidgets('줄 내용은 제약 없이 그려지고 줄 크기는 LcdLineScope로 안다 (M2 연동)', (
      tester,
    ) async {
      final constraints = <String, BoxConstraints>{};
      final scopes = <String, Size?>{};
      Widget probe(String name) => LayoutBuilder(
        builder: (context, c) {
          constraints[name] = c;
          scopes[name] = LcdLineScope.maybeOf(context);
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
        expect(constraints[name]!.hasBoundedWidth, isFalse, reason: name);
        expect(constraints[name]!.hasBoundedHeight, isFalse, reason: name);
        expect(scopes[name], area, reason: name);
      }
    });

    testWidgets('줄보다 큰 Row·Column(2D 수식 모양)도 넘침 오류 없이 잘린다', (tester) async {
      await _pump(
        tester,
        LcdDisplay(
          input: Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (var i = 0; i < 40; i++) const Text('12')],
          ),
          result: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text('1'), Text('-'), Text('2')],
          ),
        ),
        height: 120,
      );
      expect(tester.takeException(), isNull);
      final inputArea = tester.getRect(_content(_inputLine));
      final row = tester.getRect(
        find.descendant(of: _inputLine, matching: find.byType(Row)).last,
      );
      expect(row.width, greaterThan(inputArea.width));
      expect(row.left, closeTo(inputArea.left, 0.01));
      final resultArea = tester.getRect(_content(_resultLine));
      final column = tester.getRect(
        find.descendant(of: _resultLine, matching: find.byType(Column)),
      );
      expect(column.height, greaterThan(resultArea.height));
      // 결과는 아래쪽 정렬: 넘치는 부분은 위쪽이 잘린다.
      expect(column.bottom, closeTo(resultArea.bottom, 0.01));
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
          input: Builder(
            builder: (context) => SizedBox.fromSize(
              size: LcdLineScope.maybeOf(context),
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Text(long),
              ),
            ),
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

    testWidgets('긴 입력 Text는 축소 없이 앞부분이 보이고 나머지는 잘린다', (tester) async {
      final long = '1234567890' * 10;
      await _pump(tester, LcdDisplay(input: Text(long)));
      expect(tester.takeException(), isNull);
      final area = tester.getRect(_content(_inputLine));
      final text = tester.getRect(find.text(long));
      expect(text.width, greaterThan(area.width));
      expect(text.left, closeTo(area.left, 0.01));
      // 축소하지 않았다: 글자 크기는 그대로다.
      expect(
        DefaultTextStyle.of(tester.element(find.text(long))).style.fontSize,
        CalcTheme.lcdInputStyle.fontSize,
      );
    });

    testWidgets('긴 결과 Text는 오른쪽 정렬을 지켜 끝부분이 보인다', (tester) async {
      final long = '9876543210' * 6;
      await _pump(tester, LcdDisplay(result: Text(long)));
      expect(tester.takeException(), isNull);
      final area = tester.getRect(_content(_resultLine));
      final text = tester.getRect(find.text(long));
      expect(text.width, greaterThan(area.width));
      expect(text.right, closeTo(area.right, 0.01));
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
          // 줄 내용은 제약 없이 그려지므로 rect 높이가 곧 글자의 실제 높이다.
          final textRect = tester.getRect(find.text(text));
          expect(
            textRect.height,
            lessThanOrEqualTo(lineRect.height + 0.01),
            reason: '$text 높이가 줄 높이를 넘는다',
          );
          final element = tester.element(find.text(text));
          final style = DefaultTextStyle.of(element).style;
          expect(
            MediaQuery.textScalerOf(element).scale(style.fontSize!) *
                style.height!,
            lessThanOrEqualTo(lineRect.height + 0.01),
            reason: '$text 스타일 높이가 줄 높이를 넘는다',
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

    /// 렌더링 높이(TextPainter처럼 정수 올림)
    double rendered(TextStyle s, TextScaler scaler) =>
        (scaler.scale(s.fontSize!) * hf).ceilToDouble();

    test('배율 반영 높이가 줄 높이를 넘으면 줄 높이에 맞춰 줄인다', () {
      const scaler = TextScaler.linear(1.3);
      final s = LcdDisplay.fitLineStyle(
        base,
        lineHeight: 30,
        textScaler: scaler,
      );
      expect(s.fontSize, lessThan(base.fontSize!));
      expect(rendered(s, scaler), lessThanOrEqualTo(30));
      // 지나치게 줄이지 않는다: 1dp만 커져도 줄을 넘는다.
      expect(
        rendered(s.copyWith(fontSize: s.fontSize! + 1), scaler),
        greaterThan(30),
      );
    });

    test('비선형 배율(작은 글자일수록 크게 확대)에서도 줄 높이를 넘지 않는다', () {
      const scaler = _NonLinearScaler();
      for (final lineHeight in [10.0, 25.0, 30.0, 45.0, 60.0]) {
        final s = LcdDisplay.fitLineStyle(
          base,
          lineHeight: lineHeight,
          textScaler: scaler,
        );
        expect(
          rendered(s, scaler),
          lessThanOrEqualTo(lineHeight),
          reason: '$lineHeight',
        );
        if (s.fontSize! < base.fontSize!) {
          // 줄였다면 지나치게 줄이지 않는다: 1dp만 커져도 줄을 넘는다.
          expect(
            rendered(s.copyWith(fontSize: s.fontSize! + 1), scaler),
            greaterThan(lineHeight),
            reason: '$lineHeight',
          );
        } else {
          expect(s.fontSize, base.fontSize, reason: '$lineHeight');
        }
      }
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

  test('글자 크기 주입값이 0 이하·무한대·NaN이면 assert로 막는다', () {
    for (final bad in [0.0, -1.0, double.infinity, double.nan]) {
      expect(() => LcdDisplay(statusFontSize: bad), throwsAssertionError);
      expect(() => LcdDisplay(inputFontSize: bad), throwsAssertionError);
      expect(() => LcdDisplay(resultFontSize: bad), throwsAssertionError);
    }
  });

  group('LcdFontSizes (LCD 크기 → 글자 크기)', () {
    const chrome = 2 * (CalcTheme.lcdFrameWidth + CalcTheme.lcdInnerPadding);
    final hf = CalcTheme.lcdInputStyle.height!;
    const ls = 1.2; // 입력·결과 줄 중 큰 자간 (lcdInputStyle) — 폭 기준은 이 값으로 계산한다

    /// 높이 기준 사용량 (배율 1): 상태 표시줄 + 4행(+정수 올림 여유 1dp) + 분수 막대 2개
    double usedHeight(double f) =>
        f * CalcTheme.lcdStatusFontRatio * CalcTheme.lcdStatusBarHeightRatio +
        4 * (f * hf + 1) +
        2 * f * CalcTheme.lcdFractionBarRatio;

    /// 폭 기준 사용량 (배율 1): 17칸 + 양쪽 ◄/►
    double usedWidth(double f) =>
        CalcTheme.lcdLineColumns * (f * CalcTheme.lcdLineCharWidthRatio + ls) +
        2 *
            f *
            CalcTheme.lcdScrollArrowFontRatio *
            CalcTheme.lcdScrollArrowWidthRatio;

    test('입력·결과 줄은 같은 크기이고 상태 표시는 비율만큼 작다', () {
      final f = LcdFontSizes.forSize(
        const Size(360, 160),
        TextScaler.noScaling,
      );
      expect(f.input, f.result);
      expect(
        f.status,
        moreOrLessEquals(f.input * CalcTheme.lcdStatusFontRatio, epsilon: 1e-9),
      );
    });

    test('높이에 걸리는 LCD: 내부 구성이 안쪽 높이를 꽉 채운다 (독립 계산값)', () {
      // 안쪽 82dp: (82 − 4) / (0.42·1.4 + 4·1.3 + 2·0.25) = 78 / 6.288
      final f = LcdFontSizes.forSize(
        const Size(1000, 100),
        TextScaler.noScaling,
      );
      expect(f.input, moreOrLessEquals(78 / 6.288, epsilon: 1e-3));
      expect(usedHeight(f.input), lessThanOrEqualTo(100 - chrome + 1e-9));
    });

    test('폭에 걸리는 LCD: 결과 줄 17칸으로 정해지고 높이를 키워도 그대로다 (독립 계산값)', () {
      // 안쪽 356dp: (356 − 17·1.2) / (17·0.6 + 2·0.54) = 335.6 / 11.28
      final tall = LcdFontSizes.forSize(
        const Size(374, 1000),
        TextScaler.noScaling,
      );
      expect(tall.input, moreOrLessEquals(335.6 / 11.28, epsilon: 1e-3));
      expect(usedWidth(tall.input), lessThanOrEqualTo(374 - chrome + 1e-9));
      expect(
        LcdFontSizes.forSize(const Size(374, 2000), TextScaler.noScaling),
        tall,
      );
    });

    test('폰 폭의 LCD 최대 높이(폭 / 최소 가로세로비)에서는 글자가 폭 기준에 걸린다', () {
      for (final width in [304.0, 344.0, 374.0, 396.0, 414.0]) {
        final atMax = LcdFontSizes.forSize(
          Size(width, width / CalcTheme.screenLcdMinAspectRatio),
          TextScaler.noScaling,
        );
        final unlimited = LcdFontSizes.forSize(
          Size(width, 10000),
          TextScaler.noScaling,
        );
        expect(atMax, unlimited, reason: '$width');
      }
    });

    test('LCD 최소 높이에서도 가장 좁은 폰 폭의 줄 글자는 14dp 이상이다', () {
      final f = LcdFontSizes.forSize(
        const Size(304, CalcTheme.screenLcdMinHeight),
        TextScaler.noScaling,
      );
      expect(f.input, greaterThanOrEqualTo(14));
    });

    test('배율을 키우면 상태 표시는 커지고 줄 글자는 LCD 안에서 그만큼만 줄어든다', () {
      for (final size in const [Size(374, 213), Size(1000, 100)]) {
        final base = LcdFontSizes.forSize(size, TextScaler.noScaling);
        const scaler = TextScaler.linear(1.3);
        final f = LcdFontSizes.forSize(size, scaler);
        // 상태 표시 = 배율 반영 줄 글자 × 비율 × 배율
        expect(
          scaler.scale(f.status),
          moreOrLessEquals(
            scaler.scale(f.input) * CalcTheme.lcdStatusFontRatio * 1.3,
            epsilon: 1e-6,
          ),
          reason: '$size',
        );
        expect(
          scaler.scale(f.status),
          greaterThan(base.status),
          reason: '$size',
        );
        // 줄 글자는 배율로 커지지 않는다 (LCD를 이미 채운다).
        expect(scaler.scale(f.input), lessThanOrEqualTo(base.input + 1e-6));
        expect(scaler.scale(f.input), greaterThan(base.input * 0.95));
      }
    });

    test('배율을 줄여도 줄 글자는 LCD를 채운다 (작아지지 않는다)', () {
      const size = Size(374, 213);
      final base = LcdFontSizes.forSize(size, TextScaler.noScaling);
      const scaler = TextScaler.linear(0.8);
      final f = LcdFontSizes.forSize(size, scaler);
      expect(
        scaler.scale(f.input),
        moreOrLessEquals(base.input, epsilon: 0.01),
      );
    });

    test('비선형 배율에서도 ◄/►를 실제 배율로 계산해 폭을 넘지 않는다', () {
      const scaler = _NonLinearScaler();
      const size = Size(374, 213);
      final f = LcdFontSizes.forSize(size, scaler);
      final line = scaler.scale(f.input);
      final arrow =
          scaler.scale(f.input * CalcTheme.lcdScrollArrowFontRatio) *
          CalcTheme.lcdScrollArrowWidthRatio;
      expect(
        CalcTheme.lcdLineColumns *
                (line * CalcTheme.lcdLineCharWidthRatio + ls) +
            2 * arrow,
        lessThanOrEqualTo(size.width - chrome + 1e-9),
      );
      // 선형 근사(배율 반영 줄 글자 × 비율)보다 화살표가 넓다 — 근사로 계산하면 넘친다.
      expect(
        arrow,
        greaterThan(
          line *
              CalcTheme.lcdScrollArrowFontRatio *
              CalcTheme.lcdScrollArrowWidthRatio,
        ),
      );
    });

    test('아주 작거나 무한·NaN 크기여도 유한한 양수 글자 크기를 준다', () {
      for (final size in const [
        Size.zero,
        Size(10, 10),
        Size(400, 5),
        Size.infinite,
        Size(double.infinity, 120),
        Size(double.nan, double.nan),
      ]) {
        final f = LcdFontSizes.forSize(size, TextScaler.noScaling);
        for (final v in [f.status, f.input, f.result]) {
          expect(v, greaterThan(0), reason: '$size');
          expect(v.isFinite, isTrue, reason: '$size');
        }
      }
      expect(
        LcdFontSizes.forSize(Size.infinite, TextScaler.noScaling),
        LcdFontSizes.forSize(LcdDisplay.fallbackSize, TextScaler.noScaling),
      );
    });

    /// 분수 모양 2D 내용: 분자 · 막대(줄 글자 × 막대 비율, 여백 포함) · 분모
    Widget fraction(String tag, double barHeight) => Column(
      key: ValueKey('fraction-$tag'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('1$tag'),
        SizedBox(height: barHeight, width: 10),
        Text('3$tag'),
      ],
    );

    for (final (size, scaler) in <(Size, TextScaler)>[
      (const Size(304, CalcTheme.screenLcdMinHeight), TextScaler.noScaling),
      (const Size(304, 125), TextScaler.noScaling),
      (const Size(374, 213.7), TextScaler.noScaling),
      (const Size(374, 213.7), const TextScaler.linear(1.3)),
      (const Size(374, 188), const _NonLinearScaler()),
      (const Size(1000, 120), const TextScaler.linear(1.3)),
    ]) {
      testWidgets('$size·$scaler: fitFontsToSize면 입력·결과 줄이 분수를 잘림 없이 담고 '
          '결과 줄은 17칸을 담는다', (tester) async {
        final f = LcdFontSizes.forSize(size, scaler);
        final bar = scaler.scale(f.input) * CalcTheme.lcdFractionBarRatio;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: scaler),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.fromSize(
                  size: size,
                  child: LcdDisplay(
                    fitFontsToSize: true,
                    input: fraction('i', bar),
                    result: fraction('r', bar),
                    inputOverflow: const LcdLineOverflow(
                      left: true,
                      right: true,
                    ),
                    resultOverflow: const LcdLineOverflow(
                      left: true,
                      right: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        // 산출한 크기가 그대로 쓰이고 줄 높이 맞춤으로 다시 줄지 않는다.
        // (LCD는 상한을 적용한 배율 객체로 계산하므로 이분 탐색 오차만큼 다를 수 있다.)
        expect(
          DefaultTextStyle.of(tester.element(find.text('1i'))).style.fontSize,
          moreOrLessEquals(f.input, epsilon: 1e-3),
        );
        expect(
          tester.widget<Text>(_statusText('Math')).style?.fontSize,
          moreOrLessEquals(f.status, epsilon: 1e-3),
        );
        for (final (line, tag) in [(_inputLine, 'i'), (_resultLine, 'r')]) {
          final area = tester.getRect(_content(line));
          final frac = tester.getRect(find.byKey(ValueKey('fraction-$tag')));
          expect(_containsRect(area, frac), isTrue, reason: '$frac ⊄ $area');
        }
        final resultWidth = tester.getSize(_content(_resultLine)).width;
        final line = scaler.scale(f.result);
        expect(
          resultWidth,
          greaterThanOrEqualTo(
            CalcTheme.lcdLineColumns *
                    (line * CalcTheme.lcdLineCharWidthRatio + ls) -
                1e-6,
          ),
        );
      });
    }

    test('fitFontsToSize와 글자 크기 주입을 함께 쓰면 assert로 막는다', () {
      expect(
        () => LcdDisplay(fitFontsToSize: true, inputFontSize: 10),
        throwsAssertionError,
      );
    });

    test('동등성', () {
      const a = LcdFontSizes(status: 1, input: 2, result: 3);
      expect(a, const LcdFontSizes(status: 1, input: 2, result: 3));
      expect(
        a.hashCode,
        const LcdFontSizes(status: 1, input: 2, result: 3).hashCode,
      );
      expect(a, isNot(const LcdFontSizes(status: 1, input: 2, result: 4)));
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

/// 안드로이드 14 비선형 글꼴 배율 흉내: 작은 글자는 1.3배, 큰 글자는 1.1배까지 줄어든다.
class _NonLinearScaler extends TextScaler {
  const _NonLinearScaler();

  @override
  double scale(double fontSize) {
    final t = ((fontSize - 10) / 30).clamp(0.0, 1.0);
    return fontSize * (1.3 - 0.2 * t);
  }

  @override
  double get textScaleFactor => 1.3;
}
