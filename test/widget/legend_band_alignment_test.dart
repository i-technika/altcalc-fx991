import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/device_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/key_legends.dart';

/// 키캡 위 각인(SHIFT·ALPHA)의 좌우 정렬 (#265) — 규칙과 실물 측정은 [CalcTheme] "각인 띠 좌우 정렬 (#265)" 절.
///
/// - 각인이 하나면 키캡 가운데다.
/// - 둘이면 SHIFT는 왼쪽·ALPHA는 오른쪽이고, 바깥 끝을 키캡 끝에서 똑같이 들인다. 들이는 거리는 키캡 폭의
///   [CalcTheme.keyLegendSideInsetRatio]와 키캡 모서리 반경 가운데 큰 쪽까지이고, 두 각인과 최소 사이 간격을 빼고 남는 폭이
///   모자라면 남는 폭의 1/3로 줄어든다(왼쪽 여백·사이·오른쪽 여백이 똑같이 나눈다).
///
/// 실제 앱([AltCalcApp])을 번들 글꼴로 띄워 **그려진 자리(화면 좌표)** 를 잰다. 기대값은 그려진 키캡·각인 폭에서 이 파일의
/// 식([_expectedInset])으로 따로 구한다 — 구현 함수(`keyLegendPairInset`·`keyLegendSideInset`)를 부르지 않는다.

/// 화면 하나 (dp). [folds]가 있으면 폴더블 기기의 접힘선 기준 배치다.
typedef _Window = ({
  String name,
  Size size,
  Handedness handedness,
  List<Rect> folds,

  /// 그려져야 하는 키패드 배열 — 이름과 다른 배치를 재고 있지 않은지 확인한다
  KeypadArrangement arrangement,
});

const _standard = KeypadArrangement.standard;
const _wide = KeypadArrangement.wide;

const _windows = <_Window>[
  (
    name: '폰 세로 360×780',
    size: Size(360, 780),
    handedness: Handedness.right,
    folds: [],
    arrangement: _standard,
  ),
  (
    name: '작은 폰 세로 320×568 (각인이 가장 빠듯하다)',
    size: Size(320, 568),
    handedness: Handedness.right,
    folds: [],
    arrangement: _standard,
  ),
  (
    name: '폰 가로 800×360 (넓은 배열)',
    size: Size(800, 360),
    handedness: Handedness.right,
    folds: [],
    arrangement: _wide,
  ),
  (
    name: '태블릿 세로 800×1280',
    size: Size(800, 1280),
    handedness: Handedness.right,
    folds: [],
    arrangement: _standard,
  ),
  (
    name: '태블릿 가로 1280×800 (넓은 배열)',
    size: Size(1280, 800),
    handedness: Handedness.right,
    folds: [],
    arrangement: _wide,
  ),
  (
    name: '태블릿 가로 1280×800 왼손 (넓은 배열 대칭)',
    size: Size(1280, 800),
    handedness: Handedness.left,
    folds: [],
    arrangement: _wide,
  ),
  (
    name: '폴드 책 자세 750×840 (세로 접힘선)',
    size: Size(750, 840),
    handedness: Handedness.right,
    folds: [Rect.fromLTWH(375, 0, 0, 840)],
    arrangement: _standard,
  ),
  (
    name: '폴드 가로 접힘선 840×750 (넓은 배열)',
    size: Size(840, 750),
    handedness: Handedness.right,
    folds: [Rect.fromLTWH(0, 375, 840, 0)],
    arrangement: _wide,
  ),
];

/// 자리를 재는 허용 오차 (dp) — 배치 계산의 부동소수 오차와, 들이는 거리를 정할 때 쓰는 각인 폭(큰 글자 크기로 잰 비율)과
/// 그려진 폭의 차
const _tolerance = 0.05;

/// 각인 띠가 있는 키캡 키 (원형 버튼·커서 패드 제외)
final _legendKeys = [
  for (final def in allKeys)
    if (def.face == KeyFace.keycap && (def.hasShift || def.hasAlpha)) def,
];

