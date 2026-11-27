import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/layout_log.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/device_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_keypad.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/history_panel.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/touch_metrics.dart';

/// 폴더블 에뮬레이터에서 잰 접힘선 기준 배치를 위젯 테스트로 다시 그려 고정한다 (#140).
///
/// 각 경우는 Android 에뮬레이터 진단 릴리스 빌드(`--dart-define=ALTCALC_LAYOUT_LOG=true`)의 logcat "배치" 줄을 그대로
/// 옮긴 것이다 — 창·인셋·제스처 영역·접힘 정보를 기기 px ÷ 밀도로 넣으면 같은 줄(키패드 영역 포함)이 나와야 한다.
/// 에뮬레이터 기록 전체(키 높이·회전·접기·TalkBack)는 [CalcTheme] "접힘선 기준 배치" 절의 "에뮬레이터 실측 (#140)"이다.
/// - Pixel Fold: `pixel_fold` 기기 정의, Android 16(36.1) Google Play 이미지, 밀도 2.625(420dpi). 내부 화면 2208×1840px,
///   접힘선 x=1104px. 분할·자유 형식 창은 `am task resize`로 만든 창이다.
/// - 6.7" Flip: Android Studio `6.7in Foldable` 기기 정의, 같은 이미지, 밀도 3(480dpi), 1080×2636px, 힌지 y=1318~1319px.
///   반 접힘에서만 접힘 정보(폭 1px `hinge`)를 보고하고 완전히 펼치면 보고하지 않는다(에뮬레이터 한계 — 실기기는 펼침도 보고).
/// - Flip 크기를 Pixel Fold로 흉내 냄: `wm size 1080x2636`·`wm density 480`·`display_features fold-[0,1318,1080,1318]` —
///   펼침·반 접힘 모두 폭 0 `fold`를 보고한다.

/// 에뮬레이터 한 경우 — 값은 모두 기기 px이고, [density]로 나눠 dp로 넣는다
class _Case {
  final String name;
  final double density;
  final Size windowPx;

  /// 시스템 인셋 (위·아래, px)
  final double topPx;
  final double bottomPx;

  /// 시스템 제스처 영역 (왼·위·오른·아래, px)
  final EdgeInsets gesturePx;

  /// 접힘 정보 (창 좌표 px) — 없으면 빈 목록
  final List<(DisplayFeatureType, DisplayFeatureState, Rect)> featuresPx;
  final Handedness handedness;

  /// 에뮬레이터 logcat 배치 줄 (`AltCalc 배치: ` 뒤, ` @` 앞)
  final String line;

  /// 가장 낮은 키(함수 키)의 터치 높이 (dp) — 에뮬레이터 uiautomator 노드 높이는 px 정수라 1px 안에서 이 값과 맞는다
  final double functionKeyTouch;

  const _Case(
    this.name, {
    required this.density,
    required this.windowPx,
    required this.topPx,
    required this.bottomPx,
    required this.gesturePx,
    this.featuresPx = const [],
    this.handedness = Handedness.right,
    required this.line,
    required this.functionKeyTouch,
  });

  Size get window => windowPx / density;
  EdgeInsets get padding =>
      EdgeInsets.only(top: topPx / density, bottom: bottomPx / density);
  EdgeInsets get gestures => gesturePx / density;
  List<DisplayFeature> get features => [
    for (final (type, state, r) in featuresPx)
      DisplayFeature(
        bounds: Rect.fromLTRB(
          r.left / density,
          r.top / density,
          r.right / density,
          r.bottom / density,
        ),
        type: type,
        state: state,
      ),
  ];
}

const _fold = DisplayFeatureType.fold;
const _hinge = DisplayFeatureType.hinge;
const _flat = DisplayFeatureState.postureFlat;
const _half = DisplayFeatureState.postureHalfOpened;

/// Pixel Fold 내부 화면 (가로가 기본 방향) — 상태 표시줄 74px, 제스처 핸들 84px, 좌우 뒤로가기 78px
const _pf = 2.625;
const _pfGestures = EdgeInsets.fromLTRB(78, 74, 78, 84);

/// 6.7" Flip 에뮬레이터 — 상태 표시줄·제스처 핸들 72px, 좌우 뒤로가기 90px, 아래 제스처 96px
const _flip = 3.0;
const _flipGestures = EdgeInsets.fromLTRB(90, 72, 90, 96);

