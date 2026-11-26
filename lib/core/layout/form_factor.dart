import 'dart:math' as math;
import 'dart:ui'
    show
        DisplayFeature,
        DisplayFeatureState,
        DisplayFeatureType,
        FlutterView,
        Rect,
        Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 기기 종류 — 화면 방향 고정을 고를 때 쓴다 (#24).
enum DeviceKind {
  /// 일반 폰
  phone,

  /// 폴더블 — 시작 시 폴더블로 판정했거나([FormFactor.queryFoldableDevice]) 그 뒤 화면 정보로 알아본
  /// (`DeviceOrientationLock.foldableDevice` — 접히는 부분 보고, [FormFactor.isOtherScreen]) 기기 (커버 화면 포함)
  foldable,

  /// 태블릿 — 짧은 변 [FormFactor.largeScreenMinShortestSide] 이상인 폴더블이 아닌 기기
  tablet,
}

/// 계산기 화면 배치 종류 (#24, 접힘선 기준 배치는 #25).
enum ScreenArrangement {
  /// 위아래 배치: 위 LCD, 아래 키패드 (폰 세로 화면, 세로·좁은 창, 폴더블 커버 화면)
  stacked,

  /// 좌우 분할 배치: LCD와 키패드를 좌우로 나누고 주로 쓰는 손 쪽에 키패드 (대화면 가로 창)
  split,

  /// 세로 접힘선 기준 좌우 배치 (폴더블 내부 화면, 책 자세): 접힘선 한쪽 절반에 키패드(주로 쓰는 손 쪽),
  /// 다른 절반에 LCD. 어느 것도 접힘선을 가로지르지 않는다.
  hingeSplit,

  /// 가로 접힘선 기준 위아래 배치 (반 접어 세운 테이블톱 자세, 물리 힌지 — 펼친 폭 0 가로 접힘선은 제외):
  /// 접힘선 위 절반에 LCD, 아래 절반에 키패드. 어느 것도 접힘선을 가로지르지 않는다.
  hingeStacked,
}

/// 기기 종류·화면 크기별로 요청할 화면 방향 정책 (#24, 폴더블은 #25)
enum OrientationPolicy {
  /// 세로만 (폰, 폴더블 커버 화면)
  portrait,

  /// 가로 두 방향 (태블릿)
  landscape,

  /// 네 방향 모두 (폴더블 내부 화면 — 배치가 접힘선 방향을 따른다)
  any,
}

/// 기기·창 크기에 따른 화면 구분 규칙 (#24).
///
/// 두 가지를 따로 판정한다.
/// - **기기 종류**([deviceKindOf]): 물리 화면(디스플레이) 크기와 힌지 유무로 정한다. 앱 시작 시 방향 고정에 쓴다.
/// - **배치**([arrangementOf]): 앱 **창** 크기로 정한다. 방향 고정은 대부분의 대화면에서 지켜지지 않으므로(아래)
///   화면 배치는 항상 실제 창 크기를 따른다.
///
/// ## 태블릿 가로 고정이 실제로 동작하는 범위
/// 태블릿에는 가로를 요청하지만, **Android 15 이하 태블릿에서만** 지켜진다.
/// - Android 16 이상: targetSdk 36(Flutter 기본값)이면 짧은 변 600dp 이상 화면은 앱의 방향 고정을 **항상** 무시한다.
///   이를 끄는 `android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY`는 targetSdk 37에서 없어지는
///   임시 장치라 쓰지 않는다.
/// - iPad: 멀티태스킹(Split View·Slide Over·Stage Manager)을 지원하는 앱은 전체 화면에서도 방향 고정이
///   반영되지 않는다(전체 화면 강제 `UIRequiresFullScreen`을 켜야 반영되는데, iPadOS 26부터 폐기 예정이다).
///   계산기는 다른 앱과 나란히 쓰는 경우가 많아 멀티태스킹을 끄지 않는다 — `Info.plist`의 iPad 방향은
///   네 방향 모두 허용한 채로 둔다(멀티태스킹 요건).
/// - 분할 화면·팝업 창처럼 창 자체가 화면보다 작은 경우. 폰도 마찬가지라, 세로 고정과 무관하게 낮은 창이 생긴다.
///   그런 창은 화면이 본체 크기로 다시 판정해 좌우 분할로 그리거나 창을 키워 달라는 안내를 띄운다
///   (`CalculatorScreen`, `CalcTheme` "짧은 창" 절, #38). 분할 화면·팝업 창 자체는 막지 않는다
///   (`resizeableActivity`·최소 창 크기를 선언하지 않는 이유도 그 절).
/// 그래서 태블릿을 세로로 들면 대개 세로 창이 되고, 그때는 위아래 배치로 보여 준다.
abstract final class FormFactor {
  /// 대화면 기준 짧은 변 (dp). Material 창 크기 등급 medium(폭 600dp) 이상과 같고, Android가 방향
  /// 고정을 무시하는 대화면 기준과도 같다.
  static const double largeScreenMinShortestSide = 600.0;

  /// 기기 특성 조회 채널 (Android `MainActivity`)
  @visibleForTesting
  static const MethodChannel deviceChannel = MethodChannel('altcalc/device');

  /// [deviceChannel]의 폴더블 판정 메서드 이름 ([queryFoldableDevice])
  @visibleForTesting
  static const String foldableDeviceMethod = 'isFoldableDevice';

  /// [features]에 접히는 부분(fold·hinge)이 있는지. 화면 구멍(cutout)은 세지 않는다.
  static bool hasFoldOrHinge(Iterable<DisplayFeature> features) => features.any(
    (f) =>
        f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge,
  );

  /// 폴더블 기기인지 (#24, 보강 #70). 폴더블 기기를 앱 시작 시점에 구분하는 데 쓴다 — 접히는 부분 정보
  /// ([FlutterView.displayFeatures])는 화면이 붙은 뒤 비동기로 와서 시작 시점에는 비어 있고, 비어 있어도
  /// "아직 안 옴"인지 "없음"인지 구분할 수 없다.
  ///
  /// Android `MainActivity`(`FoldableDeviceProbe`)가 다음 중 하나라도 있으면 폴더블로 답한다.
  /// 1. 힌지 각도 센서 기능 선언 (`FEATURE_SENSOR_HINGE_ANGLE`, API 30+) — 제조사가 선언해야만 보고된다.
  /// 2. 힌지 각도 센서 자체 (`Sensor.TYPE_HINGE_ANGLE`, API 30+)
  /// 3. Jetpack WindowManager 창 배치 정보 첫 값의 접히는 부분 — Samsung처럼 OEM 확장으로 접힘 정보만 주는 기기 대비.
  ///    창이 붙은 뒤 오므로 Android 쪽이 최대 500ms 기다린다(그동안 시작 화면이 남는다).
  ///
  /// Android가 아니거나, 조회에 실패하거나, [foldableQueryTimeout] 안에 응답이 없으면 `false` — 앱 시작(`main()`)이
  /// 이 조회를 기다리므로 어떤 경우에도 오류를 내거나 멈추지 않는다.
  ///
  /// 한계: 1·2가 없는 폴더블을 접은 커버 화면에서 시작하면 3도 없어(창이 접힘선에 걸치지 않는다) 폰으로 판정된다.
  /// 펼치면 `DeviceOrientationLock`이 물리 화면이 바뀐 것([isOtherScreen])을 보고 폴더블로 기억한다.
  /// 각 신호의 실기기 값은 #158에서 기록한다.
  static Future<bool> queryFoldableDevice() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await deviceChannel
          .invokeMethod<bool>(foldableDeviceMethod)
          .timeout(foldableQueryTimeout);
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (error) {
      debugPrint('폴더블 판정 조회 실패: $error');
      return false;
    }
  }

  /// 폴더블 판정 조회 응답 제한 시간. Android 쪽이 창 배치 정보를 기다리는 최대 시간(`FoldableDeviceProbe`
  /// `LAYOUT_TIMEOUT_MILLIS`)보다 넉넉히 길어야 한다 — `test/unit/main_activity_source_test.dart`가 대조한다.
  static const Duration foldableQueryTimeout = Duration(seconds: 1);

  /// 기기 종류를 정한다.
  /// - [displaySize]: 물리 화면 크기 (dp)
  /// - [features]: 화면 특징 (접히는 부분 등)
  /// - [foldableDevice]: 앱 시작 시 판정한 폴더블 기기 여부 ([queryFoldableDevice])
  ///
  /// 폴더블 내부 화면은 짧은 변이 600dp를 넘어 크기로는 태블릿과 구분되지 않으므로, 시작 시 판정이나 접히는
  /// 부분 정보로 구분한다. 폴더블은 접은 커버 화면에서도 [DeviceKind.foldable]이다.
  static DeviceKind deviceKindOf(
    Size displaySize,
    Iterable<DisplayFeature> features, {
    bool foldableDevice = false,
  }) {
    if (foldableDevice || hasFoldOrHinge(features)) return DeviceKind.foldable;
    if (displaySize.shortestSide >= largeScreenMinShortestSide) {
      return DeviceKind.tablet;
    }
    return DeviceKind.phone;
  }

  /// [view]가 놓인 물리 화면 크기 (dp). 플랫폼이 화면 크기를 알려주지 않으면(크기 0) 창 크기를 쓴다.
  static Size displaySizeOf(FlutterView view) =>
      reportedDisplaySizeOf(view) ?? view.physicalSize / view.devicePixelRatio;

  /// 플랫폼이 알려 준 [view]의 물리 화면 크기 (dp). 알려 주지 않으면(크기 0) `null` — 창 크기로 대신하지 않는다.
  static Size? reportedDisplaySizeOf(FlutterView view) {
    final display = view.display;
    if (display.size.isEmpty || !(display.devicePixelRatio > 0)) return null;
    return display.size / display.devicePixelRatio;
  }

  /// 물리 화면이 바뀌었다고 볼 화면 비율(긴 변 ÷ 짧은 변) 차이 (작은 쪽 비율에 대한 상대값). 폴더블의 커버 ↔ 내부
  /// 화면은 비율이 크게 다르다(Galaxy Z Fold 커버 약 2.6 ↔ 내부 약 1.2, Z Flip 내부 약 2.4 ↔ 커버 약 1.0).
  static const double otherScreenAspectTolerance = 0.15;

  /// 물리 화면 크기 [before]에서 [after]로 바뀐 것이 **폴더블의 다른 화면**으로 바뀐 것인지 (#70) — 커버 ↔ 내부 화면
  /// 전환이다. 다음 두 조건을 모두 만족할 때만 참이다.
  /// - 비율(긴 변 ÷ 짧은 변)이 [otherScreenAspectTolerance]보다 많이 다르다. 회전(가로·세로가 맞바뀜)과 화면 크기·글자
  ///   확대 설정(dp 크기만 바뀐다)은 비율이 그대로라 세지 않는다.
  /// - 적어도 한쪽이 폰 크기(짧은 변 [largeScreenMinShortestSide] 미만)다. 폴더블은 한쪽이 늘 폰 크기다(Fold·Flip의 커버,
  ///   Flip의 내부). 양쪽이 모두 대화면인 전환 — 노트북 화면 ↔ 모니터(ChromeOS·Mac), iPad ↔ 외부 모니터, 태블릿 ↔
  ///   모니터 — 은 다른 디스플레이로 옮긴 것이라 세지 않는다. 플랫폼은 창이 놓인 디스플레이의 크기를 알려 주는데,
  ///   어느 디스플레이인지는 알 수 없다(Android는 늘 같은 디스플레이 번호를 준다).
  ///
  /// 한계: 폰을 외부 디스플레이(DeX 등)로 옮기면 참이 된다 — 그러면 폴더블로 기억해 접힘선 없는 넓은 창도 위아래 배치가
  /// 된다([arrangementOf]의 폴더블 외부 디스플레이 제약과 같다). 폰 화면 자체의 정책은 폴더블이어도 같다(세로).
  static bool isOtherScreen(Size before, Size after) {
    if (before.isEmpty || after.isEmpty) return false;
    if (before.shortestSide >= largeScreenMinShortestSide &&
        after.shortestSide >= largeScreenMinShortestSide) {
      return false;
    }
    double aspect(Size s) => s.longestSide / s.shortestSide;
    final a = aspect(before);
    final b = aspect(after);
    return (a - b).abs() / math.min(a, b) > otherScreenAspectTolerance;
  }

  /// 기기 종류([kind])와 물리 화면 크기([displaySize], dp)별 방향 정책.
  /// - 폰: 세로 — 가로 화면에서는 키패드가 쓸 수 없을 만큼 작아진다.
  /// - 태블릿: 가로 — LCD와 키패드를 좌우로 나눠 보여 준다 (지켜지는 범위는 클래스 설명 참조).
  /// - 폴더블의 짧은 변 [largeScreenMinShortestSide] 미만 화면: 폰과 같이 세로. Fold 계열의 접은 커버 화면과
  ///   Galaxy Z Flip 계열의 내부 화면(세로로 긴 폰 크기, 가로 접힘선)이 여기에 든다.
  /// - 폴더블 대화면(Fold 계열 내부 화면): 네 방향 모두 허용한다 (#25). 내부 화면의 기본 방향이 기기마다
  ///   달라(Galaxy Z Fold는 세로, Pixel Fold는 가로) 세로로 고정하면 Pixel Fold에서는 오히려 접힘선이 가로로
  ///   눕는다. 배치는 고정 대신 접힘선 방향을 따른다([arrangementOf]). Android 16 이상은 대화면에서 어차피
  ///   방향 고정을 무시하므로, 어떤 버전에서도 같은 동작이 된다.
  static OrientationPolicy orientationPolicyOf(
    DeviceKind kind,
    Size displaySize,
  ) => switch (kind) {
    DeviceKind.phone => OrientationPolicy.portrait,
    DeviceKind.tablet => OrientationPolicy.landscape,
    DeviceKind.foldable =>
      displaySize.shortestSide >= largeScreenMinShortestSide
          ? OrientationPolicy.any
          : OrientationPolicy.portrait,
  };

  /// [policy]로 요청할 방향 목록. 빈 목록은 플랫폼에서 "제한 없음"이 되므로 [OrientationPolicy.any]도
  /// 네 방향을 명시한다.
  static List<DeviceOrientation> preferredOrientationsOf(
    OrientationPolicy policy,
  ) => switch (policy) {
    OrientationPolicy.portrait => const [DeviceOrientation.portraitUp],
    OrientationPolicy.landscape => const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    OrientationPolicy.any => const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
    ],
  };

  /// 접힘선이 창을 다 가로지르는지 볼 때의 허용 오차 (dp)
  static const double _hingeSpanTolerance = 1.0;

  /// 접힘선 기준으로 나눌 때 접힘선 양쪽 각각이 가져야 하는 최소 길이 (dp, 창 좌표·접힘선에 수직인 방향).
  /// 접힘선이 창 가장자리에 치우친 창이나 인셋 안의 접힘선처럼 한쪽 패널(LCD 쪽 포함)이 쓸 수 없게 좁아지는
  /// 경우를 걸러 내는 거친 사전 판정이다. 인셋·화면 여백을 뺀 실제 키패드가 터치 하한을 지키는지는 화면이
  /// 본체 크기로 다시 판정한다(`CalculatorScreen`, `KeypadMetrics.minKeyTouchHeightOf`).
  static const double hingeMinPanelExtent = 280.0;

  /// 창([windowSize], dp)을 한 축으로 끝까지 가로지르는 접히는 부분(fold·hinge). 영역은 창 좌표다.
  /// 없으면 `null`. 화면 구멍(cutout)과, 창 밖에 있거나 창을 끝까지 가로지르지 않는 접힘 정보는 세지 않는다.
  ///
  /// 접힘 정보의 좌표는 그 정보를 담은 `MediaQuery`가 가리키는 화면(창)의 좌표다. 실제 앱에서는 창 = 화면이다.
  static DisplayFeature? hingeOf(
    Size windowSize,
    Iterable<DisplayFeature> features,
  ) {
    const t = _hingeSpanTolerance;
    for (final f in features) {
      if (f.type != DisplayFeatureType.fold &&
          f.type != DisplayFeatureType.hinge) {
        continue;
      }
      final b = f.bounds;
      if (!(b.left.isFinite &&
          b.top.isFinite &&
          b.right.isFinite &&
          b.bottom.isFinite)) {
        continue;
      }
      final spansHeight = b.top <= t && b.bottom >= windowSize.height - t;
      final spansWidth = b.left <= t && b.right >= windowSize.width - t;
      final insideX = b.left >= -t && b.right <= windowSize.width + t;
      final insideY = b.top >= -t && b.bottom <= windowSize.height + t;
      // 세로 접힘선: 위에서 아래까지 정확히 창 높이만큼, 좌우로는 창 안 (가로 접힘선은 반대).
      // 창보다 긴 접힘 정보는 받지 않는다 — 회전 직후 창 크기는 새 값인데 접힘 정보는 이전 방향 값으로
      // 몇 프레임 늦게 올 수 있다(#25 R2). 그동안은 접힘선이 없는 것으로 본다(폴더블이면 위아래 배치).
      if (spansHeight && insideX && insideY && b.width < windowSize.width - t) {
        return f;
      }
      if (spansWidth &&
          insideX &&
          insideY &&
          b.height < windowSize.height - t) {
        return f;
      }
    }
    return null;
  }

  /// [hinge]가 세로 접힘선(위에서 아래로 가로지름)인지. 폭이 0인 접힘선도 판정된다.
  static bool isVerticalHinge(Rect hinge) => hinge.height >= hinge.width;

  /// [hinge]가 화면을 실제로 두 부분으로 나누는지 — 물리 힌지(종류가 hinge이거나 폭이 있음)이거나 반 접힌 상태.
  /// Android `FoldingFeature.isSeparating`(HINGE 종류는 항상 나눔)에 맞추고, Flutter `DisplayFeatureSubScreen`의
  /// 기준(폭이 있거나 반 접힘)을 포함한다.
  static bool separates(DisplayFeature hinge) =>
      hinge.type == DisplayFeatureType.hinge ||
      hinge.bounds.shortestSide > 0 ||
      hinge.state == DisplayFeatureState.postureHalfOpened;

  /// 앱 창([windowSize], dp)의 배치.
  ///
  /// 1. 창을 가로지르는 접힘선([hingeOf]) 양쪽이 모두 [hingeMinPanelExtent] 이상이면 접힘선을 경계로 나눈다 (#25).
  ///    - 세로 접힘선: 항상 [ScreenArrangement.hingeSplit]. 펼친 상태(flat)여도 나눈다 — 주름이 키·글자 한가운데를
  ///      지나지 않게 하는 것이 이슈 요구이고, 좌우로 나눠도 각 절반이 폰 폭이라 키 크기 손해가 작다.
  ///    - 가로 접힘선: 화면을 실제로 나눌 때([separates] — 반 접은 테이블톱 자세, 물리 힌지)만
  ///      [ScreenArrangement.hingeStacked]. 펼친 폭 0 가로 접힘선(Fold 내부 화면을 가로로 돌림, Flip을 펼침)은
  ///      나누지 않는다(아래 2번). #25에서는 나누면 키패드가 아래 절반에 갇혀 터치 하한(28dp) 아래로 작아진다는 것이
  ///      근거였으나, 넓은 키패드 배열(#80)이 생긴 뒤로는 Fold 가로도 나누는 쪽 키가 더 크다(위아래 32.1dp, 나누면
  ///      39.9dp) — 펼친 가로 접힘선을 나눌지는 후속 이슈에서 다시 정한다.
  /// 2. 접힘 정보는 있는데 위 조건에 맞지 않거나, 폴더블 기기([foldableDevice])인데 접힘선이 없으면
  ///    위아래 배치다. 폴더블 내부 화면은 접힘 정보가 창이 붙은 뒤 늦게 오므로, 그 전 몇 프레임 동안
  ///    접힘선을 무시한 좌우 분할로 그렸다가 바뀌는 깜빡임을 막는다. 접은 커버 화면은 어차피 위아래 배치다.
  ///    제약: 폴더블 여부는 기기 단위라, 폴더블을 외부 디스플레이(DeX 등)에 띄운 넓은 창도 위아래 배치다.
  ///    시작 구간에만 기기 단위로 보려면 "접힘 정보가 아직 안 옴"과 "접힘선 없음"을 구분해야 하는데 그런
  ///    신호가 없고, 시간 제한을 두면 펼칠 때마다 배치가 한 번씩 튄다. 드문 경우라 위아래 배치로 둔다 (#25 검토).
  /// 3. 그 밖에는 창 크기로 정한다: 짧은 변이 [largeScreenMinShortestSide] 이상인 가로(폭 > 높이) 창이면
  ///    좌우 분할, 아니면 위아래 배치다. 방향 고정이 무시된 태블릿 세로 화면이나 분할 화면의 좁은 창은
  ///    위아래 배치가 된다.
  ///
  /// 위아래 배치를 돌려받은 창이라도 짧은 변이 [largeScreenMinShortestSide] 미만이면(분할 화면·팝업 창 등), 화면이
  /// 인셋·화면 여백을 뺀 본체 크기로 좌우 분할과 비교해 키가 더 큰 쪽으로 그린다 (`CalculatorScreen`, #38). 접힘선
  /// 기준 배치를 쓸 수 없을 때 위아래 배치로 대체하는 것과 같이, 본체 크기가 필요한 판정은 화면이 한다.
  static ScreenArrangement arrangementOf(
    Size windowSize,
    Iterable<DisplayFeature> features, {
    bool foldableDevice = false,
  }) {
    final hinge = hingeOf(windowSize, features);
    if (hinge != null) {
      final b = hinge.bounds;
      final vertical = isVerticalHinge(b);
      final before = vertical ? b.left : b.top;
      final after = vertical
          ? windowSize.width - b.right
          : windowSize.height - b.bottom;
      if (before >= hingeMinPanelExtent && after >= hingeMinPanelExtent) {
        if (vertical) return ScreenArrangement.hingeSplit;
        if (separates(hinge)) return ScreenArrangement.hingeStacked;
      }
    }
    if (foldableDevice || hasFoldOrHinge(features)) {
      return ScreenArrangement.stacked;
    }
    return windowSize.shortestSide >= largeScreenMinShortestSide &&
            windowSize.width > windowSize.height
        ? ScreenArrangement.split
        : ScreenArrangement.stacked;
  }
}