/// 각인이 둘(SHIFT·ALPHA)인 키
final _pairKeys = [
  for (final def in _legendKeys)
    if (def.hasShift && def.hasAlpha) def,
];

Future<void> _pump(
  WidgetTester tester,
  _Window window, {
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = window.size;
  tester.view.displayFeatures = [
    for (final fold in window.folds)
      DisplayFeature(
        bounds: fold,
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      ),
  ];
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({
    HandednessNotifier.storageKey: window.handedness.storageValue,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (window.folds.isNotEmpty)
          foldableDeviceProvider.overrideWithValue(ValueNotifier(true)),
      ],
      child: const AltCalcApp(),
    ),
  );
  expect(
    tester.widget<CalcKeypad>(find.byType(CalcKeypad)).arrangement,
    window.arrangement,
    reason: '${window.name}: 재려는 배열이 아니다',
  );
}

Finder _button(CalcKeyId id) => find.byWidgetPredicate(
  (w) => w is CalcKeyButton && w.keyDef.id == id,
  description: 'CalcKeyButton(${id.name})',
);

/// [id] 키에 그려진 키캡 상자 (전역 dp)
Rect _keycap(WidgetTester tester, CalcKeyId id) =>
    tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id)));

Finder _legendFinder(CalcKeyDef def, KeyLegend legend) =>
    find.descendant(of: _button(def.id), matching: findLegend(legend));

/// [def] 키의 각인 [legend]가 그려진 상자 (전역 dp — 줄어든 각인은 줄어든 크기)
Rect _legend(WidgetTester tester, CalcKeyDef def, KeyLegend legend) {
  final finder = _legendFinder(def, legend);
  expect(finder, findsOneWidget, reason: '${def.id.name} ${legend.plainText}');
  return tester.getRect(finder);
}

/// 각인이 둘인 키 하나의 그려진 자리
typedef _Pair = ({
  CalcKeyDef def,
  Rect cap,
  Rect shift,
  Rect alpha,

  /// SHIFT 왼끝·ALPHA 오른끝을 키캡 끝에서 들인 거리 (dp)
  double left,
  double right,

  /// 두 각인 사이 (dp)
  double middle,

  /// 키캡 모서리 반경 (dp)
  double radius,

  /// SHIFT·ALPHA 사이 최소 간격 (dp)
  double gap,

  /// 각인이 줄어든 비율 (1 = 줄지 않음)
  double shiftScale,
});

_Pair _measure(WidgetTester tester, CalcKeyDef def) {
  final cap = _keycap(tester, def.id);
  final shiftFinder = _legendFinder(def, def.shiftLegend!);
  final shift = _legend(tester, def, def.shiftLegend!);
  final alpha = _legend(tester, def, def.alphaLegend!);
  final fontSize = legendStyleOf(tester, shiftFinder).fontSize!;
  return (
    def: def,
    cap: cap,
    shift: shift,
    alpha: alpha,
    left: shift.left - cap.left,
    right: cap.right - alpha.right,
    middle: alpha.left - shift.right,
    radius: keyCapCornerRadius(def.category, cap.height),
    gap: math.min(
      fontSize * CalcTheme.keyLegendGapRatio,
      cap.width * CalcTheme.keyLegendGapMaxWidthRatio,
    ),
    shiftScale: shift.height / tester.getSize(shiftFinder).height,
  );
}

/// 들이는 거리의 상한 (dp) — 키캡 폭의 비율과 모서리 반경 가운데 큰 쪽
double _sideInsetOf(_Pair p) =>
    math.max(p.cap.width * CalcTheme.keyLegendSideInsetRatio, p.radius);

/// 그려진 키캡·각인 폭에서 구한 들이는 거리의 기대값 (dp) — 남는 폭의 1/3, 상한까지
double _expectedInset(_Pair p) {
  final spare = p.cap.width - p.gap - p.shift.width - p.alpha.width;
  return math.max(0, math.min(_sideInsetOf(p), spare / 3));
}

