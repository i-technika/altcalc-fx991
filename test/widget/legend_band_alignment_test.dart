import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/key_legends.dart';

/// 키캡 위 각인(SHIFT·ALPHA)의 좌우 정렬 (#265) — 규칙과 실물 측정은 [CalcTheme] "각인 띠 좌우 정렬 (#265)" 절.
///
/// - 각인이 하나면 키캡 가운데다.
/// - 둘이면 SHIFT는 왼쪽·ALPHA는 오른쪽이고, 바깥 끝을 키캡 끝에서 똑같이 들인다. 들이는 거리는 [keyLegendSideInset]까지이고,
///   두 각인이 그 안에 들어가지 않으면 줄어든다([keyLegendPairInset]).
///
/// 실제 앱([AltCalcApp])을 번들 글꼴로 띄워 그려진 자리를 잰다 — 자리 계산을 다시 하는 검사가 아니라 화면 좌표다.

/// 화면 하나 (dp)
typedef _Window = ({String name, Size size, Handedness handedness});

const _windows = <_Window>[
  (name: '폰 세로 360×780', size: Size(360, 780), handedness: Handedness.right),
  (
    name: '태블릿 세로 800×1280',
    size: Size(800, 1280),
    handedness: Handedness.right,
  ),
  (
    name: '태블릿 가로 1280×800 (넓은 배열)',
    size: Size(1280, 800),
    handedness: Handedness.right,
  ),
  (
    name: '태블릿 가로 1280×800 왼손 (넓은 배열 대칭)',
    size: Size(1280, 800),
    handedness: Handedness.left,
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

Future<void> _pump(
  WidgetTester tester,
  _Window window, {
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = window.size;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({
    HandednessNotifier.storageKey: window.handedness.storageValue,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AltCalcApp(),
    ),
  );
}

Finder _button(CalcKeyId id) => find.byWidgetPredicate(
  (w) => w is CalcKeyButton && w.keyDef.id == id,
  description: 'CalcKeyButton(${id.name})',
);

/// [id] 키에 그려진 키캡 상자 (전역 dp)
Rect _keycap(WidgetTester tester, CalcKeyId id) =>
    tester.getRect(find.byKey(CalcKeyButton.keycapKeyOf(id)));

/// [def] 키의 각인 [legend]가 그려진 상자 (전역 dp — 줄어든 각인은 줄어든 크기)
Rect _legend(WidgetTester tester, CalcKeyDef def, KeyLegend legend) {
  final finder = find.descendant(
    of: _button(def.id),
    matching: findLegend(legend),
  );
  expect(finder, findsOneWidget, reason: '${def.id.name} ${legend.plainText}');
  return tester.getRect(finder);
}

/// [def] 키의 각인 둘을 들이는 거리의 기대값 (dp) — 그려진 키캡과 각인 폭에서 다시 구한다
({double sideInset, double inset}) _expectedInset(
  WidgetTester tester,
  CalcKeyDef def,
  Rect cap,
  Rect shift,
  Rect alpha,
) {
  final sideInset = keyLegendSideInset(
    faceWidth: cap.width,
    cornerRadius: keyCapCornerRadius(def.category, cap.height),
  );
  final fontSize = legendStyleOf(
    tester,
    find.descendant(
      of: _button(def.id),
      matching: findLegend(def.shiftLegend!),
    ),
  ).fontSize!;
  final gap = math.min(
    fontSize * CalcTheme.keyLegendGapRatio,
    cap.width * CalcTheme.keyLegendGapMaxWidthRatio,
  );
  return (
    sideInset: sideInset,
    inset: keyLegendPairInset(
      width: cap.width,
      gap: gap,
      shiftWidth: shift.width,
      alphaWidth: alpha.width,
      sideInset: sideInset,
    ),
  );
}

/// 키 버튼 하나를 [size] 상자에 각인 글자 크기 [legendFontSize]로 띄운다 (키패드 밖 — 각인이 키캡 폭에 비해 긴 경우를 만든다)
Future<void> _pumpButton(
  WidgetTester tester,
  CalcKeyId id, {
  required Size size,
  required double legendFontSize,
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

  group('각인 쌍이 키캡 폭에 비해 길 때 (SOLVE · =)', () {
    const size = Size(60, 60);
    final def = keyDefOf(CalcKeyId.calc);

    /// 왼쪽·오른쪽으로 들인 거리, 상한, 각인이 줄어든 비율
    ({double left, double right, double sideInset, double scale}) measure(
      WidgetTester tester,
    ) {
      final cap = _keycap(tester, def.id);
      final shiftFinder = find.descendant(
        of: _button(def.id),
        matching: findLegend(def.shiftLegend!),
      );
      final shift = tester.getRect(shiftFinder);
      final alpha = _legend(tester, def, def.alphaLegend!);
      return (
        left: shift.left - cap.left,
        right: cap.right - alpha.right,
        sideInset: keyLegendSideInset(
          faceWidth: cap.width,
          cornerRadius: keyCapCornerRadius(def.category, cap.height),
        ),
        scale: shift.height / tester.getSize(shiftFinder).height,
      );
    }

    testWidgets('넉넉하면 상한까지 들인다', (tester) async {
      await _pumpButton(tester, def.id, size: size, legendFontSize: 6);
      final m = measure(tester);
      expect(m.sideInset, greaterThan(0));
      expect(m.left, closeTo(m.sideInset, _tolerance));
      expect(m.right, closeTo(m.sideInset, _tolerance));
      expect(m.scale, closeTo(1, 1e-6));
    });

    testWidgets('빠듯하면 들이는 거리부터 양쪽 똑같이 줄이고, 각인은 줄이지 않는다', (tester) async {
      // 실물 `SOLVE =`·`Ran# RanInt`처럼 각인이 키캡 폭을 거의 다 쓰는 경우
      await _pumpButton(tester, def.id, size: size, legendFontSize: 13);
      final m = measure(tester);
      expect(m.left, greaterThan(_tolerance));
      expect(m.left, lessThan(m.sideInset - _tolerance));
      expect(m.right, closeTo(m.left, 2 * _tolerance));
      // 줄어도 폭 비례 배분의 반올림(1/1000)만큼이다
      expect(m.scale, closeTo(1, 2e-3));
    });

    testWidgets('들어가지 않으면 들이지 않고 키캡 폭을 다 쓴 뒤 각인이 줄어든다', (tester) async {
      await _pumpButton(tester, def.id, size: size, legendFontSize: 24);
      final m = measure(tester);
      expect(m.left, closeTo(0, _tolerance));
      expect(m.right, closeTo(0, _tolerance));
      expect(m.scale, lessThan(0.9));
    });
  });

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

    test('각인과 간격을 빼고 남는 폭의 절반까지만 들인다', () {
      double inset(double shift, double alpha) => keyLegendPairInset(
        width: 100,
        gap: 4,
        shiftWidth: shift,
        alphaWidth: alpha,
        sideInset: 9,
      );
      // 넉넉하면 상한
      expect(inset(30, 10), 9);
      expect(inset(60, 18), 9); // 남는 폭 18 = 상한의 두 배
      // 빠듯하면 남는 폭의 절반 (양쪽 똑같이)
      expect(inset(60, 26), 5);
      // 들어가지 않으면 들이지 않는다 (키캡 폭을 다 쓰고, 그래도 넘치면 각인 줄이 줄인다)
      expect(inset(70, 26), 0);
      expect(inset(90, 40), 0);
    });

    test('실물 비율: 들이는 거리는 키캡 폭의 0.08~0.10', () {
      // CalcTheme "각인 띠 좌우 정렬 (#265)" 절의 사진 실측 가운데값
      expect(CalcTheme.keyLegendSideInsetRatio, inInclusiveRange(0.08, 0.10));
    });
  });

  for (final window in _windows) {
    group(window.name, () {
      testWidgets('각인이 하나뿐인 키: 키캡 가운데', (tester) async {
        await _pump(tester, window);
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

      testWidgets('각인이 둘인 키: SHIFT 왼쪽·ALPHA 오른쪽, 바깥 끝을 똑같이 들인다', (
        tester,
      ) async {
        await _pump(tester, window);
        final pairs = _legendKeys.where((d) => d.hasShift && d.hasAlpha);
        expect(pairs, isNotEmpty);
        for (final def in pairs) {
          final cap = _keycap(tester, def.id);
          final shift = _legend(tester, def, def.shiftLegend!);
          final alpha = _legend(tester, def, def.alphaLegend!);
          final expected = _expectedInset(tester, def, cap, shift, alpha);
          final reason =
              '${def.id.name} SHIFT ${shift.left}~${shift.right} · '
              'ALPHA ${alpha.left}~${alpha.right} · 키캡 ${cap.left}~${cap.right}';
          expect(
            shift.left - cap.left,
            closeTo(expected.inset, _tolerance),
            reason: reason,
          );
          expect(
            cap.right - alpha.right,
            closeTo(expected.inset, _tolerance),
            reason: reason,
          );
          // SHIFT가 ALPHA 왼쪽이고 겹치지 않는다
          expect(shift.right, lessThanOrEqualTo(alpha.left + _tolerance));
        }
      });

      testWidgets('실물에서 바깥 끝이 들어와 있는 쌍은 둥근 모서리 안쪽까지 들인다', (tester) async {
        await _pump(tester, window);
        ({double sideInset, double inset, Rect cap}) insetOf(CalcKeyId id) {
          final def = keyDefOf(id);
          final cap = _keycap(tester, id);
          final e = _expectedInset(
            tester,
            def,
            cap,
            _legend(tester, def, def.shiftLegend!),
            _legend(tester, def, def.alphaLegend!),
          );
          return (sideInset: e.sideInset, inset: e.inset, cap: cap);
        }

        // 실물에서 바깥 끝이 키캡 폭의 0.08~0.12만큼 들어와 있는 쌍 — 상한까지 들인다
        for (final id in [
          CalcKeyId.negative, // log · A
          CalcKeyId.reciprocal, // x! · C
          CalcKeyId.parenClose, // , · x
          CalcKeyId.mPlus, // M− · M
          CalcKeyId.exp10, // π · e
        ]) {
          final e = insetOf(id);
          expect(e.inset, closeTo(e.sideInset, 1e-9), reason: id.name);
          // 둥근 모서리 안쪽 (키캡 윗변이 곧은 구간)
          expect(
            e.inset,
            greaterThanOrEqualTo(
              keyCapCornerRadius(keyDefOf(id).category, e.cap.height) - 1e-9,
            ),
            reason: id.name,
          );
        }
      });

      testWidgets('글자 배율 1.3: 각인이 커져도 양쪽이 같고 키캡 폭 안에 있다', (tester) async {
        await _pump(tester, window, textScale: 1.3);
        for (final def in _legendKeys.where((d) => d.hasShift && d.hasAlpha)) {
          final cap = _keycap(tester, def.id);
          final shift = _legend(tester, def, def.shiftLegend!);
          final alpha = _legend(tester, def, def.alphaLegend!);
          final left = shift.left - cap.left;
          final right = cap.right - alpha.right;
          expect(left, closeTo(right, 2 * _tolerance), reason: def.id.name);
          expect(left, greaterThanOrEqualTo(-_tolerance), reason: def.id.name);
          expect(
            shift.right,
            lessThanOrEqualTo(alpha.left + _tolerance),
            reason: def.id.name,
          );
        }
      });
    });
  }
}