final _cases = <_Case>[
  // ── Pixel Fold 책 자세 (세로 접힘선) ──
  for (final (h, keypad) in [
    (Handedness.right, '428.57,219.12-833.14,660.95'),
    (Handedness.left, '8,219.12-412.57,660.95'),
  ])
    for (final (state, stateName) in [
      (_flat, 'postureFlat'),
      (_half, 'postureHalfOpened'),
    ])
      _Case(
        'Pixel Fold 책 자세 ${h.name} $stateName',
        density: _pf,
        windowPx: const Size(2208, 1840),
        topPx: 74,
        bottomPx: 84,
        gesturePx: _pfGestures,
        featuresPx: [(_fold, state, const Rect.fromLTRB(1104, 0, 1104, 1840))],
        handedness: h,
        line:
            'hingeSplit — 창 841.1x701, 키패드 $keypad, '
            '화면 특징 [fold $stateName 420.6,0-420.6,701], 가로지르는 접힘선 1, 폴더블=true',
        functionKeyTouch: 37.56,
      ),
  // ── Pixel Fold 세로로 돌림 (가로 접힘선, 넓은 배열) ──
  for (final h in Handedness.values)
    for (final (state, stateName) in [
      (_flat, 'postureFlat'),
      (_half, 'postureHalfOpened'),
    ])
      _Case(
        'Pixel Fold 세로 ${h.name} $stateName',
        density: _pf,
        windowPx: const Size(1840, 2208),
        topPx: 74,
        bottomPx: 84,
        gesturePx: _pfGestures,
        featuresPx: [(_fold, state, const Rect.fromLTRB(0, 1104, 1840, 1104))],
        handedness: h,
        line:
            'hingeStacked — 창 701x841.1, 키패드 8,579.48-692.95,801.14, '
            '화면 특징 [fold $stateName 0,420.6-701,420.6], 가로지르는 접힘선 1, 폴더블=true',
        functionKeyTouch: 37.68,
      ),
  // ── 회전 중 한 프레임: 접힘 정보가 창 크기보다 먼저 새 방향으로 왔다 (화면 캡처에는 나오지 않았다) ──
  const _Case(
    'Pixel Fold 세로로 돌리는 중 (창은 가로, 접힘 정보는 세로 방향)',
    density: _pf,
    windowPx: Size(2208, 1840),
    topPx: 74,
    bottomPx: 84,
    gesturePx: _pfGestures,
    featuresPx: [(_fold, _flat, Rect.fromLTRB(0, 1104, 1840, 1104))],
    line:
        'stacked — 창 841.1x701, 키패드 8,219.12-833.14,660.95, '
        '화면 특징 [fold postureFlat 0,420.6-701,420.6], 가로지르는 접힘선 0, 폴더블=true',
    functionKeyTouch: 37.56,
  ),
  const _Case(
    'Pixel Fold 가로로 돌리는 중 (창은 세로, 접힘 정보는 가로 방향)',
    density: _pf,
    windowPx: Size(1840, 2208),
    topPx: 74,
    bottomPx: 84,
    gesturePx: _pfGestures,
    featuresPx: [(_fold, _flat, Rect.fromLTRB(1104, 0, 1104, 1840))],
    line:
        'stacked — 창 701x841.1, 키패드 8,258.38-692.95,801.14, '
        '화면 특징 [fold postureFlat 420.6,0-420.6,701], 가로지르는 접힘선 0, 폴더블=true',
    functionKeyTouch: 46.14,
  ),
  // ── 손 쪽 패널이 짧은 책 자세 (#143 R1): 자유 형식 창 2208×930px (인셋 없음) ──
  for (final (h, keypad) in [
    (Handedness.right, '428.57,16.87-833.14,346.29'),
    (Handedness.left, '8,16.87-412.57,346.29'),
  ])
    _Case(
      'Pixel Fold 짧은 창 책 자세 ${h.name}',
      density: _pf,
      windowPx: const Size(2208, 930),
      topPx: 0,
      bottomPx: 0,
      gesturePx: EdgeInsets.zero,
      featuresPx: [(_fold, _flat, const Rect.fromLTRB(1104, 0, 1104, 930))],
      handedness: h,
      line:
          'hingeSplit (LCD 옆 패널) — 창 841.1x354.3, 키패드 $keypad, '
          '화면 특징 [fold postureFlat 420.6,0-420.6,354.3], 가로지르는 접힘선 1, 폴더블=true',
      functionKeyTouch: CalcTheme.keyTouchHeightFloor,
    ),
  // ── 가로 접힘선을 지나는 좁은 창 1103×1767px (= 약 420×673dp, Galaxy Z Fold 좌우 분할 창 크기) ──
  const _Case(
    'Pixel Fold 자유 형식 창 420×673 (가로 접힘선)',
    density: _pf,
    windowPx: Size(1103, 1767),
    topPx: 0,
    bottomPx: 0,
    gesturePx: EdgeInsets.zero,
    featuresPx: [(_fold, _flat, Rect.fromLTRB(0, 883, 1103, 883))],
    line:
        'hingeStacked — 창 420.2x673.1, 키패드 8,344.38-412.19,665.14, '
        '화면 특징 [fold postureFlat 0,336.4-420.2,336.4], 가로지르는 접힘선 1, 폴더블=true',
    functionKeyTouch: 27.26,
  ),
  // ── 6.7" Flip 에뮬레이터 ──
  const _Case(
    'Flip 반 접힘 (폭 1px 힌지)',
    density: _flip,
    windowPx: Size(1080, 2636),
    topPx: 72,
    bottomPx: 72,
    gesturePx: _flipGestures,
    featuresPx: [(_hinge, _flat, Rect.fromLTRB(0, 1318, 1080, 1319))],
    line:
        'hingeStacked — 창 360x878.7, 키패드 8,447.67-352,846.67, '
        '화면 특징 [hinge postureFlat 0,439.3-360,439.7], 가로지르는 접힘선 1, 폴더블=true',
    functionKeyTouch: 33.91,
  ),
  const _Case(
    'Flip 완전히 펼침 (에뮬레이터는 접힘 정보 없음)',
    density: _flip,
    windowPx: Size(1080, 2636),
    topPx: 72,
    bottomPx: 72,
    gesturePx: _flipGestures,
    line:
        'stacked — 창 360x878.7, 키패드 8,388-352,846.67, '
        '화면 특징 [], 가로지르는 접힘선 0, 폴더블=true',
    functionKeyTouch: 38.99,
  ),
  // ── Flip 크기를 흉내 낸 Pixel Fold (상태 표시줄 84px) — 펼침·반 접힘이 같은 배치 ──
  for (final (state, stateName) in [
    (_flat, 'postureFlat'),
    (_half, 'postureHalfOpened'),
  ])
    _Case(
      'Flip 크기 흉내 $stateName',
      density: _flip,
      windowPx: const Size(1080, 2636),
      topPx: 84,
      bottomPx: 72,
      gesturePx: const EdgeInsets.fromLTRB(90, 84, 90, 96),
      featuresPx: [(_fold, state, const Rect.fromLTRB(0, 1318, 1080, 1318))],
      line:
          'hingeStacked — 창 360x878.7, 키패드 8,447.33-352,846.67, '
          '화면 특징 [fold $stateName 0,439.3-360,439.3], 가로지르는 접힘선 1, 폴더블=true',
      functionKeyTouch: 33.94,
    ),
];

