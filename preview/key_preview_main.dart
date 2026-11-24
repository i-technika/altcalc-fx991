// 개발용 키패드·화면 미리보기 실행기 (#21).
//
// 실제 앱 화면([CalculatorScreen])을 기기 크기 틀 안에 띄우고, 키 입력 로그를 옆에 보여준다.
// 키패드 배열을 따로 구현하지 않고 앱과 같은 루트([AltCalcApp])·위젯·상태(provider)를 그대로 쓴다.
//
// 실행: flutter run -d chrome -t preview/key_preview_main.dart  (VS Code: "Key Preview (Chrome)")
//
// 앱 릴리스 빌드에 포함되지 않는다 — 앱 진입점은 lib/main.dart이고 lib/에서 이 파일로 가는 import가 없으며
// pubspec 에셋에도 preview/가 없다(test/widget/key_preview_test.dart가 검증).
//
// TODO(#18): M6의 광고·인앱결제 플러그인은 웹 구현이 없으므로, 미리보기에서는 광고 슬롯을 빈 슬롯으로
// 덮어쓸 수 있게(provider 주입 등) 연결 구조를 정한다. CI가 이 파일을 웹으로 빌드한다(Sub-issue Linux CI).
import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart'
    show clampDouble, listEquals, precisionErrorTolerance;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/main.dart' show AltCalcApp;
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/screen_coordinate_root.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(
  ProviderScope(
    child: AltCalcApp(
      frameBuilder: (context, screen) => KeyPreviewScreen(screen: screen),
    ),
  ),
);

/// 미리보기 화면 크기 프리셋 (논리 픽셀, dp).
///
/// 대표 기기의 화면 크기를 근사한 값이다. [padding]은 시스템 인셋이다 — 상태 표시줄(위),
/// 홈 표시줄·내비게이션 바·작업 표시줄(아래). Android 15 이상은 edge-to-edge가 강제되어
/// 내비게이션 바 높이(3버튼 48dp, 제스처 약 24dp)가 아래 인셋으로 들어온다.
/// [systemGestureInsets]는 Android가 보고하는 시스템 제스처 영역이다(#50).
/// [displayFeatures]는 폴더블의 접힘선(힌지) 등 화면 특징이다(#51).
///
/// [foldable] 프리셋(폴더블 내부 화면)은 조작 패널에서 자세(펼침/반 접힘)와 방향(세로/가로)을 고를 수 있다(#93).
/// 앱이 세로로 고정하는 화면(Galaxy Z Flip 내부 등, [orientations])은 자세만 고른다(#104).
/// 이때 [size]·[padding]·[systemGestureInsets]·[displayFeatures]는 기기를 **기본 방향**([naturalOrientation])으로
/// 들고 **펼친** 상태의 값이고, 고른 자세·방향의 화면은 [posed]가 계산한다. 자세·방향마다 프리셋을 복제하지 않는
/// 이유: 기기 하나의 값이 한 곳에만 있어야 돌린 화면의 크기·접힘선이 원래 값과 어긋나지 않는다.
@immutable
class PreviewDevice {
  /// 표시 이름
  final String name;

  /// 화면 크기 (dp)
  final Size size;

  /// 시스템 인셋 (dp) — `MediaQuery.padding`/`viewPadding`으로 전달한다
  final EdgeInsets padding;

  /// 시스템 제스처 영역 (dp) — `MediaQuery.systemGestureInsets`로 전달한다.
  ///
  /// 이 영역에서 시작한 키 터치는 손을 뗄 때 확정된다(`CalcKeyButton`). 값은 근사다.
  /// - iOS: Flutter가 전달하지 않으므로 0이다.
  /// - Android: `WindowInsets.Type.systemGestures()`의 네 변이 그대로 들어온다. 위·아래는 상태 표시줄
  ///   (알림창 끌어내리기)·내비게이션 바 영역과 같게 두고, 제스처 내비게이션이면 좌우에 뒤로가기 영역
  ///   ([previewBackGestureWidth])을 더한다. 실제 아래 제스처 영역은 기기에 따라 이보다 클 수 있다.
  final EdgeInsets systemGestureInsets;

  /// 화면 특징 (접힘선·힌지 등, 영역은 화면 좌표 dp) — `MediaQuery.displayFeatures`로 전달한다 (#51).
  ///
  /// 실제 앱에서는 Android Jetpack WindowManager의 `FoldingFeature`가 들어온다. 화면을 펼친 폴더블은
  /// 폭 0인 접힘선(`DisplayFeatureType.fold`, `postureFlat`)을 보고한다. 값은 근사다.
  final List<DisplayFeature> displayFeatures;

  /// 폴더블 내부 화면인지 — 자세를 고를 수 있고, 방향은 [orientations]가 둘 이상일 때만 고른다([posed], #93·#104).
  /// 접힘선([displayFeatures])이 있어야 한다.
  final bool foldable;

  /// 자세·방향을 적용한 화면이면 적용하기 전의 프리셋, 프리셋이면 `null` ([base] 참조)
  final PreviewDevice? _base;

  const PreviewDevice(
    this.name,
    this.size, {
    this.padding = EdgeInsets.zero,
    this.systemGestureInsets = EdgeInsets.zero,
    this.displayFeatures = const [],
    this.foldable = false,
  }) : _base = null;

  PreviewDevice._posed(
    PreviewDevice base,
    this.size, {
    required this.displayFeatures,
  }) : _base = base,
       name = base.name,
       padding = base.padding,
       systemGestureInsets = base.systemGestureInsets,
       foldable = base.foldable;

  /// 자세·방향을 적용하기 전의 프리셋 (기본 방향으로 펼친 값). 프리셋이면 자기 자신이다.
  PreviewDevice get base => _base ?? this;

  /// 칩에 표시할 이름 (예: `일반 폰 390×844`)
  String get label =>
      '$name ${size.width.toStringAsFixed(0)}×${size.height.toStringAsFixed(0)}';

  /// 기본 방향 — 프리셋([base]) 크기가 가로로 길면 가로, 아니면 세로 (Galaxy Z Fold 내부는 세로, Pixel Fold
  /// 내부는 가로). 자세·방향을 적용한 화면도 원래 프리셋의 기본 방향을 답한다.
  PreviewOrientation get naturalOrientation =>
      base.size.width > base.size.height
      ? PreviewOrientation.landscape
      : PreviewOrientation.portrait;

  /// 앱 화면이 돌 수 있는 방향 (#104). 순서는 [PreviewOrientation.values] 그대로다 — 조작 패널 버튼 순서가 기기마다
  /// 바뀌지 않게 한다. [naturalOrientation]은 항상 들어 있다.
  ///
  /// 폴더블 프리셋은 앱의 방향 정책([FormFactor.orientationPolicyOf], 폴더블 기기·프리셋 크기 = 물리 화면 크기)을 따른다.
  /// 짧은 변이 [FormFactor.largeScreenMinShortestSide] 미만인 화면(Flip 내부)은 앱이 세로로 고정하므로 세로뿐이고,
  /// Fold 계열 내부 화면은 네 방향을 허용하므로 세로·가로 둘 다다. 폴더블이 아니면 고를 수 없으므로 기본 방향뿐이다.
  List<PreviewOrientation> get orientations {
    final base = this.base;
    final natural = base.naturalOrientation;
    if (!base.foldable) return [natural];
    final allowed = switch (FormFactor.orientationPolicyOf(
      DeviceKind.foldable,
      base.size,
    )) {
      OrientationPolicy.portrait => const [PreviewOrientation.portrait],
      OrientationPolicy.landscape => const [PreviewOrientation.landscape],
      OrientationPolicy.any => PreviewOrientation.values,
    };
    assert(allowed.contains(natural), '${base.name}: 기본 방향을 앱이 허용하지 않는다');
    return allowed;
  }

