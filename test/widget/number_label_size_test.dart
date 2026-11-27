import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/key_legend_view.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bundled_fonts.dart';
import '../support/ttf_cmap.dart';

/// 숫자부 메인 각인 크기 (#225, [CalcTheme] "숫자부 메인 각인 크기 (#225)" 절):
/// - 숫자는 숫자부 키캡 높이의 비율이고, 두 구역의 글자/키캡 비가 실물의 같은 배수다.
/// - 글자 각인(DEL·AC·Ans·×10ˣ)은 숫자의 0.83배, 연산 기호(× ÷ + − =)는 Noto Sans Mono Medium을 숫자의 1.41배로 그리고, 잉크 가운데를 숫자에 맞춰
///   내려 그린다.
/// - 글자 배율 1.0·1.3·2.0에서 숫자부 각인은 따로 줄지 않는다.

// 실물 키패드 근접 사진에서 잰 값 (CalcTheme "숫자부 메인 각인 크기" 절)
const _photoDigitPerNumberCap = 0.57;
const _photoUpperPerFunctionCap = 0.48;

/// 근접 사진의 연산 기호 잉크 크기 (px) — (높이, 폭). `−`·`=`의 높이는 획 두께·줄 간격이라 배율 계산에 넣지 않는다.
const _photoOperatorInkPx = <String, (double?, double)>{
  '×': (41, 39),
  '÷': (43, 43),
  '+': (43, 41),
  '−': (null, 42),
  '=': (null, 43),
};

/// 근접 사진의 윗변이 평평한 숫자(1·4·7) 높이 (px) — Saira '4'(평평한 윗변)와 짝짓는다
const _photoFlatDigitPx = 45.0;

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

Finder _mainText(CalcKeyId id) =>
    find.descendant(of: _keycap(id), matching: find.byType(Text));

Future<void> _pumpScreen(
  WidgetTester tester,
  Size size,
  EdgeInsets padding, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
}

Future<void> _pumpKeypad(
  WidgetTester tester,
  Size size,
  KeypadArrangement arrangement, {
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CalcKeypad(arrangement: arrangement),
          ),
        ),
      ),
    ),
  );
}

KeypadMetrics _drawnMetrics(WidgetTester tester, double textScale) {
  final keypad = tester.widget<CalcKeypad>(find.byType(CalcKeypad));
  return KeypadMetrics.compute(
    tester.getSize(find.byKey(const ValueKey('calc-keypad'))),
    TextScaler.linear(textScale),
    arrangement: keypad.arrangement,
  );
}

/// 글리프 가운데 높이 (em, 기준선 위)
double _inkCenter(ByteData font, String ch) {
  final y = readGlyphYBounds(font, ch.runes.single)!;
  return (y.yMin + y.yMax) / 2;
}

