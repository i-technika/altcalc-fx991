import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';

/// 크기를 지정한 LCD를 띄운다. [width]/[height]가 `null`이면 그 축은 무한 제약.
Future<void> _pump(
  WidgetTester tester,
  LcdDisplay lcd, {
  double? width = 360,
  double? height = 160,
  double textScale = 1.0,
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
        size: const Size(800, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
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

Color? _colorOf(WidgetTester tester, Finder f) =>
    tester.widget<Text>(f).style?.color;

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
          ),
        ),
      );
      expect(_colorOf(tester, _statusText('S')), CalcTheme.lcdStatusActive);
      expect(_statusText('R'), findsOneWidget);
      expect(_statusText('D'), findsNothing);
      expect(_statusText('SCI'), findsOneWidget);
      expect(_statusText('FIX'), findsNothing);
      expect(_statusText('i'), findsOneWidget);
      expect(_colorOf(tester, _statusText('i')), CalcTheme.lcdStatusActive);
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
        ),
      );
      expect(on, off);
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
  });

  group('입력·결과 줄', () {
    testWidgets('입력은 왼쪽, 결과는 오른쪽에 정렬되고 줄별 기본 스타일이 적용된다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(input: Text('2+3'), result: Text('5')),
      );
      final lcd = tester.getRect(find.byType(LcdDisplay));
      final input = tester.getRect(find.text('2+3'));
      final result = tester.getRect(find.text('5'));
      expect(input.left - lcd.left, lessThan(lcd.width / 4));
      expect(lcd.right - result.right, lessThan(lcd.width / 4));
      expect(input.center.dy, lessThan(result.center.dy));

      final inputStyle = DefaultTextStyle.of(tester.element(find.text('2+3')));
      final resultStyle = DefaultTextStyle.of(tester.element(find.text('5')));
      expect(inputStyle.style.fontSize, CalcTheme.lcdInputStyle.fontSize);
      expect(resultStyle.style.fontSize, CalcTheme.lcdResultStyle.fontSize);
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
      for (final (line, text) in [
        ('lcd-input-line', '1'),
        ('lcd-result-line', '2'),
      ]) {
        final lineRect = tester.getRect(find.byKey(ValueKey(line)));
        final textRect = tester.getRect(find.text(text));
        expect(textRect.height, lessThan(lineRect.height), reason: line);
        expect(
          textRect.center.dy,
          closeTo(lineRect.center.dy, 0.5),
          reason: line,
        );
      }
    });

    testWidgets('내용은 베젤 안쪽에 그려진다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(input: Text('1'), result: Text('1')),
      );
      final lcd = tester.getRect(find.byType(LcdDisplay));
      final inner = lcd.deflate(CalcTheme.lcdFrameWidth);
      for (final slot in LcdIndicatorSlot.values) {
        final r = tester.getRect(find.byKey(ValueKey(slot)));
        expect(inner.contains(r.topLeft), isTrue, reason: slot.name);
      }
    });

    testWidgets('스크롤 표시 ◀/▶는 지정한 쪽에만 나타난다', (tester) async {
      await _pump(
        tester,
        const LcdDisplay(
          inputOverflow: LcdLineOverflow(right: true),
          resultOverflow: LcdLineOverflow(left: true),
        ),
      );
      final inputLine = find.byKey(const ValueKey('lcd-input-line'));
      final resultLine = find.byKey(const ValueKey('lcd-result-line'));
      Finder inLine(Finder line, String s) =>
          find.descendant(of: line, matching: find.text(s));
      expect(inLine(inputLine, '▶'), findsOneWidget);
      expect(inLine(inputLine, '◀'), findsNothing);
      expect(inLine(resultLine, '◀'), findsOneWidget);
      expect(inLine(resultLine, '▶'), findsNothing);
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

    testWidgets('긴 입력은 축소 없이 잘리며 넘침 오류가 없다', (tester) async {
      final long = '1234567890' * 10;
      await _pump(tester, LcdDisplay(input: Text(long)));
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(long));
      expect(text, isNotNull);
      // 축소되지 않았으므로 텍스트 폭이 LCD보다 넓다.
      expect(
        tester.getSize(find.text(long)).width,
        greaterThan(tester.getSize(find.byType(LcdDisplay)).width),
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
      (120.0, 160.0, 1.0),
      (360.0, 24.0, 1.0),
      (360.0, 4.0, 1.0),
      (200.0, 100.0, 3.0),
    ]) {
      testWidgets('작은 LCD($w×$h, 글자 배율 $scale)에서도 넘침 오류가 없다', (tester) async {
        await _pump(
          tester,
          const LcdDisplay(
            status: LcdStatus(shift: true, disp: true),
            input: Text('sin(30)+cos(60)'),
            result: Text('1'),
            inputOverflow: LcdLineOverflow(left: true, right: true),
          ),
          width: w,
          height: h,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('상태 표시 글자 배율은 상한까지만 반영된다', (tester) async {
      await _pump(tester, const LcdDisplay(), textScale: 3.0);
      final text = tester.widget<Text>(_statusText('Math'));
      expect(
        text.textScaler!.scale(10),
        closeTo(10 * CalcTheme.lcdMaxTextScaleFactor, 1e-9),
      );
    });
  });
}