  /// [posture] 자세로 [orientation] 방향으로 든 화면 (#93). [foldable]이 아니면 그대로 돌려준다.
  /// 항상 [base](기본 방향으로 펼친 프리셋) 기준으로 계산하므로, 자세·방향을 적용한 화면에 다시 불러도
  /// 결과는 [posture]·[orientation] 그대로다(겹쳐 돌지 않는다). 기본 방향으로 펼친 상태면 [base] 자신이다.
  ///
  /// - [orientation]은 [orientations] 중 하나여야 한다 (#104, 디버그 빌드에서 assert로 확인) — 앱이 돌지 않는
  ///   방향(세로 고정 화면의 가로)은 조작 패널에서 고를 수 없으므로, 그런 값이 오면 호출하는 쪽의 버그다.
  /// - 방향이 기본 방향과 다르면 기기를 반시계 방향으로 90° 돌린 화면이다: 크기의 가로·세로가 바뀌고,
  ///   화면 특징 영역은 기본 방향 화면의 위 가장자리가 왼쪽 가장자리가 되도록 옮긴다(가운데 접힘선은 돌리는
  ///   방향과 상관없이 같은 자리다).
  /// - 접힘선·힌지(fold·hinge)의 상태는 [posture]의 상태가 된다. 영역은 자세와 상관없다 — Jetpack
  ///   WindowManager는 반 접어도 같은 영역을 보고한다. 화면 구멍 등 다른 특징은 상태를 바꾸지 않는다.
  /// - 시스템 인셋·제스처 영역은 화면 기준으로 그대로 둔다: 대화면에서는 돌려도 상태 표시줄은 위, 제스처
  ///   내비게이션 표시줄은 아래, 뒤로가기 영역은 좌우에 남는다(근사 — 화면 구멍 쪽 인셋은 흉내 내지 않는다).
  /// - 결과의 [name]·인셋·[foldable]은 [base]와 같다.
  PreviewDevice posed(
    PreviewFoldPosture posture,
    PreviewOrientation orientation,
  ) {
    final base = this.base;
    if (!base.foldable) return base;
    assert(
      base.orientations.contains(orientation),
      '${base.name}: 앱이 돌지 않는 방향 $orientation',
    );
    final rotate = orientation != base.naturalOrientation;
    if (!rotate && posture == PreviewFoldPosture.flat) return base;
    final w = base.size.width;
    return PreviewDevice._posed(
      base,
      rotate ? base.size.flipped : base.size,
      displayFeatures: [
        for (final f in base.displayFeatures)
          DisplayFeature(
            bounds: rotate
                ? Rect.fromLTRB(
                    f.bounds.top,
                    w - f.bounds.right,
                    f.bounds.bottom,
                    w - f.bounds.left,
                  )
                : f.bounds,
            type: f.type,
            state: FormFactor.hasFoldOrHinge([f]) ? posture.state : f.state,
          ),
      ],
    );
  }
}

/// 폴더블 내부 화면의 자세 (#93)
enum PreviewFoldPosture {
  /// 펼침 — 접힘선 상태 `postureFlat`
  flat('펼침', DisplayFeatureState.postureFlat),

  /// 반 접힘 — 접힘선 상태 `postureHalfOpened`. 세로 접힘선이면 책 자세, 가로 접힘선이면 테이블톱 자세다.
  halfOpened('반 접힘', DisplayFeatureState.postureHalfOpened);

  /// 패널 표시 이름
  final String label;

  /// 접힘선에 넣을 상태
  final DisplayFeatureState state;

  const PreviewFoldPosture(this.label, this.state);
}

/// 기기를 든 방향 (#93)
enum PreviewOrientation {
  /// 세로 (높이 ≥ 폭)
  portrait('세로'),

  /// 가로 (폭 > 높이)
  landscape('가로');

  /// 패널 표시 이름
  final String label;

  const PreviewOrientation(this.label);
}

/// Android 제스처 내비게이션의 뒤로가기 영역 폭 근사값 (좌우 각각, dp).
/// 실제 폭은 Android 버전·뒤로가기 감도 설정·제조사에 따라 다르다(더 넓은 기기도 있다).
const double previewBackGestureWidth = 24;

/// 제스처 내비게이션 Android 기기의 시스템 제스처 영역 (상태 표시줄 24, 뒤로가기 좌우, 홈 24)
const EdgeInsets _gestureNavInsets = EdgeInsets.fromLTRB(
  previewBackGestureWidth,
  24,
  previewBackGestureWidth,
  24,
);

