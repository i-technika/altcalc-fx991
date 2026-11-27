import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/lcd_status.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_status_icon.dart';
import 'package:material_ui/material_ui.dart';

import '../support/korean_locale.dart';

/// 크기를 지정한 LCD를 띄운다. [width]/[height]가 `null`이면 그 축은 무한 제약.
Future<void> _pump(
  WidgetTester tester,
  Widget lcd, {
  double? width = 360,
  double? height = 160,
  double textScale = 1.0,
  TextDirection textDirection = TextDirection.ltr,
  bool highContrast = false,
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
        highContrast: highContrast,
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

/// [icon] 상태 아이콘 위젯 (#57 — 글자 대신 직접 그리는 표시기)
Finder _statusIcon(LcdIndicatorIcon icon) => find.descendant(
  of: find.byType(LcdStatusBar),
  matching: find.byKey(ValueKey(icon)),
);

/// [slot]의 반전 상자 글자 위젯 (#160 — S·A·D·R·G)
Finder _boxedLetter(LcdIndicatorSlot slot) => find.descendant(
  of: find.byType(LcdStatusBar),
  matching: find.byKey(ValueKey('boxed-${slot.name}')),
);

/// [slot]이 그려진 위젯(글자, 반전 상자 글자 또는 아이콘)
Finder _slotDrawing(LcdIndicatorSlot slot) => switch (slot.icon) {
  final icon? => _statusIcon(icon),
  null when slot.boxed => _boxedLetter(slot),
  null => _statusText(slot.template),
};

/// 반전 상자 글자 [slot]의 색. 상자 안 글자가 슬롯의 대표 문자인지도 확인한다(#160 리뷰 R1).
Color _boxedColor(WidgetTester tester, LcdIndicatorSlot slot) {
  final boxed = tester.widget<LcdStatusBoxedLetter>(_boxedLetter(slot));
  expect(boxed.letter, slot.template, reason: slot.name);
  return boxed.color;
}

/// [slot]이 그려진 색
Color? _slotColor(WidgetTester tester, LcdIndicatorSlot slot) =>
    switch (slot.icon) {
      final icon? => tester.widget<LcdStatusIcon>(_statusIcon(icon)).color,
      null when slot.boxed => _boxedColor(tester, slot),
      null => _colorOf(tester, _statusText(slot.template)),
    };

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
        expect(_slotDrawing(slot), findsOneWidget, reason: slot.name);
      }
      for (final slot in LcdIndicatorSlot.values) {
        expect(
          _slotColor(tester, slot),
          LcdStatus.initial.indicatorFor(slot) == null
              ? CalcTheme.lcdStatusInactive
              : CalcTheme.lcdStatusActive,
          reason: slot.name,
        );
      }
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
      expect(
        _slotColor(tester, LcdIndicatorSlot.shift),
        CalcTheme.lcdStatusActive,
      );
      // D/R/G는 자리가 따로 있다 — R만 켜지고 D·G는 꺼진 색으로 남는다 (#58).
      expect(
        _slotColor(tester, LcdIndicatorSlot.angleRadian),
        CalcTheme.lcdStatusActive,
      );
      expect(
        _slotColor(tester, LcdIndicatorSlot.angleDegree),
        CalcTheme.lcdStatusInactive,
      );
      expect(
        _slotColor(tester, LcdIndicatorSlot.angleGradian),
        CalcTheme.lcdStatusInactive,
      );
      expect(_colorOf(tester, _statusText('SCI')), CalcTheme.lcdStatusActive);
      // FIX는 SCI와 다른 자리라 꺼진 색으로 남는다 (#44).
      expect(_colorOf(tester, _statusText('FIX')), CalcTheme.lcdStatusInactive);
      expect(_colorOf(tester, _statusText('i')), CalcTheme.lcdStatusActive);
      // i와 ∠도 자리가 따로 있다 (#58).
      expect(_colorOf(tester, _statusText('∠')), CalcTheme.lcdStatusInactive);
      expect(_colorOf(tester, _statusText('▼')), CalcTheme.lcdStatusActive);
    });

    testWidgets('고대비 모드에서는 꺼진 표시기(글자·아이콘)를 고대비 색으로, 켜진 표시기는 그대로 그린다 (#54)', (
      tester,
    ) async {
      await _pump(tester, const LcdDisplay(), highContrast: true);
      for (final slot in LcdIndicatorSlot.values) {
        expect(
          _slotColor(tester, slot),
          LcdStatus.initial.indicatorFor(slot) == null
              ? CalcTheme.lcdStatusInactiveHighContrast
              : CalcTheme.lcdStatusActive,
          reason: slot.name,
        );
      }
    });

    testWidgets(
      '상태가 같으면 키 입력으로 줄 내용이 바뀌어도 아이콘·상자 글자를 다시 칠하지 않는다 (#160 리뷰 R2)',
      (tester) async {
        const status = LcdStatus(shift: true, store: true);
        await _pump(tester, const LcdDisplay(status: status, input: Text('1')));
        // 다시 칠하면 경계 레이어 아래의 그림 레이어가 새로 만들어진다 — 같은 객체면 다시 칠하지 않고 재사용한 것이다.
        // (debug 칠하기 횟수는 부모만 칠하고 이 경계를 재사용한 경우도 센다.)
        Layer? picture(Finder drawing) => tester
            .renderObject<RenderRepaintBoundary>(
              find
                  .ancestor(of: drawing, matching: find.byType(RepaintBoundary))
                  .first,
            )
            .debugLayer!
            .firstChild;

        final drawings = [
          _slotDrawing(LcdIndicatorSlot.shift),
          _slotDrawing(LcdIndicatorSlot.store),
          _slotDrawing(LcdIndicatorSlot.math),
        ];
        final before = [for (final d in drawings) picture(d)];
        expect(before, everyElement(isNotNull));
        for (final input in ['12', '123', '1234']) {
          await _pump(tester, LcdDisplay(status: status, input: Text(input)));
        }
        for (final (i, d) in drawings.indexed) {
          expect(identical(picture(d), before[i]), isTrue, reason: '$i');
        }
        // 상태가 바뀌면 그 슬롯은 다시 칠한다.
        await _pump(
          tester,
          const LcdDisplay(status: LcdStatus(store: true), input: Text('1234')),
        );
        expect(identical(picture(drawings[0]), before[0]), isFalse);
      },
    );

    testWidgets('showInactiveIndicators가 false면 꺼진 표시기를 그리지 않는다', (
      tester,
    ) async {
      await _pump(tester, const LcdDisplay(showInactiveIndicators: false));
      expect(_slotDrawing(LcdIndicatorSlot.angleDegree), findsOneWidget);
      expect(_slotDrawing(LcdIndicatorSlot.math), findsOneWidget);
      expect(_slotDrawing(LcdIndicatorSlot.shift), findsNothing);
      expect(_slotDrawing(LcdIndicatorSlot.disp), findsNothing);
      expect(_slotDrawing(LcdIndicatorSlot.store), findsNothing);
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
          keepScreenOn: true,
        ),
      );
      expect(on, off);
    });

    testWidgets('폭이 넉넉하면 슬롯 가운데가 실물 세그먼트 위치에 온다 (#58)', (tester) async {
      // 테스트 화면(800×600) 안에 들어가는 폭이어야 실제로 그 폭에서 돈다.
      await _pump(tester, const LcdDisplay(), width: 760);
      final bar = tester.getRect(find.byType(LcdStatusBar));
      for (final slot in LcdIndicatorSlot.values) {
        expect(
          tester.getCenter(find.byKey(ValueKey(slot))).dx,
          closeTo(bar.left + slot.centerFraction * bar.width, 0.5),
          reason: slot.name,
        );
      }
    });

    // 실제 화면처럼 LCD 크기에서 글자 크기를 산출하고(fitFontsToSize), 큰 글자 배율까지 본다.
    // 크기는 화면이 실제로 만드는 LCD(높이 ≤ 폭 / CalcTheme.screenLcdMinAspectRatio)다.
    // 480은 화면이 주는 최대 LCD 폭(CalcTheme.screenLcdMaxWidth)이다. 이 상한이 풀리거나(#141~#144)
    // 슬롯 폭(columns)이 바뀌면(#160) 배율 1.3 허용치를 다시 잰다 — LCD가 넓을수록 어긋남이 조금 커진다
    // (실측: 폭 800에서 3.8, 2000에서 4.0도트).
    // 허용치(실물 위치에서 벗어나도 되는 도트 수, 192도트 기준)는 배율마다 둔다.
    // - 배율 1.0: 실측 최대 0.4도트 → 1도트
    // - 배율 1.3: 실측 최대 3.6도트(480×274) → 4.5도트. 글자가 실물 세그먼트보다 넓어 붙어 있는 D·R·G,
    //   SCI·E·i·∠가 서로 밀어낸다. 슬롯 최소 간격이 크면 줄 전체를 붙여 축소하는 쪽으로 넘어가 30도트 안팎까지 벌어진다.
    for (final (w, h) in [
      (200.0, 114.0),
      (300.0, 171.0),
      (360.0, 205.0),
      (480.0, 274.0),
    ]) {
      for (final (scale, maxDots) in [(1.0, 1.0), (1.3, 4.5)]) {
        testWidgets(
          'LCD $w×$h·배율 $scale: 슬롯이 겹치지 않고 실물 위치에서 $maxDots도트 안에 있다',
          (tester) async {
            await _pump(
              tester,
              const LcdDisplay(fitFontsToSize: true),
              width: w,
              height: h,
              textScale: scale,
            );
            final bar = tester.getRect(find.byType(LcdStatusBar));
            final rects = [
              for (final slot in LcdIndicatorSlot.values)
                tester.getRect(find.byKey(ValueKey(slot))),
            ];
            for (final r in rects) {
              expect(_containsRect(bar, r), isTrue);
            }
            for (var i = 1; i < rects.length; i++) {
              expect(rects[i].left, greaterThan(rects[i - 1].right));
            }
            final dot = bar.width / LcdIndicatorSlot.dotColumns;
            for (final (i, slot) in LcdIndicatorSlot.values.indexed) {
              expect(
                (rects[i].center.dx -
                            (bar.left + slot.centerFraction * bar.width))
                        .abs() /
                    dot,
                lessThan(maxDots),
                reason: slot.name,
              );
            }
          },
        );
      }
    }

    testWidgets('폭 제약이 없으면 슬롯을 최소 간격으로 붙여 그린다', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: UnconstrainedBox(
            child: LcdStatusBar(status: LcdStatus.initial),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final rects = [
        for (final slot in LcdIndicatorSlot.values)
          tester.getRect(find.byKey(ValueKey(slot))),
      ];
      final gap =
          CalcTheme.lcdStatusStyle.fontSize! * CalcTheme.lcdStatusSlotGapRatio;
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left - rects[i - 1].right, closeTo(gap, 0.01));
      }
    });

    testWidgets('글리프 폭보다 큰 음수 자간을 넘겨도 예외 없이 그린다 (#44 리뷰 R2)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 300,
              child: LcdStatusBar(
                status: LcdStatus.initial,
                style: CalcTheme.lcdStatusStyle.copyWith(letterSpacing: -7),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

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

    testWidgets('스크린리더에는 켜진 표시기의 의미만 읽힌다 (기호가 아니라 말로)', (tester) async {
      final handle = tester.ensureSemantics();
      useKoreanLocale(tester);
      await _pump(
        tester,
        const LcdDisplay(status: LcdStatus(alpha: true, memory: true)),
      );
      expect(
        tester.getSemantics(find.byType(LcdStatusBar)),
        matchesSemantics(label: '알파, 메모리, 수학 입출력, 각도 단위 도'),
      );
      handle.dispose();
    });

    testWidgets('statusFontSize를 주입하면 상태 표시 글자 크기에 반영된다', (tester) async {
      await _pump(tester, const LcdDisplay(statusFontSize: 14));
      expect(tester.widget<Text>(_statusText('M')).style?.fontSize, 14);
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
        tester.widget<Text>(_statusText('M')).style?.fontSize,
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

    testWidgets('스크린리더: 줄 이름("입력"/"결과")·스크롤 방향·내용을 한 덩어리로 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      useKoreanLocale(tester);
      await _pump(
        tester,
        const LcdDisplay(
          input: Text('12+3'),
          result: Text('15'),
          inputOverflow: LcdLineOverflow(left: true),
          resultOverflow: LcdLineOverflow(right: true),
        ),
      );
      final input = tester.getSemantics(_inputLine).label;
      final result = tester.getSemantics(_resultLine).label;
      expect(input.split('\n'), ['입력', '왼쪽에 내용 더 있음', '12+3']);
      expect(result.split('\n'), ['결과', '15', '오른쪽에 내용 더 있음']);
      // 화살표 기호 자체는 읽히지 않는다.
      expect(input, isNot(contains('◄')));
      expect(result, isNot(contains('►')));
      handle.dispose();
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
      final status = tester.widget<Text>(_statusText('M'));
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

    test('폰·태블릿 폭의 LCD 최대 높이(폭 / 최소 가로세로비)에서는 글자가 폭 기준 또는 상한(#189)에 걸린다', () {
      for (final width in [
        304.0,
        344.0,
        374.0,
        396.0,
        414.0,
        424.0,
        480.0, // #143 전 테이블톱 LCD 최대 폭 (#92)
        752.0, // 태블릿 세로 iPad 768×1024 (#141 — 세로형 LCD는 본체 폭 전체)
        784.0, // 태블릿 세로 10인치 800×1280
        1008.0, // 태블릿 세로 12.9인치 iPad
      ]) {
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

    group('줄 글자 상한 (#189)', () {
      const cap = CalcTheme.lcdLineMaxFontSize;

      test('상한 높이는 상태 표시줄 + 4행 + 분수 막대 2개를 상한 글자로 더한 값이다 (독립 계산값)', () {
        // 40·0.42·1.4 + 4·(40·1.3 + 1) + 2·40·0.25 + 베젤·여백 2·(3 + 6) = 23.52 + 212 + 20 + 18
        expect(LcdFontSizes.heightAtMaxLineFont, moreOrLessEquals(273.52));
        expect(
          LcdFontSizes.heightAtMaxLineFont,
          moreOrLessEquals(usedHeight(cap) + chrome),
        );
      });

      test(
        '상수 관계 불변식: 상한 높이 > 기록 영역 문턱 > LCD 최소 높이, 상한 높이에 걸리는 폭에서는 글자가 아직 상한 미만',
        () {
          // 상한 높이가 LCD 최소 높이 이하면 배치의 max(최소 높이, …)가 상한을 조용히 무력화한다.
          expect(
            LcdFontSizes.heightAtMaxLineFont,
            greaterThan(CalcTheme.screenLandscapeHistoryMinHeight),
          );
          expect(
            CalcTheme.screenLandscapeHistoryMinHeight,
            greaterThan(CalcTheme.screenLcdMinHeight),
          );
          // LCD가 폭 기준 최대 높이 대신 상한 높이에 걸리기 시작하는 폭(478.7)은 글자가 상한에 닿는 폭(489.6)보다 좁다 —
          // 그 폭에서 글자는 아직 폭에 묶여 있으므로 높이 상한이 글자를 상한보다 작게 묶지 않는다.
          final heightCapWidth =
              LcdFontSizes.heightAtMaxLineFont *
              CalcTheme.screenLcdMinAspectRatio;
          expect(heightCapWidth, moreOrLessEquals(478.66, epsilon: 0.01));
          expect(
            LcdFontSizes.forSize(
              Size(heightCapWidth, 10000),
              TextScaler.noScaling,
            ).input,
            lessThan(cap),
          );
          // 상한이 키 각인 상한보다 크다(LCD 글자가 키 각인보다 작아지지 않는다).
          expect(cap, greaterThan(CalcTheme.keyMainLabelMaxFontSize));
        },
      );

      test('충분히 넓으면 상한 높이에서 줄 글자가 정확히 상한이고, 그보다 높여도 그대로, 낮추면 줄어든다', () {
        final h = LcdFontSizes.heightAtMaxLineFont;
        for (final width in [600.0, 963.1, 1008.0, 2144.0, 5000.0]) {
          final at = LcdFontSizes.forSize(Size(width, h), TextScaler.noScaling);
          expect(at.input, cap, reason: '$width');
          expect(at.result, cap, reason: '$width');
          expect(
            at.status,
            moreOrLessEquals(cap * CalcTheme.lcdStatusFontRatio),
            reason: '$width',
          );
          for (final taller in [h + 0.5, h * 2, 1056.0, 10000.0]) {
            expect(
              LcdFontSizes.forSize(Size(width, taller), TextScaler.noScaling),
              at,
              reason: '$width×$taller',
            );
          }
          expect(
            LcdFontSizes.forSize(
              Size(width, h - 0.5),
              TextScaler.noScaling,
            ).input,
            lessThan(cap),
            reason: '$width',
          );
        }
      });

      test('상한에 닿는 가장 좁은 LCD 폭은 실물 크기(480dp) 근처다 — 그보다 좁으면 폭에 묶인다', () {
        // 폭 기준 글자가 상한이 되는 폭: 17·(40·0.6 + 1.2) + 2·40·0.54 + 베젤·여백 18 = 428.4 + 43.2 + 18
        const widest = 489.6;
        double at(double w) => LcdFontSizes.forSize(
          Size(w, LcdFontSizes.heightAtMaxLineFont),
          TextScaler.noScaling,
        ).input;
        expect(at(widest), moreOrLessEquals(cap, epsilon: 1e-3));
        expect(at(widest - 1), lessThan(cap));
        // 예전 LCD 최대 크기 480×274(#24·#92)는 39.1dp — 상한은 이 값을 올림했다(키 각인 상한 16.45 → 16.5와 같은 기준).
        final realSize = LcdFontSizes.forSize(
          const Size(480, 480 / CalcTheme.screenLcdMinAspectRatio),
          TextScaler.noScaling,
        ).input;
        expect(realSize, moreOrLessEquals(39.1, epsilon: 0.05));
        expect(cap, realSize.ceilToDouble());
        // 키 메인 각인 상한 대비 — 폰의 줄 글자 / 키 각인 비(약 2.3배)와 비슷하게 2.5배 미만에서 멈춘다.
        expect(
          cap / CalcTheme.keyMainLabelMaxFontSize,
          inInclusiveRange(2.2, 2.5),
        );
      });

      test('배율을 바꿔도 배율 반영 후 줄 글자는 상한을 넘지 않는다 (아주 큰 LCD 포함)', () {
        for (final size in const [
          Size(963.1, 550.3), // #189 전 가로형 2000×1400 활성 LCD (82dp)
          Size(1856.3, 858.5), // #189 전 4K 3840×2160 활성 LCD (133dp)
          Size(2144, 1056.2), // #189 전 세로 창 2160×3800 LCD (164.5dp)
          Size(10000, 10000),
          Size(1008, 273.52),
        ]) {
          for (final scaler in const <TextScaler>[
            TextScaler.noScaling,
            TextScaler.linear(0.85),
            TextScaler.linear(1.3),
            _NonLinearScaler(),
          ]) {
            final f = LcdFontSizes.forSize(size, scaler);
            expect(
              scaler.scale(f.input),
              lessThanOrEqualTo(cap + 1e-9),
              reason: '$size $scaler',
            );
            expect(f.input, f.result, reason: '$size $scaler');
          }
          // 배율 1·축소 배율이면 상한에 닿는다 (줄 글자는 배율과 무관하게 같은 크기로 보인다).
          for (final scaler in const <TextScaler>[
            TextScaler.noScaling,
            TextScaler.linear(0.85),
          ]) {
            expect(
              scaler.scale(LcdFontSizes.forSize(size, scaler).input),
              moreOrLessEquals(cap, epsilon: 1e-3),
              reason: '$size $scaler',
            );
          }
        }
      });
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
          tester.widget<Text>(_statusText('M')).style?.fontSize,
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

  group('lcdStatusSlotLefts (#58)', () {
    test('겹치지 않으면 가운데를 실물 위치에 그대로 둔다', () {
      final lefts = lcdStatusSlotLefts(
        centers: const [0.1, 0.5, 0.9],
        widths: const [10, 20, 10],
        barWidth: 100,
        minGap: 1,
      );
      expect(lefts, [5, 40, 85]);
    });

    test('겹치는 슬롯만 순서를 지키며 최소 간격까지 양쪽으로 고르게 민다', () {
      // 가운데 두 슬롯이 겹친다(40~50, 45~55). 12 떨어져야 하므로 모자란 7을 둘이 3.5씩 나눠 움직인다.
      final lefts = lcdStatusSlotLefts(
        centers: const [0.1, 0.45, 0.5, 0.9],
        widths: const [10, 10, 10, 10],
        barWidth: 100,
        minGap: 2,
      )!;
      expect(lefts, [5, 36.5, 48.5, 85]);
    });

    test('표시줄 밖으로 나가는 슬롯은 안으로 들이고, 이웃도 따라 민다', () {
      final lefts = lcdStatusSlotLefts(
        centers: const [0.0, 0.92, 1.0],
        widths: const [10, 10, 10],
        barWidth: 100,
        minGap: 2,
      )!;
      expect(lefts.first, 0);
      expect(lefts.last, 90);
      expect(lefts[1], 78); // 90 - 2 - 10
    });

    test('무작위 입력(정렬 안 된 중심 포함)에서 결과가 최적해다 — KKT 조건 확인', () {
      // 목적 Σ(x_i − t_i)², 제약: x_0 ≥ 0, x_{i+1} − x_i ≥ w_i + g, x_{n−1} ≤ W − w_{n−1}. 볼록 이차 계획이라
      // KKT 조건을 만족하는 실현 가능한 점이 곧 최적해다. 기울기 g_i = 2(x_i − t_i)의 앞쪽 합을 P_i라 하면
      // 간격 제약 승수는 λ_i = μ_L − P_i, 오른쪽 경계 승수는 μ_R = μ_L − P_{n−1}이다(μ_L: 왼쪽 경계 승수).
      // 모든 승수가 0 이상이고, 느슨한 제약의 승수는 0이어야 한다.
      final random = math.Random(58);
      const eps = 1e-6;
      for (var trial = 0; trial < 2000; trial++) {
        final n = 1 + random.nextInt(16);
        final centers = [
          for (var i = 0; i < n; i++) random.nextDouble() * 1.4 - 0.2,
        ];
        if (trial.isEven) centers.sort();
        final widths = [for (var i = 0; i < n; i++) random.nextDouble() * 20];
        final minGap = random.nextDouble() * 3;
        final barWidth = 50 + random.nextDouble() * 400;
        final lefts = lcdStatusSlotLefts(
          centers: centers,
          widths: widths,
          barWidth: barWidth,
          minGap: minGap,
        );
        final need = widths.fold(0.0, (a, b) => a + b) + minGap * (n - 1);
        final why = 'trial $trial';
        if (lefts == null) {
          expect(need, greaterThan(barWidth), reason: why);
          continue;
        }
        // 실현 가능성
        expect(lefts.first, greaterThanOrEqualTo(-eps), reason: why);
        expect(
          lefts.last + widths.last,
          lessThanOrEqualTo(barWidth + eps),
          reason: why,
        );
        final gapTight = <bool>[];
        for (var i = 0; i + 1 < n; i++) {
          final slack = lefts[i + 1] - lefts[i] - widths[i] - minGap;
          expect(slack, greaterThanOrEqualTo(-eps), reason: why);
          gapTight.add(slack < 1e-6);
        }
        final leftTight = lefts.first < 1e-6;
        final rightTight = barWidth - widths.last - lefts.last < 1e-6;
        // 앞쪽 합 P_i
        final prefix = <double>[];
        var sum = 0.0;
        for (var i = 0; i < n; i++) {
          sum += 2 * (lefts[i] - (centers[i] * barWidth - widths[i] / 2));
          prefix.add(sum);
        }
        // μ_L 고르기: 느슨한 간격 제약이 있으면 그 P_i로 정해지고, 없으면 조건을 만족하는 가장 작은 값
        double muL;
        final slackIndex = gapTight.indexWhere((t) => !t);
        if (slackIndex >= 0) {
          muL = prefix[slackIndex];
        } else if (!leftTight) {
          muL = 0;
        } else if (!rightTight) {
          muL = prefix[n - 1];
        } else {
          muL = [0.0, ...prefix].reduce(math.max);
        }
        final tol = 1e-5 * math.max(1, barWidth);
        expect(muL, greaterThanOrEqualTo(-tol), reason: '$why μ_L');
        if (!leftTight) expect(muL.abs(), lessThan(tol), reason: '$why μ_L');
        for (var i = 0; i + 1 < n; i++) {
          final lambda = muL - prefix[i];
          expect(lambda, greaterThanOrEqualTo(-tol), reason: '$why λ_$i');
          if (!gapTight[i]) {
            expect(lambda.abs(), lessThan(tol), reason: '$why λ_$i');
          }
        }
        final muR = muL - prefix[n - 1];
        expect(muR, greaterThanOrEqualTo(-tol), reason: '$why μ_R');
        if (!rightTight) expect(muR.abs(), lessThan(tol), reason: '$why μ_R');
      }
    });

    test('슬롯 폭과 최소 간격의 합이 폭과 같으면 꽉 붙이고, 넘으면 null', () {
      expect(
        lcdStatusSlotLefts(
          centers: const [0.5, 0.5, 0.5],
          widths: const [10, 10, 10],
          barWidth: 34,
          minGap: 2,
        ),
        [0, 12, 24],
      );
      expect(
        lcdStatusSlotLefts(
          centers: const [0.5, 0.5, 0.5],
          widths: const [10, 10, 10],
          barWidth: 33.9,
          minGap: 2,
        ),
        isNull,
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
