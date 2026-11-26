import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/calc_semantic_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/key_legend_view.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';
import '../support/key_legends.dart';
import '../support/korean_locale.dart';
import '../support/ttf_cmap.dart';

/// 50키의 2차원 각인과 그 스타일 (메인·SHIFT·ALPHA)
List<(CalcKeyDef, KeyLegend, TextStyle)> _twoDimensional() => [
  for (final k in allKeys)
    for (final (legend, style) in [
      (k.mainLegend, CalcTheme.keyMainLabelStyle),
      (k.shiftLegend, CalcTheme.keyShiftLabelStyle),
      (k.alphaLegend, CalcTheme.keyAlphaLabelStyle),
    ])
      if (legend != null && !legend.isPlain) (k, legend, style),
];

Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Material(
      color: CalcTheme.bodyBackground,
      child: Center(child: child),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => loadBundledFonts());

  group('잉크 범위 표 (KeyLegendView.glyphInk)', () {
    test('2차원 각인의 모든 글자가 표에 있다', () {
      final missing = {
        for (final (_, legend, _) in _twoDimensional())
          for (final piece in legend.texts)
            for (final ch in piece.text.split(''))
              if (!KeyLegendView.glyphInk.containsKey(ch)) ch,
      };
      expect(missing, isEmpty, reason: '표에 없으면 한 줄 상자를 잉크로 봐 배치가 성겨진다');
    });

    test('표의 값은 번들 글꼴의 glyf 잉크 범위와 0.012em 안에서 같다 (각인에 쓰는 굵기 모두)', () async {
      // 메인 각인은 SemiBold, SHIFT·ALPHA 각인은 Medium이다. ∫·∑는 대체 글꼴 Noto Sans Math에만 있다.
      final fonts = {
        'SemiBold': await rootBundle.load(
          'assets/fonts/NotoSansMono-SemiBold.ttf',
        ),
        'Medium': await rootBundle.load('assets/fonts/NotoSansMono-Medium.ttf'),
      };
      final math = await rootBundle.load(
        'assets/fonts/NotoSansMath-Regular.ttf',
      );
      expect(
        {
          CalcTheme.keyMainLabelStyle.fontWeight,
          CalcTheme.keyShiftLabelStyle.fontWeight,
          CalcTheme.keyAlphaLabelStyle.fontWeight,
        },
        {FontWeight.w600, FontWeight.w500},
        reason: '굵기가 바뀌면 위 글꼴 목록도 바꾼다',
      );
      for (final MapEntry(key: ch, value: (yMin, yMax))
          in KeyLegendView.glyphInk.entries) {
        final code = ch.runes.single;
        final sources = readCmap(fonts['Medium']!).containsKey(code)
            ? fonts.entries.toList()
            : [MapEntry('Math', math)];
        for (final MapEntry(key: weight, value: data) in sources) {
          final bounds = readGlyphYBounds(data, code)!;
          expect(
            yMin,
            moreOrLessEquals(bounds.yMin, epsilon: 0.012),
            reason: '$ch $weight yMin',
          );
          expect(
            yMax,
            moreOrLessEquals(bounds.yMax, epsilon: 0.012),
            reason: '$ch $weight yMax',
          );
        }
      }
    });
  });

  group('크기·기준선', () {
    testWidgets('글자만 있는 각인의 emSize는 같은 스타일 Text(strut 고정)의 크기와 같다', (
      tester,
    ) async {
      const style = CalcTheme.keyShiftLabelStyle;
      for (final text in ['SOLVE', 'A', '⇔']) {
        await tester.pumpWidget(
          _host(
            Text(
              text,
              style: style.copyWith(fontSize: 100),
              strutStyle: StrutStyle.fromTextStyle(
                style.copyWith(fontSize: 100),
                forceStrutHeight: true,
              ),
            ),
          ),
        );
        final size = KeyLegendView.emSize(LegendText(text), style) * 100;
        expect(
          size.width,
          moreOrLessEquals(tester.getSize(find.text(text)).width, epsilon: 0.5),
        );
        expect(
          size.height,
          moreOrLessEquals(tester.getSize(find.text(text)).height, epsilon: 1),
        );
      }
    });

    test('2차원 각인은 한 줄보다 크게 높아지지 않는다 — 가장 높아도 1.15em, 아래로는 0.07em까지', () {
      // 각인 띠는 글자 크기의 1/0.8 = 1.25em 높이다(keyLegendFontRatio). 첨자·분수가 한 줄을 크게 넘으면
      // 통일 글자 크기 계산이 모든 각인을 그만큼 줄이므로, 넘는 폭을 상한으로 묶어 둔다.
      // 아래로 넘는 만큼 기준선이 올라가므로(아래 정렬) 이웃 각인과 기준선 차이도 함께 묶는다.
      for (final (k, legend, style) in _twoDimensional()) {
        final em = KeyLegendView.emSize(legend, style);
        expect(
          em.height,
          lessThanOrEqualTo(1.15),
          reason: '${k.id.name} ${legend.plainText}',
        );
        final plain = KeyLegendView.emSize(const LegendText('x'), style);
        expect(em.height, greaterThanOrEqualTo(plain.height - 1e-9));
      }
    });

    testWidgets('기준선은 같은 글자 크기의 Text 기준선과 같고(아래로 넘치지 않는 각인), 글자 배율을 따른다', (
      tester,
    ) async {
      final legend = keyDefOf(CalcKeyId.square).mainLegend; // x²
      const style = TextStyle(
        fontFamily: CalcTheme.monoFontFamily,
        fontFamilyFallback: CalcTheme.monoFontFallback,
        fontSize: 20,
        height: 1,
        letterSpacing: 0,
      );
      for (final scale in [1.0, 1.3]) {
        await tester.pumpWidget(
          _host(
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'x',
                  style: style,
                  textScaler: TextScaler.linear(scale),
                  strutStyle: StrutStyle.fromTextStyle(
                    style,
                    forceStrutHeight: true,
                  ),
                ),
                KeyLegendView(
                  legend: legend,
                  style: style,
                  textScaler: TextScaler.linear(scale),
                ),
              ],
            ),
          ),
        );
        final view = tester.renderObject<RenderBox>(find.byType(KeyLegendView));
        final text = tester.renderObject<RenderBox>(find.text('x'));
        // 기준선 질의는 배치 밖에서 막혀 있다 — 프레임워크 테스트처럼 고유 크기 검사 중으로 표시하고 읽는다.
        double baselineOf(RenderBox box) {
          RenderObject.debugCheckingIntrinsics = true;
          try {
            return box.localToGlobal(Offset.zero).dy +
                box.getDistanceToBaseline(TextBaseline.alphabetic)!;
          } finally {
            RenderObject.debugCheckingIntrinsics = false;
          }
        }

        final viewBaseline = baselineOf(view);
        final textBaseline = baselineOf(text);
        expect(viewBaseline, moreOrLessEquals(textBaseline, epsilon: 0.01));
        expect(
          view.size.width,
          moreOrLessEquals(
            KeyLegendView.emSize(legend, style).width * 20 * scale,
            epsilon: 0.5,
          ),
          reason: '배율 $scale',
        );
      }
    });
  });

  group('그리기', () {
    testWidgets('분수는 분자·가로줄·분모, 근호는 선과 피개법수, 첨자는 글자 둘로 그린다', (tester) async {
      Future<RenderObject> draw(KeyLegend legend) async {
        await tester.pumpWidget(
          _host(
            KeyLegendView(
              legend: legend,
              style: CalcTheme.keyMainLabelStyle.copyWith(
                fontSize: 30,
                color: const Color(0xFF123456),
              ),
            ),
          ),
        );
        return tester.renderObject(find.byType(KeyLegendView));
      }

      expect(
        await draw(keyDefOf(CalcKeyId.fraction).mainLegend),
        paints
          ..paragraph()
          ..rect(color: const Color(0xFF123456))
          ..paragraph(),
      );
      expect(
        await draw(keyDefOf(CalcKeyId.sqrt).mainLegend),
        paints
          ..path(color: const Color(0xFF123456), style: PaintingStyle.stroke)
          ..paragraph(),
      );
      expect(
        await draw(keyDefOf(CalcKeyId.square).mainLegend),
        paints
          ..paragraph()
          ..paragraph(),
      );
    });

    testWidgets('색만 바뀌면 다시 배치하지 않고 다시 그린다 (눌림 애니메이션)', (tester) async {
      final legend = keyDefOf(CalcKeyId.fraction).mainLegend;
      Widget view(Color color) => _host(
        KeyLegendView(
          legend: legend,
          style: CalcTheme.keyMainLabelStyle.copyWith(
            fontSize: 30,
            color: color,
          ),
        ),
      );
      await tester.pumpWidget(view(const Color(0xFF000000)));
      final render = tester.renderObject<RenderKeyLegend>(
        find.byType(KeyLegendView),
      );
      final size = render.size;
      await tester.pumpWidget(view(const Color(0xFFFFFFFF)));
      expect(render.size, size);
      expect(render, paints..rect(color: const Color(0xFFFFFFFF)));
    });
  });

  group('키 버튼에서 (#155 체크리스트)', () {
    testWidgets('이슈 표의 모든 각인이 2차원 각인 위젯으로 그려지고 한 줄 표기 Text는 없다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 390, height: 520, child: CalcKeypad())),
      );
      for (final (k, legend, _) in _twoDimensional()) {
        expect(findLegend(legend), findsOneWidget, reason: legend.plainText);
        expect(
          find.text(legend.plainText),
          findsNothing,
          reason: '${k.id.name}: 한 줄 표기가 화면에 남았다',
        );
      }
    });

    testWidgets('스크린리더 문구는 그려진 모양과 무관하게 지금 음성 라벨 그대로다', (tester) async {
      const strings = KoSemanticStrings();
      final handle = tester.ensureSemantics();
      final ids = {for (final (k, _, _) in _twoDimensional()) k.id};
      useKoreanLocale(tester);
      for (final id in ids) {
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 80,
              height: 90,
              child: CalcKeyButton(keyDef: keyDefOf(id), onPressed: (_) {}),
            ),
          ),
        );
        final node = tester.getSemantics(find.byType(CalcKeyButton));
        expect(node.label, strings.keyButton(id), reason: id.name);
        expect(node.hint, strings.keyButtonHint(id), reason: id.name);
        // 각인 기호(칸·위첨자)를 읽지 않는다 — 각인 위젯은 의미 트리에 아무것도 더하지 않는다.
        for (final text in [node.label, node.hint]) {
          expect(
            text,
            isNot(matches(RegExp('[◼◻^²³⁻¹ˣ√∛]'))),
            reason: '${id.name}: $text',
          );
        }
      }
      handle.dispose();
    });

    for (final scale in [1.0, 1.3]) {
      for (final size in const [
        Size(320, 420),
        Size(390, 520),
        Size(600, 700),
      ]) {
        testWidgets(
          '${size.width}×${size.height} 글자 배율 $scale: 2차원 각인이 키 버튼 밖으로 나가지 않는다',
          (tester) async {
            await tester.pumpWidget(
              _host(
                SizedBox.fromSize(size: size, child: const CalcKeypad()),
                textScale: scale,
              ),
            );
            for (final (k, legend, _) in _twoDimensional()) {
              final button = find.byWidgetPredicate(
                (w) => w is CalcKeyButton && w.keyDef.id == k.id,
              );
              final rect = tester.getRect(
                find.descendant(of: button, matching: findLegend(legend)),
              );
              final bounds = tester.getRect(button).inflate(0.01);
              expect(
                bounds.contains(rect.topLeft) &&
                    bounds.contains(rect.bottomRight),
                isTrue,
                reason: '${k.id.name} ${legend.plainText}: $rect ⊄ $bounds',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
