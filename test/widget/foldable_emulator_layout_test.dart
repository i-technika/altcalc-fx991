import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
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

import '../support/semantics_order.dart';
import '../support/touch_metrics.dart';

// 폴더블 에뮬레이터에서 잰 접힘선 기준 배치를 위젯 테스트로 다시 그려 고정한다 (#140).
//
// 각 경우는 Android 에뮬레이터 진단 릴리스 빌드(`--dart-define=ALTCALC_LAYOUT_LOG=true`)의 logcat "시스템 영역"·"배치" 줄을
// 그대로 옮긴 것이다 — 창·인셋·제스처 영역·접힘 정보를 기기 px ÷ 밀도로 넣으면 같은 두 줄(키패드 영역 포함)이 나와야 한다.
// 에뮬레이터 기록 전체(회전·접기·TalkBack)는 CalcTheme "접힘선 기준 배치" 절의 "에뮬레이터 실측 (#140)"이다.
// 모두 Android 16(36.1) Google Play 이미지다.
// - Pixel Fold: `pixel_fold`, 밀도 2.625, 내부 화면 2208×1840px, 접힘선 x=1104px. 자유 형식 창은 `am task resize`로 만들었다.
// - 7.6" Foldable: `7.6in Foldable`, 밀도 2.625, 1768×2208px, 힌지 x=884~885px. 6.7" Flip: `6.7in Foldable`, 밀도 3,
//   1080×2636px, 힌지 y=1318~1319px. 둘 다 접은(반 접힘·닫힘) 자세에서만 폭 1px `hinge`를 보고하고(상태는 반 접힘 자세에서도
//   `postureFlat`), 완전히 펼치면 보고하지 않는다 — 에뮬레이터 한계다.
// - Flip 크기를 Pixel Fold로 흉내 냄: `wm size 1080x2636`·`wm density 480`·`display_features fold-[0,1318,1080,1318]` —
//   펼침·반 접힘 모두 폭 0 `fold`를 보고한다.
//
// 키 크기: [_Case.keyNodePx]는 #140 때 에뮬레이터 `uiautomator dump`로 잰 가장 낮은 키 노드 높이(px 정수)다. 그때는 키
// 노드가 셀과 같았으므로, 위젯이 그린 함수 키 셀 기준 터치 높이([functionKeyTouchHeight]) × 밀도와 1px 안에서 맞아야 한다.
// #236부터 셀 전체를 터치하는 키의 노드는 셀 둘레 키 사이 간격 몫까지 넓다 — 지금 다시 덤프하면 노드가 그만큼(행 간격) 높게
// 나온다. 그 값은 `calculator_screen_test.dart` "폰 세로 화면의 터치 대상 높이"와 같은 규칙(셀 + 위아래 간격 몫)이다. 스크린리더 읽기 순서는 모든 경우에 검사하지만(활성 LCD → 기록 → 함수부 쪽 키 전부 →
// 숫자부 키 전부), TalkBack 쓸어 넘기기로 실제로 확인한 것은 [_Case.talkBack]이 있는 경우와 그 범위뿐이다.

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

  /// 에뮬레이터 logcat 시스템 영역 줄 (`AltCalc 시스템 영역: ` 뒤, ` @` 앞)
  final String insetsLine;

  /// 에뮬레이터 logcat 배치 줄 (`AltCalc 배치: ` 뒤, ` @` 앞)
  final String line;

  /// 계산 기록 영역이 보이는지
  final bool hasHistory;

  /// 가장 낮은 키(함수 키)의 터치 높이 (dp, 위젯이 그린 값)
  final double functionKeyTouch;

  /// 에뮬레이터 uiautomator의 가장 낮은 키 노드 높이 (px). 재지 않은 경우(회전 중 한 프레임)는 `null`.
  final int? keyNodePx;

  /// TalkBack 쓸어 넘기기로 실제로 확인한 읽기 순서 범위 (테스트 이름에만 쓴다). 확인하지 않았으면 `null`.
  final String? talkBack;

  const _Case(
    this.name, {
    required this.density,
    required this.windowPx,
    required this.topPx,
    required this.bottomPx,
    required this.gesturePx,
    this.featuresPx = const [],
    this.handedness = Handedness.right,
    required this.insetsLine,
    required this.line,
    required this.hasHistory,
    required this.functionKeyTouch,
    required this.keyNodePx,
    this.talkBack,
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

/// Pixel Fold — 상태 표시줄 74px, 제스처 핸들 84px, 좌우 뒤로가기 78px (밀도 2.625)
const _pf = 2.625;
const _pfGestures = EdgeInsets.fromLTRB(78, 74, 78, 84);
const _pfInsets =
    '인셋 0/28.19/0/32, 시스템 바 0/28.19/0/32, 제스처 영역 29.71/28.19/29.71/32';

/// 7.6" Foldable — 상태 표시줄 63px, 제스처 핸들 84px, 좌우 뒤로가기 78px (밀도 2.625)
const _f76Gestures = EdgeInsets.fromLTRB(78, 63, 78, 84);
const _f76Insets = '인셋 0/24/0/32, 시스템 바 0/24/0/32, 제스처 영역 29.71/24/29.71/32';

/// 6.7" Flip — 상태 표시줄·제스처 핸들 72px, 좌우 뒤로가기 90px, 아래 제스처 96px (밀도 3)
const _flip = 3.0;
const _flipGestures = EdgeInsets.fromLTRB(90, 72, 90, 96);

const _noInsets = '인셋 0/0/0/0, 시스템 바 0/0/0/0, 제스처 영역 0/0/0/0';

final _cases = <_Case>[
  // ── Pixel Fold 책 자세 (세로 접힘선) — TalkBack: 오른손잡이 펼침 ──
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
        insetsLine: '창 841.14x700.95, 밀도 2.625, $_pfInsets',
        line:
            'hingeSplit — 창 841.1x701, 키패드 $keypad, '
            '화면 특징 [fold $stateName 420.6,0-420.6,701], 가로지르는 접힘선 1, 폴더블=true',
        hasHistory: true,
        functionKeyTouch: 37.56,
        keyNodePx: 98,
        talkBack: h == Handedness.right && state == _flat
            ? 'LCD→기록→함수부→숫자부'
            : null,
      ),
  // ── Pixel Fold 세로로 돌림 (가로 접힘선, 넓은 배열, 기록 없음) — TalkBack: 두 손잡이 펼침 ──
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
        insetsLine: '창 700.95x841.14, 밀도 2.625, $_pfInsets',
        line:
            'hingeStacked — 창 701x841.1, 키패드 8,579.48-692.95,801.14, '
            '화면 특징 [fold $stateName 0,420.6-701,420.6], 가로지르는 접힘선 1, 폴더블=true',
        hasHistory: false,
        functionKeyTouch: 37.68,
        keyNodePx: 99,
        talkBack: state == _flat ? 'LCD→함수부→숫자부' : null,
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
    insetsLine: '창 841.14x700.95, 밀도 2.625, $_pfInsets',
    line:
        'stacked — 창 841.1x701, 키패드 8,219.12-833.14,660.95, '
        '화면 특징 [fold postureFlat 0,420.6-701,420.6], 가로지르는 접힘선 0, 폴더블=true',
    hasHistory: false,
    functionKeyTouch: 37.56,
    keyNodePx: null,
  ),
  const _Case(
    'Pixel Fold 가로로 돌리는 중 (창은 세로, 접힘 정보는 가로 방향)',
    density: _pf,
    windowPx: Size(1840, 2208),
    topPx: 74,
    bottomPx: 84,
    gesturePx: _pfGestures,
    featuresPx: [(_fold, _flat, Rect.fromLTRB(1104, 0, 1104, 1840))],
    insetsLine: '창 700.95x841.14, 밀도 2.625, $_pfInsets',
    line:
        'stacked — 창 701x841.1, 키패드 8,258.38-692.95,801.14, '
        '화면 특징 [fold postureFlat 420.6,0-420.6,701], 가로지르는 접힘선 0, 폴더블=true',
    hasHistory: false,
    functionKeyTouch: 46.14,
    keyNodePx: null,
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
      insetsLine: '창 841.14x354.29, 밀도 2.625, $_noInsets',
      line:
          'hingeSplit (LCD 옆 패널) — 창 841.1x354.3, 키패드 $keypad, '
          '화면 특징 [fold postureFlat 420.6,0-420.6,354.3], 가로지르는 접힘선 1, 폴더블=true',
      hasHistory: false,
      functionKeyTouch: CalcTheme.keyTouchHeightFloor,
      keyNodePx: 73,
    ),
  // ── 가로 접힘선을 지나는 자유 형식 창 1103×1767px (인셋 없음) ──
  const _Case(
    'Pixel Fold 자유 형식 창 420×673 (가로 접힘선)',
    density: _pf,
    windowPx: Size(1103, 1767),
    topPx: 0,
    bottomPx: 0,
    gesturePx: EdgeInsets.zero,
    featuresPx: [(_fold, _flat, Rect.fromLTRB(0, 883, 1103, 883))],
    insetsLine: '창 420.19x673.14, 밀도 2.625, $_noInsets',
    line:
        'hingeStacked — 창 420.2x673.1, 키패드 8,344.38-412.19,665.14, '
        '화면 특징 [fold postureFlat 0,336.4-420.2,336.4], 가로지르는 접힘선 1, 폴더블=true',
    hasHistory: false,
    functionKeyTouch: 27.26,
    keyNodePx: 71,
  ),
  // ── 7.6" Foldable (Galaxy Z Fold형) — 접힘 정보는 반 접힘 자세(posture 2)에서 postureFlat,
  // 닫힘 자세(1)에서 postureHalfOpened로 온다 ──
  for (final (state, stateName, posture) in [
    (_flat, 'postureFlat', '반 접힘 자세'),
    (_half, 'postureHalfOpened', '닫힘 자세'),
  ])
    _Case(
      '7.6" Foldable 책 자세 ($posture)',
      density: _pf,
      windowPx: const Size(1768, 2208),
      topPx: 63,
      bottomPx: 84,
      gesturePx: _f76Gestures,
      featuresPx: [(_hinge, state, const Rect.fromLTRB(884, 0, 885, 2208))],
      insetsLine: '창 673.52x841.14, 밀도 2.625, $_f76Insets',
      line:
          'hingeSplit — 창 673.5x841.1, 키패드 345.14,373.97-665.52,801.14, '
          '화면 특징 [hinge $stateName 336.8,0-337.1,841.1], 가로지르는 접힘선 1, 폴더블=true',
      hasHistory: true,
      functionKeyTouch: 36.31,
      keyNodePx: 95,
    ),
  const _Case(
    '7.6" Foldable 가로로 돌림 (넓은 배열 + 기록)',
    density: _pf,
    windowPx: Size(2208, 1768),
    topPx: 63,
    bottomPx: 84,
    gesturePx: _f76Gestures,
    featuresPx: [(_hinge, _flat, Rect.fromLTRB(0, 883, 2208, 884))],
    insetsLine: '창 841.14x673.52, 밀도 2.625, $_f76Insets',
    line:
        'hingeStacked — 창 841.1x673.5, 키패드 8,366.49-833.14,633.52, '
        '화면 특징 [hinge postureFlat 0,336.4-841.1,336.8], 가로지르는 접힘선 1, 폴더블=true',
    hasHistory: true,
    functionKeyTouch: 45.40,
    keyNodePx: 119,
    talkBack: 'LCD→기록→함수부→숫자부',
  ),
  for (final (state, stateName, posture) in [
    (_flat, 'postureFlat', '반 접힘 자세'),
    (_half, 'postureHalfOpened', '닫힘 자세'),
  ])
    _Case(
      '7.6" Foldable 가로 화면의 좌우 분할 창 (오른쪽, 약 416×674, $posture)',
      density: _pf,
      windowPx: const Size(1091, 1768),
      topPx: 63,
      bottomPx: 84,
      gesturePx: const EdgeInsets.fromLTRB(0, 63, 78, 84),
      featuresPx: [(_hinge, state, const Rect.fromLTRB(0, 883, 1091, 884))],
      insetsLine:
          '창 415.62x673.52, 밀도 2.625, 인셋 0/24/0/32, 시스템 바 0/24/0/32, '
          '제스처 영역 0/24/29.71/32',
      line:
          'hingeStacked — 창 415.6x673.5, 키패드 8,344.76-407.62,633.52, '
          '화면 특징 [hinge $stateName 0,336.4-415.6,336.8], 가로지르는 접힘선 1, 폴더블=true',
      hasHistory: false,
      functionKeyTouch: 24.55,
      keyNodePx: 64,
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
    insetsLine:
        '창 360x878.67, 밀도 3, 인셋 0/24/0/24, 시스템 바 0/24/0/24, 제스처 영역 30/24/30/32',
    line:
        'hingeStacked — 창 360x878.7, 키패드 8,447.67-352,846.67, '
        '화면 특징 [hinge postureFlat 0,439.3-360,439.7], 가로지르는 접힘선 1, 폴더블=true',
    hasHistory: true,
    functionKeyTouch: 33.91,
    keyNodePx: 101,
    talkBack: 'LCD→기록→함수부, 숫자부까지는 쓸지 않음',
  ),
  const _Case(
    'Flip 완전히 펼침 (에뮬레이터는 접힘 정보 없음)',
    density: _flip,
    windowPx: Size(1080, 2636),
    topPx: 72,
    bottomPx: 72,
    gesturePx: _flipGestures,
    insetsLine:
        '창 360x878.67, 밀도 3, 인셋 0/24/0/24, 시스템 바 0/24/0/24, 제스처 영역 30/24/30/32',
    line:
        'stacked — 창 360x878.7, 키패드 8,388-352,846.67, '
        '화면 특징 [], 가로지르는 접힘선 0, 폴더블=true',
    hasHistory: false,
    functionKeyTouch: 38.99,
    keyNodePx: 116,
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
      insetsLine: '창 360x878.67, 밀도 3, 인셋 0/28/0/24, 시스템 바 0/28/0/24, 제스처 영역 30/28/30/32',
      line:
          'hingeStacked — 창 360x878.7, 키패드 8,447.33-352,846.67, '
          '화면 특징 [fold $stateName 0,439.3-360,439.3], 가로지르는 접힘선 1, 폴더블=true',
      hasHistory: true,
      functionKeyTouch: 33.94,
      keyNodePx: 101,
    ),
];

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

