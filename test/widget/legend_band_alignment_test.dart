import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/device_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/release_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/key_legends.dart';

/// 키캡 위 각인(SHIFT·ALPHA·모드 전용 각인)의 좌우 정렬 (#265, 모드 전용 각인은 #266) — 규칙과 실물 측정은 [CalcTheme]
/// "각인 띠 좌우 정렬 (#265)" 절. 각인 목록은 [CalcKeyDef.bandLegendsIn]이다(왼쪽부터).
///
/// 배포 목록(#267): 대부분의 검사는 실물 인쇄 전체([allKeyFeatures] — Base-N의 파랑 각인과 괄호, `QR`까지)를 그려 놓고
/// 잰다. 그래야 배포 전이라 숨긴 각인의 배치도 계속 검사된다. 지금 배포 목록([releasedKeyFeatures], v1.0)의 화면은 창마다
/// "v1.0 배포 목록" 검사가 따로 본다. 띄운 화면의 배포 목록은 [_released]에 둔다([_pump]·[_pumpButton]이 정한다).
///
/// - 각인이 하나면 키캡 가운데다.
/// - 둘이면 첫째(SHIFT)는 왼쪽·둘째(ALPHA 또는 모드 색 각인)는 오른쪽이고, 바깥 끝을 키캡 끝에서 똑같이 들인다. 들이는 거리는 키캡 폭의
///   [CalcTheme.keyLegendSideInsetRatio]와 키캡 모서리 반경 가운데 큰 쪽까지이고, 두 각인 사이가 최소 간격·들이는 거리보다
///   좁아지지 않는 만큼만 들인다([_expectedInset]). 키캡 폭에 들어가지 않는 쌍은 키캡 가운데에 둔 채 양옆으로 셀 폭까지
///   나간다(#264 — 들인 거리가 음수다).
/// - 셋이면(ENG 키의 `┌∠┐ ← i`) 첫째는 왼쪽 끝·마지막은 오른쪽 끝이고 사이를 똑같이 띄운다([_expectedTripleInset]).
/// - 괄호로 둘러싼 각인(`┌∠┐`·`┌A┐`)은 괄호까지가 그 각인이다 — 바깥 끝은 괄호의 바깥 끝이다([_bandRect]).
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

/// 지금 띄운 화면의 배포 목록 (#267) — [_pump]·[_pumpButton]이 정한다. 테스트마다 실물 인쇄 전체로 되돌린다(`setUp`).
Set<KeyFeature> _released = allKeyFeatures;

/// v1.0의 배포 목록 — 상수 [releasedKeyFeatures]와 따로 적는다(버전을 올려도 "v1.0" 검사는 그대로 돈다)
const _v10 = {KeyFeature.complex};

/// [def] 키의 각인 띠에 그려진 각인 (지금 띄운 화면의 배포 목록 기준)
List<BandLegend> _band(CalcKeyDef def) => def.bandLegendsIn(_released);

/// 각인 띠가 있는 키캡 키 (원형 버튼·커서 패드 제외)
List<CalcKeyDef> get _legendKeys => [
  for (final def in allKeys)
    if (def.face == KeyFace.keycap && _band(def).isNotEmpty) def,
];

/// 각인이 둘(SHIFT·ALPHA 또는 SHIFT·모드 색 각인)인 키
List<CalcKeyDef> get _pairKeys => [
  for (final def in _legendKeys)
    if (_band(def).length == 2) def,
];