/// Galaxy Z Fold5 내부 화면(690×829, 세로)을 펼쳤을 때의 접힘선 근사값.
///
/// 펼친 폴더블은 Jetpack WindowManager 문서상 폭 0인 접힘선을 `FOLD`·`FLAT`으로 보고하므로, 물리 화면
/// (1812×2176 px) 가운데(x=906 px)에 위에서 아래까지 가로지르는 세로 접힘선이 올 것으로 본다.
/// 밀도 2.625(420dpi, 기본 화면 크기 설정) 가정으로 dp로 바꾸면 화면 690.29×828.95, 접힘선 x=345.14이며,
/// 프리셋 크기에 맞춰 정수로 반올림했다. 밀도는 기기 화면 크기(확대/축소) 설정에 따라 달라진다.
/// 보고 값·밀도 모두 실기기 미확인이다.
const DisplayFeature previewFoldInnerFold = DisplayFeature(
  bounds: Rect.fromLTWH(345, 0, 0, 829),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

/// Pixel Fold 내부 화면(841×701, 가로가 기본 방향)을 펼쳤을 때의 접힘선 근사값 (#93).
///
/// 물리 화면 2208×1840 px 가운데(x=1104 px)의 세로 접힘선을 밀도 2.625 가정으로 dp로 바꾼 값이다(화면
/// 841.1×701.0, 접힘선 x=420.6 — 프리셋 크기 841의 가운데 420.5로 맞췄다). 보고 값·밀도 모두 실기기 미확인이다.
const DisplayFeature previewLandscapeFoldInnerFold = DisplayFeature(
  bounds: Rect.fromLTWH(420.5, 0, 0, 701),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

/// Galaxy Z Flip5·Flip6 내부 화면(411×1006, 세로)을 펼쳤을 때의 접힘선 근사값 (#104).
///
/// 물리 화면 1080×2640 px(Samsung 공개 사양의 내부 화면 해상도) 가운데(y=1320 px)를 왼쪽에서 오른쪽까지 가로지르는
/// 가로 접힘선을 밀도 2.625(420dpi, 기본 화면 크기 설정) 가정으로 dp로 바꾼 값이다(화면 411.43×1005.71, 접힘선
/// y=502.86 — 프리셋 크기를 정수로 반올림하고 접힘선은 그 가운데 503으로 맞췄다). 배치 테스트(`split_layout_test` 등)의
/// Flip 근사도 같은 값을 쓴다. 밀도는 자료에 따라 2.75(393×960dp)로 적힌 것도 있다 — 그 크기로도 반 접힘 테이블톱의
/// 가장 낮은 키 터치 높이가 일반 하한(28dp)을 넘어(#104 리뷰 실측 약 31~33dp) 배치·방향 판정은 같다.
/// 보고 값·밀도 모두 실기기 미확인이다.
const DisplayFeature previewFlipInnerFold = DisplayFeature(
  bounds: Rect.fromLTWH(0, 503, 411, 0),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

/// Flip 내부 화면의 상태 표시줄 높이 근사값 (dp) — 화면 위 가운데의 카메라 구멍 때문에 구멍 없는 화면(24dp)보다
/// 높게 잡았다(배치 테스트 `split_layout_test`·`top_strip_test`의 Flip 근사와 같다). 실기기 미확인이다.
const double _flipStatusBarHeight = 32;

/// 미리보기 프리셋 목록. 첫 항목이 기본값이다.
const List<PreviewDevice> previewDevices = [
  // iPhone 14·13 (상태 표시줄 47, 홈 표시줄 34)
  PreviewDevice(
    '일반 폰',
    Size(390, 844),
    padding: EdgeInsets.only(top: 47, bottom: 34),
  ),
  // 소형 Android, 3버튼 내비게이션 (키패드가 가장 압박받는 경우)
  PreviewDevice(
    '소형 폰',
    Size(360, 640),
    padding: EdgeInsets.only(top: 24, bottom: 48),
    systemGestureInsets: EdgeInsets.only(top: 24, bottom: 48),
  ),
  // iPhone 15 Pro Max
  PreviewDevice(
    '대형 폰',
    Size(430, 932),
    padding: EdgeInsets.only(top: 59, bottom: 34),
  ),
  // Galaxy Z Fold5 커버, 제스처 내비게이션 (뒤로가기 영역 좌우 약 24dp)
  PreviewDevice(
    '폴더블 커버',
    Size(344, 882),
    padding: EdgeInsets.only(top: 24, bottom: 24),
    systemGestureInsets: _gestureNavInsets,
  ),
  // Galaxy Z Fold5 내부, 펼친 상태: 화면 가운데의 세로 접힘선을 기준으로 LCD/키패드를 좌우로 나눈다(#25).
  // 자세·방향을 고를 수 있다(#93) — 가로로 돌려 반 접으면 테이블톱 배치, 펼친 채 돌리면 위아래 배치다.
  PreviewDevice(
    '폴더블 내부',
    Size(690, 829),
    padding: EdgeInsets.only(top: 24, bottom: 24),
    systemGestureInsets: _gestureNavInsets,
    displayFeatures: [previewFoldInnerFold],
    foldable: true,
  ),
  // Pixel Fold 내부, 가로가 기본 방향 (#93). 인셋은 Fold5 내부와 같게 근사했다.
  // 펼치면 세로 접힘선 기준 좌우 배치, 세로로 돌려 반 접으면 테이블톱 배치다.
  PreviewDevice(
    '가로형 폴더블 내부',
    Size(841, 701),
    padding: EdgeInsets.only(top: 24, bottom: 24),
    systemGestureInsets: _gestureNavInsets,
    displayFeatures: [previewLandscapeFoldInnerFold],
    foldable: true,
  ),
  // Galaxy Z Flip 내부, 제스처 내비게이션 (#104). 짧은 변이 600dp 미만이라 앱이 세로로 고정하므로 자세만 고른다.
  // 펼치면 가로 접힘선을 배치에 쓰지 않는 위아래 배치, 반 접으면(Flex 모드) 테이블톱 배치다.
  // 출고 기본 내비게이션은 One UI 버전에 따라 3버튼(아래 48dp)일 수 있다. 제스처로 둔 것은 폭을 다 쓰는 키패드의
  // 바깥쪽 열이 좌우 뒤로가기 영역에 걸리는 것을 이 프리셋에서 보기 위해서다 — 3버튼(아래 48dp)이어도 반 접힘
  // 테이블톱의 가장 낮은 키 터치 높이는 약 33dp로 일반 하한을 넘는다(#104 리뷰 실측).
  PreviewDevice(
    '플립형 폴더블 내부',
    Size(411, 1006),
    padding: EdgeInsets.only(top: _flipStatusBarHeight, bottom: 24),
    systemGestureInsets: EdgeInsets.fromLTRB(
      previewBackGestureWidth,
      _flipStatusBarHeight,
      previewBackGestureWidth,
      24,
    ),
    displayFeatures: [previewFlipInnerFold],
    foldable: true,
  ),
  // 10인치급 Android 태블릿, 작업 표시줄 48dp (3버튼 — 좌우 제스처 영역 없음)
  PreviewDevice(
    '태블릿 세로',
    Size(800, 1280),
    padding: EdgeInsets.only(top: 24, bottom: 48),
    systemGestureInsets: EdgeInsets.only(top: 24, bottom: 48),
  ),
  // 태블릿 가로: LCD/키패드 좌우 분할 배치 (#24). 손잡이는 화면의 설정 버튼으로 바꾼다 —
  // 대화상자는 기기 틀 안에 그 기기의 크기·글자 배율로 뜬다 (#72).
  PreviewDevice(
    '태블릿 가로',
    Size(1280, 800),
    padding: EdgeInsets.only(top: 24, bottom: 48),
    systemGestureInsets: EdgeInsets.only(top: 24, bottom: 48),
  ),
  // 같은 태블릿을 제스처 내비게이션으로 쓰는 경우 (#62): 좌우에 뒤로가기 영역이 생겨, 화면 오른쪽(왼손잡이면
  // 왼쪽) 끝에 붙은 키패드의 바깥쪽 열 키 중 화면 가장자리 쪽 일부(뒤로가기 영역 안)에서 시작한 터치는 손을 뗄 때
  // 입력된다 — 같은 키라도 가운데를 누르면 바로 입력된다. 아래는 AOSP·Pixel 대화면의 임시 작업 표시줄(평소에는
  // 숨고 제스처 핸들만 남음)을 가정해 폴더블 내부와 같게 근사했다. Samsung 등 제스처 내비게이션에서도 작업
  // 표시줄을 항상 보이게 하는 기기는 아래 인셋이 이보다 크다. 값은 실기기 미확인이다.
  PreviewDevice(
    '태블릿 가로 (제스처)',
    Size(1280, 800),
    padding: EdgeInsets.only(top: 24, bottom: 24),
    systemGestureInsets: _gestureNavInsets,
  ),
  // 분할 화면의 위쪽 창 (상태 표시줄만 걸친다, 3버튼 내비게이션 가정 — 좌우 제스처 영역 없음).
  // 짧은 창이라 위아래 배치보다 키가 큰 좌우 분할로 그린다(#38) — 손잡이를 바꾸면 키패드가 옮겨 간다.
  PreviewDevice(
    '분할 화면 위',
    Size(390, 420),
    padding: EdgeInsets.only(top: 24),
    systemGestureInsets: EdgeInsets.only(top: 24),
  ),
  // 키를 쓸 수 없을 만큼 작은 팝업 창 — 계산기 대신 창을 키워 달라는 안내가 나온다(#38). 다른 기기로 바꾸면
  // 계산기가 입력 상태 그대로 돌아온다.
  PreviewDevice('작은 팝업 창', Size(320, 240)),
];

/// 기본 시스템 글자 배율
const double previewDefaultTextScale = 1.0;

/// 미리보기 시스템 글자 배율 선택지 (Android 최소 85% ~ 최대 200%, 선형 근사).
///
/// 키패드·LCD는 [CalcTheme.keyMaxTextScaleFactor]·[CalcTheme.lcdMaxTextScaleFactor](130%)에서 배율을
/// 자르므로, 200%는 그 잘림이 지켜지는지 확인하는 용도다. Android 14 이상의 비선형 배율은 흉내 내지 않는다.
const List<double> previewTextScales = [0.85, 1.0, 1.3, 2.0];

/// 기기 틀 둘레 여백 (dp)
const double previewFrameMargin = 16;

/// 기기 틀 위 캡션(기기·배율 표시) 줄 높이 (dp)
const double previewFrameCaptionHeight = 24;

/// 입력 로그 기본 최대 보관 줄 수 (오래된 것부터 버린다)
const int previewLogCapacity = 500;

/// 미리보기가 구독하는 상태 조각: (모디파이어 대기, 입력 수, 마지막 입력)
typedef PreviewWatch = (KeyModifier, int, KeyInput?);

PreviewWatch _watchOf(CalcState s) => (s.modifier, s.inputCount, s.lastInput);

/// 입력 로그 한 줄. 기능 입력이면 [number](초기화 이후 몇 번째 입력, 1부터)와 [layer]가 있고,
/// 모디파이어 대기 변화면 둘 다 `null`이다.
typedef PreviewLogEntry = ({int? number, String text, KeyLayer? layer});

/// 기능 입력 문구 (예: `SOLVE  ← SHIFT + CALC`, `◄ (반복)`)
String describePreviewInput(KeyInput input) {
  final key = keyDefOf(input.id).mainLabel;
  return switch (input.layer) {
    KeyLayer.main => input.isRepeat ? '${input.label} (반복)' : input.label,
    KeyLayer.shift => '${input.label}  ← SHIFT + $key',
    KeyLayer.alpha => '${input.label}  ← ALPHA + $key',
  };
}

/// 입력 없이 모디파이어 대기만 바뀐 경우의 문구. 바뀌지 않았으면 `null`.
/// (예: `[SHIFT 대기]`, SHIFT → ALPHA는 `[ALPHA 대기]`, 기능 없는 층의 키·같은 키 다시 누름은 `[SHIFT 해제]`)
String? describePreviewModifierChange(KeyModifier before, KeyModifier after) {
  String name(KeyModifier m) => m == KeyModifier.shift ? 'SHIFT' : 'ALPHA';
  if (before == after) return null;
  if (after != KeyModifier.none) return '[${name(after)} 대기]';
  return '[${name(before)} 해제]';
}

/// 조작 패널(기기·글자 배율·입력 로그) + 기기 틀 속 실제 계산기 화면.
/// 넓은 창은 좌우, 좁은 창([narrowWidth] 미만)은 위아래로 배치한다.
///
/// ## Navigator 구조 (#72)
/// `AltCalcApp.frameBuilder`로 앱을 감싸므로 [screen]은 **앱의 루트 Navigator**(첫 화면 `CalculatorScreen`)와
/// 그 위의 대비 테마(가장 가까운 MediaQuery의 고대비 설정으로 고르는 `AnimatedTheme`, #97 — 텍스트 선택 색·Cupertino
/// 테마도 함께 다시 정한다, #107)다.
/// 이것을 기기 틀 안에 그대로 넣어, 실제 앱과 같은 Navigator 구조로 띄운다. 그래서 화면이 띄우는
/// 대화상자·툴팁·SnackBar와 프레임워크가 루트 Overlay에 그리는 것(텍스트 선택 툴바·컨텍스트 메뉴 등)이 모두
/// 기기 틀 안에 그 기기의 MediaQuery(크기·인셋·글자 배율)로, 기기 틀의 축소와 함께 그려진다.
/// 조작 패널은 형제인 자기 Navigator([_PanelNavigator])를 쓴다 — 계산기 화면의 조상이 아니므로 화면 쪽의
/// `rootNavigator: true`·`rootOverlay: true` 조회를 가로채지 않는다.
class KeyPreviewScreen extends ConsumerStatefulWidget {
  /// 앱의 루트 Navigator와 그 위 대비 테마 (`AltCalcApp.frameBuilder`가 넘겨준다)
  final Widget screen;

  /// 입력 로그 최대 보관 줄 수
  final int logCapacity;

  const KeyPreviewScreen({
    super.key,
    required this.screen,
    this.logCapacity = previewLogCapacity,
  }) : assert(logCapacity > 0, 'logCapacity는 양수여야 한다');

  /// 좌우 배치에서 조작 패널 폭 (dp)
  static const double panelWidth = 280;

  /// 이 폭보다 좁은 창은 위아래로 배치한다 (dp)
  static const double narrowWidth = 640;

  @override
  ConsumerState<KeyPreviewScreen> createState() => _KeyPreviewScreenState();
}

class _KeyPreviewScreenState extends ConsumerState<KeyPreviewScreen> {
  PreviewDevice _device = previewDevices.first;
  PreviewFoldPosture _posture = PreviewFoldPosture.flat;
  PreviewOrientation _orientation = previewDevices.first.naturalOrientation;
  double _textScale = previewDefaultTextScale;
  bool _highContrast = false;
  final List<PreviewLogEntry> _log = [];
  int _inputTotal = 0;
  bool _trimmed = false;

  @override
  void didUpdateWidget(KeyPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logCapacity < oldWidget.logCapacity) _trimLog();
  }

  /// 보관 줄 수를 넘는 오래된 줄을 버린다.
  void _trimLog() {
    final excess = _log.length - widget.logCapacity;
    if (excess <= 0) return;
    _log.removeRange(0, excess);
    _trimmed = true;
  }

  /// 상태를 처음으로 되돌리고 로그를 비운다.
  void _reset() {
    // invalidate 직후 read하면 provider가 즉시 다시 만들어지고 리스너가 그 자리에서(동기) 불린다.
    // 그래서 처음 상태로 돌아가는 알림(예: SHIFT 대기 → 해제)은 아래에서 로그를 비우기 전에 들어왔다가
    // 함께 지워진다. read를 빼면 그 알림이 다음 프레임에 와서 빈 로그에 남는다(테스트가 검증).
    ref.invalidate(calcProvider);
    ref.read(calcProvider);
    setState(() {
      _log.clear();
      _inputTotal = 0;
      _trimmed = false;
    });
  }

  void _onChanged(PreviewWatch? previous, PreviewWatch next) {
    if (previous == null) return;
    final (before, countBefore, _) = previous;
    final (after, count, input) = next;
    final PreviewLogEntry entry;
    if (count != countBefore) {
      // 기능 입력 (반복 입력 포함). 모디파이어 해제는 입력의 층 표기로 드러난다.
      if (input == null) return;
      entry = (
        number: ++_inputTotal,
        text: describePreviewInput(input),
        layer: input.layer,
      );
    } else {
      final text = describePreviewModifierChange(before, after);
      if (text == null) return;
      entry = (number: null, text: text, layer: null);
    }
    setState(() {
      _log.add(entry);
      _trimLog();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(calcProvider.select(_watchOf), _onChanged);

    // 패널과 기기 화면은 의미 트리에서 서로 독립된 노드로 묶는다 — [_DeviceFrame._deviceScreen] 참조 (#105).
    final panel = Semantics(
      container: true,
      child: _PanelNavigator(
        child: _ControlPanel(
          device: _device,
          posture: _posture,
          orientation: _orientation,
          textScale: _textScale,
          highContrast: _highContrast,
          log: _log,
          inputTotal: _inputTotal,
          trimmed: _trimmed,
          // 기기를 바꾸면 자세·방향은 그 기기의 기본값(기본 방향으로 펼침)으로 돌아간다 — 기본 방향이 기기마다
          // 달라, 고른 방향을 이어 가면 다른 기기에서는 돌린 화면이 된다. 드롭다운은 같은 항목을 다시 골라도
          // 알리므로, 같은 프리셋이면 고른 자세·방향을 그대로 둔다.
          onDeviceChanged: (d) {
            if (identical(d, _device)) return;
            setState(() {
              _device = d;
              _posture = PreviewFoldPosture.flat;
              _orientation = d.naturalOrientation;
            });
          },
          onPostureChanged: (p) => setState(() => _posture = p),
          onOrientationChanged: (o) => setState(() => _orientation = o),
          onTextScaleChanged: (s) => setState(() => _textScale = s),
          onHighContrastChanged: (v) => setState(() => _highContrast = v),
          onReset: _reset,
        ),
      ),
    );
    // 앱의 루트 Navigator는 WidgetsApp이 GlobalKey로 들고 있어, 창 배치(좌우 ↔ 위아래)가 바뀌어도 유지된다.
    final frame = _DeviceFrame(
      device: _device.posed(_posture, _orientation),
      textScale: _textScale,
      highContrast: _highContrast,
      screen: widget.screen,
    );

    // Scaffold가 아니라 Material을 쓴다 — 계산기 화면의 Scaffold가 앱의 ScaffoldMessenger에 루트 Scaffold로
    // 등록되어야 SnackBar가 기기 틀 안에 뜬다(바깥에 Scaffold가 있으면 그쪽에 뜬다). Material은 캡션 글자의
    // 기본 글꼴 스타일을 준다.
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < KeyPreviewScreen.narrowWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: frame),
                  Expanded(flex: 2, child: panel),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: KeyPreviewScreen.panelWidth, child: panel),
                Expanded(child: frame),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 선택한 기기 크기로 [CalculatorScreen]을 그린다. 창보다 크면 비율을 유지해 축소한다.
///
/// 화면 크기·인셋·시스템 제스처 영역·화면 특징(접힘선)·글자 배율은 [ScreenCoordinateRoot]로 `MediaQuery`를 덮어써 전달해
/// 화면이 실제 기기에서처럼 배치를 산출하게 한다. 화면은 패널 폭만큼 밀리고 축소되므로, 같은 위젯이
/// 이 화면을 좌표 원점으로 표시해 키 버튼이 제스처 영역을 화면 기준 좌표로 판정하게 한다(#50).
/// 접힘선 영역도 화면 크기·제스처 영역처럼 화면 좌표이며, 기기 화면 위에 점선([PreviewDisplayFeaturePainter])으로
/// 표시한다(#51). 호스트(브라우저)의 화면 특징은 넘기지 않는다 — 축소된 화면 좌표와 맞지 않는다.
/// 실제 기기와 다르게 남는 값:
/// - `devicePixelRatio`·플랫폼(스크린리더 알림 경로)은 호스트(브라우저) 값이다.
/// - 폴더블 여부(`foldableDeviceProvider`, 앱은 힌지 센서로 판정)는 덮어쓰지 않는다(기본값: 폴더블 아님).
///   접힘선이 있는 프리셋은 접힘선이 배치를 정하므로 결과가 같다. 접힘 정보가 늦게 오는 시작 구간은
///   흉내 내지 않는다. 폴더블 커버 프리셋은 폭이 좁아 폴더블 여부와 상관없이 위아래 배치다.
/// - 제스처 영역에서 시작한 터치를 시스템이 가로채지는 않는다 — 손을 뗄 때 확정되는 동작만 확인할 수 있다.
///
/// 화면 자리에 앱의 루트 Navigator([screen])를 두므로, 계산기 화면이 띄우는 대화상자·툴팁 등도
/// 기기 틀 안에 그 기기의 MediaQuery로 뜬다(#72, [KeyPreviewScreen] 참조). 대화상자 테마(#97)와 MaterialApp이
/// 테마로 정하는 텍스트 선택·커서 색, Cupertino 테마(#107)도 호스트가 아니라 이 틀의 고대비 설정을 따른다.
class _DeviceFrame extends StatelessWidget {
  final PreviewDevice device;
  final double textScale;

  /// 기기의 고대비 설정 (`MediaQuery.highContrast`, #54). 호스트(브라우저·OS)의 고대비 설정은 쓰지 않는다 —
  /// 흉내 내는 기기의 설정이므로 패널 스위치만 따른다.
  final bool highContrast;

  /// 앱의 루트 Navigator와 그 위 대비 테마 ([KeyPreviewScreen.screen])
  final Widget screen;

  const _DeviceFrame({
    required this.device,
    required this.textScale,
    required this.highContrast,
    required this.screen,
  });

  /// 기기 크기의 화면: 기기 MediaQuery와 좌표 원점([ScreenCoordinateRoot]) 아래에 앱 Navigator를 둔다.
  /// 접힘선은 화면(대화상자 포함) 위에 겹쳐 그린다 — 터치는 가로채지 않는다.
  ///
  /// 의미 트리에서 화면을 독립된 노드로 묶는다(#105, 패널도 [KeyPreviewScreen]에서 같이 묶는다): 앱 Navigator와 패널
  /// Navigator([_PanelNavigator])의 라우트 장벽(`ModalBarrier`)은 `BlockSemantics`라 같은 노드 안에서 먼저 그려진
  /// 형제를 통째로 가린다. 묶지 않으면 넓은 배치(패널 → 기기 틀 순)에서는 패널 전체가, 좁은 배치(기기 틀 → 패널 순)에서는
  /// 기기 화면 전체(대화상자 포함)가 의미 트리에서 빠진다. 각자를 경계로 묶어 형제로 두면 장벽이 자기 안만 가린다.
  Widget _deviceScreen(BuildContext context, {Key? key}) => SizedBox.fromSize(
    key: key,
    size: device.size,
    child: Semantics(
      container: true,
      child: CustomPaint(
        key: const ValueKey('preview-display-features'),
        foregroundPainter: device.displayFeatures.isEmpty
            ? null
            : PreviewDisplayFeaturePainter(device.displayFeatures),
        child: ScreenCoordinateRoot(
          data: MediaQuery.of(context).copyWith(
            size: device.size,
            padding: device.padding,
            viewPadding: device.padding,
            viewInsets: EdgeInsets.zero,
            systemGestureInsets: device.systemGestureInsets,
            // 프리셋 값만 넘긴다 — 호스트의 화면 특징은 축소된 화면 좌표와 맞지 않는다.
            displayFeatures: device.displayFeatures,
            textScaler: TextScaler.linear(textScale),
            highContrast: highContrast,
          ),
          child: screen,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = device.size;
        final availableWidth = constraints.maxWidth - previewFrameMargin * 2;
        final availableHeight =
            constraints.maxHeight -
            previewFrameMargin * 2 -
            previewFrameCaptionHeight;
        final scale = math.max(
          0.0,
          math.min(
            1.0,
            math.min(
              availableWidth / size.width,
              availableHeight / size.height,
            ),
          ),
        );

        // 여백·캡션조차 들어가지 않는 창: 안내 문구만 보인다. 앱 화면은 트리에서 빼지 않고 숨겨 둔다 —
        // 빼면 앱의 루트 Navigator와 열린 라우트(대화상자 등)가 사라진다.
        if (scale <= 0) {
          return Stack(
            children: [
              const Center(
                child: Text(
                  '창이 너무 작아 기기 화면을 표시할 수 없습니다.',
                  key: ValueKey('preview-frame-too-small'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              Offstage(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: size.width,
                  maxWidth: size.width,
                  minHeight: size.height,
                  maxHeight: size.height,
                  child: _deviceScreen(context),
                ),
              ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.all(previewFrameMargin),
          child: Column(
            children: [
              SizedBox(
                height: previewFrameCaptionHeight,
                child: Text(
                  // 창이 좁으면 끝부터 말줄임으로 잘린다. 패널에 보이지 않는 값(표시 배율, 접힘선)을
                  // 앞에 두고, 패널에서 고른 글자 배율을 맨 끝에 둔다.
                  '${device.label} · 표시 배율 ${(scale * 100).round()}%'
                  '${previewDisplayFeatureCaption(device.size, device.displayFeatures)}'
                  ' · 글자 ${(textScale * 100).round()}%',
                  key: const ValueKey('preview-frame-caption'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Expanded(
                child: Center(
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                    ),
                    child: SizedBox(
                      width: size.width * scale,
                      height: size.height * scale,
                      child: FittedBox(
                        child: _deviceScreen(
                          context,
                          key: const ValueKey('preview-device-screen'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 그릴 접힘선·힌지: 종류가 fold·hinge이고 영역이 유한한 것 (화면 구멍 등은 뺀다)
Iterable<DisplayFeature> _drawableFolds(List<DisplayFeature> features) =>
    features.where((f) => FormFactor.hasFoldOrHinge([f]) && f.bounds.isFinite);

/// 앱이 [screen] 크기 화면을 나누는 데 쓰는 접힘선. 없으면 `null`.
///
/// 앱의 배치 규칙([FormFactor.arrangementOf])과 같다: 화면을 가로지르는 접힘선 중 **첫 번째**
/// ([FormFactor.hingeOf]) 하나만 보고, 양쪽 패널 길이([FormFactor.hingeMinPanelExtent])와 가로 접힘선의
/// 나눔 여부([FormFactor.separates])까지 맞아 접힘선 기준 배치가 될 때만 그 접힘선이다.
/// 화면이 키 터치 하한 때문에 위아래 배치로 되돌아가는 경우(`CalculatorScreen`, 본체 크기로 판정)는
/// 반영하지 않는다. 지금 프리셋에서는 테이블톱 조합(#93, Flip 내부 #104)도 완화된 하한(`tabletopKeyTouchHeightFloor`)을
/// 넘어 되돌아가지 않는다(테스트가 조합마다 확인 — 넓은 키패드 배열(#80) 뒤로는 일반 하한도 넘는다). 하한이나 테이블톱
/// 배치를 바꿔 이 표시가 실제 배치와 어긋나면(주황인데 배치는 접힘선을 가로지름) 조합 테스트가 실패한다.
DisplayFeature? _splittingFold(Size screen, List<DisplayFeature> features) {
  final used = FormFactor.hingeOf(screen, features);
  if (used == null) return null;
  return switch (FormFactor.arrangementOf(screen, features)) {
    ScreenArrangement.hingeSplit || ScreenArrangement.hingeStacked => used,
    ScreenArrangement.stacked || ScreenArrangement.split => null,
  };
}

/// 캡션에 덧붙일 접힘선 설명 (예: ` · 접힘선(점선) 세로 x=345`). 그릴 접힘선이 없으면 빈 문자열.
///
/// 세로 접힘선은 가운데 x, 가로 접힘선은 가운데 y를 화면 좌표(dp)로 적는다. 폭이 있는 힌지는 폭도 적고,
/// 앱이 [screen] 크기 화면을 나누는 데 쓰지 않는 접힘선([_splittingFold]가 아닌 것 — 화면을 끝까지
/// 가로지르지 않음, 한쪽 패널이 너무 좁음, 펼친 가로 접힘선, 두 번째 접힘선)은 `(배치에 안 씀)`을 붙인다.
/// 점선은 있는데 배치가 나뉘지 않는 것을 오류로 오인하지 않게 하기 위해서다(점선도 회색으로 구분한다).
/// 폴더블 프리셋을 펼친 채 접힘선이 가로가 되게 돌린 화면(펼친 가로 접힘선)이 그렇다(#93).
/// 반 접힌 접힘선(`postureHalfOpened`)은 위치 뒤에 `반 접힘`을 적는다 — 세로 접힘선은 펼침과 반 접힘의
/// 배치가 같아, 캡션 없이는 스크린숏으로 자세를 구분할 수 없다(#93).
String previewDisplayFeatureCaption(
  Size screen,
  List<DisplayFeature> features,
) {
  final parts = <String>[];
  final splitting = _splittingFold(screen, features);
  for (final f in _drawableFolds(features)) {
    final b = f.bounds;
    final vertical = FormFactor.isVerticalHinge(b);
    final position = vertical
        ? '세로 x=${_dp(b.center.dx)}'
        : '가로 y=${_dp(b.center.dy)}';
    final extent = vertical ? b.width : b.height;
    final unused = identical(f, splitting) ? '' : ' (배치에 안 씀)';
    final halfOpened = f.state == DisplayFeatureState.postureHalfOpened
        ? ' 반 접힘'
        : '';
    parts.add(
      '$position${extent > 0 ? ' 폭 ${_dp(extent)}' : ''}$halfOpened$unused',
    );
  }
  return parts.isEmpty ? '' : ' · 접힘선(점선) ${parts.join(', ')}';
}

/// dp 값을 짧게 적는다 (정수면 소수점 없이, 아니면 소수 첫째 자리까지)
String _dp(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// 기기 화면 위에 접힘선·힌지 위치를 점선으로 표시한다 (#51). 폭이 있는 힌지는 영역을 반투명하게 칠한다.
///
/// 그리는 영역의 크기가 곧 기기 화면 크기다(화면 좌표). 앱이 화면을 나누는 데 쓰는 접힘선([_splittingFold])은
/// [splittingColor](주황), 그 밖의 접힘선은 [otherColor](회색)로 그린다. 화면 구멍(cutout) 등 접힘선이 아닌
/// 특징과 영역이 유한하지 않은 특징은 그리지 않는다.
/// 앱 화면 위에 그리지만 히트 테스트에 참여하지 않으므로([CustomPainter.hitTest] 기본값) 터치를 가로채지 않는다.
class PreviewDisplayFeaturePainter extends CustomPainter {
  final List<DisplayFeature> features;

  const PreviewDisplayFeaturePainter(this.features);

  /// 앱이 화면을 나누는 데 쓰는 접힘선 색 (미리보기 전용 — 앱 화면 색과 겹치지 않는 주황)
  static const Color splittingColor = Color(0xCCFF9800);

  /// 배치에 쓰이지 않는 접힘선 색
  static const Color otherColor = Color(0xCC9E9E9E);

  /// 점선 한 칸 길이·간격 (dp, 기기 화면 좌표)
  static const double _dash = 8;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final splitting = _splittingFold(size, features);
    for (final f in _drawableFolds(features)) {
      final color = identical(f, splitting) ? splittingColor : otherColor;
      final line = Paint()
        ..color = color
        ..strokeWidth = 2;
      final b = f.bounds;
      if (b.width > 0 && b.height > 0) {
        canvas.drawRect(b, Paint()..color = color.withValues(alpha: 0.25));
      }
      final vertical = FormFactor.isVerticalHinge(b);
      final from = vertical ? b.topCenter : b.centerLeft;
      final to = vertical ? b.bottomCenter : b.centerRight;
      final length = (to - from).distance;
      if (length <= 0) continue;
      final step = (to - from) / length;
      for (var d = 0.0; d < length; d += _dash + _gap) {
        canvas.drawLine(
          from + step * d,
          from + step * math.min(d + _dash, length),
          line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PreviewDisplayFeaturePainter oldDelegate) =>
      !listEquals(oldDelegate.features, features);
}

/// 조작 패널 전용 Navigator (#72).
///
/// 패널의 드롭다운 메뉴 등은 Navigator·Overlay가 필요한데, 앱의 루트 Navigator는 기기 틀 안에 있으므로
/// 패널에 따로 둔다. 기기 틀의 형제라 계산기 화면의 조상이 아니다 — 화면 쪽의 루트 조회를 가로채지 않는다.
/// 페이지 목록(`pages`)으로 만들어, 패널 내용이 바뀌면(로그 추가 등) 같은 키의 페이지가 갱신되어 다시 그려진다.
class _PanelNavigator extends StatelessWidget {
  final Widget child;

  const _PanelNavigator({required this.child});

  @override
  Widget build(BuildContext context) {
    // 앱의 HeroController는 앱 Navigator 몫이다 — 한 HeroController를 두 Navigator가 나눠 쓸 수 없으므로 끊는다.
    return HeroControllerScope.none(
      child: Navigator(
        pages: [
          MaterialPage<void>(
            key: const ValueKey('preview-panel-page'),
            child: Material(color: Colors.black, child: child),
          ),
        ],
        onDidRemovePage: (_) {},
      ),
    );
  }
}

/// 기기(폴더블이면 자세·방향 포함)·글자 배율·고대비 선택, 초기화 버튼, 입력 로그.
///
/// 설정 영역을 작게 두고 입력 로그가 남은 높이를 모두 쓴다 — 키를 누르는 동안 로그가 보여야 하기 때문이다.
/// 설정 영역은 위에 고정하고 로그만 스크롤하되, 설정 영역 아래에 로그가 [_minLogLines]줄 들어가지 않을 만큼
/// 패널이 낮으면 설정과 로그를 한꺼번에 스크롤한다(오버플로 방지, #105).
///
/// 전환 높이는 상수로 두지 않고 그때그때 잰 설정 영역 높이로 정한다([_PinnedWhenRoomSliver]) — 설정 항목
/// (폴더블 자세·방향 줄 등)과 플랫폼별 버튼 터치 영역(Android 40 / 데스크톱 32), 호스트 글자 배율이 모두
/// 그 높이에 들어 있다. 두 배치가 같은 스크롤 뷰 하나라, 창 높이가 전환 높이를 넘나들어도 설정 위젯이
/// 다시 만들어지지 않는다(드롭다운·스위치 상태 유지).
///
/// 스크롤 뷰가 하나라 생기는 동작 (의도한 것):
/// - 설정을 고정한 동안에도 설정 위에서 휠을 굴리면 로그가 스크롤된다. 데스크톱 스크롤바도 패널 전체 높이에 걸친다
///   (오른쪽 안쪽 여백 안이라 설정 조작을 가리지 않는다).
/// - 고정한 채 로그를 설정 높이 이상 내려 본 상태에서 패널을 전환 높이보다 낮게 줄이면, 같은 스크롤 위치에서
///   설정이 함께 스크롤되는 배치가 되어 설정이 위로 밀려나 있다 — 위로 스크롤하면 다시 보인다.
class _ControlPanel extends StatelessWidget {
  /// 고른 프리셋 (자세·방향을 적용하기 전)
  final PreviewDevice device;
  final PreviewFoldPosture posture;
  final PreviewOrientation orientation;
  final double textScale;
  final bool highContrast;
  final List<PreviewLogEntry> log;
  final int inputTotal;
  final bool trimmed;
  final ValueChanged<PreviewDevice> onDeviceChanged;
  final ValueChanged<PreviewFoldPosture> onPostureChanged;
  final ValueChanged<PreviewOrientation> onOrientationChanged;
  final ValueChanged<double> onTextScaleChanged;
  final ValueChanged<bool> onHighContrastChanged;
  final VoidCallback onReset;

  const _ControlPanel({
    required this.device,
    required this.posture,
    required this.orientation,
    required this.textScale,
    required this.highContrast,
    required this.log,
    required this.inputTotal,
    required this.trimmed,
    required this.onDeviceChanged,
    required this.onPostureChanged,
    required this.onOrientationChanged,
    required this.onTextScaleChanged,
    required this.onHighContrastChanged,
    required this.onReset,
  });

  /// 설정 영역을 고정할 때 그 아래에 다 보여야 하는 로그 줄 수 (#105).
  ///
  /// SHIFT·ALPHA 조합 입력 하나가 두 줄(`[SHIFT 대기]`, 기능 입력)을 남기므로, 방금 누른 조합과 그 앞의 입력
  /// 한 줄까지 보이는 3줄로 정했다. 이보다 낮은 패널은 설정을 함께 스크롤해, 설정을 밀어 올리면 로그를 더 볼 수 있다.
  /// 화면에 보이는 줄 기준이다 — 패널 폭(약 35자, 호스트 글자 130%면 약 27자)을 넘는 긴 입력은 두 줄로 접혀
  /// 보이는 입력 수가 줄 수 있다(지금 문구는 대부분 이보다 짧다).
  static const int _minLogLines = 3;

  /// 패널 안쪽 여백 (dp)
  static const double _padding = 12;

  /// 패널 배경 (미리보기 전용)
  static const Color _background = Color(0xFF1E1E1E);

  static const TextStyle _label = TextStyle(
    color: Colors.white70,
    fontSize: 12,
  );

  static const TextStyle _heading = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle _logStyle = TextStyle(
    fontFamily: CalcTheme.monoFontFamily,
    fontFamilyFallback: CalcTheme.monoFontFallback,
    fontSize: 12,
  );

  static Color _colorOf(KeyLayer? layer) => switch (layer) {
    null => Colors.white54,
    KeyLayer.main => Colors.white,
    KeyLayer.shift => CalcTheme.shiftLabel,
    KeyLayer.alpha => CalcTheme.alphaLabel,
  };

  /// 이름표([label]) + 선택지 한 줄 (폴더블 자세·방향, #93). 선택지 글자의 키는 `<keyPrefix>-<값 이름>`이다.
  static Widget _choiceRow<T extends Enum>({
    required String label,
    required String keyPrefix,
    required List<T> values,
    required String Function(T) labelOf,
    required T selected,
    required ValueChanged<T> onChanged,
  }) => Row(
    children: [
      SizedBox(width: 40, child: Text(label, style: _label)),
      Expanded(
        child: SegmentedButton<T>(
          key: ValueKey(keyPrefix),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final v in values)
              ButtonSegment(
                value: v,
                label: Text(
                  labelOf(v),
                  key: ValueKey('$keyPrefix-${v.name}'),
                  maxLines: 1,
                ),
              ),
          ],
          selected: {selected},
          onSelectionChanged: (v) => onChanged(v.first),
        ),
      ),
    ],
  );

  Widget _settings() => Column(
    key: const ValueKey('preview-settings'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('기기 크기', style: _label),
      DropdownButton<int>(
        key: const ValueKey('preview-device-select'),
        isExpanded: true,
        value: previewDevices.indexOf(device),
        items: [
          for (final (i, d) in previewDevices.indexed)
            DropdownMenuItem(
              value: i,
              child: Text(
                d.label,
                key: ValueKey('preview-device-$i'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (i) {
          if (i != null) onDeviceChanged(previewDevices[i]);
        },
      ),
      // 폴더블 내부 화면의 자세·방향 (#93) — 폴더블 프리셋에서만 보인다.
      if (device.foldable) ...[
        const SizedBox(height: 8),
        _choiceRow<PreviewFoldPosture>(
          label: '자세',
          keyPrefix: 'preview-fold-posture',
          values: PreviewFoldPosture.values,
          labelOf: (p) => p.label,
          selected: posture,
          onChanged: onPostureChanged,
        ),
        const SizedBox(height: 4),
        // 앱이 세로로 고정하는 화면(Flip 내부, #104)은 돌린 화면이 실제로 나오지 않으므로 고를 수 없게 하고 이유를 적는다.
        if (device.orientations.length > 1)
          _choiceRow<PreviewOrientation>(
            label: '방향',
            keyPrefix: 'preview-fold-orientation',
            values: device.orientations,
            labelOf: (o) => o.label,
            selected: orientation,
            onChanged: onOrientationChanged,
          )
        else
          Row(
            children: [
              const SizedBox(width: 40, child: Text('방향', style: _label)),
              Expanded(
                child: Text(
                  // 이유(짧은 변 600dp 미만이라 앱이 세로로 고정)는 README에 있다 — 패널 폭에서 한 줄로 둔다.
                  '${device.orientations.single.label} 고정',
                  key: const ValueKey('preview-fold-orientation-locked'),
                  style: _label,
                ),
              ),
            ],
          ),
      ],
      const SizedBox(height: 8),
      const Text('시스템 글자 배율', style: _label),
      const SizedBox(height: 4),
      SegmentedButton<double>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          for (final s in previewTextScales)
            ButtonSegment(
              value: s,
              label: Text(
                '${(s * 100).round()}%',
                key: ValueKey('preview-text-scale-$s'),
                maxLines: 1,
              ),
            ),
        ],
        selected: {textScale},
        onSelectionChanged: (v) => onTextScaleChanged(v.first),
      ),
      // 기기의 고대비 설정 흉내 (#54) — iOS "대비 증가", Android 14 이상 "색상 대비" 중간·높음
      Row(
        children: [
          const Expanded(
            child: Text('고대비 (MediaQuery.highContrast)', style: _label),
          ),
          Switch(
            key: const ValueKey('preview-high-contrast'),
            value: highContrast,
            onChanged: onHighContrastChanged,
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              '입력 로그 · 입력 $inputTotal회'
              '${trimmed ? ' (최근 ${log.length}줄만 표시)' : ''}',
              key: const ValueKey('preview-log-header'),
              style: _heading,
            ),
          ),
          TextButton(
            key: const ValueKey('preview-reset'),
            onPressed: onReset,
            child: const Text('초기화'),
          ),
        ],
      ),
    ],
  );

  /// 입력 로그 (최근 줄이 맨 위). 화면에 보이는 줄만 만든다(지연 생성).
  /// 줄 높이는 [strut]으로 고정한다 — 대체 글꼴로 그리는 글자(`∫`·`∑` 등 Math 글꼴, 한글)가 든 줄도 높이가 같아야
  /// 전환 높이 계산([_logLineHeight])과 맞는다(`test/widget/key_preview_log_font_test.dart`가 번들 글꼴로 확인).
  /// 대가로 Math 글꼴 글리프는 줄 상자 아래로 2dp 미만 넘칠 수 있다(자르지 않으므로 다음 줄과 살짝 겹칠 뿐이다).
  Widget _logSliver(StrutStyle strut) => log.isEmpty
      ? const SliverToBoxAdapter(
          child: Text(
            '키를 누르면 여기에 최근 순으로 기록됩니다.',
            key: ValueKey('preview-log-empty'),
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        )
      : SliverList.builder(
          key: const ValueKey('preview-log'),
          itemCount: log.length,
          itemBuilder: (context, i) {
            final (:number, :text, :layer) = log[log.length - 1 - i];
            return Text(
              number == null ? text : '$number. $text',
              style: _logStyle.copyWith(color: _colorOf(layer)),
              strutStyle: strut,
            );
          },
        );

  /// 로그 줄 높이를 고정하는 strut — 로그 줄([Text])이 [DefaultTextStyle]과 합친 스타일 그대로다.
  static StrutStyle _logStrut(BuildContext context) => StrutStyle.fromTextStyle(
    DefaultTextStyle.of(context).style.merge(_logStyle),
    forceStrutHeight: true,
  );

  /// 로그 한 줄 높이 (dp). 로그 줄과 같은 [strut]·호스트 글자 배율로 잰다(줄 높이가 strut으로 고정이라
  /// 글자 내용·대체 글꼴과 상관없다).
  static double _logLineHeight(BuildContext context, StrutStyle strut) {
    final defaults = DefaultTextStyle.of(context);
    final painter = TextPainter(
      text: TextSpan(text: '0', style: defaults.style.merge(_logStyle)),
      strutStyle: strut,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      textHeightBehavior: defaults.textHeightBehavior,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final strut = _logStrut(context);
    return ColoredBox(
      key: const ValueKey('preview-panel'),
      color: _background,
      child: CustomScrollView(
        slivers: [
          _PinnedWhenRoomSliver(
            // 설정 아래에 로그 [_minLogLines]줄과 아래 여백이 들어가야 설정을 고정한다.
            minRemainingExtent:
                _minLogLines * _logLineHeight(context, strut) + _padding,
            // 고정한 채 로그가 밑으로 스크롤되어 지나가므로 불투명해야 한다. 의미 트리 묶음은
            // PinnedHeaderSliver와 같다 — 고정된 상자를 스크롤 대상에서 뺄 수 있게 한 노드로 묶는다.
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: ColoredBox(
                color: _background,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _padding,
                    _padding,
                    _padding,
                    0,
                  ),
                  child: _settings(),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_padding, 0, _padding, _padding),
            sliver: _logSliver(strut),
          ),
        ],
      ),
    );
  }
}

/// 스크롤 뷰 맨 위의 상자 하나. 그 아래에 [minRemainingExtent]가 남을 만큼 화면(뷰포트)이 높으면 위에 고정하고
/// (뒤 sliver가 그 밑으로 스크롤된다 — [PinnedHeaderSliver]와 같다), 아니면 뒤 sliver와 함께 스크롤한다
/// ([SliverToBoxAdapter]와 같다) (#105).
///
/// 판정에 쓰는 높이는 레이아웃할 때 잰 상자 높이라, 상자 내용이 바뀌면(항목 추가, 플랫폼별 터치 영역, 글자 배율)
/// 전환 높이도 따라 바뀐다. 아래 방향으로 스크롤하는 뷰의 첫 sliver로만 쓴다(앞 sliver가 없다고 보고 뷰포트 높이만으로
/// 판정한다 — 디버그 빌드에서 assert로 확인. 겹침은 고정 기하에 그대로 반영한다). 고정할 때 상자는 불투명해야 한다.
class _PinnedWhenRoomSliver extends SingleChildRenderObjectWidget {
  /// 상자를 고정하려면 그 아래에 남아야 하는 높이 (dp)
  final double minRemainingExtent;

  const _PinnedWhenRoomSliver({
    required this.minRemainingExtent,
    required Widget super.child,
  });

  @override
  _RenderPinnedWhenRoomSliver createRenderObject(BuildContext context) =>
      _RenderPinnedWhenRoomSliver(minRemainingExtent);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPinnedWhenRoomSliver renderObject,
  ) {
    renderObject.minRemainingExtent = minRemainingExtent;
  }
}

class _RenderPinnedWhenRoomSliver extends RenderSliverSingleBoxAdapter {
  _RenderPinnedWhenRoomSliver(this._minRemainingExtent);

  double get minRemainingExtent => _minRemainingExtent;
  double _minRemainingExtent;
  set minRemainingExtent(double value) {
    if (value == _minRemainingExtent) return;
    _minRemainingExtent = value;
    markNeedsLayout();
  }

  /// 마지막 레이아웃에서 상자를 고정했는지
  bool _pinned = false;

  @override
  double childMainAxisPosition(RenderBox child) =>
      _pinned ? 0 : -constraints.scrollOffset;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      _pinned = false;
      geometry = SliverGeometry.zero;
      return;
    }
    final constraints = this.constraints;
    assert(
      constraints.precedingScrollExtent == 0,
      '_PinnedWhenRoomSliver는 첫 sliver여야 한다',
    );
    assert(
      applyGrowthDirectionToAxisDirection(
            constraints.axisDirection,
            constraints.growthDirection,
          ) ==
          AxisDirection.down,
      '_PinnedWhenRoomSliver는 아래 방향 스크롤 전용이다',
    );
    child.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final extent = switch (constraints.axis) {
      Axis.vertical => child.size.height,
      Axis.horizontal => child.size.width,
    };
    // 부동소수 오차로 경계에서 판정이 흔들리지 않게 작은 여유를 둔다.
    _pinned =
        extent + minRemainingExtent <=
        constraints.viewportMainAxisExtent + precisionErrorTolerance;
    final cacheExtent = calculateCacheOffset(constraints, from: 0, to: extent);
    if (_pinned) {
      // PinnedHeaderSliver와 같은 기하: 스크롤하면 뒤 sliver가 상자 밑으로 들어간다(겹침).
      geometry = SliverGeometry(
        scrollExtent: extent,
        paintOrigin: constraints.overlap,
        paintExtent: math.min(
          extent,
          constraints.remainingPaintExtent - constraints.overlap,
        ),
        layoutExtent: clampDouble(
          extent - constraints.scrollOffset,
          0,
          constraints.remainingPaintExtent,
        ),
        maxPaintExtent: extent,
        maxScrollObstructionExtent: extent,
        cacheExtent: cacheExtent,
        hasVisualOverflow: true,
      );
      (child.parentData! as SliverPhysicalParentData).paintOffset = Offset.zero;
    } else {
      // SliverToBoxAdapter와 같은 기하
      final painted = calculatePaintOffset(constraints, from: 0, to: extent);
      geometry = SliverGeometry(
        scrollExtent: extent,
        paintExtent: painted,
        cacheExtent: cacheExtent,
        maxPaintExtent: extent,
        hitTestExtent: painted,
        hasVisualOverflow:
            extent > constraints.remainingPaintExtent ||
            constraints.scrollOffset > 0,
      );
      setChildParentData(child, constraints, geometry!);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // PinnedHeaderSliver와 같다: 고정된 채 일부가 가려지면 스크롤 대상에서 뺀다.
    final geometry = this.geometry;
    if (_pinned &&
        geometry != null &&
        child != null &&
        geometry.layoutExtent < geometry.scrollExtent) {
      config.addTagForChildren(RenderViewport.excludeFromScrolling);
    }
  }
}
