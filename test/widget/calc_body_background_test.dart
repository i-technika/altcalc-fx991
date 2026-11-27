import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_body_background.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';

/// 본체 바탕·LCD 유리 그늘 (#156) — 일반 모드에서만 입체 장식을 그리고, 고대비를 켜고 꺼도 화면 내용이 다시 만들어지지 않는다.
void main() {
  Widget host(Widget child, {bool highContrast = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        devicePixelRatio: 2.625,
        padding: const EdgeInsets.only(top: 24, bottom: 16),
        highContrast: highContrast,
      ),
      child: child,
    ),
  );

  CustomPaint paintOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(CalcBodyBackground.paintKey));

  group('본체 바탕', () {
    testWidgets('일반 모드: 잔무늬·그라데이션·가장자리 선을 그리는 바탕이 내용 뒤에 깔리고 터치는 받지 않는다', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const CalcBodyBackground(child: Text('내용'))),
      );
      final painter = paintOf(tester).painter;
      expect(painter, isA<BodyTexturePainter>());
      final texture = painter! as BodyTexturePainter;
      // 무늬 한 칸 그림은 기기 픽셀 배율에 맞춘 정수 픽셀 크기다(반복할 때 이음매가 없다)
      const scale = 2.625; // host의 MediaQuery 배율 (5dp × 2.625 = 13.125 → 13px)
      expect(texture.tile.width, (CalcTheme.bodyTexturePitch * scale).round());
      expect(texture.tile.height, texture.tile.width);
      expect(texture.insets, const EdgeInsets.only(top: 24, bottom: 16));
      // 그라데이션은 바탕에서 시작해 대비를 검사한 두 본체 색 사이에서 끝난다
      expect(BodyTexturePainter.gradient.first, CalcTheme.bodyBackground);
      expect(
        BodyTexturePainter.gradient.last.computeLuminance(),
        inInclusiveRange(
          CalcTheme.bodyBottomGradient.computeLuminance(),
          CalcTheme.bodyBackground.computeLuminance(),
        ),
      );
      // 바탕은 따로 그리는 층이고 터치를 받지 않는다
      expect(
        find.ancestor(
          of: find.byKey(CalcBodyBackground.paintKey),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(
          of: find.byKey(CalcBodyBackground.paintKey),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
      expect(find.text('내용'), findsOneWidget);
    });

    testWidgets('고대비 모드: 바탕에 아무것도 더 그리지 않는다 (단색 본체)', (tester) async {
      await tester.pumpWidget(
        host(const CalcBodyBackground(child: Text('내용')), highContrast: true),
      );
      expect(paintOf(tester).painter, isNull);
    });

    testWidgets('고대비를 켜고 꺼도 내용의 상태가 남는다 (트리 모양이 같다)', (tester) async {
      final key = GlobalKey<_CounterState>();
      _CounterState.initCount = 0;
      for (final highContrast in [false, true, false]) {
        await tester.pumpWidget(
          host(
            CalcBodyBackground(child: _Counter(key: key)),
            highContrast: highContrast,
          ),
        );
        key.currentState!.count++;
      }
      expect(_CounterState.initCount, 1);
      expect(key.currentState!.count, 3);
    });
  });

  group('LCD 유리 그늘', () {
    BoxDecoration shadeOf(WidgetTester tester) =>
        tester
                .widget<DecoratedBox>(find.byKey(LcdDisplay.glassShadeKey))
                .decoration
            as BoxDecoration;

    testWidgets('일반 모드에서만 유리 위쪽에 옅은 그늘을 덧칠하고, 베젤은 바깥 테두리로 본체와 구분된다', (
      tester,
    ) async {
      for (final highContrast in [false, true]) {
        await tester.pumpWidget(
          host(
            const Center(
              child: SizedBox(width: 360, height: 200, child: LcdDisplay()),
            ),
            highContrast: highContrast,
          ),
        );
        final gradient = shadeOf(tester).gradient;
        if (highContrast) {
          expect(gradient, isNull);
        } else {
          expect(gradient, isA<LinearGradient>());
          expect(gradient!.colors.first, CalcTheme.lcdGlassShade);
          expect(gradient.colors.last.a, 0);
        }
      }
      expect(lcdBezelDecoration.color, CalcTheme.lcdBackground);
      expect(
        lcdBezelDecoration.border,
        Border.all(color: CalcTheme.lcdFrame, width: CalcTheme.lcdFrameWidth),
      );
      expect(
        lcdBezelDecoration.boxShadow!.single.color,
        CalcTheme.lcdBezelEdge,
      );
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  /// 상태를 만든 횟수 (테스트마다 0으로 되돌린다)
  static int initCount = 0;
  int count = 0;

  @override
  void initState() {
    super.initState();
    initCount++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