/// 함수부 쪽 키(상단 조작부 — 설정 키 ON 포함 —, 커서 패드, 함수부)와 숫자부 키
final _functionSideKeys = [
  for (final rows in [controlLeftRows, controlRightRows, functionRows])
    for (final row in rows)
      for (final def in row) def.id,
  for (final def in cursorPad.all) def.id,
];
final _numberKeys = [
  for (final row in numberRows)
    for (final def in row) def.id,
];

/// [log]에서 [kind] 줄(`AltCalc <kind>: `)들을 시각(` @…ms`)을 떼고 돌려준다
List<String> _linesOf(List<String> log, String kind) => [
  for (final l in log)
    if (l.startsWith('${LayoutLog.prefix} $kind: '))
      l
          .substring('${LayoutLog.prefix} $kind: '.length)
          .replaceFirst(RegExp(r' @[0-9.]+ms$'), ''),
];

void main() {
  for (final c in _cases) {
    final tb = c.talkBack == null ? '' : ' (TalkBack 확인: ${c.talkBack})';
    testWidgets('${c.name}: 에뮬레이터 로그와 같은 배치$tb', (tester) async {
      final printed = <String>[];
      LayoutLog.enable(sink: printed.add, frameTimings: false);
      addTearDown(LayoutLog.disable);

      final size = c.window;
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.displayFeatures = c.features;
      addTearDown(tester.view.resetDisplayFeatures);
      SharedPreferences.setMockInitialValues({
        HandednessNotifier.storageKey: c.handedness.storageValue,
      });
      final prefs = await SharedPreferences.getInstance();
      final foldable = ValueNotifier(true);
      addTearDown(foldable.dispose);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          foldableDeviceProvider.overrideWithValue(foldable),
        ],
      );
      addTearDown(container.dispose);
      final handle = tester.ensureSemantics();
      try {
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

        // 에뮬레이터 logcat과 같은 두 줄
        expect(_linesOf(printed, '시스템 영역'), [c.insetsLine]);
        expect(_linesOf(printed, '배치'), [c.line]);

        // 키 크기 — 위젯이 그린 값, 그리고 에뮬레이터 노드 높이(px 정수)와 1px 안. 실측(#140) 때 키 노드는 셀과 같았다 —
        // #236부터 키 노드는 셀 둘레 키 사이 간격 몫까지 넓으므로, 셀 기준 터치 높이([functionKeyTouchHeight])와 견준다.
        final touch = functionKeyTouchHeight(tester);
        expect(touch, moreOrLessEquals(c.functionKeyTouch, epsilon: 0.01));
        if (c.keyNodePx != null) {
          expect((touch * c.density - c.keyNodePx!).abs(), lessThan(1.0));
        }

        // 계산 기록 영역 유무
        final history = find.byType(HistoryPanel);
        expect(history, c.hasHistory ? findsOneWidget : findsNothing);
        final lcdRect = tester.getRect(find.byType(LcdDisplay));
        final keypadRect = tester.getRect(
          find.byKey(const ValueKey('calc-keypad')),
        );

        final historyRect = c.hasHistory ? tester.getRect(history) : null;
        final regions = <String, Rect>{
          'LCD': lcdRect,
          '키패드': keypadRect,
          '기록': ?historyRect,
        };

        // LCD·기록·키패드는 서로 겹치지 않는다
        final names = regions.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final a = regions[names[i]]!;
            final b = regions[names[j]]!;
            final o = a.intersect(b);
            expect(
              o.width <= 0.01 || o.height <= 0.01,
              isTrue,
              reason: '${names[i]} $a ↔ ${names[j]} $b',
            );
          }
        }

        final keypad = tester.widget<CalcKeypad>(find.byType(CalcKeypad));
        final sin = tester.getRect(_keycap(CalcKeyId.sin));
        final seven = tester.getRect(_keycap(CalcKeyId.num7));

        // 접힘선 기준 배치: 세 영역이 접힘선 양쪽 간격 띠에 걸치지 않고, 패널 배정이 기록대로다
        if (c.line.startsWith('hinge')) {
          final hinge = FormFactor.hingeOf(size, c.features);
          expect(hinge, isNotNull);
          final b = hinge!.bounds;
          final vertical = FormFactor.isVerticalHinge(b);
          const m = CalcTheme.screenHingeMargin - 0.01;
          bool before(Rect r) =>
              vertical ? r.right <= b.left - m : r.bottom <= b.top - m;
          bool after(Rect r) =>
              vertical ? r.left >= b.right + m : r.top >= b.bottom + m;
          for (final e in regions.entries) {
            expect(
              before(e.value) || after(e.value),
              isTrue,
              reason: '${e.key} ${e.value}',
            );
          }
          if (vertical) {
            // 책 자세: 키패드는 손 쪽 패널, 기록은 반대쪽 패널. 손 쪽 패널이 짧으면 활성 LCD도 반대쪽 패널이다.
            final keypadOnRight = after(keypadRect);
            expect(keypadOnRight, c.handedness == Handedness.right);
            if (historyRect != null) {
              expect(after(historyRect), !keypadOnRight);
            }
            final lcdBeside = c.line.contains('(LCD 옆 패널)');
            expect(after(lcdRect), lcdBeside ? !keypadOnRight : keypadOnRight);
          } else {
            // 가로 접힘선: 키패드는 아래 패널, 활성 LCD·기록은 위 패널
            expect(after(keypadRect), isTrue);
            expect(before(lcdRect), isTrue);
            if (historyRect != null) {
              expect(before(historyRect), isTrue);
              if (keypad.arrangement == KeypadArrangement.wide) {
                // 넓은 배열: 기록은 함수부 위, 활성 LCD는 숫자부 위
                double dx(Rect a, Rect b) => (a.center.dx - b.center.dx).abs();
                expect(
                  dx(historyRect, sin) < dx(historyRect, seven),
                  isTrue,
                  reason: '기록 $historyRect',
                );
                expect(
                  dx(lcdRect, seven) < dx(lcdRect, sin),
                  isTrue,
                  reason: 'LCD $lcdRect',
                );
              } else {
                // 실물 배열: 활성 LCD 아래에 기록
                expect(historyRect.top, greaterThan(lcdRect.bottom));
              }
            }
          }
        }

        // 숫자부 위치: 넓은 배열은 손잡이 쪽(실물 배열은 함수부 아래)
        if (keypad.arrangement == KeypadArrangement.wide) {
          expect(
            seven.center.dx < sin.center.dx,
            c.handedness == Handedness.left,
          );
          expect(keypad.numbersOnLeft, c.handedness == Handedness.left);
        } else {
          expect(seven.top, greaterThan(sin.bottom));
        }

        // 스크린리더 읽기 순서: 활성 LCD → 계산 기록(있으면) → 함수부 쪽 키 전부 → 숫자부 키 전부
        final order = semanticsTraversalOrder(tester);
        final lcd = semanticsIndexIn(tester, order, find.byType(LcdDisplay));
        final functionIdx = [
          for (final id in _functionSideKeys)
            semanticsIndexIn(tester, order, _keycap(id)),
        ];
        final numberIdx = [
          for (final id in _numberKeys)
            semanticsIndexIn(tester, order, _keycap(id)),
        ];
        final firstFunction = functionIdx.reduce((a, b) => a < b ? a : b);
        final lastFunction = functionIdx.reduce((a, b) => a > b ? a : b);
        final firstNumber = numberIdx.reduce((a, b) => a < b ? a : b);
        expect(lcd, lessThan(firstFunction));
        expect(lastFunction, lessThan(firstNumber));
        if (c.hasHistory) {
          final h = semanticsIndexIn(tester, order, history);
          expect(lcd, lessThan(h));
          expect(h, lessThan(firstFunction));
        }
      } finally {
        handle.dispose();
      }
    });
  }
}