Future<void> _pump(
  WidgetTester tester,
  _Window window, {
  double textScale = 1.0,
  Set<KeyFeature> released = allKeyFeatures,
}) async {
  _released = released;
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
        releasedKeyFeaturesProvider.overrideWithValue(released),
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

/// [def] 키의 각인 띠 각인 [item]이 차지한 상자 (전역 dp) — 괄호로 둘러싼 각인은 괄호까지다(#266)
Rect _bandRect(WidgetTester tester, CalcKeyDef def, BandLegend item) {
  final label = _legendFinder(def, item.legend);
  expect(label, findsOneWidget, reason: '${def.id.name} $item');
  final brackets = find.ancestor(
    of: label,
    matching: find.byType(LegendBrackets),
  );
  expect(
    brackets,
    item.bracketed ? findsOneWidget : findsNothing,
    reason: '${def.id.name} $item',
  );
  return tester.getRect(item.bracketed ? brackets : label);
}

/// 각인이 둘인 키 하나의 그려진 자리
typedef _Pair = ({
  CalcKeyDef def,
  Rect cap,

  /// 키 버튼(셀) 상자
  Rect cell,

  /// 왼쪽(첫째)·오른쪽(둘째) 각인 상자 — 괄호 포함
  Rect first,
  Rect last,

  /// 첫째 왼끝·둘째 오른끝을 키캡 끝에서 들인 거리 (dp)
  double left,
  double right,

  /// 두 각인 사이 (dp)
  double middle,

  /// 키캡 모서리 반경 (dp)
  double radius,

  /// 두 각인 사이 최소 간격 (dp)
  double gap,

  /// 첫째 각인이 줄어든 비율 (1 = 줄지 않음)
  double firstScale,
});

/// 각인 사이 최소 간격 (dp) — 글자 크기의 비율이되 키캡 폭의 비율을 넘지 않는다
double _gapOf(WidgetTester tester, Finder legend, Rect cap) => math.min(
  legendStyleOf(tester, legend).fontSize! * CalcTheme.keyLegendGapRatio,
  cap.width * CalcTheme.keyLegendGapMaxWidthRatio,
);

_Pair _measure(WidgetTester tester, CalcKeyDef def) {
  final band = _band(def);
  expect(band, hasLength(2), reason: def.id.name);
  final cap = _keycap(tester, def.id);
  final firstFinder = _legendFinder(def, band.first.legend);
  final first = _bandRect(tester, def, band.first);
  final last = _bandRect(tester, def, band.last);
  return (
    def: def,
    cap: cap,
    cell: tester.getRect(_button(def.id)),
    first: first,
    last: last,
    left: first.left - cap.left,
    right: cap.right - last.right,
    middle: last.left - first.right,
    radius: keyCapCornerRadius(def.category, cap.height),
    gap: _gapOf(tester, firstFinder, cap),
    firstScale:
        tester.getRect(firstFinder).height / tester.getSize(firstFinder).height,
  );
}

/// 들이는 거리의 상한 (dp) — 키캡 폭의 비율과 모서리 반경 가운데 큰 쪽
double _sideInsetOf(_Pair p) => _sideInsetFor(p.cap, p.radius);

double _sideInsetFor(Rect cap, double radius) =>
    math.max(cap.width * CalcTheme.keyLegendSideInsetRatio, radius);

/// 각인이 셋인 키(ENG)의 들이는 거리 기대값 (dp, #266) — 사이가 둘이라 사이 하나(`최소 간격 + (남는 폭 − 2 × 들이는 거리) ÷ 2`)가
/// 최소 간격보다도(남는 폭 ÷ 2) 들이는 거리보다도((남는 폭 + 최소 간격 × 2) ÷ 4) 좁아지지 않는 만큼 상한까지 들인다.
/// 키캡 폭에 들어가지 않으면 양옆으로 똑같이 나가되 셀 끝을 넘지 않는다.
double _expectedTripleInset({
  required Rect cap,
  required Rect cell,
  required double radius,
  required double gap,
  required double total,
}) {
  final spare = cap.width - 2 * gap - total;
  final margin = math.max(0.0, (cell.width - cap.width) / 2);
  if (spare < 0) return math.max(-margin, spare / 2);
  return [
    _sideInsetFor(cap, radius),
    spare / 2,
    (spare + 2 * gap) / 4,
  ].reduce(math.min);
}

/// 그려진 키캡·각인 폭에서 구한 들이는 거리의 기대값 (dp) — 상한까지 들이되, 두 각인 사이가 최소 간격보다도(남는 폭 ÷ 2)
/// 들이는 거리보다도((남는 폭 + 최소 간격) ÷ 3) 좁아지지 않는 만큼. 키캡 폭에 들어가지 않으면 음수다 — 키캡 양옆으로 똑같이
/// 나가되(남는 폭 ÷ 2) 셀 끝을 넘지 않는다(#264).
double _expectedInset(_Pair p) {
  final spare = p.cap.width - p.gap - p.first.width - p.last.width;
  if (spare < 0) return math.max(-_faceMarginOf(p), spare / 2);
  return [_sideInsetOf(p), spare / 2, (spare + p.gap) / 3].reduce(math.min);
}

/// 키캡 옆 여백 (dp) — 셀 폭과 그린 키캡 폭의 차의 절반
double _faceMarginOf(_Pair p) => math.max(0, (p.cell.width - p.cap.width) / 2);

String _describe(_Pair p) =>
    '${p.def.id.name}: 왼쪽 ${p.left.toStringAsFixed(3)} · 사이 ${p.middle.toStringAsFixed(3)} · '
    '오른쪽 ${p.right.toStringAsFixed(3)} · 키캡 폭 ${p.cap.width.toStringAsFixed(2)} · '
    '상한 ${_sideInsetOf(p).toStringAsFixed(3)}';

/// 키 버튼 하나를 [size] 상자에 띄운다 (키패드 밖 — 각인이 키캡 폭·띠 높이에 비해 큰 경우를 만든다).
/// [legendFontSize]가 없으면 키 버튼 기본값(띠 높이의 비율)이다. 실물 인쇄 전체를 그린다(괄호가 든 쌍 `sin⁻¹ ┌D┐` 포함).
Future<void> _pumpButton(
  WidgetTester tester,
  CalcKeyId id, {
  required Size size,
  double? legendFontSize,
}) {
  _released = allKeyFeatures;
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox.fromSize(
            size: size,
            child: CalcKeyButton(
              keyDef: keyDefOf(id),
              legendFontSize: legendFontSize,
              releasedFeatures: allKeyFeatures,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadBundledFonts);
  // 앞 테스트가 띄운 화면의 배포 목록이 넘어오지 않게 한다
  setUp(() => _released = allKeyFeatures);

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

    test('두 묶음 사이가 최소 간격·들이는 거리보다 좁아지지 않는 만큼만 들인다 (상한까지)', () {
      const gap = 4.0;
      double inset(double left, double right) => keyLegendPairInset(
        width: 100,
        gap: gap,
        leftWidth: left,
        rightWidth: right,
        sideInset: 9,
      );
      // 들인 뒤 두 묶음 사이
      double middle(double left, double right) =>
          100 - left - right - 2 * inset(left, right);

      // 넉넉하면 상한 — 나머지는 사이가 가져간다
      expect(inset(30, 10), 9);
      expect(inset(50, 23), 9); // 남는 폭 23: (23 + 4) ÷ 3 = 상한
      // 빠듯하면 사이가 들이는 거리와 같아질 때까지만 — (남는 폭 + 간격) ÷ 3
      expect(inset(60, 25), 5); // 남는 폭 11
      expect(middle(60, 25), 5);
      expect(inset(60, 27), closeTo(13 / 3, 1e-9)); // 남는 폭 9
      // 남는 폭이 간격의 두 배보다 작으면 남는 폭의 절반 — 사이는 최소 간격 그대로다
      expect(inset(60, 34), 1); // 남는 폭 2
      expect(middle(60, 34), gap);
      // 들어가지 않으면 들이지 않는다 (키캡 폭을 다 쓰고, 그래도 넘치면 각인 줄이 줄인다)
      expect(inset(60, 36), 0);
      expect(inset(70, 30), 0);
      expect(inset(90, 40), 0);
      // 어느 경우에도 사이는 최소 간격·들이는 거리보다 좁지 않다
      for (var right = 0.0; right <= 36; right += 0.5) {
        final i = inset(60, right);
        expect(i, inInclusiveRange(0, 9));
        expect(middle(60, right), greaterThanOrEqualTo(gap - 1e-9));
        expect(middle(60, right), greaterThanOrEqualTo(i - 1e-9));
      }
    });
  });

  group('키캡 폭에 들어가지 않는 쌍은 키캡 밖 셀 폭까지 쓴다 (#264)', () {
    test('들이는 거리는 음수가 되어 양옆으로 똑같이 나가고, 키캡 옆 여백에서 멈춘다', () {
      double inset(double outerMargin) => keyLegendPairInset(
        width: 50,
        gap: 4,
        leftWidth: 30,
        rightWidth: 22, // 남는 폭 −6
        sideInset: 5,
        outerMargin: outerMargin,
      );
      expect(inset(10), -3); // 남는 폭의 절반만큼 양쪽으로
      expect(inset(3), -3);
      expect(inset(2), -2); // 키캡 옆 여백에서 멈춘다 (그 뒤로는 각인 줄이 줄인다)
      expect(inset(0), 0); // 키캡이 셀 폭을 다 쓰면 나갈 자리가 없다
      // 들어가는 쌍은 옆 여백이 있어도 키캡 안에 놓인다
      expect(
        keyLegendPairInset(
          width: 50,
          gap: 4,
          leftWidth: 20,
          rightWidth: 10,
          sideInset: 5,
          outerMargin: 10,
        ),
        5,
      );
    });

    testWidgets('폰 세로 360×780: Ran# · RanInt는 키캡보다 넓게, 줄지 않고 셀 폭 안에 그려진다', (
      tester,
    ) async {
      await _pump(tester, _windows.first);
      final p = _measure(tester, keyDefOf(CalcKeyId.dot));
      final reason = _describe(p);
      // 실물도 이 쌍은 키보다 넓다 (CalcTheme "글자 크기 실물 대조 (#264)" 절 4)
      expect(
        p.first.width + p.last.width + p.gap,
        greaterThan(p.cap.width),
        reason: reason,
      );
      expect(p.left, lessThan(-0.1), reason: reason);
      expect(p.left, closeTo(p.right, 2 * _tolerance), reason: reason);
      expect(p.left, closeTo(_expectedInset(p), _tolerance), reason: reason);
      expect(
        p.left,
        greaterThanOrEqualTo(-_faceMarginOf(p) - _tolerance),
        reason: reason,
      );
      expect(p.first.left, greaterThanOrEqualTo(p.cell.left - _tolerance));
      expect(p.last.right, lessThanOrEqualTo(p.cell.right + _tolerance));
      expect(p.firstScale, closeTo(1, 1e-3), reason: reason);
      // 이웃 키(0 키의 Rnd, ×10ˣ 키의 π)의 각인과 겹치지 않는다
      final rnd = _legend(
        tester,
        keyDefOf(CalcKeyId.num0),
        keyDefOf(CalcKeyId.num0).shiftLegend!,
      );
      final pi = _legend(
        tester,
        keyDefOf(CalcKeyId.exp10),
        keyDefOf(CalcKeyId.exp10).shiftLegend!,
      );
      expect(rnd.right, lessThan(p.first.left));
      expect(pi.left, greaterThan(p.last.right));
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
      expect(p.firstScale, closeTo(1, 1e-6));
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
      // 사이는 최소 간격·들이는 거리보다 좁지 않다
      expect(p.middle, greaterThanOrEqualTo(p.gap - _tolerance));
      expect(p.middle, greaterThanOrEqualTo(p.left - 3 * _tolerance));
      // 각인은 줄지 않는다 (부동소수 오차만큼)
      expect(p.firstScale, closeTo(1, 1e-3));
    });

    testWidgets('들어가지 않으면 들이지 않고 키캡 폭을 다 쓴 뒤 각인이 줄어든다', (tester) async {
      await _pumpButton(tester, def.id, size: size, legendFontSize: 24);
      final p = _measure(tester, def);
      expect(p.left, closeTo(0, _tolerance), reason: _describe(p));
      expect(p.right, closeTo(0, _tolerance), reason: _describe(p));
      expect(p.firstScale, lessThan(0.9));
    });

    testWidgets('띠 높이 때문에 줄어든 각인은 줄어든 폭으로 들인다 (글자 크기를 주입받지 않은 키 버튼)', (
      tester,
    ) async {
      // sin⁻¹ · ┌D┐: 글자 크기가 띠 높이보다 커서 각인이 높이에 맞춰 줄어든다 — 줄기 전 폭으로 재면 들일 자리가 거의 없다고
      // 본다. 괄호까지가 D의 폭이라(#266) 다른 검사보다 넓은 키에서 잰다 — 폭 60에서는 줄어든 폭으로도 키캡 폭을 다 쓴다.
      final sin = keyDefOf(CalcKeyId.sin);
      await _pumpButton(
        tester,
        sin.id,
        size: const Size(80, 60),
        legendFontSize: 20,
      );
      final p = _measure(tester, sin);
      expect(p.firstScale, lessThan(0.9), reason: '각인이 높이 때문에 줄어야 한다');
      // 줄어든(그려진) 폭에서 구한 기대값만큼 들인다 — 줄기 전 폭으로 재면 그 절반도 안 된다(#265 R1)
      final naturalSpare =
          p.cap.width - p.gap - (p.first.width + p.last.width) / p.firstScale;
      expect(p.left, greaterThan(2), reason: _describe(p));
      expect(
        p.left,
        greaterThan(2 * math.max(0, naturalSpare / 2)),
        reason: '줄기 전 폭으로 잰 값 ${naturalSpare / 2} · ${_describe(p)}',
      );
      expect(
        p.left,
        closeTo(_expectedInset(p), _tolerance),
        reason: _describe(p),
      );
      expect(p.right, closeTo(p.left, 2 * _tolerance), reason: _describe(p));
    });

    // 글자 크기를 바꿔 가며 훑는다 — 우선 배분 쌍(SOLVE · =, M− · M: 짧은 쪽이 자연 폭을 먼저 쓴다)과 폭 비례 배분 쌍
    // (Ran# · RanInt, INS · UNDO), 2차원 각인이 있는 쌍(sin⁻¹ · D)을 모두 본다. 글자 배율 1.3은 줄 상자 높이 반올림이
    // 높이 맞춤 판정에 걸리는 크기를 만든다(#265 R2).
    for (final id in [
      CalcKeyId.calc,
      CalcKeyId.mPlus,
      CalcKeyId.dot,
      CalcKeyId.del,
      CalcKeyId.sin,
    ]) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '${id.name} 글자 크기 3~24 (배율 $textScale): 좌우가 같고, 그려진 폭에서 구한 만큼 들이고, 사이가 더 좁지 않다',
          (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = textScale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final regimes = <String>{};
            for (var fontSize = 3.0; fontSize <= 24; fontSize += 0.5) {
              await _pumpButton(
                tester,
                id,
                size: const Size(64, 56),
                legendFontSize: fontSize,
              );
              final p = _measure(tester, keyDefOf(id));
              final reason = '글자 $fontSize · ${_describe(p)}';
              expect(p.right, closeTo(p.left, 2 * _tolerance), reason: reason);
              expect(
                p.left,
                closeTo(_expectedInset(p), _tolerance),
                reason: reason,
              );
              expect(
                p.middle,
                greaterThanOrEqualTo(p.gap - _tolerance),
                reason: reason,
              );
              expect(
                p.middle,
                greaterThanOrEqualTo(p.left - 3 * _tolerance),
                reason: reason,
              );
              regimes.add(
                p.left > _sideInsetOf(p) - _tolerance
                    ? '상한'
                    : p.left > _tolerance
                    ? '줄어듦'
                    : '0',
              );
            }
            // 훑은 범위에 상한까지 들이는 크기와 덜 들이는 크기가 모두 있어야 한다 (검사가 한쪽만 보지 않게)
            expect(regimes, containsAll(['상한', '줄어듦']), reason: '$regimes');
          },
        );
      }
    }
  });

  for (final window in _windows) {
    group(window.name, () {
      testWidgets('각인이 하나뿐인 키: 키캡 가운데', (tester) async {
        await _pump(tester, window);
        // `x³`·`◼√◻`·`10^◼`·`e^◼`는 파란 Base-N 각인(`DEC`…)과 짝이라 하나뿐인 키가 아니다 — 실물처럼 왼쪽이다(#266).
        final singles = _legendKeys.where((d) => _band(d).length == 1);
        for (final id in [
          CalcKeyId.square,
          CalcKeyId.power,
          CalcKeyId.logBase,
          CalcKeyId.ln,
        ]) {
          expect(singles.map((d) => d.id), isNot(contains(id)));
        }
        // 실물에서 가운데인 각인이 빠지지 않았는지 (목록이 비면 아래 검사가 헛돈다)
        expect(
          singles.map((d) => _band(d).single.legend.plainText),
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
          final legend = _bandRect(tester, def, _band(def).single);
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
          '각인이 둘인 키 (글자 배율 $textScale): 첫째 왼쪽·둘째 오른쪽, 바깥 끝을 똑같이 들이고 사이가 더 좁지 않다',
          (tester) async {
            await _pump(tester, window, textScale: textScale);
            // SHIFT·ALPHA 쌍과 SHIFT·모드 색 각인 쌍(`x³ DEC`…), 괄호가 있는 쌍(`log ┌A┐`…)이 모두 들어 있다
            expect(
              _pairKeys.map((d) => d.id),
              containsAll([
                CalcKeyId.calc,
                CalcKeyId.square,
                CalcKeyId.power,
                CalcKeyId.logBase,
                CalcKeyId.ln,
                CalcKeyId.negative,
                CalcKeyId.tan,
              ]),
            );
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
              // 키캡 밖으로 나가는 긴 쌍도 셀 폭 안이다 (#264)
              expect(
                p.left,
                greaterThanOrEqualTo(-_faceMarginOf(p) - _tolerance),
                reason: reason,
              );
              // 첫째가 둘째 왼쪽이고, 사이는 최소 간격·들인 거리보다 좁지 않다 (바깥을 들이느라 붙지 않는다)
              expect(
                p.middle,
                greaterThanOrEqualTo(p.gap - _tolerance),
                reason: reason,
              );
              expect(
                p.middle,
                greaterThanOrEqualTo(p.left - 3 * _tolerance),
                reason: reason,
              );
            }
          },
        );
      }

      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '각인이 셋인 키 ENG (글자 배율 $textScale): ┌∠┐ ← i 순서, 바깥 끝을 똑같이 들이고 사이가 같다 (#266)',
          (tester) async {
            await _pump(tester, window, textScale: textScale);
            final def = keyDefOf(CalcKeyId.eng);
            final band = _band(def);
            expect(band.map((b) => b.legend.plainText), ['∠', '←', 'i']);
            final cap = _keycap(tester, def.id);
            final cell = tester.getRect(_button(def.id));
            final rects = [for (final b in band) _bandRect(tester, def, b)];
            final gap = _gapOf(
              tester,
              _legendFinder(def, band.first.legend),
              cap,
            );
            final radius = keyCapCornerRadius(def.category, cap.height);
            final left = rects.first.left - cap.left;
            final right = cap.right - rects.last.right;
            final between = [
              rects[1].left - rects[0].right,
              rects[2].left - rects[1].right,
            ];
            final reason =
                '왼쪽 ${left.toStringAsFixed(3)} · 사이 ${between.map((b) => b.toStringAsFixed(3))} · '
                '오른쪽 ${right.toStringAsFixed(3)} · 키캡 폭 ${cap.width.toStringAsFixed(2)}';
            expect(left, closeTo(right, 2 * _tolerance), reason: reason);
            expect(
              between[0],
              closeTo(between[1], 2 * _tolerance),
              reason: reason,
            );
            expect(
              left,
              closeTo(
                _expectedTripleInset(
                  cap: cap,
                  cell: cell,
                  radius: radius,
                  gap: gap,
                  total: rects.fold(0.0, (sum, r) => sum + r.width),
                ),
                _tolerance,
              ),
              reason: reason,
            );
            // 사이는 최소 간격·들인 거리보다 좁지 않고, 셀 폭 안이다
            expect(
              between[0],
              greaterThanOrEqualTo(gap - _tolerance),
              reason: reason,
            );
            expect(
              between[0],
              greaterThanOrEqualTo(left - 3 * _tolerance),
              reason: reason,
            );
            expect(
              rects.first.left,
              greaterThanOrEqualTo(cell.left - _tolerance),
            );
            expect(
              rects.last.right,
              lessThanOrEqualTo(cell.right + _tolerance),
            );
          },
        );
      }

      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '괄호로 둘러싼 각인 (글자 배율 $textScale): 글자 양옆에 괄호 자리가 똑같이 있고, 괄호 아래끝은 키캡 위에 있다 (#266)',
          (tester) async {
            await _pump(tester, window, textScale: textScale);
            final bracketed = [
              for (final def in _legendKeys)
                for (final item in _band(def))
                  if (item.bracketed) (def, item),
            ];
            // 실물: ENG의 ∠(Complex)와 A~F(Base-N)
            expect(
              bracketed.map((e) => e.$2.legend.plainText),
              unorderedEquals(['∠', 'A', 'B', 'C', 'D', 'E', 'F']),
            );
            for (final (def, item) in bracketed) {
              final finder = _legendFinder(def, item.legend);
              final box = _bandRect(tester, def, item);
              final label = _legend(tester, def, item.legend);
              final scale = label.height / tester.getSize(finder).height;
              // 그리는 글자 크기 × 괄호 자리 비율 × 줄어든 비율
              final widget = tester.widget<LegendBrackets>(
                find.ancestor(
                  of: finder,
                  matching: find.byType(LegendBrackets),
                ),
              );
              final pad =
                  widget.fontSize * CalcTheme.keyLegendBracketPad * scale;
              final reason = '${def.id.name} $item · 상자 $box · 글자 $label';
              expect(
                widget.fontSize,
                closeTo(
                  legendStyleOf(tester, finder).fontSize! * textScale,
                  1e-6,
                ),
                reason: reason,
              );
              expect(
                label.left - box.left,
                closeTo(pad, _tolerance),
                reason: reason,
              );
              expect(
                box.right - label.right,
                closeTo(pad, _tolerance),
                reason: reason,
              );
              // 높이는 글자 줄 상자 그대로다 (글자는 그린 기준선에 맞추느라 1dp 안에서 옮겨 그린다 — #252)
              expect(
                box.height,
                closeTo(label.height, _tolerance),
                reason: reason,
              );
              expect((box.top - label.top).abs(), lessThan(1), reason: reason);
              // 키패드에서는 각인이 줄지 않는다 — 괄호 획도 줄지 않는다
              expect(scale, closeTo(1, 1e-3), reason: reason);
              // 괄호 아래끝: 줄 상자 아래로 나가되(실물) 키캡 위끝에 닿지 않는다
              final strokes = LegendBracketPainter(
                color: widget.color,
                fontSize: widget.fontSize,
                depth: widget.depth,
                heightScale: widget.heightScale,
                maxDrop: widget.maxDrop,
              ).strokesFor(box.size);
              final bottom = box.top + strokes[0].bottom;
              final cap = _keycap(tester, def.id);
              expect(bottom, greaterThan(box.bottom), reason: reason);
              expect(
                bottom,
                lessThanOrEqualTo(
                  cap.top -
                      widget.fontSize * CalcTheme.keyLegendBracketKeyGap +
                      0.01,
                ),
                reason: '$reason · 괄호 아래끝 $bottom · 키캡 위끝 ${cap.top}',
              );
              // 기준선 아래 깊이 = 실물 치수와 키캡까지의 여유 가운데 작은 쪽 (화면 좌표로 따로 구한다 — 위젯에 넘긴
              // 한도 `maxDrop`을 쓰지 않는다)
              final baseline = box.bottom - widget.depth;
              final full =
                  widget.fontSize *
                  CalcTheme.keyLegendBracketDrop *
                  widget.heightScale;
              final room =
                  cap.top -
                  baseline -
                  widget.fontSize * CalcTheme.keyLegendBracketKeyGap;
              final drop = bottom - baseline;
              expect(
                drop,
                closeTo(math.min(full, room), 0.01),
                reason: '$reason · 온전한 깊이 $full · 여유 $room',
              );
              // 실물 치수에 대한 비율 (CalcTheme "모드 전용 각인의 괄호" 절): `A`~`F`는 글자 배율 1.0에서 그대로, 1.3에서
              // 0.9배 이상. `∠`는 키캡까지의 거리에 묶여 모든 화면에서 0.65~0.8배다
              final ratio = drop / full;
              if (item.legend.plainText == '∠') {
                expect(widget.heightScale, CalcTheme.keyGlyphScale('∠'));
                expect(ratio, inInclusiveRange(0.65, 0.8), reason: reason);
              } else {
                expect(widget.heightScale, 1.0, reason: reason);
                expect(
                  ratio,
                  textScale == 1.0
                      ? closeTo(1, 1e-6)
                      : inInclusiveRange(0.9, 1.0),
                  reason: reason,
                );
              }
            }
          },
        );
      }

      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          'v1.0 배포 목록 (글자 배율 $textScale): QR·파랑 각인 없이 — 남은 각인 하나는 가운데, 둘은 똑같이 들인다 (#267)',
          (tester) async {
            // 실물 인쇄 전체일 때의 각인 글자 크기 (숨긴 각인이 글자 크기를 바꾸지 않는지 견준다)
            await _pump(tester, window, textScale: textScale);
            final solve = find.text('SOLVE');
            final fullFontSize = legendStyleOf(tester, solve).fontSize!;
            for (final text in ['QR', 'DEC', 'HEX', 'BIN', 'OCT']) {
              expect(find.text(text), findsOneWidget, reason: text);
            }

            await _pump(tester, window, textScale: textScale, released: _v10);
            // 숨긴 각인은 그려지지 않는다 — 괄호는 ENG의 ∠(Complex) 하나뿐이다
            for (final text in ['QR', 'DEC', 'HEX', 'BIN', 'OCT']) {
              expect(find.text(text), findsNothing, reason: text);
            }
            expect(find.byType(LegendBrackets), findsOneWidget);
            expect(
              find.descendant(
                of: _button(CalcKeyId.eng),
                matching: find.byType(LegendBrackets),
              ),
              findsOneWidget,
            );
            // 빨강 A~F는 그대로 있다
            for (final (id, text) in [
              (CalcKeyId.negative, 'A'),
              (CalcKeyId.degMinSec, 'B'),
              (CalcKeyId.reciprocal, 'C'),
              (CalcKeyId.sin, 'D'),
              (CalcKeyId.cos, 'E'),
              (CalcKeyId.tan, 'F'),
            ]) {
              expect(
                find.descendant(of: _button(id), matching: find.text(text)),
                findsOneWidget,
                reason: text,
              );
            }
            // 각인 글자 크기는 그대로다
            expect(
              legendStyleOf(tester, solve).fontSize,
              closeTo(fullFontSize, 1e-9),
            );

            // 하나뿐인 키: 파랑 각인의 짝이던 노랑 각인 넷이 들어오고, 각인이 없어진 OPTN은 빠진다
            final singles = _legendKeys.where((d) => _band(d).length == 1);
            expect(
              singles.map((d) => d.id),
              containsAll([
                CalcKeyId.square,
                CalcKeyId.power,
                CalcKeyId.logBase,
                CalcKeyId.ln,
              ]),
            );
            expect(
              _legendKeys.map((d) => d.id),
              isNot(contains(CalcKeyId.optn)),
            );
            for (final def in singles) {
              final cap = _keycap(tester, def.id);
              final legend = _bandRect(tester, def, _band(def).single);
              expect(
                legend.center.dx,
                closeTo(cap.center.dx, _tolerance),
                reason:
                    '${def.id.name} ${legend.left}~${legend.right} · 키캡 $cap',
              );
              expect(legend.left, greaterThanOrEqualTo(cap.left - _tolerance));
              expect(legend.right, lessThanOrEqualTo(cap.right + _tolerance));
            }

            // 둘인 키: 괄호가 빠진 `log A`~`tan⁻¹ F`도 #265 규칙 그대로다
            expect(
              _pairKeys.map((d) => d.id),
              containsAll([
                CalcKeyId.calc,
                CalcKeyId.negative,
                CalcKeyId.degMinSec,
                CalcKeyId.reciprocal,
                CalcKeyId.sin,
                CalcKeyId.cos,
                CalcKeyId.tan,
              ]),
            );
            for (final def in _pairKeys) {
              final p = _measure(tester, def);
              final reason = _describe(p);
              expect(p.left, closeTo(p.right, 2 * _tolerance), reason: reason);
              expect(
                p.left,
                closeTo(_expectedInset(p), _tolerance),
                reason: reason,
              );
              expect(
                p.middle,
                greaterThanOrEqualTo(p.gap - _tolerance),
                reason: reason,
              );
              expect(p.firstScale, closeTo(1, 1e-3), reason: reason);
            }
            // 괄호가 없으니 `log A`는 실물 인쇄 전체일 때보다 넉넉히 들인다 — 글자 배율 1.0에서는 모서리 반경까지
            if (textScale == 1.0) {
              final log = _measure(tester, keyDefOf(CalcKeyId.negative));
              expect(
                log.left,
                greaterThanOrEqualTo(log.radius - _tolerance),
                reason: _describe(log),
              );
            }
          },
        );
      }

      testWidgets('실물에서 바깥 끝이 들어와 있는 쌍은 둥근 모서리 안쪽까지 들인다', (tester) async {
        await _pump(tester, window);
        // 실물에서 바깥 끝이 키캡 폭의 0.08~0.12만큼 들어와 있는 쌍 (CalcTheme "각인 띠 좌우 정렬 (#265)" 절).
        // 괄호가 든 쌍(`log ┌A┐`·`x! ┌C┐`)은 괄호까지가 각인이라 넓다 — 상한(모서리 반경)에는 조금 못 미치고 두 각인 사이와
        // 같은 거리만큼 들인다(실물은 괄호 끝 0.05~0.07·SHIFT 각인 0.04~0.13, CalcTheme "모드 전용 각인의 괄호" 절).
        for (final id in [
          CalcKeyId.negative, // log · ┌A┐
          CalcKeyId.reciprocal, // x! · ┌C┐
          CalcKeyId.parenClose, // , · x
          CalcKeyId.mPlus, // M− · M
          CalcKeyId.exp10, // π · e
        ]) {
          final p = _measure(tester, keyDefOf(id));
          final reason = _describe(p);
          if (_band(keyDefOf(id)).any((b) => b.bracketed)) {
            expect(
              p.left,
              closeTo(_expectedInset(p), _tolerance),
              reason: reason,
            );
            expect(p.left, greaterThan(0.8 * p.radius), reason: reason);
            expect(p.right, closeTo(p.left, 2 * _tolerance), reason: reason);
          } else {
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
          }
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

  group('배포 목록 (#267)', () {
    testWidgets('앱 기본값: 아무것도 바꾸지 않은 앱은 배포 목록 상수대로 그린다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late Set<KeyFeature> provided;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: Consumer(
            builder: (context, ref, child) {
              provided = ref.watch(releasedKeyFeaturesProvider);
              return child!;
            },
            child: const AltCalcApp(),
          ),
        ),
      );
      expect(provided, releasedKeyFeatures);
      expect(
        tester.widget<CalcKeypad>(find.byType(CalcKeypad)).releasedFeatures,
        releasedKeyFeatures,
      );
      // 그려진 각인이 키마다 배포 목록의 각인 그대로다 (상수가 바뀌어도 이 검사는 그 값을 따라간다)
      for (final button in tester.widgetList<CalcKeyButton>(
        find.byType(CalcKeyButton),
      )) {
        final def = button.keyDef;
        expect(
          button.releasedFeatures,
          releasedKeyFeatures,
          reason: def.id.name,
        );
        if (def.face != KeyFace.keycap) continue;
        for (final item in def.printedBandLegends) {
          final shown = def.bandLegends.any((b) => b.legend == item.legend);
          expect(
            find.descendant(
              of: _button(def.id),
              matching: findLegend(item.legend),
            ),
            shown ? findsOneWidget : findsNothing,
            reason: '${def.id.name} $item',
          );
        }
        expect(
          find.descendant(
            of: _button(def.id),
            matching: find.byType(LegendBrackets),
          ),
          findsNWidgets(def.bandLegends.where((b) => b.bracketed).length),
          reason: def.id.name,
        );
      }
      // 숨긴 것이 하나라도 있어야 위 검사가 뜻이 있다 (QR은 배포 계획이 없다)
      expect(find.text('QR'), findsNothing);
      expect(find.text('SOLVE'), findsOneWidget);
    });

    test('숨긴 각인은 각인 글자 크기를 정하지 않는다 — 배포 목록을 바꿔도 화면의 글자 크기가 같다', () {
      // 각인 글자 크기는 높이 기준과 폭 기준(키마다 `쓸 수 있는 폭 ÷ 각인의 em 폭`의 최솟값) 가운데 작은 쪽이다. 배포 목록이
      // 바꾸는 것은 폭 기준에 들어가는 각인뿐이다(키패드 크기·띠 높이·메인 글자는 배포 목록을 읽지 않는다).
      // 그래서 "숨긴 각인이 있는 키들의 폭 한계가, 실물 인쇄 전체를 그릴 때도 v1.0 전체의 폭 한계보다 넉넉하다"가 성립하면
      // 숨긴 각인은 어느 화면에서도 글자 크기를 정하지 못한다. 폭 한계의 키 사이 비는 창 크기와 거의 무관하므로(둘 다 폭에
      // 비례) 배열마다 대표 크기 몇 개로 본다.
      bool hasHidden(CalcKeyDef def) =>
          def.bandLegendsIn(allKeyFeatures).toString() !=
          def.bandLegendsIn(_v10).toString();
      expect(allKeys.where(hasHidden).map((d) => d.id), [
        CalcKeyId.optn,
        CalcKeyId.square,
        CalcKeyId.power,
        CalcKeyId.logBase,
        CalcKeyId.ln,
        CalcKeyId.negative,
        CalcKeyId.degMinSec,
        CalcKeyId.reciprocal,
        CalcKeyId.sin,
        CalcKeyId.cos,
        CalcKeyId.tan,
      ]);
      for (final (arrangement, sizes) in const [
        (
          KeypadArrangement.standard,
          [Size(320, 380), Size(360, 420), Size(600, 700), Size(800, 900)],
        ),
        (
          KeypadArrangement.wide,
          [Size(760, 300), Size(800, 330), Size(1240, 520)],
        ),
      ]) {
        for (final size in sizes) {
          for (final scale in [1.0, 1.3]) {
            KeypadMetrics metrics(Set<KeyFeature> released) =>
                KeypadMetrics.compute(
                  size,
                  TextScaler.linear(scale),
                  arrangement: arrangement,
                  releasedFeatures: released,
                );
            final base = metrics(_v10);
            final reason = '${arrangement.name} $size 배율 $scale';
            // 1) 구조: 숨긴 각인이 있는 키들의 폭 한계(실물 인쇄 전체) > v1.0 전체의 폭 한계
            final hiddenKeys = KeypadMetrics.debugWidthLimits(
              base,
              where: hasHidden,
              releasedFeatures: allKeyFeatures,
            ).legend;
            final v10All = KeypadMetrics.debugWidthLimits(
              base,
              releasedFeatures: _v10,
            ).legend;
            expect(hiddenKeys, greaterThan(v10All * 1.05), reason: reason);
            // 2) 결과: 어느 배포 목록에서도 각인 글자 크기와 올림이 같다
            for (final released in [
              allKeyFeatures,
              const {KeyFeature.complex, KeyFeature.baseN},
              const <KeyFeature>{},
            ]) {
              final other = metrics(released);
              expect(
                other.legendFontSize,
                base.legendFontSize,
                reason: '$reason $released',
              );
              expect(
                other.legendBaseLift,
                base.legendBaseLift,
                reason: '$reason $released',
              );
            }
          }
        }
      }
      // 글자 배율 2.0은 따로 보지 않는다 — 키패드가 글자 배율을 [CalcTheme.keyMaxTextScaleFactor]에서 묶는다
      expect(CalcTheme.keyMaxTextScaleFactor, lessThan(2.0));
    });

    testWidgets('키패드가 받은 배포 목록을 글자 크기 계산과 모든 키 버튼에 그대로 넘긴다', (tester) async {
      const v13 = {KeyFeature.complex, KeyFeature.baseN};
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: CalcKeypad(releasedFeatures: v13),
            ),
          ),
        ),
      );
      for (final button in tester.widgetList<CalcKeyButton>(
        find.byType(CalcKeyButton),
      )) {
        expect(button.releasedFeatures, v13, reason: button.keyDef.id.name);
      }
      // Base-N만 더한 v1.3: 파랑 각인은 있고 QR은 없다
      expect(find.text('DEC'), findsOneWidget);
      expect(find.text('QR'), findsNothing);
      expect(find.byType(LegendBrackets), findsNWidgets(7));
      // 글자 크기 계산도 같은 목록을 잰다 — 폭 기준이 그 목록의 각인만 본다
      final metrics = KeypadMetrics.compute(
        const Size(360, 420),
        TextScaler.noScaling,
        releasedFeatures: v13,
      );
      bool bracketed(CalcKeyDef def) => def.alphaBracketMode != null;
      final withBrackets = KeypadMetrics.debugWidthLimits(
        metrics,
        where: bracketed,
        releasedFeatures: v13,
      ).legend;
      final withoutBrackets = KeypadMetrics.debugWidthLimits(
        metrics,
        where: bracketed,
        releasedFeatures: _v10,
      ).legend;
      // 괄호가 있으면 그 키들의 폭 한계가 더 빠듯하다 (괄호까지가 각인의 폭)
      expect(withBrackets, lessThan(withoutBrackets));
      // 그래도 키패드 전체 각인 글자 크기는 같다 — 괄호 키가 글자 크기를 정하지 않는다
      expect(
        metrics.legendFontSize,
        KeypadMetrics.compute(
          const Size(360, 420),
          TextScaler.noScaling,
          releasedFeatures: _v10,
        ).legendFontSize,
      );
    });
  });

  group('글자 배율 1.3에서도 들인다', () {
    // 옛 배치(양 끝에 붙임)는 들인 거리가 0이다 — 배율을 키워도 대표 키는 상한까지, 가장 긴 쌍은 그보다 덜 들인다
    testWidgets(
      '폰 세로 360×780: π · e와 M− · M은 상한까지, log · ┌A┐·Ran# · RanInt는 그보다 덜',
      (tester) async {
        await _pump(tester, _windows.first, textScale: 1.3);
        for (final id in [CalcKeyId.exp10, CalcKeyId.mPlus]) {
          final p = _measure(tester, keyDefOf(id));
          expect(p.left, greaterThan(1), reason: _describe(p));
          expect(
            p.left,
            closeTo(_sideInsetOf(p), _tolerance),
            reason: _describe(p),
          );
        }
        // 괄호가 든 쌍은 괄호 자리만큼 덜 들인다 — 그래도 사이가 들인 거리보다 좁지 않게 (#266)
        final log = _measure(tester, keyDefOf(CalcKeyId.negative));
        expect(log.left, greaterThan(1), reason: _describe(log));
        expect(
          log.left,
          closeTo(_expectedInset(log), _tolerance),
          reason: _describe(log),
        );
        expect(log.left, lessThan(_sideInsetOf(log)), reason: _describe(log));
        // 가장 긴 쌍은 상한에 못 미치고, 그려진 폭에서 구한 만큼만 들인다 (키캡 폭을 거의 다 쓴다)
        final dot = _measure(tester, keyDefOf(CalcKeyId.dot));
        expect(
          dot.left,
          closeTo(_expectedInset(dot), _tolerance),
          reason: _describe(dot),
        );
        expect(
          dot.left,
          lessThan(_sideInsetOf(dot) / 2),
          reason: _describe(dot),
        );
        expect(dot.right, closeTo(dot.left, 2 * _tolerance));
      },
    );
  });
}