String _describe(_Pair p) =>
    '${p.def.id.name}: 왼쪽 ${p.left.toStringAsFixed(3)} · 사이 ${p.middle.toStringAsFixed(3)} · '
    '오른쪽 ${p.right.toStringAsFixed(3)} · 키캡 폭 ${p.cap.width.toStringAsFixed(2)} · '
    '상한 ${_sideInsetOf(p).toStringAsFixed(3)}';

/// 키 버튼 하나를 [size] 상자에 띄운다 (키패드 밖 — 각인이 키캡 폭·띠 높이에 비해 큰 경우를 만든다).
/// [legendFontSize]가 없으면 키 버튼 기본값(띠 높이의 비율)이다.
Future<void> _pumpButton(
  WidgetTester tester,
  CalcKeyId id, {
  required Size size,
  double? legendFontSize,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox.fromSize(
          size: size,
          child: CalcKeyButton(
            keyDef: keyDefOf(id),
            legendFontSize: legendFontSize,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(loadBundledFonts);

  group('들이는 거리 계산', () {
    test('상한은 키캡 폭의 비율과 모서리 반경 가운데 큰 쪽이다', () {
      const ratio = CalcTheme.keyLegendSideInsetRatio;
      // 모서리가 작은 넓은 키: 폭 비율
      expect(
        keyLegendSideInset(faceWidth: 100, cornerRadius: 5),
        closeTo(100 * ratio, 1e-9),
      );
      // 모서리가 폭에 비해 큰 키: 반경 (각인 끝이 둥근 모서리 위로 나가지 않는다)
      expect(keyLegendSideInset(faceWidth: 40, cornerRadius: 6), 6);
      // 키캡 폭의 절반을 넘지 않는다
      expect(keyLegendSideInset(faceWidth: 10, cornerRadius: 12), 5);
      expect(keyLegendSideInset(faceWidth: 0, cornerRadius: 12), 0);
      expect(keyLegendSideInset(faceWidth: -3, cornerRadius: 12), 0);
    });

    test('남는 폭을 왼쪽 여백·사이·오른쪽 여백이 똑같이 나눈다 (상한까지)', () {
      double inset(double left, double right) => keyLegendPairInset(
        width: 100,
        gap: 4,
        leftWidth: left,
        rightWidth: right,
        sideInset: 9,
      );
      // 넉넉하면 상한 — 나머지는 사이가 가져간다
      expect(inset(30, 10), 9);
      expect(inset(50, 19), 9); // 남는 폭 27 = 상한의 세 배
      // 빠듯하면 남는 폭의 1/3 (양쪽 똑같이, 사이도 그만큼 더 넓다)
      expect(inset(60, 21), 5);
      expect(inset(60, 33), 1);
      // 들어가지 않으면 들이지 않는다 (키캡 폭을 다 쓰고, 그래도 넘치면 각인 줄이 줄인다)
      expect(inset(70, 26), 0);
      expect(inset(90, 40), 0);
    });
  });

  group('각인 쌍이 키캡 폭에 비해 길 때 (키 버튼 하나, SOLVE · =)', () {
    const size = Size(60, 60);
    final def = keyDefOf(CalcKeyId.calc);

    testWidgets('넉넉하면 상한까지 들인다', (tester) async {
      await _pumpButton(tester, def.id, size: size, legendFontSize: 6);
      final p = _measure(tester, def);
      expect(_sideInsetOf(p), greaterThan(0));
      expect(
        p.left,
        closeTo(_sideInsetOf(p), _tolerance),
        reason: _describe(p),
      );
      expect(
        p.right,
        closeTo(_sideInsetOf(p), _tolerance),
        reason: _describe(p),
      );
      expect(p.shiftScale, closeTo(1, 1e-6));
    });

    testWidgets('빠듯하면 들이는 거리를 양쪽 똑같이 줄이되 두 각인이 붙지 않고, 각인은 줄이지 않는다', (
      tester,
    ) async {
      // 실물 `SOLVE =`·`INS UNDO`처럼 각인이 키캡 폭을 거의 다 쓰는 경우
      await _pumpButton(tester, def.id, size: size, legendFontSize: 12);
      final p = _measure(tester, def);
      expect(p.left, greaterThan(_tolerance), reason: _describe(p));
      expect(
        p.left,
        lessThan(_sideInsetOf(p) - _tolerance),
        reason: _describe(p),
      );
      expect(p.left, closeTo(_expectedInset(p), _tolerance));
      expect(p.right, closeTo(p.left, 2 * _tolerance), reason: _describe(p));
      // 사이는 최소 간격에 들이는 거리만큼 더 넓다
      expect(p.middle, closeTo(p.gap + p.left, 3 * _tolerance));
      // 줄어도 폭 비례 배분의 반올림(1/1000)만큼이다
      expect(p.shiftScale, closeTo(1, 2e-3));
    });

    testWidgets('들어가지 않으면 들이지 않고 키캡 폭을 다 쓴 뒤 각인이 줄어든다', (tester) async {
      await _pumpButton(tester, def.id, size: size, legendFontSize: 24);
      final p = _measure(tester, def);
      expect(p.left, closeTo(0, _tolerance), reason: _describe(p));
      expect(p.right, closeTo(0, _tolerance), reason: _describe(p));
      expect(p.shiftScale, lessThan(0.9));
    });

    testWidgets('띠 높이 때문에 줄어든 각인은 줄어든 폭으로 들인다 (글자 크기를 주입받지 않은 키 버튼)', (
      tester,
    ) async {
      // sin⁻¹ · D: 글자 크기가 띠 높이보다 커서 각인이 높이에 맞춰 줄어든다 — 줄기 전 폭으로 재면 들일 자리가 없다고 본다
      final sin = keyDefOf(CalcKeyId.sin);
      await _pumpButton(tester, sin.id, size: size, legendFontSize: 20);
      final p = _measure(tester, sin);
      expect(p.shiftScale, lessThan(0.9), reason: '각인이 높이 때문에 줄어야 한다');
      // 줄어든(그려진) 폭에서 구한 기대값만큼 들인다 — 줄기 전 폭으로 재면 0.25dp쯤이다(#265 R1)
      expect(p.left, greaterThan(2), reason: _describe(p));
      expect(p.left, closeTo(_expectedInset(p), 0.3), reason: _describe(p));
      expect(p.right, closeTo(p.left, 0.3), reason: _describe(p));
    });
  });

  for (final window in _windows) {
    group(window.name, () {
      testWidgets('각인이 하나뿐인 키: 키캡 가운데', (tester) async {
        await _pump(tester, window);
        // `x³`·`◼√◻`·`10^◼`·`e^◼`도 지금은 각인이 하나라 가운데다. 실물에서는 파란 Base-N 각인(`DEC`…)과 짝이라 왼쪽에
        // 있다 — 파란 각인을 그리면(#266) 이 넷은 "각인이 하나뿐인 키"가 아니게 된다.
        final singles = _legendKeys.where((d) => d.hasShift != d.hasAlpha);
        // 실물에서 가운데인 각인이 빠지지 않았는지 (목록이 비면 아래 검사가 헛돈다)
        expect(
          singles.map((d) => (d.shiftLabel ?? d.alphaLabel)!),
          containsAll([
            'QR',
            'RECALL',
            'Abs',
            'CONST',
            'CONV',
            'RESET',
            'nPr',
            'nCr',
            'Pol',
            'Rec',
            'Rnd',
            '%',
            '≈',
          ]),
        );
        for (final def in singles) {
          final cap = _keycap(tester, def.id);
          final legend = _legend(
            tester,
            def,
            (def.shiftLegend ?? def.alphaLegend)!,
          );
          expect(
            legend.center.dx,
            closeTo(cap.center.dx, _tolerance),
            reason: '${def.id.name} ${legend.left}~${legend.right} · 키캡 $cap',
          );
          // 키캡 폭 안에 있다
          expect(legend.left, greaterThanOrEqualTo(cap.left - _tolerance));
          expect(legend.right, lessThanOrEqualTo(cap.right + _tolerance));
        }
      });

      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '각인이 둘인 키 (글자 배율 $textScale): SHIFT 왼쪽·ALPHA 오른쪽, 바깥 끝을 똑같이 들이고 사이가 더 넓다',
          (tester) async {
            await _pump(tester, window, textScale: textScale);
            expect(_pairKeys, isNotEmpty);
            for (final def in _pairKeys) {
              final p = _measure(tester, def);
              final reason = _describe(p);
              // 양쪽 똑같이, 그려진 폭에서 구한 기대값만큼
              expect(p.left, closeTo(p.right, 2 * _tolerance), reason: reason);
              expect(
                p.left,
                closeTo(_expectedInset(p), _tolerance),
                reason: reason,
              );
              // 상한(모서리 반경·폭 비율 가운데 큰 쪽)을 넘지 않고, 키캡 밖으로 나가지 않는다
              expect(
                p.left,
                lessThanOrEqualTo(_sideInsetOf(p) + _tolerance),
                reason: reason,
              );
              expect(p.left, greaterThanOrEqualTo(-_tolerance), reason: reason);
              // SHIFT가 ALPHA 왼쪽이고, 사이는 최소 간격에 들인 거리만큼 더 넓다 (바깥을 들이느라 붙지 않는다)
              expect(
                p.middle,
                greaterThanOrEqualTo(p.gap + p.left - 3 * _tolerance),
                reason: reason,
              );
            }
          },
        );
      }

      testWidgets('실물에서 바깥 끝이 들어와 있는 쌍은 둥근 모서리 안쪽까지 들인다', (tester) async {
        await _pump(tester, window);
        // 실물에서 바깥 끝이 키캡 폭의 0.08~0.12만큼 들어와 있는 쌍 (CalcTheme "각인 띠 좌우 정렬 (#265)" 절)
        for (final id in [
          CalcKeyId.negative, // log · A
          CalcKeyId.reciprocal, // x! · C
          CalcKeyId.parenClose, // , · x
          CalcKeyId.mPlus, // M− · M
          CalcKeyId.exp10, // π · e
        ]) {
          final p = _measure(tester, keyDefOf(id));
          final reason = _describe(p);
          // 화면에서 잰 자리가 키캡 윗변의 곧은 구간(모서리 반경 안쪽)이다
          expect(
            p.left,
            greaterThanOrEqualTo(p.radius - _tolerance),
            reason: reason,
          );
          expect(
            p.right,
            greaterThanOrEqualTo(p.radius - _tolerance),
            reason: reason,
          );
          // 키캡 폭에 대한 비율: 실물 0.08~0.10, 반경이 큰 함수부 키는 0.12까지 (같은 절)
          expect(
            p.left / p.cap.width,
            inInclusiveRange(0.085, 0.125),
            reason: reason,
          );
          expect(
            p.right / p.cap.width,
            inInclusiveRange(0.085, 0.125),
            reason: reason,
          );
        }
      });
    });
  }

  group('글자 배율 1.3에서도 들인다', () {
    // 옛 배치(양 끝에 붙임)는 들인 거리가 0이다 — 배율을 키워도 대표 키는 상한까지, 가장 긴 쌍은 그보다 덜 들인다
    testWidgets('폰 세로 360×780: log · A와 M− · M은 상한까지, Ran# · RanInt는 그보다 덜', (
      tester,
    ) async {
      await _pump(tester, _windows.first, textScale: 1.3);
      for (final id in [CalcKeyId.negative, CalcKeyId.mPlus]) {
        final p = _measure(tester, keyDefOf(id));
        expect(p.left, greaterThan(1), reason: _describe(p));
        expect(
          p.left,
          closeTo(_sideInsetOf(p), _tolerance),
          reason: _describe(p),
        );
      }
      final dot = _measure(tester, keyDefOf(CalcKeyId.dot));
      expect(dot.left, greaterThanOrEqualTo(-_tolerance));
      expect(
        dot.left,
        lessThan(_sideInsetOf(dot) - _tolerance),
        reason: _describe(dot),
      );
    });
  });
}