/// 연산 기호 [operator]의 잉크 가운데 높이가 같은 행 숫자 [digit]의 잉크 가운데와 0.25dp 안인지 본다 (#225).
///
/// 내리는 거리는 기호·숫자의 대표 잉크 가운데(0.35·0.346em)로 정했으므로 글리프마다(기호 0.346~0.3535em, 숫자
/// 0.344~0.348em) 조금 남는다. 기호가 키캡 높이에 묶인 창은 숫자가 기호 ÷ 배율보다 커서 약 0.1dp 더 어긋난다.
/// 줄 상자 높이는 글자 크기를 정수로 반올림한 값이라(TextPainter) 가운데 정렬한 라벨은 글자 크기마다 0.25dp 이하
/// 오르내린다 — 크기가 다른 모든 각인에 공통인 반올림이므로 그 몫은 빼고(줄 상자 높이를 글자 크기로 보고) 비교한다.
void _expectOperatorInkAlignedWithDigit(
  WidgetTester tester, {
  required CalcKeyDef operator,
  required CalcKeyDef digit,
  required ByteData operatorFont,
  required ByteData digitFont,
  required double effectiveScale,
  required String reason,
}) {
  double inkCenterY(CalcKeyDef def, ByteData font) {
    final ch = def.mainLabel;
    final finder = _mainText(def.id);
    final text = tester.widget<Text>(finder);
    final fontSize = text.style!.fontSize! * effectiveScale;
    // 그린 Text와 같은 스타일·줄 상자로 기준선을 잰다
    final painter = TextPainter(
      text: TextSpan(text: ch, style: text.style),
      strutStyle: text.strutStyle,
      textScaler: text.textScaler!,
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final rounding = (painter.height - fontSize) / 2;
    painter.dispose();
    return tester.getRect(finder).top +
        rounding +
        baseline -
        _inkCenter(font, ch) * fontSize;
  }

  expect(
    inkCenterY(operator, operatorFont),
    closeTo(inkCenterY(digit, digitFont), 0.25),
    reason: reason,
  );
}

void main() {
  setUpAll(loadBundledFonts);

  late ByteData saira;
  late ByteData monoMedium;
  setUpAll(() async {
    saira = await rootBundle.load('assets/fonts/Saira-SemiBold.ttf');
    monoMedium = await rootBundle.load('assets/fonts/NotoSansMono-Medium.ttf');
  });

  group('실물 대조 (#225)', () {
    test('연산 기호 배율은 근접 사진 / Noto Sans Mono Medium의 기호·숫자 비 여덟 값의 평균이고, 글리프마다 5% 안이다', () {
      // 숫자는 같은 모양끼리 짝짓는다 — 사진의 평평한 숫자(45px)와 Saira '4'(0.688em)
      final digit = readGlyphYBounds(saira, '4'.runes.single)!;
      final digitHeight = digit.yMax - digit.yMin;
      final ratios = <String, double>{};
      for (final MapEntry(key: ch, value: (photoHeight, photoWidth))
          in _photoOperatorInkPx.entries) {
        final y = readGlyphYBounds(monoMedium, ch.runes.single)!;
        final x = readGlyphXBounds(monoMedium, ch.runes.single)!;
        ratios['$ch 폭'] =
            photoWidth / _photoFlatDigitPx / ((x.xMax - x.xMin) / digitHeight);
        if (photoHeight != null) {
          ratios['$ch 높이'] =
              photoHeight /
              _photoFlatDigitPx /
              ((y.yMax - y.yMin) / digitHeight);
        }
      }
      expect(ratios, hasLength(8));
      final mean = ratios.values.reduce((a, b) => a + b) / ratios.length;
      expect(
        CalcTheme.keyNumberOperatorLabelScale,
        closeTo(mean, 0.01),
        reason: '$ratios',
      );
      for (final MapEntry(:key, :value) in ratios.entries) {
        expect(
          value / CalcTheme.keyNumberOperatorLabelScale,
          closeTo(1.0, 0.05),
          reason: key,
        );
      }
    });

    test('실물 크기 키패드(480×640)의 숫자 글자를 올림한 값이 숫자 상한이다 (함수부 상한 16.5와 같은 기준)', () {
      final m = KeypadMetrics.compute(
        const Size(480, 640),
        TextScaler.noScaling,
      );
      expect(
        m.mainLabelFontSize,
        closeTo(CalcTheme.keyMainLabelMaxFontSize, 0.1),
      );
      expect(
        m.numberMainLabelFontSize,
        inInclusiveRange(
          CalcTheme.keyNumberMainLabelMaxFontSize - 0.1,
          CalcTheme.keyNumberMainLabelMaxFontSize,
        ),
      );
    });
  });

  testWidgets(
    '줄 상자 기준선 비(CalcTheme.keyStrutBaselineRatio)가 실제 각인 배치와 같다 — 연산 기호를 내리는 거리의 전제',
    (tester) async {
      for (final base in [
        CalcTheme.keyMainLabelStyle,
        CalcTheme.keyNumberOperatorLabelStyle,
      ]) {
        final style = base.copyWith(fontSize: 100);
        final painter = TextPainter(
          text: TextSpan(text: '7', style: style),
          strutStyle: keyLabelStrut(style),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(
          painter.computeDistanceToActualBaseline(TextBaseline.alphabetic) /
              100,
          closeTo(CalcTheme.keyStrutBaselineRatio, 1e-4),
        );
        painter.dispose();
      }
    },
  );

  group('화면의 숫자부 각인 (#225)', () {
    // (창, 인셋) — 폰·작은 폰·21:9 폰·태블릿 세로·iPad·가로형·Fold 내부·짧은 창·초광폭
    const cases = [
      (Size(360, 800), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(320, 568), EdgeInsets.only(top: 20)),
      (Size(412, 915), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(800, 1280), EdgeInsets.only(top: 24, bottom: 48)),
      (Size(1024, 1366), EdgeInsets.only(top: 24, bottom: 20)),
      (Size(800, 360), EdgeInsets.only(top: 24)),
      (Size(841, 701), EdgeInsets.only(top: 24, bottom: 32)),
      (Size(360, 520), EdgeInsets.only(top: 24)),
      (Size(2000, 400), EdgeInsets.zero),
    ];

    for (final (size, padding) in cases) {
      testWidgets('$size·글자 배율 1.0: 숫자 / 숫자 키캡과 함수부 대문자 / 함수 키캡이 실물의 같은 배수다', (
        tester,
      ) async {
        await _pumpScreen(tester, size, padding);
        final m = _drawnMetrics(tester, 1.0);
        // 상한에 걸린 큰 키(태블릿)는 글자가 실물 크기 키패드에서 멈추므로 비를 보지 않는다
        if (m.mainLabelFontSize >= CalcTheme.keyMainLabelMaxFontSize - 1e-6) {
          expect(
            m.numberMainLabelFontSize,
            CalcTheme.keyNumberMainLabelMaxFontSize,
          );
          return;
        }
        final digitInk = readGlyphYBounds(saira, '7'.runes.single)!.yMax;
        final upperInk = readGlyphYBounds(saira, 'E'.runes.single)!.yMax;
        final numberCap = tester.getSize(_keycap(CalcKeyId.num7)).height;
        final functionCap = tester.getSize(_keycap(CalcKeyId.calc)).height;
        final number =
            m.numberMainLabelFontSize *
            digitInk /
            numberCap /
            _photoDigitPerNumberCap;
        final function =
            m.mainLabelFontSize *
            upperInk /
            functionCap /
            _photoUpperPerFunctionCap;
        expect(
          number / function,
          closeTo(1.0, 0.04),
          reason: '$number / $function',
        );
      });

      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          '$size·글자 배율 $scale: 숫자부 각인이 종류별 크기로 따로 줄지 않고 그려지고, 연산 기호는 숫자와 같은 높이에 놓인다',
          (tester) async {
            await _pumpScreen(tester, size, padding, textScale: scale);
            final m = _drawnMetrics(tester, scale);
            final effective = scale.clamp(1.0, CalcTheme.keyMaxTextScaleFactor);
            for (final row in numberRows) {
              for (final def in row) {
                final reason = '${def.id.name} ($size, $scale)';
                final kind = KeypadMetrics.numberLabelKindOf(def)!;
                final button = tester.widget<CalcKeyButton>(
                  find.byWidgetPredicate(
                    (w) => w is CalcKeyButton && w.keyDef.id == def.id,
                  ),
                );
                expect(
                  button.mainLabelFontSize,
                  m.mainLabelFontSizeOf(def),
                  reason: reason,
                );
                // 넘치지 않는다 — FittedBox가 줄이지 않았다(그린 크기 = 배치 크기)
                final fitted = find
                    .descendant(
                      of: _keycap(def.id),
                      matching: find.byType(FittedBox),
                    )
                    .first;
                final render = tester.renderObject<RenderFittedBox>(fitted);
                expect(
                  render.child!.size.width,
                  lessThanOrEqualTo(render.size.width + 0.01),
                  reason: reason,
                );
                expect(
                  render.child!.size.height,
                  lessThanOrEqualTo(render.size.height + 0.01),
                  reason: reason,
                );
                final cap = tester.getRect(_keycap(def.id));
                // 연산 기호는 내려 그린 뒤의 위치(Transform 아래 글자 — 2차원 각인 ×10ˣ는 각인 위젯)로 본다
                final label = tester.getRect(
                  find
                      .descendant(
                        of: fitted,
                        matching: find.byWidgetPredicate(
                          (w) => w is RichText || w is KeyLegendView,
                        ),
                      )
                      .first,
                );
                expect(cap.contains(label.topLeft), isTrue, reason: reason);
                expect(cap.contains(label.bottomRight), isTrue, reason: reason);
                if (kind != NumberLabelKind.operator) continue;

                // 연산 기호: Noto Sans Mono Medium으로 숫자의 배율 크기 — 키캡 높이가 모자란 창은 줄이되 숫자보다 작지 않다
                final text = tester.widget<Text>(_mainText(def.id));
                expect(
                  text.style!.fontFamily,
                  CalcTheme.monoFontFamily,
                  reason: reason,
                );
                expect(text.style!.fontWeight, FontWeight.w500, reason: reason);
                expect(
                  m.numberOperatorLabelFontSize,
                  greaterThanOrEqualTo(m.numberMainLabelFontSize),
                  reason: reason,
                );
                // 잉크 가운데 높이가 같은 행 숫자(행 첫 키)의 잉크 가운데와 0.25dp 안이다 (내려 그리지 않으면 0.5~1.1dp)
                _expectOperatorInkAlignedWithDigit(
                  tester,
                  operator: def,
                  digit: row.first,
                  operatorFont: monoMedium,
                  digitFont: saira,
                  effectiveScale: effective,
                  reason: reason,
                );
              }
            }
          },
        );
      }
    }

    // 실물 배열의 작은 키패드·넓은 배열의 낮은 키패드(접힘선 기준 배치·짧은 가로 창) — 연산 기호가 키캡 높이에 묶이는 곳
    for (final (size, arrangement) in const [
      (Size(240, 320), KeypadArrangement.standard),
      (Size(320, 103.6), KeypadArrangement.wide),
      (Size(400, 129.4), KeypadArrangement.wide),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '키패드 $size(${arrangement.name})·글자 배율 $scale: 숫자부 각인이 따로 줄지 않고, 숫자는 폭에 묶이지 않는다',
          (tester) async {
            await _pumpKeypad(tester, size, arrangement, textScale: scale);
            final m = KeypadMetrics.compute(
              size,
              TextScaler.linear(scale),
              arrangement: arrangement,
            );
            // 숫자는 키캡 높이 목표 그대로다(폭 기준·높이 기준 어느 쪽에도 묶이지 않는다)
            expect(
              m.numberMainLabelFontSize,
              closeTo(
                m.numberCapHeight * CalcTheme.keyNumberMainLabelFontRatio,
                1e-6,
              ),
            );
            expect(
              m.numberOperatorLabelFontSize,
              greaterThanOrEqualTo(m.numberMainLabelFontSize),
            );
            for (final row in numberRows) {
              for (final def in row) {
                final fitted = find
                    .descendant(
                      of: _keycap(def.id),
                      matching: find.byType(FittedBox),
                    )
                    .first;
                final render = tester.renderObject<RenderFittedBox>(fitted);
                final reason = def.id.name;
                expect(
                  render.child!.size.width,
                  lessThanOrEqualTo(render.size.width + 0.01),
                  reason: reason,
                );
                expect(
                  render.child!.size.height,
                  lessThanOrEqualTo(render.size.height + 0.01),
                  reason: reason,
                );
                if (KeypadMetrics.numberLabelKindOf(def) ==
                    NumberLabelKind.operator) {
                  _expectOperatorInkAlignedWithDigit(
                    tester,
                    operator: def,
                    digit: row.first,
                    operatorFont: monoMedium,
                    digitFont: saira,
                    effectiveScale: scale,
                    reason: reason,
                  );
                }
              }
            }
          },
        );
      }
    }

    // CalcTheme "숫자부 메인 각인 크기" 절 4 — 키캡 폭 하한을 풀지 않는 근거: 함수부 글자가 키캡 폭에 가장 많이 묶이는
    // 넓은 배열의 낮은 키패드에서도 배율 1.3의 글자가 배율 1.0보다 1.14배 이상 크다
    for (final size in const [Size(320, 103.6), Size(400, 129.4)]) {
      test('키패드 $size(wide): 배율 1.3의 함수부 메인 글자가 배율 1.0의 1.14배 이상이다', () {
        KeypadMetrics at(double scale) => KeypadMetrics.compute(
          size,
          TextScaler.linear(scale),
          arrangement: KeypadArrangement.wide,
        );
        final ratio =
            at(1.3).mainLabelFontSize * 1.3 / at(1.0).mainLabelFontSize;
        expect(ratio, greaterThanOrEqualTo(1.14));
        // 키캡 폭에 실제로 묶인다 — 묶이지 않으면 이 근거가 필요 없다
        expect(ratio, lessThan(1.3));
      });
    }
  });
}