/// 의미 트리를 읽는 순서대로 훑은 노드 id 목록
List<int> _traversalOrder(WidgetTester tester) {
  final order = <int>[];
  void visit(SemanticsNode node) {
    order.add(node.id);
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child);
    }
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return order;
}

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

void main() {
  for (final c in _cases) {
    testWidgets('${c.name}: 에뮬레이터 배치 줄과 같다', (tester) async {
      final printed = <String>[];
      LayoutLog.enable(sink: printed.add, frameTimings: false);
      addTearDown(LayoutLog.disable);
      final handle = tester.ensureSemantics();

      final size = c.window;
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.displayFeatures = c.features;
      addTearDown(tester.view.resetDisplayFeatures);
      SharedPreferences.setMockInitialValues({
        HandednessNotifier.storageKey: c.handedness.storageValue,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          foldableDeviceProvider.overrideWithValue(ValueNotifier(true)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                devicePixelRatio: c.density,
                padding: c.padding,
                viewPadding: c.padding,
                systemGestureInsets: c.gestures,
                displayFeatures: c.features,
              ),
              child: const CalculatorScreen(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final lines = [
        for (final l in printed)
          if (l.startsWith('${LayoutLog.prefix} 배치: '))
            l
                .substring('${LayoutLog.prefix} 배치: '.length)
                .replaceFirst(RegExp(r' @[0-9.]+ms$'), ''),
      ];
      expect(lines, [c.line]);

      expect(
        functionKeyTouchHeight(tester),
        moreOrLessEquals(c.functionKeyTouch, epsilon: 0.01),
      );

      // 넓은 배열의 숫자부는 손잡이 쪽이다 (실물 배열은 언제나 오른쪽 — numbersOnLeft 거짓)
      final keypad = tester.widget<CalcKeypad>(find.byType(CalcKeypad));
      expect(
        keypad.numbersOnLeft,
        keypad.arrangement == KeypadArrangement.wide &&
            c.handedness == Handedness.left,
      );

      // 스크린리더 읽기 순서: 활성 LCD → 계산 기록(보일 때) → 함수부 → 숫자부 (TalkBack 쓸어 넘기기로 확인한 순서)
      final order = _traversalOrder(tester);
      int indexOf(Finder f) {
        final i = order.indexOf(tester.getSemantics(f).id);
        expect(i, isNonNegative, reason: '$f');
        return i;
      }

      final lcd = indexOf(find.byType(LcdDisplay));
      final function = indexOf(_keycap(CalcKeyId.sin));
      final number = indexOf(_keycap(CalcKeyId.num7));
      expect(lcd, lessThan(function));
      expect(function, lessThan(number));
      final history = find.byType(HistoryPanel).hitTestable();
      if (history.evaluate().isNotEmpty) {
        final h = indexOf(history);
        expect(lcd, lessThan(h));
        expect(h, lessThan(function));
      }
      handle.dispose();
    });
  }
}
